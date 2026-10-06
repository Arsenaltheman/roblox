local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local RateLimit = require("../../src/shared/Sim/RateLimit")

-- Every client->server remote must have a limit. Keep in sync with src/shared/Net/Remotes.luau.
local REMOTES = require("../../src/shared/Net/RemoteNames")

return function()
	test.suite("RateLimit", function()
		test.case("burst then refuse, then refill over time", function()
			local limiter = RateLimit.newLimiter()
			for _ = 1, 6 do
				check.is_true(limiter:allow("BuyCage", 0))
			end
			check.is_false(limiter:allow("BuyCage", 0))
			check.is_true(limiter:allow("BuyCage", 0.3))
			check.is_false(limiter:allow("BuyCage", 0.3))
		end)

		test.case("unknown events are refused", function()
			check.is_false(RateLimit.newLimiter():allow("DoAnything", 0))
		end)

		test.case("every client->server remote has a limit", function()
			for _, name in REMOTES.clientToServer do
				check.not_nil(RateLimit.limits[name], frktest.assert.msg(`missing rate limit for {name}`))
			end
		end)
	end)
end
