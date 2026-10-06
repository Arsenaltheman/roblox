local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local Loot = require("../../src/shared/Sim/Loot")
local Rng = require("../../src/shared/Sim/Rng")

return function()
	test.suite("Loot", function()
		test.case("hatch stays within parent +0..+2 and the cap", function()
			local rng = Rng.new(1)
			for _ = 1, 2000 do
				local tier = Loot.hatch(rng, 10)
				check.is_true(tier >= 10 and tier <= 12)
				check.is_true(Loot.hatch(rng, 10, 11) <= 11)
				check.equal(Loot.hatch(rng, 40), 40)
			end
		end)

		test.case("strongbox pity forces an egg", function()
			local rng = Rng.new(2)
			local loot = Loot.strongbox(rng, 5)
			check.equal(loot.kind, "egg")
			check.is_true(loot.pity)
		end)

		test.case("strongbox amounts stay in range", function()
			local rng = Rng.new(3)
			for _ = 1, 2000 do
				local loot = Loot.strongbox(rng, 0)
				if loot.kind == "cash" then
					check.is_true(loot.amount >= 60 and loot.amount <= 180)
				elseif loot.kind == "nuggets" then
					check.is_true(loot.amount >= 10 and loot.amount <= 30)
				end
			end
		end)

		test.case("a better mutation replaces a worse one only", function()
			check.is_true(Loot.betterMutation(nil, "Gold"))
			check.is_true(Loot.betterMutation("Gold", "Rainbow"))
			check.is_false(Loot.betterMutation("Rainbow", "Gold"))
			check.is_false(Loot.betterMutation("Gold", "Gold"))
		end)
	end)
end
