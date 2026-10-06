local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local TrailConfig = require("../../src/shared/Config/Trail")
local Trail = require("../../src/shared/Sim/Trail")

local noFacts =
	{ frontier = 0, boots = 0, income = 0, almanac = 0, sets = 0, gearOwned = 0, bestTier = 0, mutated = 0 }

return function()
	test.suite("Trail", function()
		test.case("8 chapters of 5 quests, every objective kind is known", function()
			check.equal(#TrailConfig.chapters, 8)
			for _, chapter in TrailConfig.chapters do
				check.equal(#chapter.quests, 5)
				for _, quest in chapter.quests do
					check.is_true(#quest.objectives >= 2)
					for _, objective in quest.objectives do
						check.is_true(
							TrailConfig.counted[objective.kind] or TrailConfig.checked[objective.kind]
						)
						check.is_true(objective.goal > 0)
					end
				end
			end
			for _, objective in TrailConfig.weeklyPool do
				check.is_true(TrailConfig.counted[objective.kind] == true)
			end
		end)

		test.case("chapter n finale requires Frontier n", function()
			for n, chapter in TrailConfig.chapters do
				local finale = chapter.quests[#chapter.quests]
				local found = false
				for _, objective in finale.objectives do
					if objective.kind == "frontier" and objective.goal == n then
						found = true
					end
				end
				check.is_true(found)
			end
		end)

		test.case("events count, cap at the goal, and complete a quest", function()
			local quest = TrailConfig.chapters[1].quests[1]
			local progress = {}
			check.is_true(Trail.event(quest, progress, "buy", 3))
			check.is_true(not Trail.event(quest, progress, "heist", 1))
			Trail.event(quest, progress, "buy", 10)
			Trail.event(quest, progress, "collect", 3)
			local view, done = Trail.view(quest, progress, noFacts)
			check.equal(view[1].have, 5)
			check.is_true(done)
		end)

		test.case("checked objectives read facts", function()
			local quest = TrailConfig.chapters[1].quests[5]
			local facts = table.clone(noFacts)
			local _, done = Trail.view(quest, { 3 }, facts)
			check.is_true(not done)
			facts.frontier = 1
			_, done = Trail.view(quest, { 3 }, facts)
			check.is_true(done)
		end)

		test.case("after walks the whole trail and ends", function()
			local c, q = 1, 1
			local steps = 1
			while true do
				local nc, nq = Trail.after(c :: number, q :: number)
				if not nc then
					break
				end
				c, q = nc, nq
				steps += 1
			end
			check.equal(steps, 40)
			check.is_true(Trail.isFinale(8, 5))
		end)

		test.case("weekly picks are distinct, stable and change week to week", function()
			local a = Trail.weekly(2900)
			check.equal(#a, TrailConfig.WEEKLY_COUNT)
			local seen = {}
			for _, i in a do
				check.is_true(not seen[i])
				seen[i] = true
			end
			check.equal(table.concat(Trail.weekly(2900), ","), table.concat(a, ","))
			local differs = false
			for w = 2901, 2910 do
				if table.concat(Trail.weekly(w), ",") ~= table.concat(a, ",") then
					differs = true
				end
			end
			check.is_true(differs)
			-- Monday 2026-10-05 00:00 UTC starts a new week.
			check.equal(Trail.week(1791158400) - Trail.week(1791158399), 1)
		end)
	end)
end
