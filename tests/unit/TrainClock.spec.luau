local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local TrainClock = require("../../src/shared/Sim/TrainClock")

return function()
	test.suite("TrainClock", function()
		test.case("cycle is 45 seconds", function()
			check.equal(TrainClock.cycleLength(), 45)
		end)

		test.case("phases in order with doors opening 1s after stopping", function()
			local epoch = 1000
			local s = TrainClock.at(epoch, epoch + 0)
			check.equal(s.phase, "arriving")
			check.equal(s.cycle, 0)
			s = TrainClock.at(epoch, epoch + 6)
			check.equal(s.phase, "dwelling")
			check.is_false(s.doorsOpen)
			s = TrainClock.at(epoch, epoch + 7)
			check.is_true(s.doorsOpen)
			s = TrainClock.at(epoch, epoch + 26)
			check.equal(s.phase, "departing")
			check.is_false(s.doorsOpen)
			s = TrainClock.at(epoch, epoch + 45)
			check.equal(s.cycle, 1)
			check.equal(s.phase, "arriving")
		end)

		test.case("every third train has a strongbox car", function()
			check.is_false(TrainClock.hasStrongbox(0))
			check.is_false(TrainClock.hasStrongbox(1))
			check.is_true(TrainClock.hasStrongbox(2))
			check.is_true(TrainClock.hasStrongbox(5))
		end)

		test.case("canBuy only while doors are open (with grace)", function()
			local epoch = 0
			check.is_false(TrainClock.canBuy(epoch, 0, 6.5))
			check.is_true(TrainClock.canBuy(epoch, 0, 7))
			check.is_true(TrainClock.canBuy(epoch, 0, 26))
			check.is_false(TrainClock.canBuy(epoch, 0, 26.5))
			check.is_true(TrainClock.canBuy(epoch, 0, 26.5, 0.75))
			check.is_false(TrainClock.canBuy(epoch, 1, 20))
		end)

		test.case("before the epoch counts as cycle 0", function()
			check.equal(TrainClock.at(100, 50).cycle, 0)
		end)
	end)
end
