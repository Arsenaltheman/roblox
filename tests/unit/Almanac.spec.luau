local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local Almanac = require("../../src/shared/Sim/Almanac")
local Economy = require("../../src/shared/Sim/Economy")
local Species = require("../../src/shared/Config/Species")
local Rarities = require("../../src/shared/Config/Rarities")

return function()
	test.suite("Almanac", function()
		test.case("empty almanac completes nothing; totals cover every species", function()
			local total = 0
			for _, p in Almanac.sets({}) do
				check.equal(p.have, 0)
				check.is_true(not p.done)
				total += p.total
			end
			check.equal(total, #Species.list)
			check.equal(Almanac.completedSets({}), 0)
		end)

		test.case("discovering every Common completes exactly that set", function()
			local almanac = {}
			for _, s in Species.list do
				if Rarities.forTier(s.tier).id == Rarities.list[1].id then
					almanac[s.id] = 1
				end
			end
			check.equal(Almanac.completedSets(almanac), 1)
		end)

		test.case("full almanac completes every set and boosts income", function()
			local almanac = {}
			for _, s in Species.list do
				almanac[s.id] = 3
			end
			local sets = Almanac.completedSets(almanac)
			check.equal(sets, #Rarities.list)
			local base = Economy.multiplier({ frontier = 0, passes = {} })
			local boosted = Economy.multiplier({ frontier = 0, passes = {}, almanacSets = sets })
			check.is_true(boosted > base)
		end)
	end)
end
