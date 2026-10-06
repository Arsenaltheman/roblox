local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local StealRules = require("../../src/shared/Sim/StealRules")

local function thief(overrides)
	local t = { frontier = 0, passes = {}, carrying = false, stunnedUntil = 0, isOwner = false }
	for k, v in overrides or {} do
		t[k] = v
	end
	return t
end

local function target(overrides)
	local t = {
		ownerShieldUntil = 0,
		lockedUntil = 0,
		pickedUntil = 0,
		critterTier = 5,
		critterBranded = false,
		critterInSafePen = false,
		critterInTransit = false,
	}
	for k, v in overrides or {} do
		t[k] = v
	end
	return t
end

return function()
	test.suite("StealRules", function()
		test.case("an open ranch can be robbed", function()
			check.falsy(StealRules.canSteal(thief(), target(), 100))
		end)

		test.case("kept protections block theft", function()
			check.not_nil(StealRules.canSteal(thief(), target({ ownerShieldUntil = 200 }), 100))
			check.not_nil(StealRules.canSteal(thief(), target({ critterBranded = true }), 100))
			check.not_nil(StealRules.canSteal(thief(), target({ critterInSafePen = true }), 100))
		end)

		test.case("lock blocks unless a lockpick is active", function()
			check.not_nil(StealRules.canSteal(thief(), target({ lockedUntil = 200 }), 100))
			check.falsy(StealRules.canSteal(thief(), target({ lockedUntil = 200, pickedUntil = 108 }), 100))
		end)

		test.case("carry limit, full hands, stun and own ranch", function()
			check.not_nil(StealRules.canSteal(thief(), target({ critterTier = 15 }), 100))
			check.falsy(StealRules.canSteal(thief({ passes = { HeavySaddlebag = true } }), target({ critterTier = 15 }), 100))
			check.not_nil(StealRules.canSteal(thief({ carrying = true }), target(), 100))
			check.not_nil(StealRules.canSteal(thief({ stunnedUntil = 101 }), target(), 100))
			check.not_nil(StealRules.canSteal(thief({ isOwner = true }), target(), 100))
		end)

		test.case("lasso: owner returns it, others intercept", function()
			check.equal(StealRules.lassoOutcome(1, 1, 5, 0, {}, false), "return")
			check.equal(StealRules.lassoOutcome(2, 1, 5, 0, {}, false), "intercept")
			check.equal(StealRules.lassoOutcome(2, 1, 5, 0, {}, true), "return")
			check.equal(StealRules.lassoOutcome(2, 1, 20, 0, {}, false), "return")
		end)
	end)
end
