local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local Trade = require("../../src/shared/Sim/Trade")

local function who(overrides: { [string]: any }?): any
	local t: { [string]: any } = { frontier = 1, accountAge = 30, tradingAllowed = true }
	for k, v in overrides or {} do
		t[k] = v
	end
	return t
end

return function()
	test.suite("Trade", function()
		test.case("eligibility: policy, account age and Frontier", function()
			check.falsy(Trade.eligibility(who()))
			check.not_nil(Trade.eligibility(who({ tradingAllowed = false })))
			check.not_nil(Trade.eligibility(who({ accountAge = 6 })))
			check.falsy(Trade.eligibility(who({ accountAge = 7 })))
			check.not_nil(Trade.eligibility(who({ frontier = 0 })))
		end)

		test.case("branded, paid-luck and in-transit critters can't be traded", function()
			check.falsy(Trade.critterBlock({ br = false, pr = false, it = false }))
			check.not_nil(Trade.critterBlock({ br = true, pr = false, it = false }))
			check.not_nil(Trade.critterBlock({ br = false, pr = true, it = false }))
			check.not_nil(Trade.critterBlock({ br = false, pr = false, it = true }))
		end)

		test.case("room counts the critters given away", function()
			check.is_true(Trade.hasRoom(6, 4, 0, 2))
			check.is_false(Trade.hasRoom(6, 5, 0, 2))
			check.is_true(Trade.hasRoom(6, 6, 2, 2))
			check.is_false(Trade.hasRoom(6, 6, 1, 2))
		end)

		test.case("one pending invite per player, expiring after 20 s", function()
			local invites = {}
			check.not_nil(Trade.canInvite(invites, 1, 1, 0))
			check.falsy(Trade.canInvite(invites, 1, 2, 0))
			Trade.addInvite(invites, 1, 2, 0)
			check.not_nil(Trade.canInvite(invites, 1, 3, 1)) -- 1 already has one out
			check.not_nil(Trade.canInvite(invites, 3, 2, 1)) -- 2 already has one in
			check.not_nil(Trade.canInvite(invites, 2, 3, 1)) -- 2 is busy answering
			check.falsy(Trade.canInvite(invites, 3, 4, 1))
			-- Expired invites can't be accepted and free both players.
			check.is_false(Trade.takeInvite(invites, 2, 1, 25))
			Trade.addInvite(invites, 1, 2, 30)
			check.is_false(Trade.takeInvite(invites, 2, 3, 31))
			check.is_true(Trade.takeInvite(invites, 2, 1, 31))
			check.falsy(Trade.canInvite(invites, 1, 2, 31))
			Trade.addInvite(invites, 1, 2, 40)
			local expired = Trade.prune(invites, 60)
			check.equal(#expired, 1)
			check.falsy(invites[2])
		end)

		test.case("offers: up to 6 critters, nuggets within balance", function()
			local s = Trade.newSession(1, 2)
			for i = 1, Trade.MAX_CRITTERS do
				check.falsy(Trade.setCritter(s, 1, tostring(i), true, 0))
			end
			check.not_nil(Trade.setCritter(s, 1, "99", true, 0))
			check.equal(#s.offers[1].critters, 6)
			check.falsy(Trade.setCritter(s, 1, "3", false, 0))
			check.equal(#s.offers[1].critters, 5)
			check.not_nil(Trade.setNuggets(s, 2, 500, 100, 0))
			check.falsy(Trade.setNuggets(s, 2, 100, 100, 0))
			check.equal(s.offers[2].nuggets, 100)
			check.not_nil(Trade.setNuggets(s, 2, 0 / 0, 100, 0))
			check.not_nil(Trade.setCritter(s, 3, "1", true, 0))
		end)

		test.case("empty trades can't be readied", function()
			local s = Trade.newSession(1, 2)
			check.not_nil(Trade.setReady(s, 1, true, 0))
			Trade.setNuggets(s, 2, 5, 10, 0)
			check.falsy(Trade.setReady(s, 1, true, 0))
		end)

		test.case("both READY starts a 5 s countdown; it executes when due", function()
			local s = Trade.newSession(1, 2)
			Trade.setCritter(s, 1, "7", true, 0)
			Trade.setReady(s, 1, true, 10)
			check.falsy(s.countdownEnd)
			Trade.setReady(s, 2, true, 11)
			check.equal(s.countdownEnd, 16)
			-- Re-sending READY doesn't restart the countdown.
			Trade.setReady(s, 1, true, 13)
			check.equal(s.countdownEnd, 16)
			check.is_false(Trade.due(s, 15.9))
			check.is_true(Trade.due(s, 16))
		end)

		test.case("any change resets both READY flags and cancels the countdown", function()
			local s = Trade.newSession(1, 2)
			Trade.setCritter(s, 1, "7", true, 0)
			Trade.setReady(s, 1, true, 1)
			Trade.setReady(s, 2, true, 1)
			local v = s.version
			Trade.setNuggets(s, 2, 10, 10, 3)
			check.is_false(s.ready[1])
			check.is_false(s.ready[2])
			check.falsy(s.countdownEnd)
			check.is_false(Trade.due(s, 100))
			check.equal(s.version, v + 1)
			check.equal(s.changedAt[2], 3)
			-- Un-READY also stops it.
			Trade.setReady(s, 1, true, 4)
			Trade.setReady(s, 2, true, 4)
			Trade.setReady(s, 2, false, 5)
			check.falsy(s.countdownEnd)
			-- No-op changes don't reset anything.
			Trade.setReady(s, 2, true, 6)
			Trade.setCritter(s, 1, "7", true, 7)
			Trade.setNuggets(s, 2, 10, 10, 7)
			check.equal(s.countdownEnd, 11)
		end)
	end)
end
