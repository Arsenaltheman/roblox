--!strict
-- Every economy number in one place. The game AND the economy simulator read this file,
-- so a change here is checked by the simulator's pacing gates before it ships.

return {
	-- Critter price and income by tier: price(t) = basePrice * priceGrowth^(t-1),
	-- income(t) = baseIncome * incomeGrowth^(t-1) cash per second.
	basePrice = 25,
	priceGrowth = 2,
	baseIncome = 1,
	incomeGrowth = 1.6,

	startingCash = 100,
	sellRefund = 0.5,
	-- Uncollected cash per pen stops growing after this many seconds of that pen's income.
	uncollectedCapSeconds = 3600,

	-- Free boosts add together and are capped. Paid multipliers multiply on top (owner decision: pay-to-win).
	freeBoostCap = 1.3,
	friendBoostEach = 0.1,
	friendBoostMax = 0.3,
	eventBoost = 1.0,
	paidMultipliers = {
		DoubleCash = 2,
		VIP = 1.5,
	},

	-- Frontier (rebirth) n needs 3 * price(T) cash plus owning a critter of tier >= T,
	-- where T = frontierBaseTier + frontierTierStep * (n - 1).
	frontierBaseTier = 14,
	frontierTierStep = 3,
	frontierCostMultiplier = 3,
	-- Cash you restart with after Frontier n = cost(n) / this.
	frontierPurseDivisor = 1000,
	maxFrontier = 30,

	basePens = 8,
	maxEarnedPens = 16,
	bigRanchExtraPens = 2,
	safePensByFrontier = { [3] = 1, [6] = 2 },

	baseLockSeconds = 60,
	lockSecondsPerFrontier = 10,
	ironLockExtraSeconds = 60,
	vipExtraLockSeconds = 10,

	-- Highest tier a player can carry when stealing: carryBaseTier + carryTierPerFrontier * F (+ saddlebag).
	carryBaseTier = 14,
	carryTierPerFrontier = 3,
	saddlebagExtraTiers = 5,

	-- Offline earnings: a share of income while away, up to a cap.
	offlineRate = 0.25,
	offlineRateFromFrontier3 = 0.5,
	offlineCapSeconds = 8 * 3600,

	-- Cash bags sold for Robux are worth N seconds of the buyer's current income (with a floor).
	cashBagFloor = 500,

	-- Exclusive (Robux) critters earn like a cage critter this many tiers above the owner's best band.
	exclusiveTierBonus = {
		DeputyDuck = 1,
		GoldenLocomotive = 3,
		DiamondDesperado = 5,
	},

	-- Cash is clamped here so maths stays exact in doubles (2^53 ~ 9e15).
	cashCeiling = 1e15,
}
