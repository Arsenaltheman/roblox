local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check
local req = frktest.assert.require

local Mutations = require("../../src/shared/Config/Mutations")
local Products = require("../../src/shared/Config/Products")
local Progression = require("../../src/shared/Config/Progression")
local Rarities = require("../../src/shared/Config/Rarities")
local Species = require("../../src/shared/Config/Species")
local Train = require("../../src/shared/Config/Train")

return function()
	test.suite("Config integrity", function()
		test.case("rarity tiers are contiguous from 1 to maxTier", function()
			local expected = 1
			for _, rarity in Rarities.list do
				check.equal(rarity.minTier, expected)
				req.is_true(rarity.maxTier >= rarity.minTier)
				expected = rarity.maxTier + 1
			end
			check.equal(Rarities.maxTier, 40)
		end)

		test.case("every tier has exactly one species", function()
			local seen = {}
			for _, species in Species.list do
				check.falsy(seen[species.tier])
				seen[species.tier] = true
			end
			for tier = 1, Rarities.maxTier do
				check.not_nil(Species.byTier[tier])
			end
			check.equal(Species.count, Rarities.maxTier)
		end)

		test.case("species ids are unique (including exclusives)", function()
			local seen = {}
			local total = 0
			for _, list in { Species.list, Species.exclusives } do
				for _, species in list do
					check.falsy(seen[species.id])
					seen[species.id] = true
					total += 1
				end
			end
			check.equal(total, #Species.list + #Species.exclusives)
		end)

		test.case("mutation multipliers increase with rarity of the mutation", function()
			local last = 1
			for _, mutation in Mutations.list do
				check.is_true(mutation.multiplier > last)
				last = mutation.multiplier
			end
		end)

		test.case("product keys are unique and prices positive", function()
			local seen = {}
			for _, product in Products.list do
				check.falsy(seen[product.key])
				seen[product.key] = true
				check.is_true(product.price > 0)
			end
		end)

		test.case("anything that changes luck is marked random (odds + policy gating)", function()
			for _, key in { "LuckyHorseshoe", "ServerLuck2", "ServerLuck3", "ServerLuck5", "SheriffStar" } do
				check.is_true(Products.byKey[key].random == true)
			end
		end)

		test.case("reserved delta table is consistent", function()
			check.equal(#Train.reservedDeltas, #Train.reservedDeltaWeights)
		end)

		test.case("playtime gifts are in time order", function()
			local last = 0
			for _, gift in Progression.gifts do
				check.is_true(gift.minute > last)
				last = gift.minute
			end
		end)
	end)
end
