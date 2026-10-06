--!strict
-- Sound playback on Roblox's new Audio API: AudioPlayer -> Wire -> bus AudioFader -> AudioDeviceOutput.
-- Buses: sfx, ui, voice, music, ambience (volumes from the player's settings). Missing ids are silent.

local SoundService = game:GetService("SoundService")

local Sounds = require("@game/ReplicatedStorage/Shared/Config/Sounds")
local Store = require("../Store")

local Sound = {}

local buses: { [string]: AudioFader } = {}
local musicPlayer: AudioPlayer? = nil
-- Music runs through its own ducking fader, so voice lines can lower it without touching the
-- player's music volume setting on the music bus.
local musicDuck: AudioFader
local voicesPlaying = 0

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

-- Pitch variance keeps repeated sounds (coins!) from getting annoying.
function Sound.play(name: string, pitchJitter: number?)
	local def = Sounds[name]
	if not def or def.id == "" then
		return
	end
	local bus = buses[def.bus] or buses.sfx
	local player = Instance.new("AudioPlayer")
	player.Asset = def.id
	player.Volume = def.volume or 1
	if pitchJitter then
		player.PlaybackSpeed = 1 + (math.random() * 2 - 1) * pitchJitter
	end
	player.Parent = bus
	wire(player, bus)
	player:Play()
	player.Ended:Once(function()
		player:Destroy()
	end)
	task.delay(10, function()
		if player.Parent then
			player:Destroy()
		end
	end)
end

-- Plays a voice line on the voice bus and ducks the music while any voice is speaking.
local function playVoice(id: string, volume: number?)
	local player = Instance.new("AudioPlayer")
	player.Asset = id
	player.Volume = volume or 1
	player.Parent = buses.voice
	wire(player, buses.voice)
	voicesPlaying += 1
	musicDuck.Volume = 0.35
	local finished = false
	local function finish()
		if finished then
			return
		end
		finished = true
		player:Destroy()
		voicesPlaying -= 1
		if voicesPlaying == 0 then
			musicDuck.Volume = 1
		end
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

function Sound.music(name: string)
	local def = Sounds[name]
	if not def or def.id == "" then
		return
	end
	if musicPlayer then
		musicPlayer:Destroy()
	end
	local player = Instance.new("AudioPlayer")
	player.Asset = def.id
	player.Looping = true
	player.Volume = def.volume or 0.4
	player.Parent = buses.music
	wire(player, buses.music)
	player:Play()
	musicPlayer = player
end

function Sound.start()
	-- Apply volume settings whenever the server sends new state.
	local Vide = require("@game/ReplicatedStorage/Packages/Vide")
	Vide.root(function()
		Vide.effect(function()
			local state = Store.state()
			if state and state.settings then
				buses.music.Volume = state.settings.Music or 0.7
				buses.sfx.Volume = state.settings.Sfx or 1
				buses.ui.Volume = state.settings.Sfx or 1
				buses.voice.Volume = state.settings.Voice or 1
			end
		end)
	end)
	Sound.music("musicCalm")
end

return Sound
