local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local Heist = require("../../src/shared/Config/Heist")
local Layout = require("../../src/shared/Config/Layout")

return function()
	test.suite("Heist", function()
		test.case("zones get deeper, faster and rarer", function()
			for i = 2, #Heist.zones do
				local a, b = Heist.zones[i - 1], Heist.zones[i]
				check.is_true(b.chaseSpeed > a.chaseSpeed)
				check.is_true(b.minTier > a.minTier)
				check.is_true(b.suggestedBoots >= a.suggestedBoots)
			end
		end)

		test.case("suggested boots outrun the zone's guards while carrying", function()
			for _, zone in Heist.zones do
				local speed = Heist.walkSpeed(zone.suggestedBoots, false, true)
				check.is_true(speed > zone.chaseSpeed)
				-- ...and two levels lower does not (the upgrade actually matters).
				if zone.suggestedBoots >= 2 then
					check.is_true(Heist.walkSpeed(zone.suggestedBoots - 2, false, true) < zone.chaseSpeed)
				end
			end
		end)

		test.case("rolled tiers stay in range, jackpot only in the last zone", function()
			for _, zone in Heist.zones do
				for i = 0, 50 do
					local tier = Heist.rollTier(zone, i / 51, 0.5)
					check.is_true(tier >= zone.minTier and tier <= zone.maxTier)
				end
				local jackpot = Heist.rollTier(zone, 0.99, 0)
				if zone.id == #Heist.zones then
					check.is_true(jackpot >= 37 and jackpot <= 40)
				else
					check.is_true(jackpot <= zone.maxTier)
				end
			end
		end)

		test.case("boots cost rises and stops at max", function()
			local previous = 0
			for level = 0, Heist.MAX_BOOTS - 1 do
				local cost = Heist.bootsCost(level) :: number
				check.is_true(cost > previous)
				previous = cost
			end
			check.falsy(Heist.bootsCost(Heist.MAX_BOOTS))
		end)

		test.case("zones stay clear of the town, the track and each other", function()
			local trackFar = Layout.track.halfStraight + Layout.track.radius -- furthest track x
			for _, zone in Heist.zones do
				-- Outside the track loop (stadium) with room to spare.
				local cx = math.max(0, math.abs(zone.x) - Layout.track.halfStraight)
				local dz = zone.z - Layout.track.centerZ
				local fromLoop = math.sqrt(cx * cx + dz * dz) - Layout.track.radius
				check.is_true(fromLoop > zone.radius + 10)
				check.is_true(math.abs(zone.x) < 400 and zone.z > -330 and zone.z < 480)
				for _, other in Heist.zones do
					if other ~= zone then
						local d = math.sqrt((zone.x - other.x) ^ 2 + (zone.z - other.z) ^ 2)
						check.is_true(d > zone.radius + other.radius + 40)
					end
				end
			end
			check.is_true(trackFar > 0)
		end)
	end)
end
