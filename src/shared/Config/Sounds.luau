--!strict
-- Sound asset ids. Empty until the audio is uploaded (docs/STATUS.md); empty ids play nothing.
-- Each key's file is assets/audio/game/<key>.ogg (voice lines: assets/audio/game/voice/<key>.ogg).
-- Prompts for every generated sound are logged in assets/audio/PROMPTS.md.

local AssetIds = require("./AssetIds")

export type SoundDef = { id: string, volume: number?, bus: "sfx" | "ui" | "voice" | "music" | "ambience" }

local Sounds = {
	-- UI
	click = { id = "", bus = "ui", volume = 0.6 },
	toast = { id = "", bus = "ui", volume = 0.5 },
	giftReady = { id = "", bus = "ui" },
	-- Economy
	coin = { id = "", bus = "sfx", volume = 0.5 },
	collect = { id = "", bus = "sfx" },
	buy = { id = "", bus = "sfx" },
	-- Train
	whistle = { id = "", bus = "sfx", volume = 0.8 },
	doors = { id = "", bus = "sfx" },
	-- Lasso / theft
	lassoThrow = { id = "", bus = "sfx" },
	lassoCatch = { id = "", bus = "sfx" },
	alarm = { id = "", bus = "sfx" },
	stolen = { id = "", bus = "sfx" },
	caught = { id = "", bus = "sfx" },
	lock = { id = "", bus = "sfx" },
	-- Reveal
	eggWobble = { id = "", bus = "sfx" },
	eggCrack = { id = "", bus = "sfx" },
	revealCommon = { id = "", bus = "sfx" },
	revealRare = { id = "", bus = "sfx" },
	revealEpic = { id = "", bus = "sfx" },
	revealLegendary = { id = "", bus = "sfx" },
	revealMythic = { id = "", bus = "sfx" },
	revealSecret = { id = "", bus = "sfx" },
	strongboxOpen = { id = "", bus = "sfx" },
	frontier = { id = "", bus = "sfx" },
	-- World
	weatherStart = { id = "", bus = "ambience" },
	goldenExpress = { id = "", bus = "sfx" },
	-- Announcer (voice bus; ducks the music)
	ann_itsA = { id = "", bus = "voice" },
	ann_trainArriving = { id = "", bus = "voice" },
	ann_goldenExpress = { id = "", bus = "voice" },
	ann_thief = { id = "", bus = "voice" },
	ann_frontier = { id = "", bus = "voice" },
	ann_weather = { id = "", bus = "voice" },
	ann_strongbox = { id = "", bus = "voice" },
	-- Music: licensed Creator Store tracks picked by the owner in Studio (Toolbox -> Audio -> Music,
	-- Roblox-licensed/APM). See docs/MUSIC.md for each slot's mood. Paste the "rbxassetid://..." into
	-- the id below; Config/Music maps these keys to states (calm/menu, tense, event, boss).
	-- Calm (town): 90-110 BPM, acoustic guitar, banjo, whistling, harmonica; light, loopable.
	musicCalm1 = { id = "", bus = "music", volume = 0.4 },
	musicCalm2 = { id = "", bus = "music", volume = 0.4 },
	musicCalm3 = { id = "", bus = "music", volume = 0.4 },
	-- Tense (carrying a heist crate or a stolen critter): 130-150 BPM galloping drums, muted guitar.
	musicTense1 = { id = "", bus = "music", volume = 0.45 },
	musicTense2 = { id = "", bus = "music", volume = 0.45 },
	-- Event (server event running): 120-140 BPM, brass + fiddle, celebratory saloon energy.
	musicEvent1 = { id = "", bus = "music", volume = 0.45 },
	musicEvent2 = { id = "", bus = "music", volume = 0.45 },
	-- Boss (Bandit King on the map): 80-100 BPM, low drums, bass, sparse twangy guitar stabs.
	musicBoss1 = { id = "", bus = "music", volume = 0.5 },
	-- Critter name callouts, keyed by species id (files: assets/audio/game/voice/<SpeciesId>.ogg).
	VoiceIds = AssetIds.voice,
} :: any

for key, def in Sounds do
	if type(def) == "table" and def.bus and def.id == "" then
		def.id = AssetIds.audio[key] or ""
	end
end

return Sounds
