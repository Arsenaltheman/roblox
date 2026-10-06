--!strict
-- Luck: the Active Luck meter and how luck reshapes odds.

local LuckConfig = require("../Config/Luck")
local Rarities = require("../Config/Rarities")
local Train = require("../Config/Train")

local Luck = {}

export type Sources = {
	activeMinutes: number?,
	horseshoe: boolean?,
	-- 1 when no server luck is running.
	serverLuck: number?,
	-- Extra event luck (Golden Express, Stampede).
	eventLuck: number?,
}

-- Active Luck meter value for a number of active minutes in this server.
function Luck.active(activeMinutes: number): number
	return math.min(1 + LuckConfig.activePerMinute * math.max(0, activeMinutes), LuckConfig.activeMax)
end

-- Total luck for a player's personal (reserved) cage.
function Luck.personal(sources: Sources): number
	local luck = Luck.active(sources.activeMinutes or 0)
	if sources.horseshoe then
		luck *= LuckConfig.horseshoe
	end
	luck *= sources.serverLuck or 1
	luck *= sources.eventLuck or 1
	return math.min(luck, LuckConfig.maxLuck)
end

-- Luck shared by the whole server (wild cages): no personal sources.
function Luck.shared(serverLuck: number?, eventLuck: number?): number
	return math.min((serverLuck or 1) * (eventLuck or 1), LuckConfig.maxLuck)
end

function Luck.soft(luck: number): number
	return luck ^ LuckConfig.softExponent
end

-- Rarity weights for wild cages after luck. Rarities a player isn't active enough for are not removed
-- here (cages are shared); they are gated at purchase time instead.
function Luck.rarityWeights(luck: number): { number }
	local weights = table.create(#Rarities.list, 0)
	for i, rarity in Rarities.list do
		weights[i] = rarity.wildWeight * (if rarity.luckAffected then luck else 1)
	end
	return weights
end

-- Reserved-cage delta weights: upgrades (delta >= +1) scale with soft luck.
function Luck.reservedDeltaWeights(luck: number): { number }
	local soft = Luck.soft(luck)
	local weights = table.create(#Train.reservedDeltas, 0)
	for i, delta in Train.reservedDeltas do
		weights[i] = Train.reservedDeltaWeights[i] * (if delta >= 1 then soft else 1)
	end
	return weights
end

function Luck.mutationChance(luck: number): number
	return math.min(Train.mutationChance * Luck.soft(luck), Train.mutationChanceCap)
end

-- Is a player active long enough to buy this rarity?
function Luck.canBuyRarity(rarityId: string, activeMinutes: number): boolean
	local rarity = Rarities.byId[rarityId]
	return rarity ~= nil and activeMinutes >= rarity.minActiveMinutes
end

return Luck
