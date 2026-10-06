local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local Manifest = require("../../src/shared/Sim/Manifest")

local function players(n: number, band: number?, minutes: number?)
	local list = {}
	for i = 1, n do
		table.insert(
			list,
			{ userId = i, bandTier = band or 5, personalLuck = 1, activeMinutes = minutes or 0 }
		)
	end
	return list
end

return function()
	test.suite("Manifest (cage rolls)", function()
		test.case("one reserved cage per player plus at least 4 wild", function()
			local m = Manifest.roll(1, 0, players(8))
			check.equal(#m.cages, 12)
			local reserved = 0
			for _, cage in m.cages do
				if cage.owner ~= 0 then
					reserved += 1
				end
			end
			check.equal(reserved, 8)
			check.equal(#Manifest.roll(1, 0, players(2)).cages, 12)
			check.equal(#Manifest.roll(1, 0, players(10)).cages, 14)
		end)

		test.case("same seed and cycle replay exactly", function()
			local a = Manifest.roll(777, 12, players(4))
			local b = Manifest.roll(777, 12, players(4))
			for i, cage in a.cages do
				check.equal(cage.tier, b.cages[i].tier)
				check.equal(cage.mutation, b.cages[i].mutation)
			end
		end)

		test.case("reserved tiers stay within band -1..+3", function()
			for cycle = 0, 300 do
				local m = Manifest.roll(42, cycle, players(1, 20, 60))
				local cage = m.cages[1]
				check.is_true(cage.tier >= 19 and cage.tier <= 23)
				check.equal(cage.goldenTicket, cage.tier >= 22)
			end
		end)

		test.case("reserved cages respect the activity gate for rare rarities", function()
			for cycle = 0, 300 do
				local m = Manifest.roll(9, cycle, players(1, 36, 0))
				check.is_true(m.cages[1].tier <= 34)
			end
		end)

		test.case("weather forces that mutation or none", function()
			for cycle = 0, 100 do
				for _, cage in Manifest.roll(3, cycle, players(3), { weatherMutation = "Frosty" }).cages do
					check.is_true(cage.mutation == nil or cage.mutation == "Frosty")
				end
			end
		end)

		test.case("strongbox flag follows the timetable", function()
			check.is_false(Manifest.roll(1, 0, {}).strongbox)
			check.is_true(Manifest.roll(1, 2, {}).strongbox)
		end)

		test.case("wild rarity distribution roughly matches the odds", function()
			local commons, total = 0, 0
			for cycle = 0, 4000 do
				for _, cage in Manifest.roll(5, cycle, {}).cages do
					total += 1
					if cage.rarity == "Common" then
						commons += 1
					end
				end
			end
			check.is_true(math.abs(commons / total - 0.5) < 0.02)
		end)
	end)
end
