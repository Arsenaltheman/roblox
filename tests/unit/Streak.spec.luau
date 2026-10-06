local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local Streak = require("../../src/shared/Sim/Streak")

local DAY = 86400
local T0 = 20000 * DAY + 3600

return function()
	test.suite("Streak", function()
		test.case("first login starts at day 1 with a reward", function()
			local r = Streak.login(Streak.new(), T0)
			check.equal(r.state.count, 1)
			check.is_true(r.reward)
			check.equal(r.slot, 1)
		end)

		test.case("same day gives no second reward", function()
			local r = Streak.login(Streak.new(), T0)
			local again = Streak.login(r.state, T0 + 3000)
			check.is_false(again.reward)
			check.equal(again.state.count, 1)
		end)

		test.case("consecutive days count up", function()
			local state = Streak.new()
			for d = 0, 4 do
				state = Streak.login(state, T0 + d * DAY).state
			end
			check.equal(state.count, 5)
		end)

		test.case("one missed day is forgiven once", function()
			local state = Streak.login(Streak.new(), T0).state
			local r = Streak.login(state, T0 + 2 * DAY)
			check.equal(r.state.count, 2)
			check.is_true(r.state.graceUsed)
			local r2 = Streak.login(r.state, T0 + 4 * DAY)
			check.equal(r2.state.count, 1)
			check.is_true(r2.broke)
		end)

		test.case("a full week earns grace back and slot stays at 7", function()
			local state = Streak.login(Streak.new(), T0).state
			state = Streak.login(state, T0 + 2 * DAY).state
			for d = 3, 7 do
				state = Streak.login(state, T0 + d * DAY).state
			end
			check.equal(state.count, 7)
			check.is_false(state.graceUsed)
			local r = Streak.login(state, T0 + 8 * DAY)
			check.equal(r.slot, 7)
		end)

		test.case("clock going backwards never resets or rewards", function()
			local state = Streak.login(Streak.new(), T0 + 5 * DAY).state
			local r = Streak.login(state, T0)
			check.is_false(r.reward)
			check.equal(r.state.count, 1)
		end)

		test.case("countdown to next UTC day", function()
			check.equal(Streak.secondsUntilNextDay(T0), DAY - 3600)
		end)
	end)
end
