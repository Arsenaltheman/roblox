local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local Economy = require("../../src/shared/Sim/Economy")

local function near(a: number, b: number, rel: number?): boolean
	return math.abs(a - b) <= (rel or 1e-9) * math.max(1, math.abs(b))
end

return function()
	test.suite("Economy", function()
		test.case("price and income match the plan's formulas", function()
			check.equal(Economy.price(1), 25)
			check.equal(Economy.price(7), 1600)
			check.equal(Economy.price(14), 204800)
			check.equal(Economy.income(1), 1)
			check.is_true(near(Economy.income(14), 1.6 ^ 13))
			check.is_true(near(Economy.price(40), 25 * 2 ^ 39))
		end)

		test.case("tierForBudget picks the highest affordable tier", function()
			check.equal(Economy.tierForBudget(10), 0)
			check.equal(Economy.tierForBudget(25), 1)
			check.equal(Economy.tierForBudget(49), 1)
			check.equal(Economy.tierForBudget(50), 2)
			check.equal(Economy.tierForBudget(204800), 14)
			check.equal(Economy.tierForBudget(1e30), 40)
			for tier = 1, 40 do
				check.equal(Economy.tierForBudget(Economy.price(tier)), tier)
			end
		end)

		test.case("bandTier uses the larger of cash and 45s of income", function()
			check.equal(Economy.bandTier(100, 0), 3)
			check.equal(Economy.bandTier(0, 0), 1)
			check.equal(Economy.bandTier(0, 1600 / 45), 7)
		end)

		test.case("free boosts add and cap; paid multipliers multiply (pay-to-win)", function()
			local base = { frontier = 0, passes = {} }
			check.equal(Economy.multiplier(base), 1)
			check.is_true(near(Economy.multiplier({ frontier = 0, passes = {}, friends = 5 }), 1.3))
			check.is_true(
				near(Economy.multiplier({ frontier = 0, passes = {}, friends = 3, eventActive = true }), 1.8)
			)
			check.equal(Economy.multiplier({ frontier = 0, passes = { DoubleCash = true } }), 2)
			check.equal(Economy.multiplier({ frontier = 0, passes = { DoubleCash = true, VIP = true } }), 3)
			check.equal(Economy.multiplier({ frontier = 2, passes = { DoubleCash = true, VIP = true } }), 9)
		end)

		test.case("a companion adds a free boost by rarity, inside the free cap", function()
			local none = Economy.multiplier({ frontier = 0, passes = {} })
			local common = Economy.multiplier({ frontier = 0, passes = {}, companion = { tier = 1 } })
			local secret = Economy.multiplier({ frontier = 0, passes = {}, companion = { tier = 40 } })
			check.is_true(common > none)
			check.is_true(near(common, 1.03))
			check.is_true(near(secret, 1.24))
			check.is_true(near(Economy.companionBoost({ tier = 13, mutation = "Gold" }), 0.12))
			check.equal(Economy.companionBoost(nil), 0)
			-- Free boosts add together: friends +0.3, event +0.5, Secret mutated companion +0.27.
			local stacked = Economy.multiplier({
				frontier = 0,
				passes = {},
				friends = 3,
				eventActive = true,
				companion = { tier = 40, mutation = "Rainbow" },
			})
			check.is_true(near(stacked, 2.07))
			-- The shared cap still holds when everything stacks.
			check.is_true(stacked <= 1 + 1.3 + 1e-9)
		end)

		test.case("ranch income sums critters with mutations", function()
			local income = Economy.ranchIncome({
				{ tier = 1 },
				{ tier = 1, mutation = "Rainbow" },
				{ tier = 2, mutation = "Gold" },
			}, { frontier = 1, passes = {} })
			check.is_true(near(income, (1 + 10 + 1.6 * 1.5) * 2))
		end)

		test.case("frontier costs match the plan", function()
			check.equal(Economy.frontierTargetTier(1), 14)
			check.equal(Economy.frontierCost(1), 6 * 204800)
			check.is_true(near(Economy.frontierCost(8), 6 * 25 * 2 ^ 34))
			check.is_false(Economy.canFrontier(0, 1228799, 14))
			check.is_false(Economy.canFrontier(0, 1228800, 13))
			check.is_true(Economy.canFrontier(0, 1228800, 14))
		end)

		test.case("Frontiers past the top tier keep going with rising costs", function()
			check.equal(Economy.frontierTargetTier(9), 38)
			check.equal(Economy.frontierTargetTier(10), 40)
			check.equal(Economy.frontierTargetTier(12), 40)
			local f9, f10, f11, f12 =
				Economy.frontierCost(9),
				Economy.frontierCost(10),
				Economy.frontierCost(11),
				Economy.frontierCost(12)
			check.is_true(f10 > f9 and f11 > f10 and f12 > f11)
			check.is_true(near(f11 / f10, 4))
		end)

		test.case("pens, safe pens, locks and carry limits", function()
			check.equal(Economy.pens(0, {}), 8)
			check.equal(Economy.pens(20, {}), 16)
			check.equal(Economy.pens(20, { BigRanch = true }), 18)
			check.equal(Economy.safePens(2), 0)
			check.equal(Economy.safePens(3), 1)
			check.equal(Economy.safePens(9), 2)
			check.equal(Economy.lockSeconds(0, {}), 60)
			check.equal(Economy.lockSeconds(2, { IronLock = true, VIP = true }), 150)
			check.equal(Economy.carryLimit(0, {}), 14)
			check.equal(Economy.carryLimit(0, { HeavySaddlebag = true }), 19)
			check.equal(Economy.carryLimit(30, {}), 40)
		end)

		test.case("offline earnings use the rate by frontier and the 8h cap", function()
			check.equal(Economy.offlineEarnings(100, 3600, 0), 100 * 3600 * 0.25)
			check.equal(Economy.offlineEarnings(100, 3600, 3), 100 * 3600 * 0.5)
			check.equal(Economy.offlineEarnings(100, 100 * 3600, 0), 100 * 8 * 3600 * 0.25)
			check.equal(Economy.offlineEarnings(100, -50, 0), 0)
		end)

		test.case("cash bags have a floor and scale with income", function()
			check.equal(Economy.cashBag(600, 0), 500)
			check.equal(Economy.cashBag(600, 10), 6000)
		end)

		test.case("exclusive critters track the owner's band", function()
			check.equal(Economy.exclusiveTier("GoldenLocomotive", 10), 11)
			check.equal(Economy.exclusiveTier("DeputyDuck", 10), 10)
			check.equal(Economy.exclusiveTier("DiamondDesperado", 39), 40)
		end)

		test.case("cash clamps NaN, negatives and the ceiling", function()
			check.equal(Economy.clampCash(0 / 0), 0)
			check.equal(Economy.clampCash(-5), 0)
			check.equal(Economy.clampCash(1e40), 1e30)
		end)
	end)
end
