local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local Luck = require("../../src/shared/Sim/Luck")

return function()
	test.suite("Luck", function()
		test.case("active luck grows per minute and caps", function()
			check.equal(Luck.active(0), 1)
			check.is_true(math.abs(Luck.active(10) - 1.4) < 1e-9)
			check.equal(Luck.active(1000), 2.2)
			check.equal(Luck.active(-5), 1)
		end)

		test.case("personal luck multiplies sources and caps", function()
			check.equal(Luck.personal({}), 1)
			check.equal(Luck.personal({ horseshoe = true }), 1.5)
			check.equal(Luck.personal({ horseshoe = true, serverLuck = 2 }), 3)
			check.equal(Luck.personal({ activeMinutes = 1000, horseshoe = true, serverLuck = 5, eventLuck = 4 }), 40)
		end)

		test.case("luck only boosts Rare and up", function()
			local base = Luck.rarityWeights(1)
			local lucky = Luck.rarityWeights(2)
			check.equal(lucky[1], base[1])
			check.equal(lucky[2], base[2])
			check.equal(lucky[3], base[3] * 2)
			check.equal(lucky[8], base[8] * 2)
		end)

		test.case("reserved upgrades scale softly", function()
			local w = Luck.reservedDeltaWeights(4)
			check.equal(w[1], 30)
			check.equal(w[2], 40)
			check.equal(w[3], 44)
		end)

		test.case("mutation chance scales softly and caps", function()
			check.equal(Luck.mutationChance(1), 0.04)
			check.equal(Luck.mutationChance(4), 0.08)
			check.equal(Luck.mutationChance(1000), 0.25)
		end)

		test.case("rare cages need activity", function()
			check.is_true(Luck.canBuyRarity("Mythic", 0))
			check.is_false(Luck.canBuyRarity("Outlaw", 9.9))
			check.is_true(Luck.canBuyRarity("Outlaw", 10))
			check.is_false(Luck.canBuyRarity("Secret", 15))
			check.is_true(Luck.canBuyRarity("Secret", 20))
		end)
	end)
end
