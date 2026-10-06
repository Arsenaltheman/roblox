local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local RemoteNames = require("../../src/shared/Net/RemoteNames")
local Schemas = require("../../src/shared/Net/Schemas")

return function()
	test.suite("Network schemas", function()
		test.case("every client->server message has a schema", function()
			for _, list in { RemoteNames.clientToServer, RemoteNames.functions } do
				for _, name in list do
					check.not_nil(Schemas.schemas[name], frktest.assert.msg(`missing schema for {name}`))
				end
			end
		end)

		test.case("valid requests pass", function()
			check.is_true(Schemas.validate("BuyCage", { 12, 3 }, 2))
			check.is_true(Schemas.validate("Collect", {}, 0))
			check.is_true(Schemas.validate("Sell", { "42" }, 1))
			check.is_true(Schemas.validate("Claim", { "gift", 3 }, 2))
			check.is_true(Schemas.validate("Setting", { "Music", 0.5 }, 2))
		end)

		test.case("wrong types, NaN, out-of-range and extra args are rejected", function()
			check.is_false(Schemas.validate("BuyCage", { "12", 3 }, 2))
			check.is_false(Schemas.validate("BuyCage", { 0 / 0, 3 }, 2))
			check.is_false(Schemas.validate("BuyCage", { 1.5, 3 }, 2))
			check.is_false(Schemas.validate("BuyCage", { 12, 999 }, 2))
			check.is_false(Schemas.validate("BuyCage", { 12, 3, "extra" }, 3))
			check.is_false(Schemas.validate("Collect", { true }, 1))
			check.is_false(Schemas.validate("Sell", { "abc" }, 1))
			check.is_false(Schemas.validate("Sell", { "12345678901" }, 1))
			check.is_false(Schemas.validate("Claim", { "robux", 1 }, 2))
			check.is_false(Schemas.validate("Setting", { "Music", 5 }, 2))
			check.is_false(Schemas.validate("NotARemote", {}, 0))
		end)

		test.case("strings are length-limited", function()
			check.is_false(Schemas.validate("BugReport", { "other", string.rep("a", 201) }, 2))
			check.is_true(Schemas.validate("BugReport", { "other", "train stuck" }, 2))
		end)
	end)
end
