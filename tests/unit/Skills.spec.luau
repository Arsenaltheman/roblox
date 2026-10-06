local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local Skills = require("../../src/shared/Sim/Skills")
local Config = require("../../src/shared/Config/Skills")

return function()
	test.suite("Skills", function()
		test.case("level 1 with no xp, bar empty", function()
			local level, into, need = Skills.levelFor(0)
			check.equal(level, 1)
			check.equal(into, 0)
			check.equal(need, Skills.cost(1))
		end)

		test.case("xp exactly at a threshold levels up with an empty bar", function()
			local level, into = Skills.levelFor(Skills.cost(1))
			check.equal(level, 2)
			check.equal(into, 0)
		end)

		test.case("caps at MAX_LEVEL with a full bar", function()
			local level, into, need = Skills.levelFor(1e12)
			check.equal(level, Config.MAX_LEVEL)
			check.equal(into, need)
		end)

		test.case("perks every 10 levels", function()
			check.equal(Skills.perks(9), 0)
			check.equal(Skills.perks(10), 1)
			check.equal(Skills.perks(50), 5)
			check.equal(Skills.perkValue("Rancher", 30), 3)
		end)

		test.case("steal feeds Rustler only; unknown kinds feed nothing", function()
			local xp = Skills.xpFor("steal", 2)
			check.equal(xp.Rustler, 50)
			check.is_true(xp.Rancher == nil)
			check.is_true(next(Skills.xpFor("nothing", 1)) == nil)
		end)

		test.case("add reports level-ups", function()
			local state = {}
			local ups = Skills.add(state, "steal", 1)
			check.equal(#ups, 0)
			ups = Skills.add(state, "steal", 1) -- 50 xp > cost(1) = 40
			check.equal(#ups, 1)
			check.equal(ups[1].skill, "Rustler")
			check.equal(ups[1].to, 2)
		end)

		test.case("max level takes a long-term amount of play", function()
			local total = Skills.totalFor(Config.MAX_LEVEL)
			-- Roughly 20k-26k xp: ~900 steals for Rustler, ~10k collects for Rancher.
			check.is_true(total > 20000 and total < 26000)
		end)

		test.case("every skill has a perk per 10 levels and a colour", function()
			for _, skill in Config.list do
				check.is_true(skill.perkPer > 0)
				check.is_true(#skill.color == 7)
				check.is_true(next(skill.kinds) ~= nil)
			end
		end)
	end)
end
