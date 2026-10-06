--!strict
-- Pure economy maths. No Roblox APIs: runs in the game, in unit tests and in the economy simulator.

local Config = require("../Config/Economy")
local Mutations = require("../Config/Mutations")
local Rarities = require("../Config/Rarities")
local Train = require("../Config/Train")

local Economy = {}

export type Passes = {
	Premium: boolean?,
	Club: boolean?,
	DoubleCash: boolean?,
	VIP: boolean?,
	IronLock: boolean?,
	BigRanch: boolean?,
	HeavySaddlebag: boolean?,
}

export type IncomeContext = {
	frontier: number,
	passes: Passes,
	-- Friends from the player's friend list in the same server.
	friends: number?,
	-- True while a server event that boosts income is running.
	eventActive: boolean?,
	-- Timed paid boosts (e.g. Starter Pack 2x cash) currently running.
	timedDoubleCash: boolean?,
	-- Live-config dial (1 = normal).
	incomeScale: number?,
	-- Completed Almanac rarity sets.
	almanacSets: number?,
	-- The critter following the player around (Equipped.companion), if any.
	companion: { tier: number, mutation: string? }?,
	-- Rancher mastery perk (0.01 per perk), counts toward the free cap.
	skillBoost: number?,
}

export type CritterLike = {
	tier: number,
	mutation: string?,
}

function Economy.price(tier: number): number
	return Config.basePrice * Config.priceGrowth ^ (tier - 1)
end

function Economy.income(tier: number): number
	return Config.baseIncome * Config.incomeGrowth ^ (tier - 1)
end

-- Highest tier whose price fits the budget, or 0 if even tier 1 doesn't.
function Economy.tierForBudget(budget: number): number
	if budget < Config.basePrice then
		return 0
	end
	local tier = math.floor(math.log(budget / Config.basePrice, Config.priceGrowth) + 1e-9) + 1
	return math.clamp(tier, 1, Rarities.maxTier)
end

-- The tier a player's reserved cage is centred on.
function Economy.bandTier(cash: number, incomePerSecond: number): number
	local budget = math.max(cash, incomePerSecond * Train.bandIncomeSeconds)
	return math.max(1, Economy.tierForBudget(budget))
end

function Economy.critterIncome(critter: CritterLike): number
	return Economy.income(critter.tier) * Mutations.multiplierOf(critter.mutation)
end

-- Free boost from a companion: one step per rarity (1..8), one more if mutated.
function Economy.companionBoost(companion: { tier: number, mutation: string? }?): number
	if not companion then
		return 0
	end
	local tier = math.clamp(companion.tier, 1, Rarities.maxTier)
	local steps = Rarities.indexOf(Rarities.forTier(tier).id)
	if companion.mutation and companion.mutation ~= "" then
		steps += 1
	end
	return Config.companionBoostPerRarity * steps
end

-- Total multiplier on base income. Free boosts add (capped); paid multipliers multiply.
function Economy.multiplier(ctx: IncomeContext): number
	local free = 0
	free += math.min((ctx.friends or 0) * Config.friendBoostEach, Config.friendBoostMax)
	if ctx.eventActive then
		free += Config.eventBoost
	end
	free += Economy.companionBoost(ctx.companion)
	free += ctx.skillBoost or 0
	free = math.min(free, Config.freeBoostCap)

	local paid = 1
	if ctx.passes.DoubleCash or ctx.timedDoubleCash then
		paid *= Config.paidMultipliers.DoubleCash
	end
	if ctx.passes.VIP then
		paid *= Config.paidMultipliers.VIP
	end
	if ctx.passes.Premium then
		paid *= Config.paidMultipliers.Premium
	end
	if ctx.passes.Club then
		paid *= Config.paidMultipliers.Club
	end

	local almanac = 1 + (ctx.almanacSets or 0) * Config.almanacSetBonus
	return (1 + ctx.frontier) * (1 + free) * paid * almanac * (ctx.incomeScale or 1)
end

function Economy.ranchIncome(critters: { CritterLike }, ctx: IncomeContext): number
	local base = 0
	for _, critter in critters do
		base += Economy.critterIncome(critter)
	end
	return base * Economy.multiplier(ctx)
end

-- Exclusive (Robux) critters earn like a cage critter a few tiers above the owner's band,
-- so they stay useful at every stage without breaking the curve.
function Economy.exclusiveTier(speciesId: string, bandTier: number): number
	local bonus = Config.exclusiveTierBonus[speciesId] or 0
	return math.clamp(bandTier + bonus, 1, Rarities.maxTier)
end

function Economy.sellValue(critter: CritterLike): number
	return Economy.price(critter.tier) * Mutations.multiplierOf(critter.mutation) * Config.sellRefund
end

local function uncappedTargetTier(n: number): number
	return Config.frontierBaseTier + Config.frontierTierStep * (n - 1)
end

function Economy.frontierTargetTier(n: number): number
	return math.min(uncappedTargetTier(n), Rarities.maxTier)
end

function Economy.frontierCost(n: number): number
	local cost = Config.frontierCostMultiplier * Economy.price(Economy.frontierTargetTier(n))
	-- Past the top tier, each extra Frontier costs frontierEndlessGrowth times more per tier step skipped.
	local overflowSteps = math.max(0, uncappedTargetTier(n) - Rarities.maxTier) / Config.frontierTierStep
	if overflowSteps > 0 then
		cost *= Config.frontierEndlessGrowth ^ math.ceil(overflowSteps)
	end
	return cost
end

function Economy.frontierPurse(n: number): number
	return math.max(Config.startingCash, Economy.frontierCost(n) / Config.frontierPurseDivisor)
end

-- Can a player at `frontier` with `cash` and best owned tier `bestTier` move to the next Frontier?
function Economy.canFrontier(frontier: number, cash: number, bestTier: number): boolean
	local n = frontier + 1
	if n > Config.maxFrontier then
		return false
	end
	return cash >= Economy.frontierCost(n) and bestTier >= Economy.frontierTargetTier(n)
end

function Economy.pens(frontier: number, passes: Passes): number
	local earned = math.min(Config.basePens + frontier, Config.maxEarnedPens)
	return earned + (if passes.BigRanch then Config.bigRanchExtraPens else 0)
end

function Economy.safePens(frontier: number): number
	local best = 0
	for fromFrontier, count in Config.safePensByFrontier do
		if frontier >= fromFrontier and count > best then
			best = count
		end
	end
	return best
end

function Economy.lockSeconds(frontier: number, passes: Passes): number
	local seconds = Config.baseLockSeconds + Config.lockSecondsPerFrontier * frontier
	if passes.IronLock then
		seconds += Config.ironLockExtraSeconds
	end
	if passes.VIP then
		seconds += Config.vipExtraLockSeconds
	end
	return seconds
end

function Economy.carryLimit(frontier: number, passes: Passes): number
	local limit = Config.carryBaseTier + Config.carryTierPerFrontier * frontier
	if passes.HeavySaddlebag then
		limit += Config.saddlebagExtraTiers
	end
	return math.min(limit, Rarities.maxTier)
end

function Economy.offlineEarnings(incomePerSecond: number, secondsAway: number, frontier: number): number
	local rate = if frontier >= 3 then Config.offlineRateFromFrontier3 else Config.offlineRate
	local seconds = math.clamp(secondsAway, 0, Config.offlineCapSeconds)
	return incomePerSecond * seconds * rate
end

-- Cash bag value: N seconds of current income, never below the floor.
function Economy.cashBag(seconds: number, incomePerSecond: number): number
	return math.max(Config.cashBagFloor, incomePerSecond * seconds)
end

-- Clamp cash into the safe range (no NaN, no negatives, below the exact-double ceiling).
function Economy.clampCash(cash: number): number
	if cash ~= cash then
		return 0
	end
	return math.clamp(cash, 0, Config.cashCeiling)
end

return Economy
