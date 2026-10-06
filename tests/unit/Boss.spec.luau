local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local Boss = require("../../src/shared/Config/Boss")

return function()
	test.suite("Boss", function()
		test.case("health grows with players and is capped", function()
			check.is_true(Boss.health(1) >= 60)
			check.is_true(Boss.health(4) > Boss.health(2))
			check.equal(Boss.health(100), 420)
		end)

		test.case("cash reward has a floor and scales with income", function()
			check.equal(Boss.cashReward(0), Boss.REWARD_MIN_CASH)
			check.equal(Boss.cashReward(1000), 1000 * Boss.REWARD_INCOME_SECONDS)
		end)

		test.case("only players with enough hits win; top lassoer picked", function()
			local winners, top = Boss.results({ a = 10, b = 2, c = 10, d = 3 }, { "a", "b", "c", "d" })
			check.equal(#winners, 3)
			check.equal(top, "a")
			local none, noTop = Boss.results({ a = 1 }, { "a" })
			check.equal(#none, 0)
			check.equal(noTop, nil)
		end)
	end)
end
