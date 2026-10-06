local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local Profile = require("../../src/shared/Sim/Profile")

return function()
	test.suite("Profile (saves)", function()
		test.case("template is the current version with starting cash", function()
			local data = Profile.template()
			check.equal(data.V, Profile.CURRENT_VERSION)
			check.equal(data.Cash, 100)
		end)

		test.case("current profiles migrate as a no-op", function()
			local result = Profile.migrate(Profile.template())
			check.is_true(result.ok)
		end)

		test.case("version guard refuses newer profiles", function()
			local data = Profile.template()
			data.V = Profile.CURRENT_VERSION + 1
			local result = Profile.migrate(data)
			check.is_false(result.ok)
			check.equal(result.reason, "newer")
		end)

		test.case("migrations chain step by step (example v1 -> v3)", function()
			local steps = {
				[1] = function(d)
					d.Gems = d.Nuggets
					d.V = 2
					return d
				end,
				[2] = function(d)
					d.Gems = nil
					d.V = 3
					return d
				end,
			}
			local result = Profile.migrate(Profile.template(), steps, 3)
			check.is_true(result.ok)
			check.equal(result.data.V, 3)
		end)

		test.case("missing or broken migrations fail loudly", function()
			local missing = Profile.migrate(Profile.template(), {}, 2)
			check.is_false(missing.ok)
			local broken = Profile.migrate(Profile.template(), {
				[1] = function(d)
					return d
				end,
			}, 2)
			check.is_false(broken.ok)
		end)

		test.case("receipts are idempotent and capped", function()
			local data = Profile.template()
			check.is_true(Profile.recordReceipt(data, "a"))
			check.is_false(Profile.recordReceipt(data, "a"))
			for i = 1, 150 do
				Profile.recordReceipt(data, tostring(i))
			end
			check.equal(#data.Receipts, Profile.MAX_RECEIPTS)
		end)

		test.case("best tier ignores critters being carried away", function()
			local data = Profile.template()
			data.Critters["1"] = { s = "x", tier = 5, p = 1, src = "cage", uid = 1, pr = false, br = false, it = false, born = 0 }
			data.Critters["2"] = { s = "y", tier = 9, p = 2, src = "cage", uid = 1, pr = false, br = false, it = true, born = 0 }
			check.equal(Profile.bestTier(data), 5)
		end)
	end)
end
