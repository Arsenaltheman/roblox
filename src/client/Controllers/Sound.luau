--!strict
-- Sound playback on Roblox's new Audio API: AudioPlayer -> Wire -> bus AudioFader -> AudioDeviceOutput.
-- Buses: sfx, ui, voice, music, ambience. Settings (Store.state().settings): Music -> music bus,
-- Sfx -> sfx + ui + ambience buses, Voice -> voice bus, Muted -> everything. Missing ids are silent.
--
-- Music is a small state machine over Config/Music (calm / menu / tense / event / boss) with
-- crossfades, a 2 s debounce and a ducking fader (voices, reveals, stingers) in front of the music bus.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Music = require("@game/ReplicatedStorage/Shared/Config/Music")
local Sounds = require("@game/ReplicatedStorage/Shared/Config/Sounds")
local Store = require("../Store")

local Sound = {}

local buses: { [string]: AudioFader } = {}
-- Music runs through its own ducking fader, so voice lines can lower it without touching the
-- player's music volume setting on the music bus.
local musicDuck: AudioFader
local duckers: { [string]: number } = {} -- tag -> count of active duck requests

-- Default pitch jitter (fraction of playback speed) for sounds that repeat a lot.
local JITTER: { [string]: number } = {
	coin = 0.08,
	click = 0.05,
	collect = 0.04,
	eggWobble = 0.03,
	lassoThrow = 0.05,
	caught = 0.04,
	lock = 0.04,
}
-- Layers: extra one-shots played with a key ({ key, delay, jitter }).
local LAYERS: { [string]: { { string | number } } } = {
	buy = { { "coin", 0.08, 0.1 } },
	collect = { { "coin", 0.05, 0.12 } },
	strongboxOpen = { { "coin", 0.3, 0.1 } },
}
-- Simultaneous instances per key; more are dropped (coins during a collect shower).
local MAX_INSTANCES = 4
local playing: { [string]: number } = {}

-- Distance attenuation for world sounds: full volume up to NEAR, silent beyond FAR studs.
local NEAR, FAR = 20, 150

local function wire(source: Instance, target: Instance)
	local w = Instance.new("Wire")
	w.SourceInstance = source
	w.TargetInstance = target
	-- Parent to the source so the wire goes away with a finished AudioPlayer (buses live forever).
	w.Parent = source
end

function Sound.init()
	local output = Instance.new("AudioDeviceOutput")
	output.Name = "Output"
	output.Parent = SoundService
	musicDuck = Instance.new("AudioFader")
	musicDuck.Name = "MusicDuck"
	musicDuck.Parent = SoundService
	wire(musicDuck, output)
	for _, name in { "sfx", "ui", "voice", "music", "ambience" } do
		local fader = Instance.new("AudioFader")
		fader.Name = "Bus_" .. name
		fader.Parent = SoundService
		wire(fader, if name == "music" then musicDuck else output)
		buses[name] = fader
	end
end

-- One-shots -------------------------------------------------------------------------------------

local function oneShot(name: string, pitchJitter: number?, gain: number)
	local def = Sounds[name]
	if not def or def.id == "" or gain <= 0 then
		return
	end
	if (playing[name] or 0) >= MAX_INSTANCES then
		return
	end
	local bus = buses[def.bus] or buses.sfx
	local player = Instance.new("AudioPlayer")
	player.Asset = def.id
	player.Volume = (def.volume or 1) * gain
	local jitter = pitchJitter or JITTER[name]
	if jitter then
		player.PlaybackSpeed = 1 + (math.random() * 2 - 1) * jitter
	end
	player.Parent = bus
	wire(player, bus)
	playing[name] = (playing[name] or 0) + 1
	local done = false
	local function finish()
		if done then
			return
		end
		done = true
		playing[name] -= 1
		player:Destroy()
	end
	player.Ended:Once(finish)
	task.delay(10, finish)
	player:Play()
	local layers = LAYERS[name]
	if layers then
		for _, layer in layers do
			task.delay(layer[2] :: number, oneShot, layer[1] :: string, layer[3] :: number, gain)
		end
	end
end

-- Pitch variance keeps repeated sounds (coins!) from getting annoying; common keys jitter by default.
function Sound.play(name: string, pitchJitter: number?)
	oneShot(name, pitchJitter, 1)
end

-- Gain (0..1) for a world position: 1 within NEAR studs of the camera, 0 beyond `range` (default FAR).
function Sound.gainAt(position: Vector3, range: number?): number
	local camera = Workspace.CurrentCamera
	local far = range or FAR
	if not camera or far <= NEAR then
		return 1
	end
	local distance = (camera.CFrame.Position - position).Magnitude
	return 1 - math.clamp((distance - NEAR) / (far - NEAR), 0, 1)
end

-- A one-shot happening at a world position: quieter with distance, skipped when out of range.
function Sound.playAt(name: string, position: Vector3, pitchJitter: number?, range: number?)
	oneShot(name, pitchJitter, Sound.gainAt(position, range))
end

-- Ducking ---------------------------------------------------------------------------------------

-- Holds the music down while `tag` is active (voice, reveal, stinger); nested requests stack.
function Sound.duck(tag: string, on: boolean)
	local n = (duckers[tag] or 0) + (if on then 1 else -1)
	if n > 0 then
		duckers[tag] = n
	else
		duckers[tag] = nil
	end
end

-- Ducks for a fixed time (stingers).
local function duckFor(tag: string, seconds: number)
	Sound.duck(tag, true)
	task.delay(seconds, Sound.duck, tag, false)
end

-- Voices ----------------------------------------------------------------------------------------

-- Plays a voice line on the voice bus and ducks the music while any voice is speaking.
local function playVoice(id: string, volume: number?)
	local player = Instance.new("AudioPlayer")
	player.Asset = id
	player.Volume = volume or 1
	player.Parent = buses.voice
	wire(player, buses.voice)
	Sound.duck("voice", true)
	local finished = false
	local function finish()
		if finished then
			return
		end
		finished = true
		player:Destroy()
		Sound.duck("voice", false)
	end
	player.Ended:Once(finish)
	task.delay(8, finish)
	player:Play()
end

-- A critter's name callout ("Cactus Carl!").
function Sound.voice(speciesId: string)
	local id = Sounds.VoiceIds[speciesId]
	if id and id ~= "" then
		playVoice(id)
	end
end

-- An announcer line from Config/Sounds (keys starting with "ann_").
function Sound.announce(name: string)
	local def = Sounds[name]
	if def and def.id ~= "" then
		playVoice(def.id, def.volume)
	end
end

-- Music -----------------------------------------------------------------------------------------

type Track = { player: AudioPlayer, key: string, state: string, target: number, peak: number }

local tracks: { Track } = {} -- every live music player (the current one plus any fading out)
local currentState: string? = nil -- the state the music is playing
local wantedState: string = "calm" -- the state the inputs ask for
local wantedSince = 0 -- when wantedState last changed
local lastKey: { [string]: string } = {} -- last track per state, to avoid repeats
local musicArmed = false -- settings arrived (or timed out): the first note may play
local menuOpen = false

local function trackVolume(key: string, state: string): number
	local def = Sounds[key]
	return (def and def.volume or 0.4) * ((Music.states :: any)[state].gain or 1)
end

local function pickKey(state: string): string?
	local def = (Music.states :: any)[state]
	local options = {}
	for _, key in def.tracks do
		local sound = Sounds[key]
		if sound and sound.id ~= "" and (key ~= lastKey[state] or #def.tracks == 1) then
			table.insert(options, key)
		end
	end
	if #options == 0 then
		local only = lastKey[state]
		return if only and Sounds[only] and Sounds[only].id ~= "" then only else nil
	end
	return options[math.random(#options)]
end

-- Crossfades to `state`: the current track fades out; a still-fading track of the new state is
-- revived in place (a state that flickered back never restarts its song).
local function switchTo(state: string)
	currentState = state
	local revived = false
	for _, t in tracks do
		if t.state == state and not revived then
			t.target = t.peak
			revived = true
		else
			t.target = 0
		end
	end
	if revived then
		return
	end
	local key = pickKey(state)
	if not key then
		return -- no licensed track for this state yet: silence, no error
	end
	lastKey[state] = key
	local def = Sounds[key]
	local player = Instance.new("AudioPlayer")
	player.Asset = def.id
	player.Looping = true
	player.Volume = 0
	player.Parent = buses.music
	wire(player, buses.music)
	player:Play()
	table.insert(tracks, {
		player = player,
		key = key,
		state = state,
		target = trackVolume(key, state),
		peak = trackVolume(key, state),
	})
end

local function readInputs(): Music.Inputs
	local player = Players.LocalPlayer
	local carryingFrom = player and player:GetAttribute("CarryingFrom")
	local eventId = Workspace:GetAttribute("EventId")
	return {
		boss = Workspace:GetAttribute("BossActive") == true,
		tense = (player ~= nil and player:GetAttribute("HeistCarry") == true)
			or (type(carryingFrom) == "number" and carryingFrom ~= 0),
		event = type(eventId) == "string" and eventId ~= "",
		menu = menuOpen,
	}
end

-- One frame of the music machine: debounce, crossfade volumes, ducking curve.
local function step(dt: number)
	local now = os.clock()
	local wanted = Music.pick(readInputs())
	if wanted ~= wantedState then
		wantedState = wanted
		wantedSince = now
	end
	if musicArmed and wantedState ~= currentState then
		-- The first state plays at once; later changes must hold for DEBOUNCE seconds.
		if currentState == nil or now - wantedSince >= Music.DEBOUNCE then
			switchTo(wantedState)
		end
	end
	-- Crossfade.
	local rate = dt / Music.CROSSFADE
	for i = #tracks, 1, -1 do
		local t = tracks[i]
		local v = t.player.Volume
		if math.abs(t.target - v) <= rate * t.peak then
			v = t.target
		else
			v += math.sign(t.target - v) * rate * t.peak
		end
		t.player.Volume = v
		if t.target == 0 and v <= 0 then
			t.player:Destroy()
			table.remove(tracks, i)
		end
	end
	-- Duck: fast attack, slow release.
	local ducked = next(duckers) ~= nil
	local goal = if ducked then Music.duckGain() else 1
	local cur = musicDuck.Volume
	local speed = if ducked
		then (1 - Music.duckGain()) / Music.DUCK_ATTACK
		else (1 - Music.duckGain()) / Music.DUCK_RELEASE
	if math.abs(goal - cur) <= speed * dt then
		musicDuck.Volume = goal
	else
		musicDuck.Volume = cur + math.sign(goal - cur) * speed * dt
	end
end

-- The state the music is in right now (nil before the first note).
function Sound.musicState(): string?
	return currentState
end

-- A short one-shot over the music for a big moment (Config/Music.stingers), ducking the music briefly.
function Sound.stinger(event: string)
	local key = Music.stingers[event]
	if key and Sounds[key] and Sounds[key].id ~= "" then
		duckFor("stinger", Music.STINGER_DUCK)
		Sound.play(key)
	end
end

-- Settings --------------------------------------------------------------------------------------

local function applySettings(settings: any)
	local muted = settings.Muted == true
	local music = if muted then 0 else settings.Music or 0.7
	local sfx = if muted then 0 else settings.Sfx or 1
	local voice = if muted then 0 else settings.Voice or 1
	buses.music.Volume = music
	buses.sfx.Volume = sfx
	buses.ui.Volume = sfx
	buses.ambience.Volume = sfx
	buses.voice.Volume = voice
end

-- Menus that count as "browsing" for the music (the wheel and reveals keep the game music).
local MENUS = {
	shop = true,
	eggs = true,
	wardrobe = true,
	trade = true,
	quests = true,
	almanac = true,
	frontier = true,
	settings = true,
	boots = true,
	offer = true,
}

function Sound.start()
	local Vide = require("@game/ReplicatedStorage/Packages/Vide")
	Vide.root(function()
		-- Apply volume settings whenever the server sends new state; the first snapshot arms the music
		-- so the saved Music volume is in place before the first note.
		Vide.effect(function()
			local state = Store.state()
			if state and state.settings then
				applySettings(state.settings)
				musicArmed = true
			end
		end)
		Vide.effect(function()
			menuOpen = MENUS[Store.menu()] == true
		end)
	end)
	-- No snapshot yet (Studio, slow join): start with the defaults rather than stay silent.
	task.delay(Music.SETTINGS_WAIT, function()
		if not musicArmed then
			applySettings({})
			musicArmed = true
		end
	end)
	wantedSince = os.clock()
	RunService.Heartbeat:Connect(step)
end

return Sound
