local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local BanditClock = require("../../src/shared/Sim/BanditClock")

return function()
	test.suite("BanditClock (red light)", function()
		test.case("every peek is preceded by a tell", function()
			local t = 0
			local last = "napping"
			while t < 500 do
				local s = BanditClock.state(t)
				if s == "peeking" and last ~= "peeking" then
					check.equal(last, "tell")
				end
				last = s
				t += 0.05
			end
		end)

		test.case("peeksDuring agrees with sampling", function()
			for start = 0, 300, 0.37 do
				local sampled = false
				for t = start, start + 2.5, 0.01 do
					if BanditClock.state(t) == "peeking" then
						sampled = true
					end
				end
				check.equal(BanditClock.peeksDuring(start, start + 2.5), sampled)
			end
		end)

		test.case("a 2.5s grab fits between peeks sometimes (it's winnable)", function()
			local wins = 0
			for start = 0, 700, 0.5 do
				if not BanditClock.peeksDuring(start, start + BanditClock.GRAB_SECONDS) then
					wins += 1
				end
			end
			check.is_true(wins > 200)
		end)
	end)
end
