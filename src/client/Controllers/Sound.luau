--!strict
-- Sound playback on Roblox's new Audio API: AudioPlayer -> Wire -> bus AudioFader -> AudioDeviceOutput.
-- Buses: sfx, ui, voice, music, ambience (volumes from the player's settings). Missing ids are silent.

local SoundService = game:GetService("SoundService")

local Sounds = require("@game/ReplicatedStorage/Shared/Config/Sounds")
local Store = require("../Store")

local Sound = {}

local buses: { [string]: AudioFader } = {}
local musicPlayer: AudioPlayer? = nil

local function wire(source: Instance, target: Instance)
	local w = Instance.new("Wire")
	w.SourceInstance = source
	w.TargetInstance = target
	w.Parent = target
end

function Sound.init()
	local output = Instance.new("AudioDeviceOutput")
	output.Name = "Output"
	output.Parent = SoundService
	for _, name in { "sfx", "ui", "voice", "music", "ambience" } do
		local fader = Instance.new("AudioFader")
		fader.Name = "Bus_" .. name
		fader.Parent = SoundService
		wire(fader, output)
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

function Sound.voice(speciesId: string)
	local id = Sounds.VoiceIds[speciesId]
	if not id or id == "" then
		return
	end
	local player = Instance.new("AudioPlayer")
	player.Asset = id
	player.Parent = buses.voice
	wire(player, buses.voice)
	-- Duck music under the callout.
	buses.music.Volume = 0.35
	player:Play()
	player.Ended:Once(function()
		player:Destroy()
		buses.music.Volume = 1
	end)
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
