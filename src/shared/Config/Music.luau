--!strict
-- Music states and the tracks each one plays. Track ids live in Config/Sounds (keys below); every id
-- is empty until the owner picks licensed tracks in Studio: see docs/MUSIC.md for the mood each slot
-- wants and where to paste the ids. With every id empty the state machine still runs, silently.
--
-- States (highest priority first): boss, tense, event, menu, calm. "reveal" is not a state: the
-- running track is ducked instead (Sound.duck). Controllers/Sound owns the transitions.

export type State = "calm" | "tense" | "event" | "boss" | "menu"

export type Inputs = {
	boss: boolean, -- Workspace attribute BossActive
	tense: boolean, -- player attributes HeistCarry / CarryingFrom ~= 0
	event: boolean, -- Workspace attribute EventId ~= ""
	menu: boolean, -- a shop-style menu is open (Store.menu())
}

local Music = {
	-- Seconds for the outgoing track to fade down while the incoming one fades up.
	CROSSFADE = 1.5,
	-- A state must hold this long before the music follows it, so flickering inputs (dropping and
	-- re-grabbing a crate, a menu opened and closed) never restart a track.
	DEBOUNCE = 2,
	-- Ducking under voices, reveals and stingers: -8 dB, 0.25 s in, 1 s back out.
	DUCK_DB = -8,
	DUCK_ATTACK = 0.25,
	DUCK_RELEASE = 1,
	-- Seconds before the first note while the player's saved volume settings arrive.
	SETTINGS_WAIT = 4,

	-- Which state wins when several inputs are true.
	priority = { "boss", "tense", "event", "menu", "calm" } :: { State },

	-- Track keys (Config/Sounds) per state, and the state's gain on top of the track volume.
	states = {
		calm = { tracks = { "musicCalm1", "musicCalm2", "musicCalm3" }, gain = 1 },
		-- Menus reuse the calm tracks a touch quieter, so browsing the shop never changes the song.
		menu = { tracks = { "musicCalm1", "musicCalm2", "musicCalm3" }, gain = 0.75 },
		tense = { tracks = { "musicTense1", "musicTense2" }, gain = 1 },
		event = { tracks = { "musicEvent1", "musicEvent2" }, gain = 1 },
		boss = { tracks = { "musicBoss1" }, gain = 1 },
	} :: { [State]: { tracks: { string }, gain: number } },

	-- Short one-shots (existing sound keys) played over the music on big moments.
	stingers = {
		heistDeliver = "frontier",
		frontier = "frontier",
		chapter = "frontier",
		eventStart = "goldenExpress",
		bossSpawn = "goldenExpress",
		titleSlam = "whistle",
	} :: { [string]: string },
	-- How long a stinger ducks the music.
	STINGER_DUCK = 2,
}

-- The state the inputs ask for (pure; unit-tested).
function Music.pick(inputs: Inputs): State
	for _, state in Music.priority do
		if state == "calm" or (inputs :: any)[state] == true then
			return state :: State
		end
	end
	return "calm"
end

-- Linear gain for the duck depth.
function Music.duckGain(): number
	return 10 ^ (Music.DUCK_DB / 20)
end

return Music
