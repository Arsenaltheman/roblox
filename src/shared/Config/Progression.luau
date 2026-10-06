--!strict
-- Retention systems: playtime gifts, eggs, strongboxes, weather, quests, login streak.

export type Gift = {
	minute: number,
	kind: "cash" | "egg" | "nuggets",
	-- cash: seconds of current income (with floor); nuggets: amount; egg: tier offset from band.
	amount: number,
	floor: number?,
}

return {
	-- Playtime gifts (pause while idle). Cash gifts scale with income so they stay meaningful.
	gifts = {
		{ minute = 1, kind = "cash", amount = 60, floor = 250 },
		{ minute = 3, kind = "egg", amount = 1 },
		{ minute = 5, kind = "cash", amount = 120, floor = 500 },
		{ minute = 10, kind = "nuggets", amount = 25 },
		{ minute = 15, kind = "cash", amount = 150, floor = 2000 },
		{ minute = 20, kind = "egg", amount = 1 },
		{ minute = 30, kind = "nuggets", amount = 50 },
		{ minute = 45, kind = "cash", amount = 600, floor = 10000 },
		{ minute = 60, kind = "egg", amount = 2 },
	} :: { Gift },

	eggs = {
		-- A ranch critter lays an egg every this many seconds of play.
		layEverySeconds = 8 * 60,
		maxWaiting = 3,
		-- Hatched tier = parent tier + offset.
		offsets = { 0, 1, 2 },
		offsetWeights = { 75, 22, 3 },
		hatchSeconds = 120,
		-- Hatchery: buy an egg with Gold Nuggets (earned only, never sold).
		hatcheryCost = 60,
	},

	strongbox = {
		-- Loot kinds and weights.
		kinds = { "cash", "nuggets", "egg", "cosmetic" },
		weights = { 45, 25, 20, 10 },
		cashSecondsMin = 60,
		cashSecondsMax = 180,
		nuggetsMin = 10,
		nuggetsMax = 30,
		-- Lucky streak meter: after this many cracks without an egg, the next crack is an egg (+1 tier).
		pity = 6,
	},

	weather = {
		everySeconds = 12 * 60,
		durationSeconds = 2 * 60,
		-- During weather, cages roll that weather's mutation with this chance.
		cageMutationChance = 0.25,
		-- At weather start, each ranch critter rolls this chance to gain the mutation.
		ranchRollChance = 0.1,
	},

	quests = {
		dailyCount = 3,
		-- Rewards: seconds of income + nuggets.
		cashSeconds = 120,
		nuggets = 20,
		-- Daily quests are drawn from this pool (same 3 for everyone on a given UTC day).
		pool = {
			{ id = "buy10", kind = "buy", goal = 10, text = "Lasso 10 critters off the train" },
			{ id = "buy25", kind = "buy", goal = 25, text = "Lasso 25 critters off the train" },
			{ id = "crack3", kind = "crack", goal = 3, text = "Crack 3 strongboxes" },
			{ id = "hatch2", kind = "hatch", goal = 2, text = "Hatch 2 eggs" },
			{ id = "steal1", kind = "steal", goal = 1, text = "Steal a critter from another ranch" },
			{ id = "lasso2", kind = "lasso", goal = 2, text = "Lasso 2 thieves" },
			{ id = "collect20", kind = "collect", goal = 20, text = "Collect your ranch cash 20 times" },
			{ id = "bandit1", kind = "bandit", goal = 1, text = "Rob the Bandit Camp" },
			{ id = "golden1", kind = "goldenbuy", goal = 1, text = "Buy from the Golden Express" },
			{ id = "heist3", kind = "heist", goal = 3, text = "Run 3 heist crates home" },
			{ id = "heist8", kind = "heist", goal = 8, text = "Run 8 heist crates home" },
			{ id = "boss1", kind = "boss", goal = 5, text = "Lasso the Bandit King 5 times" },
		},
	},

	streak = {
		-- Day 1..7 rewards; Day 7 repeats after.
		rewards = {
			{ kind = "cash", amount = 300 },
			{ kind = "egg", amount = 1 },
			{ kind = "nuggets", amount = 40 },
			{ kind = "cash", amount = 900 },
			{ kind = "egg", amount = 2 },
			{ kind = "nuggets", amount = 80 },
			{ kind = "egg", amount = 3 },
		},
		-- One missed day per streak is forgiven.
		graceDays = 1,
	},

	newbieShieldSeconds = 15 * 60,

	-- Timed boosts (earned, never sold): finishing all daily quests gives 2x Cash, helping beat the
	-- Bandit King gives a Luck Potion (2x luck on your reserved cage).
	boosts = {
		questsDoneCashMinutes = 15,
		bossLuckMinutes = 10,
		luckPotion = 2,
	},
}
