--!strict
-- The Bounty Trail: the long campaign (8 chapters x 5 quests). Every quest has 2-3 objectives and
-- walks the player through another part of the game; each chapter ends by reaching the next
-- Frontier, so the Trail spans the whole ~10 hour curve the economy simulator shows. Weekly bounties
-- sit on top for players who've finished it. Pure data (unit-tested).
--
-- Objective kinds:
--   Counted (from when the quest starts): buy, goldenbuy, collect, lock, crack, hatch, steal, lasso,
--     bandit, heist, heist_z2/heist_z3/heist_z4 (a heist from that zone), heistRare (Rare or better
--     crate), crateRain (Crate Rain crate run home), boss (lasso hits on the Bandit King), bossWin,
--     spin, gear (gear uses).
--   Checked (current state): frontier, boots, income ($/s), almanac (species found), sets (Almanac
--     rarity sets done), gearOwned, bestTier, mutated (owns a mutated critter).

export type Objective = { kind: string, goal: number, text: string }
export type Quest = { name: string, objectives: { Objective } }
export type Chapter = { name: string, title: string, blurb: string, quests: { Quest } }

local function o(kind: string, goal: number, text: string): Objective
	return { kind = kind, goal = goal, text = text }
end

local chapters: { Chapter } = {
	{
		name = "Greenhorn",
		title = "title_greenhorn",
		blurb = "Every legend starts with one dusty critter.",
		quests = {
			{
				name = "Off the Train",
				objectives = {
					o("buy", 5, "Lasso 5 critters off the train"),
					o("collect", 3, "Collect your ranch cash 3 times"),
				},
			},
			{
				name = "Home on the Range",
				objectives = {
					o("lock", 1, "Lock your ranch gate"),
					o("collect", 10, "Collect your ranch cash 10 times"),
				},
			},
			{
				name = "First Heist",
				objectives = {
					o("heist", 1, "Run a heist crate home from Cactus Flats"),
					o("spin", 1, "Spin the Prize Wheel"),
				},
			},
			{
				name = "Egg-cellent",
				objectives = { o("hatch", 1, "Hatch an egg"), o("income", 150, "Earn $150/s") },
			},
			{
				name = "Frontier Fever",
				objectives = {
					o("heist", 3, "Run 3 more heist crates home"),
					o("frontier", 1, "Reach Frontier 1"),
				},
			},
		},
	},
	{
		name = "Deputy",
		title = "title_deputy",
		blurb = "The sheriff's got a badge with your name on it.",
		quests = {
			{
				name = "Stock the Pens",
				objectives = {
					o("buy", 15, "Lasso 15 critters off the train"),
					o("crack", 2, "Crack 2 strongboxes"),
				},
			},
			{
				name = "Canyon Run",
				objectives = {
					o("heist", 5, "Run 5 heist crates home"),
					o("heist_z2", 1, "Pull a heist in Rattlesnake Canyon"),
				},
			},
			{
				name = "Fast Feet",
				objectives = {
					o("boots", 2, "Upgrade Speed Boots to level 2"),
					o("gear", 3, "Use gear 3 times"),
				},
			},
			{
				name = "Law and Order",
				objectives = { o("lasso", 2, "Lasso 2 thieves"), o("bandit", 1, "Rob the Bandit Camp") },
			},
			{
				name = "Badge Earned",
				objectives = { o("almanac", 12, "Discover 12 species"), o("frontier", 2, "Reach Frontier 2") },
			},
		},
	},
	{
		name = "Outlaw",
		title = "title_outlaw",
		blurb = "Rules are for folks without a fast horse.",
		quests = {
			{
				name = "Sticky Fingers",
				objectives = {
					o("steal", 2, "Steal 2 critters from other ranches"),
					o("heist", 8, "Run 8 heist crates home"),
				},
			},
			{
				name = "Strange Weather",
				objectives = { o("mutated", 1, "Own a mutated critter"), o("hatch", 3, "Hatch 3 eggs") },
			},
			{
				name = "Gold on the Rails",
				objectives = {
					o("goldenbuy", 1, "Buy from the Golden Express"),
					o("crack", 5, "Crack 5 strongboxes"),
				},
			},
			{
				name = "It's Raining Crates",
				objectives = {
					o("crateRain", 1, "Run a Crate Rain crate home"),
					o("spin", 3, "Spin the Prize Wheel 3 times"),
				},
			},
			{
				name = "Wanted Poster",
				objectives = {
					o("sets", 1, "Complete an Almanac rarity set"),
					o("frontier", 3, "Reach Frontier 3"),
				},
			},
		},
	},
	{
		name = "Gunslinger",
		title = "title_gunslinger",
		blurb = "Quick on the lasso, quicker on the getaway.",
		quests = {
			{
				name = "Into the Mine",
				objectives = {
					o("heist_z3", 2, "Pull 2 heists in the Gold Mine"),
					o("boots", 4, "Upgrade Speed Boots to level 4"),
				},
			},
			{
				name = "Rare Haul",
				objectives = {
					o("heistRare", 3, "Run 3 Rare-or-better crates home"),
					o("collect", 40, "Collect your ranch cash 40 times"),
				},
			},
			{
				name = "Rope the King",
				objectives = {
					o("boss", 10, "Lasso the Bandit King 10 times"),
					o("lasso", 4, "Lasso 4 thieves"),
				},
			},
			{
				name = "Fully Loaded",
				objectives = { o("gearOwned", 2, "Own 2 pieces of gear"), o("gear", 10, "Use gear 10 times") },
			},
			{
				name = "Fastest in the West",
				objectives = { o("income", 300000, "Earn $300K/s"), o("frontier", 4, "Reach Frontier 4") },
			},
		},
	},
	{
		name = "Marshal",
		title = "title_marshal_trail",
		blurb = "The whole frontier answers to you now.",
		quests = {
			{
				name = "Heist Season",
				objectives = { o("heist", 20, "Run 20 heist crates home"), o("steal", 5, "Steal 5 critters") },
			},
			{
				name = "Down with the King",
				objectives = {
					o("bossWin", 1, "Help beat the Bandit King"),
					o("spin", 6, "Spin the Prize Wheel 6 times"),
				},
			},
			{
				name = "Naturalist",
				objectives = { o("almanac", 25, "Discover 25 species"), o("hatch", 6, "Hatch 6 eggs") },
			},
			{
				name = "Ghost Stories",
				objectives = {
					o("heist_z4", 1, "Pull a heist in Ghost Town"),
					o("boots", 6, "Upgrade Speed Boots to level 6"),
				},
			},
			{
				name = "Legendary Ranch",
				objectives = {
					o("bestTier", 25, "Own a Legendary critter"),
					o("frontier", 5, "Reach Frontier 5"),
				},
			},
		},
	},
	{
		name = "Bounty Hunter",
		title = "title_bountyhunter",
		blurb = "Every outlaw in the territory knows your name.",
		quests = {
			{
				name = "Big Score",
				objectives = {
					o("heist", 35, "Run 35 heist crates home"),
					o("heistRare", 10, "Run 10 Rare-or-better crates home"),
				},
			},
			{
				name = "Safecracker",
				objectives = {
					o("crack", 10, "Crack 10 strongboxes"),
					o("goldenbuy", 3, "Buy 3 times from the Golden Express"),
				},
			},
			{
				name = "Storm Chaser",
				objectives = {
					o("crateRain", 5, "Run 5 Crate Rain crates home"),
					o("spin", 10, "Spin the Prize Wheel 10 times"),
				},
			},
			{
				name = "Collector",
				objectives = {
					o("sets", 3, "Complete 3 Almanac rarity sets"),
					o("lasso", 10, "Lasso 10 thieves"),
				},
			},
			{
				name = "Cattle Baron",
				objectives = { o("income", 40000000, "Earn $40M/s"), o("frontier", 6, "Reach Frontier 6") },
			},
		},
	},
	{
		name = "Legend",
		title = "title_legend_trail",
		blurb = "They sing songs about you at the saloon.",
		quests = {
			{
				name = "Haunted Haul",
				objectives = {
					o("heist_z4", 10, "Pull 10 heists in Ghost Town"),
					o("boots", 8, "Upgrade Speed Boots to level 8"),
				},
			},
			{
				name = "Kingslayer",
				objectives = {
					o("bossWin", 3, "Help beat the Bandit King 3 times"),
					o("boss", 60, "Lasso the Bandit King 60 times"),
				},
			},
			{
				name = "Most Wanted",
				objectives = { o("steal", 15, "Steal 15 critters"), o("gear", 40, "Use gear 40 times") },
			},
			{
				name = "Mythic Hunter",
				objectives = {
					o("almanac", 32, "Discover 32 species"),
					o("bestTier", 30, "Own a Mythic critter"),
				},
			},
			{
				name = "Living Legend",
				objectives = {
					o("heist", 60, "Run 60 heist crates home"),
					o("frontier", 7, "Reach Frontier 7"),
				},
			},
		},
	},
	{
		name = "King of the West",
		title = "title_king",
		blurb = "One last ride to the top of the frontier.",
		quests = {
			{
				name = "Grand Larceny",
				objectives = {
					o("heist", 80, "Run 80 heist crates home"),
					o("heistRare", 30, "Run 30 Rare-or-better crates home"),
				},
			},
			{
				name = "Full Almanac",
				objectives = {
					o("sets", 5, "Complete 5 Almanac rarity sets"),
					o("hatch", 15, "Hatch 15 eggs"),
				},
			},
			{
				name = "Royal Rumble",
				objectives = {
					o("bossWin", 6, "Help beat the Bandit King 6 times"),
					o("crateRain", 15, "Run 15 Crate Rain crates home"),
				},
			},
			{
				name = "Armed to the Teeth",
				objectives = {
					o("gearOwned", 6, "Own 6 pieces of gear"),
					o("boots", 10, "Max out Speed Boots"),
				},
			},
			{
				name = "King of the West",
				objectives = {
					o("almanac", 36, "Discover 36 species"),
					o("frontier", 8, "Reach Frontier 8"),
				},
			},
		},
	},
}

-- Weekly bounties: 4 per week (same for everyone), bigger goals.
local weeklyPool: { Objective } = {
	o("heist", 50, "Run 50 heist crates home"),
	o("boss", 30, "Lasso the Bandit King 30 times"),
	o("hatch", 15, "Hatch 15 eggs"),
	o("steal", 20, "Steal 20 critters"),
	o("crack", 20, "Crack 20 strongboxes"),
	o("crateRain", 10, "Run 10 Crate Rain crates home"),
	o("spin", 20, "Spin the Prize Wheel 20 times"),
	o("buy", 150, "Lasso 150 critters off the train"),
	o("heist_z4", 15, "Pull 15 heists in Ghost Town"),
	o("gear", 50, "Use gear 50 times"),
	o("heistRare", 20, "Run 20 Rare-or-better crates home"),
	o("lasso", 15, "Lasso 15 thieves"),
}

local COUNTED = {
	buy = true,
	goldenbuy = true,
	collect = true,
	lock = true,
	crack = true,
	hatch = true,
	steal = true,
	lasso = true,
	bandit = true,
	heist = true,
	heist_z2 = true,
	heist_z3 = true,
	heist_z4 = true,
	heistRare = true,
	crateRain = true,
	boss = true,
	bossWin = true,
	spin = true,
	gear = true,
}
local CHECKED = {
	frontier = true,
	boots = true,
	income = true,
	almanac = true,
	sets = true,
	gearOwned = true,
	bestTier = true,
	mutated = true,
}

return {
	chapters = chapters,
	weeklyPool = weeklyPool,
	WEEKLY_COUNT = 4,
	counted = COUNTED,
	checked = CHECKED,
	-- Rewards. Quest: cash = seconds of your income, plus nuggets; every 3rd and 5th quest adds spins.
	questCashSeconds = function(chapter: number): number
		return 240 + 60 * chapter
	end,
	questNuggets = function(chapter: number): number
		return 15 + 10 * chapter
	end,
	questCashFloor = 500,
	finaleSpins = 3,
	finaleNuggets = function(chapter: number): number
		return 100 * chapter
	end,
	finaleBoostMinutes = 20,
	weeklyNuggets = 250,
	weeklySpins = 2,
	weeklyAllNuggets = 500,
	weeklyAllLuckMinutes = 30,
}
