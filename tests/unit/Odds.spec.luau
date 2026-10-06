local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local Odds = require("../../src/shared/Sim/Odds")

local function sumPercent(rows): number
	local total = 0
	for _, row in rows do
		total += row.percent
	end
	return total
end

local function sumProbability(rows): number
	local total = 0
	for _, row in rows do
		total += row.probability
	end
	return total
end

local function exactly100(rows): boolean
	-- Compare in display units (1e-4 %) to avoid float noise.
	return math.floor(sumPercent(rows) * 1e4 + 0.5) == 100 * 1e4
end

return function()
	test.suite("Odds (shown to players; must total 100%)", function()
		test.case("displayPercents always sums to exactly 100", function()
			check.is_true(exactly100((function()
				local rows = {}
				for i, p in Odds.displayPercents({ 1 / 3, 1 / 3, 1 / 3 }, 2) do
					rows[i] = { percent = p }
				end
				return rows
			end)()))
			local p = Odds.displayPercents({ 1 / 3, 1 / 3, 1 / 3 }, 2)
			check.equal(p[1] + p[2] + p[3], 100)
		end)

		for _, luck in { 1, 1.5, 2, 3, 5, 12, 40 } do
			test.case(`wild rarity and species tables total 100% at luck {luck}`, function()
				check.is_true(exactly100(Odds.wildRarities(luck)))
				check.is_true(exactly100(Odds.wildSpecies(luck)))
				check.is_true(math.abs(sumProbability(Odds.wildSpecies(luck)) - 1) < 1e-9)
				check.equal(#Odds.wildSpecies(luck), 40)
			end)
		end

		test.case("no species shows 0% (tiny odds keep 4 decimals)", function()
			for _, row in Odds.wildSpecies(1) do
				check.is_true(row.percent > 0)
			end
		end)

		test.case("reserved cage table folds out-of-range deltas", function()
			local rows = Odds.reserved(1, 1)
			check.is_true(exactly100(rows))
			check.equal(rows[1].id, "CactusCarl")
			check.equal(#rows, 4)
			local top = Odds.reserved(40, 3)
			check.equal(#top, 2)
			check.is_true(exactly100(top))
		end)

		test.case("mutation table includes none and totals 100%", function()
			check.is_true(exactly100(Odds.mutations(1)))
			check.is_true(exactly100(Odds.mutations(5)))
			local weather = Odds.mutations(1, "Electric")
			check.equal(#weather, 2)
			check.equal(weather[2].percent, 25)
		end)

		test.case("egg table totals 100% and respects the cap", function()
			check.is_true(exactly100(Odds.egg(10)))
			local capped = Odds.egg(10, 10)
			check.equal(#capped, 1)
			check.equal(capped[1].percent, 100)
		end)
	end)
end
