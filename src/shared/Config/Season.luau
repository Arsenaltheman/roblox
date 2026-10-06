--!strict
-- The Rail Pass: 8-week seasons with a free track (20 tiers) and a premium track (40 tiers), season
-- XP from the things players already do, and weekly contracts. Pure data + date maths, unit-tested.
--
-- Honesty rules: the season countdown is the real season end; premium sells perks and cosmetics
-- (never heist power); the pass unlocks the premium track for THIS season only, retroactively.

export type Reward = {
	-- cash: seconds of income; nuggets/spins: amount; luck/doubleCash: boost minutes;
	-- title/hat: cosmetic id in `id`.
	kind: "cash" | "nuggets" | "spins" | "luck" | "doubleCash" | "title" | "hat",
	amount: number,
	id: string?,
	text: string,
}

export type Contract = { kind: string, goal: number, text: string, nuggets: number }

local Season = {}

-- Season 1 starts Monday 2026-10-05 00:00 UTC. Seasons are 8 weeks, weeks roll over Monday 00:00 UTC.
Season.EPOCH = 1791158400
Season.WEEKS = 8
Season.SECONDS = Season.WEEKS * 7 * 86400
Season.FREE_TIERS = 20
Season.PREMIUM_TIERS = 40

-- XP per action (via Progression.questEvent). `collect` is already throttled server-side.
Season.xpFor = {
	heist = 20,
	heistRare = 30,
	steal = 25,
	lasso = 15,
	buy = 3,
	hatch = 10,
	crack = 10,
	boss = 5,
	bossWin = 60,
	spin = 5,
	collect = 1,
	crateRain = 20,
} :: { [string]: number }
Season.DAILY_QUEST_XP = 50
Season.WEEKLY_BOUNTY_XP = 150
Season.CONTRACT_XP = 400
-- Generous daily ceiling: a human can't hit it in normal play, a bot can't farm past it.
Season.XP_DAY_CAP = 1500

Season.CONTRACTS_FREE = 4
Season.CONTRACTS_PREMIUM = 6

-- Per-season accent (title tag colour and the Season Stetson). Cycles so every season looks distinct.
local COLORS = { "#3FB7B0", "#E2463A", "#9A5AFF", "#FF8C28", "#4E9A4B", "#FF5FD2" }

function Season.color(season: number): string
	return COLORS[(math.max(1, season) - 1) % #COLORS + 1]
end

-- ---------------------------------------------------------------- dates

function Season.seasonOf(unix: number): number
	return math.max(1, math.floor((unix - Season.EPOCH) / Season.SECONDS) + 1)
end

function Season.seasonStartsAt(season: number): number
	return Season.EPOCH + (season - 1) * Season.SECONDS
end

function Season.seasonEndsAt(unix: number): number
	return Season.seasonStartsAt(Season.seasonOf(unix)) + Season.SECONDS
end

-- Absolute week number (same numbering as Sim/Trail.week: weeks start Monday 00:00 UTC).
function Season.week(unix: number): number
	return math.floor((unix + 3 * 86400) / (7 * 86400))
end

function Season.weekEndsAt(week: number): number
	return (week + 1) * 7 * 86400 - 3 * 86400
end

-- 1..8 within the season (clamped before the epoch).
function Season.weekOfSeason(unix: number): number
	local start = Season.seasonStartsAt(Season.seasonOf(unix))
	return math.clamp(math.floor((unix - start) / (7 * 86400)) + 1, 1, Season.WEEKS)
end

-- ---------------------------------------------------------------- tiers

-- XP needed to go from tier-1 to tier. Rises gently so late tiers feel earned, not walled.
function Season.tierXp(tier: number): number
	return 100 + 25 * tier
end

-- Total XP at which `tier` is reached.
function Season.totalXp(tier: number): number
	local total = 0
	for t = 1, tier do
		total += Season.tierXp(t)
	end
	return total
end

-- Tier reached with `xp` (0..PREMIUM_TIERS), plus XP into the next tier and that tier's size.
function Season.tierAt(xp: number): (number, number, number)
	local tier = 0
	local remaining = math.max(0, xp)
	while tier < Season.PREMIUM_TIERS and remaining >= Season.tierXp(tier + 1) do
		remaining -= Season.tierXp(tier + 1)
		tier += 1
	end
	if tier >= Season.PREMIUM_TIERS then
		return tier, 0, 0
	end
	return tier, remaining, Season.tierXp(tier + 1)
end

-- Free track (tiers 1..20): cash / Nuggets / a spin, and a Luck Potion every 5 tiers.
function Season.freeReward(tier: number): Reward?
	if tier < 1 or tier > Season.FREE_TIERS then
		return nil
	end
	if tier % 5 == 0 then
		return { kind = "luck", amount = 20, text = "Luck Potion (20 min)" }
	elseif tier % 3 == 1 then
		local seconds = 300 + 60 * tier
		return { kind = "cash", amount = seconds, text = `{math.floor(seconds / 60)} min of income` }
	elseif tier % 3 == 2 then
		local n = 20 + 5 * tier
		return { kind = "nuggets", amount = n, text = `{n} Nuggets` }
	end
	return { kind = "spins", amount = 1, text = "1 spin" }
end

-- Premium track (tiers 1..40): more Nuggets, spins, 2x Cash boosts, the season title at 20 and the
-- Season Stetson at 40. Perks and looks only.
function Season.premiumReward(tier: number): Reward?
	if tier < 1 or tier > Season.PREMIUM_TIERS then
		return nil
	end
	if tier == Season.FREE_TIERS then
		return { kind = "title", amount = 0, id = "title_season", text = "Season title" }
	elseif tier == Season.PREMIUM_TIERS then
		return { kind = "hat", amount = 0, id = "hat_season", text = "Season Stetson" }
	elseif tier % 4 == 0 then
		return { kind = "doubleCash", amount = 20, text = "2x Cash (20 min)" }
	elseif tier % 2 == 1 then
		local n = 40 + 10 * tier
		return { kind = "nuggets", amount = n, text = `{n} Nuggets` }
	end
	return { kind = "spins", amount = 2, text = "2 spins" }
end

-- ---------------------------------------------------------------- weekly contracts

local function c(kind: string, goal: number, text: string, nuggets: number): Contract
	return { kind = kind, goal = goal, text = text, nuggets = nuggets }
end

Season.contractPool = {
	c("heist", 25, "Run 25 heist crates home", 150),
	c("lasso", 10, "Lasso 10 thieves", 150),
	c("hatch", 8, "Hatch 8 eggs", 120),
	c("bossWin", 2, "Help beat the Bandit King twice", 200),
	c("steal", 6, "Steal 6 critters", 150),
	c("buy", 60, "Lasso 60 critters off the train", 120),
	c("spin", 12, "Spin the Prize Wheel 12 times", 120),
	c("crack", 12, "Crack 12 strongboxes", 150),
	c("heistRare", 10, "Run 10 Rare-or-better crates home", 180),
	c("gear", 30, "Use gear 30 times", 120),
} :: { Contract }

-- Pool indices for a week: deterministic from season + week (same for everyone, every server).
-- The first CONTRACTS_FREE are for everyone; pass holders also get the rest up to CONTRACTS_PREMIUM.
function Season.contracts(season: number, week: number): { number }
	local pool = Season.contractPool
	local seed = ((season * 1000 + week) * 1103515245 + 12345) % 2147483648
	local indices = {}
	for i = 1, #pool do
		indices[i] = i
	end
	for i = #indices, 2, -1 do
		seed = (seed * 1103515245 + 12345) % 2147483648
		local j = (seed % i) + 1
		indices[i], indices[j] = indices[j], indices[i]
	end
	local picked = {}
	for i = 1, math.min(Season.CONTRACTS_PREMIUM, #indices) do
		table.insert(picked, indices[i])
	end
	return picked
end

return Season
