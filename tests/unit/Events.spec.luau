local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local Events = require("../../src/shared/Config/Events")

return function()
	test.suite("Events", function()
		test.case("pick never repeats the previous event", function()
			for _, previous in Events.list do
				for i = 0, 99 do
					check.is_true(Events.pick(i / 100, previous.id).id ~= previous.id)
				end
			end
		end)

		test.case("pick reaches every event", function()
			local seen = {}
			for i = 0, 999 do
				seen[Events.pick(i / 1000, nil).id] = true
			end
			for _, e in Events.list do
				check.is_true(seen[e.id] == true)
			end
		end)

		test.case("crate zones stay in range and favour early zones", function()
			local counts = {}
			for i = 0, 999 do
				local z = Events.crateZone(i / 1000)
				check.is_true(z >= 1 and z <= 4)
				counts[z] = (counts[z] or 0) + 1
			end
			check.is_true(counts[1] > counts[4])
		end)

		test.case("warning fits inside the interval", function()
			check.is_true(Events.WARNING < Events.INTERVAL)
			for _, e in Events.list do
				check.is_true(e.duration < Events.INTERVAL - Events.WARNING)
			end
		end)
	end)
end
