local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local SeasonConfig = require("../../src/shared/Config/Season")
local Season = require("../../src/shared/Sim/Season")
local Trail = require("../../src/shared/Sim/Trail")
local Cosmetics = require("../../src/shared/Config/Cosmetics")
local TrailConfig = require("../../src/shared/Config/Trail")

-- Monday 2026-10-05 00:00 UTC (season 1 starts here).
local EPOCH = 1791158400

return function()
	test.suite("Season", function()
		test.case("season and week maths", function()
			check.equal(SeasonConfig.seasonOf(EPOCH), 1)
			check.equal(SeasonConfig.seasonOf(EPOCH - 1), 1) -- before the epoch still reads as season 1
			check.equal(SeasonConfig.seasonOf(EPOCH + 8 * 7 * 86400 - 1), 1)
			check.equal(SeasonConfig.seasonOf(EPOCH + 8 * 7 * 86400), 2)
			check.equal(SeasonConfig.seasonEndsAt(EPOCH + 5), EPOCH + 8 * 7 * 86400)
			check.equal(SeasonConfig.seasonStartsAt(3), EPOCH + 2 * 8 * 7 * 86400)
			check.equal(SeasonConfig.weekOfSeason(EPOCH), 1)
			check.equal(SeasonConfig.weekOfSeason(EPOCH + 7 * 86400), 2)
			check.equal(SeasonConfig.weekOfSeason(EPOCH + 8 * 7 * 86400 - 1), 8)
			-- Same week numbering as the weekly bounties (Monday 00:00 UTC rollover).
			for _, t in { EPOCH - 1, EPOCH, EPOCH + 123456, EPOCH + 30 * 86400 } do
				check.equal(SeasonConfig.week(t), Trail.week(t))
			end
			check.equal(SeasonConfig.weekEndsAt(SeasonConfig.week(EPOCH)), EPOCH + 7 * 86400)
		end)

		test.case("tier XP rises monotonically and tierAt inverts totalXp", function()
			local last = 0
			for tier = 1, SeasonConfig.PREMIUM_TIERS do
				check.is_true(SeasonConfig.tierXp(tier) > last)
				last = SeasonConfig.tierXp(tier)
				local at, into = SeasonConfig.tierAt(SeasonConfig.totalXp(tier))
				check.equal(at, tier)
				check.equal(into, 0)
				local before = SeasonConfig.tierAt(SeasonConfig.totalXp(tier) - 1)
				check.equal(before, tier - 1)
			end
			local top, into, size = SeasonConfig.tierAt(1e9)
			check.equal(top, SeasonConfig.PREMIUM_TIERS)
			check.equal(into, 0)
			check.equal(size, 0)
			-- Generous: a few hundred XP a day finishes the free track in a few weeks of play.
			check.is_true(SeasonConfig.totalXp(SeasonConfig.FREE_TIERS) <= 21 * 400)
			check.is_true(SeasonConfig.totalXp(SeasonConfig.PREMIUM_TIERS) <= 42 * SeasonConfig.XP_DAY_CAP)
		end)

		test.case("every tier has rewards, cosmetics exist, premium is perks and looks only", function()
			for tier = 1, SeasonConfig.FREE_TIERS do
				check.not_nil(SeasonConfig.freeReward(tier))
			end
			check.equal(SeasonConfig.freeReward(SeasonConfig.FREE_TIERS + 1), nil)
			check.equal(SeasonConfig.freeReward(5).kind, "luck")
			for tier = 1, SeasonConfig.PREMIUM_TIERS do
				local r = SeasonConfig.premiumReward(tier)
				check.not_nil(r)
				if r.id then
					check.not_nil(Cosmetics.byId[r.id])
				end
			end
			check.equal(SeasonConfig.premiumReward(20).id, "title_season")
			check.equal(SeasonConfig.premiumReward(40).id, "hat_season")
			check.equal(SeasonConfig.premiumReward(41), nil)
			for _, kind in SeasonConfig.xpFor do
				check.is_true(kind > 0)
			end
			check.is_true(#SeasonConfig.color(1) == 7 and SeasonConfig.color(1) ~= SeasonConfig.color(2))
		end)

		test.case("contract pool is deterministic, distinct and uses counted kinds", function()
			for _, contract in SeasonConfig.contractPool do
				check.is_true(TrailConfig.counted[contract.kind] == true)
				check.is_true(contract.goal > 0 and contract.nuggets > 0)
			end
			check.is_true(#SeasonConfig.contractPool >= SeasonConfig.CONTRACTS_PREMIUM)
			local a = SeasonConfig.contracts(1, 2963)
			check.equal(#a, SeasonConfig.CONTRACTS_PREMIUM)
			local seen = {}
			for _, i in a do
				check.is_true(not seen[i])
				seen[i] = true
			end
			check.equal(table.concat(SeasonConfig.contracts(1, 2963), ","), table.concat(a, ","))
			local differs = false
			for w = 2964, 2970 do
				if table.concat(SeasonConfig.contracts(1, w), ",") ~= table.concat(a, ",") then
					differs = true
				end
			end
			check.is_true(differs)
		end)

		test.case("daily XP cap and day rollover", function()
			local s = Season.new()
			check.equal(Season.addXp(s, 1000, EPOCH), 1000)
			check.equal(Season.addXp(s, 1000, EPOCH + 60), SeasonConfig.XP_DAY_CAP - 1000)
			check.equal(Season.addXp(s, 50, EPOCH + 120), 0)
			check.equal(s.Xp, SeasonConfig.XP_DAY_CAP)
			-- Next UTC day: room again.
			check.equal(Season.addXp(s, 50, EPOCH + 86400), 50)
			check.equal(s.XpToday, 50)
		end)

		test.case("season rollover resets XP and claims, keeps PremiumFor", function()
			local s = Season.new()
			Season.addXp(s, 500, EPOCH)
			s.PremiumFor = 1
			s.Claimed.f1 = true
			check.is_true(Season.hasPremium(s, EPOCH))
			check.is_true(Season.ensureSeason(s, EPOCH + 8 * 7 * 86400))
			check.equal(s.Season, 2)
			check.equal(s.Xp, 0)
			check.equal(next(s.Claimed), nil)
			check.equal(s.PremiumFor, 1)
			check.is_false(Season.hasPremium(s, EPOCH + 8 * 7 * 86400))
		end)

		test.case("claims need the tier, the pass for premium, and pay once", function()
			local s = Season.new()
			Season.ensureSeason(s, EPOCH)
			Season.addXp(s, SeasonConfig.totalXp(3), EPOCH)
			check.equal(Season.tier(s), 3)
			check.is_true(Season.canClaim(s, 1, false, EPOCH))
			check.is_true(Season.canClaim(s, 3, false, EPOCH))
			check.is_false(Season.canClaim(s, 4, false, EPOCH))
			check.is_false(Season.canClaim(s, 0, false, EPOCH))
			-- Premium is locked until the pass is bought for this season...
			check.is_false(Season.canClaim(s, 1, true, EPOCH))
			check.equal(#Season.claimable(s, true, EPOCH), 0)
			s.PremiumFor = 1
			-- ...then every passed tier is claimable at once (retroactive).
			check.equal(table.concat(Season.claimable(s, true, EPOCH), ","), "1,2,3")
			check.equal(table.concat(Season.claimable(s, false, EPOCH), ","), "1,2,3")
			check.not_nil(Season.claim(s, 2, false, EPOCH))
			check.equal(Season.claim(s, 2, false, EPOCH), nil)
			check.equal(table.concat(Season.claimable(s, false, EPOCH), ","), "1,3")
			check.not_nil(Season.claim(s, 3, true, EPOCH))
			check.is_true(s.Claimed.p3 and s.Claimed.f2)
			-- Free tiers stop at 20 even with lots of XP (set directly: addXp is capped per day).
			s.Xp = SeasonConfig.totalXp(SeasonConfig.PREMIUM_TIERS)
			check.is_false(Season.canClaim(s, SeasonConfig.FREE_TIERS + 1, false, EPOCH + 40 * 86400))
			check.is_true(Season.canClaim(s, SeasonConfig.PREMIUM_TIERS, true, EPOCH + 40 * 86400))
		end)

		test.case("contracts: 4 for everyone, 6 with the pass, progress capped, claimed once", function()
			local s = Season.new()
			Season.ensureSeason(s, EPOCH)
			check.equal(#Season.activeContracts(s, EPOCH), SeasonConfig.CONTRACTS_FREE)
			s.PremiumFor = 1
			local active = Season.activeContracts(s, EPOCH)
			check.equal(#active, SeasonConfig.CONTRACTS_PREMIUM)
			local contract = SeasonConfig.contractPool[active[1]]
			check.is_false(Season.claimContract(s, 1, EPOCH) ~= nil)
			Season.contractEvent(s, contract.kind, contract.goal + 5, EPOCH)
			check.equal(s.Contracts.Progress[tostring(active[1])], contract.goal)
			check.not_nil(Season.claimContract(s, 1, EPOCH))
			check.equal(Season.claimContract(s, 1, EPOCH), nil)
			check.equal(Season.claimContract(s, 7, EPOCH), nil)
			-- Monday: a fresh week.
			check.is_true(Season.ensureWeek(s, EPOCH + 7 * 86400))
			check.equal(next(s.Contracts.Progress), nil)
		end)
	end)
end
