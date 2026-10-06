--!strict
-- Sound asset ids. Empty until the audio is uploaded (docs/STATUS.md); empty ids play nothing.
-- Generated sounds live in assets/audio/ with their prompts logged in assets/audio/PROMPTS.md.

export type SoundDef = { id: string, volume: number?, bus: "sfx" | "ui" | "voice" | "music" | "ambience" }

return {
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
	-- Music (Creator Store licensed tracks)
	musicCalm = { id = "", bus = "music", volume = 0.4 },
	musicChase = { id = "", bus = "music", volume = 0.45 },
	-- Announcer and critter name callouts are keyed "voice_<SpeciesId>" in VoiceIds below.
	VoiceIds = {} :: { [string]: string },
} :: any
