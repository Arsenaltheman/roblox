local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local Wheel = require("../../src/shared/Config/Wheel")

return function()
	test.suite("Wheel", function()
		test.case("shown odds sum to 100", function()
			local sum = 0
			for _, p in Wheel.odds() do
				sum += p
			end
			check.is_true(math.abs(sum - 100) < 1e-9)
		end)

		test.case("pick covers every segment and matches the weights", function()
			local counts = {}
			local n = 100000
			for i = 0, n - 1 do
				local idx = Wheel.pick(i / n)
				counts[idx] = (counts[idx] or 0) + 1
			end
			local odds = Wheel.odds()
			for i = 1, #Wheel.segments do
				check.is_true(math.abs(counts[i] / n * 100 - odds[i]) < 0.01)
			end
			check.equal(Wheel.pick(0), 1)
			check.equal(Wheel.pick(0.9999999), #Wheel.segments)
		end)

		test.case("every segment pays something", function()
			for _, s in Wheel.segments do
				check.is_true(s.amount > 0 and s.weight > 0)
			end
		end)

		test.case("daily spin resets on the UTC day boundary", function()
			check.equal(Wheel.day(86399), 0)
			check.equal(Wheel.day(86400), 1)
		end)
	end)
end
