--!strict
-- Odds tables shown to players before anything random. Roblox requires every outcome's chance,
-- summing to exactly 100%, updated live when luck changes. Display values use the largest-remainder
-- method so the rounded numbers always add up to 100.

local Luck = require("./Luck")
local Mutations = require("../Config/Mutations")
local Progression = require("../Config/Progression")
local Rarities = require("../Config/Rarities")
local Species = require("../Config/Species")
local Train = require("../Config/Train")

export type Row = {
	id: string,
	label: string,
	-- Exact probability 0..1 (for logic).
	probability: number,
	-- Rounded percentage for display; the column sums to exactly 100.
	percent: number,
}

local Odds = {}

Odds.DISPLAY_DECIMALS = 4
Odds.ROUNDING_NOTE = "Probabilities are rounded to 4 decimal places."

-- Normalised probabilities from weights.
function Odds.normalise(weights: { number }): { number }
	local total = 0
	for _, w in weights do
		total += w
	end
	local out = table.create(#weights, 0)
	for i, w in weights do
		out[i] = if total > 0 then w / total else 0
	end
	return out
end

-- Round probabilities to percentages with `decimals` places that sum to exactly 100.
function Odds.displayPercents(probabilities: { number }, decimals: number?): { number }
	local places = decimals or Odds.DISPLAY_DECIMALS
	local units = 100 * 10 ^ places
	local floors = table.create(#probabilities, 0)
	local remainders = {}
	local used = 0
	for i, p in probabilities do
		local exact = p * units
		local f = math.floor(exact + 1e-9)
		floors[i] = f
		used += f
		table.insert(remainders, { index = i, frac = exact - f })
	end
	table.sort(remainders, function(a, b)
		if a.frac == b.frac then
			return a.index < b.index
		end
		return a.frac > b.frac
	end)
	local left = math.floor(units - used + 0.5)
	local k = 1
	while left > 0 and #remainders > 0 do
		local entry = remainders[((k - 1) % #remainders) + 1]
		floors[entry.index] += 1
		left -= 1
		k += 1
	end
	local out = table.create(#probabilities, 0)
	for i, f in floors do
		out[i] = f / 10 ^ places
	end
	return out
end

local function rows(ids: { string }, labels: { string }, probabilities: { number }): { Row }
	local percents = Odds.displayPercents(probabilities)
	local out = {}
	for i, id in ids do
		table.insert(
			out,
			{ id = id, label = labels[i], probability = probabilities[i], percent = percents[i] }
		)
	end
	return out
end

-- Wild cage rarity odds at a given shared luck.
function Odds.wildRarities(luck: number): { Row }
	local probabilities = Odds.normalise(Luck.rarityWeights(luck))
	local ids, labels = {}, {}
	for _, rarity in Rarities.list do
		table.insert(ids, rarity.id)
		table.insert(labels, rarity.name)
	end
	return rows(ids, labels, probabilities)
end

-- Per-species odds for wild cages (each species within a rarity is equally likely).
function Odds.wildSpecies(luck: number): { Row }
	local rarityProbability = Odds.normalise(Luck.rarityWeights(luck))
	local ids, labels, probabilities = {}, {}, {}
	for i, rarity in Rarities.list do
		local count = rarity.maxTier - rarity.minTier + 1
		for tier = rarity.minTier, rarity.maxTier do
			local species = Species.byTier[tier]
			table.insert(ids, species.id)
			table.insert(labels, species.name)
			table.insert(probabilities, rarityProbability[i] / count)
		end
	end
	return rows(ids, labels, probabilities)
end

-- The reserved cage's possible tiers for a band tier at a given personal luck.
-- Deltas that would fall outside 1..maxTier fold into the nearest valid tier.
-- Highest tier a player's reserved cage can hold for how long they've been active here (matches
-- Manifest.maxTierForActivity, so the shown odds are exactly what can happen).
local function activityCap(activeMinutes: number): number
	local allowed = 1
	for _, rarity in Rarities.list do
		if activeMinutes >= rarity.minActiveMinutes then
			allowed = rarity.maxTier
		end
	end
	return allowed
end

function Odds.reserved(bandTier: number, luck: number, activeMinutes: number?): { Row }
	local cap = math.min(activityCap(activeMinutes or math.huge), Rarities.maxTier)
	local weights = Odds.normalise(Luck.reservedDeltaWeights(luck))
	local byTier: { [number]: number } = {}
	local order: { number } = {}
	for i, delta in Train.reservedDeltas do
		local tier = math.clamp(bandTier + delta, 1, cap)
		if byTier[tier] == nil then
			byTier[tier] = 0
			table.insert(order, tier)
		end
		byTier[tier] += weights[i]
	end
	table.sort(order)
	local ids, labels, probabilities = {}, {}, {}
	for _, tier in order do
		local species = Species.byTier[tier]
		table.insert(ids, species.id)
		table.insert(labels, species.name)
		table.insert(probabilities, byTier[tier])
	end
	return rows(ids, labels, probabilities)
end

-- Mutation odds on a cage, including "none".
function Odds.mutations(luck: number, weatherMutation: string?): { Row }
	local ids, labels, probabilities = { "None" }, { "No mutation" }, {}
	if weatherMutation then
		local chance = Progression.weather.cageMutationChance
		probabilities[1] = 1 - chance
		local mutation = Mutations.byId[weatherMutation]
		table.insert(ids, mutation.id)
		table.insert(labels, mutation.name)
		table.insert(probabilities, chance)
		return rows(ids, labels, probabilities)
	end
	local chance = Luck.mutationChance(luck)
	probabilities[1] = 1 - chance
	local weights = {}
	for _, mutation in Mutations.list do
		table.insert(weights, mutation.weight)
	end
	local split = Odds.normalise(weights)
	for i, mutation in Mutations.list do
		table.insert(ids, mutation.id)
		table.insert(labels, mutation.name)
		table.insert(probabilities, chance * split[i])
	end
	return rows(ids, labels, probabilities)
end

-- Egg outcomes for a parent tier (capped at `maxTier`).
function Odds.egg(parentTier: number, maxTier: number?): { Row }
	local cap = math.min(maxTier or Rarities.maxTier, Rarities.maxTier)
	local weights = Odds.normalise(Progression.eggs.offsetWeights)
	local byTier: { [number]: number } = {}
	local order: { number } = {}
	for i, offset in Progression.eggs.offsets do
		local tier = math.clamp(parentTier + offset, 1, cap)
		if byTier[tier] == nil then
			byTier[tier] = 0
			table.insert(order, tier)
		end
		byTier[tier] += weights[i]
	end
	table.sort(order)
	local ids, labels, probabilities = {}, {}, {}
	for _, tier in order do
		local species = Species.byTier[tier]
		table.insert(ids, species.id)
		table.insert(labels, species.name)
		table.insert(probabilities, byTier[tier])
	end
	return rows(ids, labels, probabilities)
end

return Odds
