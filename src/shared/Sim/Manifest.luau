--!strict
-- Rolls what every cage on one train carries. Deterministic for a given seed, so any reported
-- train can be replayed exactly from the logged seed.

local Economy = require("./Economy")
local Luck = require("./Luck")
local Rng = require("./Rng")
local Mutations = require("../Config/Mutations")
local Progression = require("../Config/Progression")
local Rarities = require("../Config/Rarities")
local Species = require("../Config/Species")
local Train = require("../Config/Train")

export type PlayerSlot = {
	userId: number,
	bandTier: number,
	-- Luck for this player's reserved cage (Active Luck x horseshoe x server luck ...).
	personalLuck: number,
	activeMinutes: number,
}

export type Cage = {
	id: number,
	tier: number,
	speciesId: string,
	rarity: string,
	mutation: string?,
	-- userId of the reserved owner, or 0 for a wild cage anyone can buy.
	owner: number,
	price: number,
	goldenTicket: boolean,
}

export type Options = {
	-- Luck shared by everyone (server luck x event luck); applies to wild cages.
	sharedLuck: number?,
	weatherMutation: string?,
	golden: boolean?,
}

export type Manifest = {
	cycle: number,
	seed: number,
	golden: boolean,
	strongbox: boolean,
	cages: { Cage },
}

local Manifest = {}

local function rollMutation(rng: Rng.Rng, luck: number, weatherMutation: string?): string?
	if weatherMutation then
		if rng:chance(Progression.weather.cageMutationChance) then
			return weatherMutation
		end
		return nil
	end
	if not rng:chance(Luck.mutationChance(luck)) then
		return nil
	end
	local weights = {}
	for _, mutation in Mutations.list do
		table.insert(weights, mutation.weight)
	end
	return Mutations.list[rng:weighted(weights)].id
end

-- Highest tier a player with `activeMinutes` is allowed to receive in a reserved cage.
function Manifest.maxTierForActivity(activeMinutes: number): number
	local allowed = 1
	for _, rarity in Rarities.list do
		if activeMinutes >= rarity.minActiveMinutes then
			allowed = rarity.maxTier
		end
	end
	return allowed
end

local function makeCage(id: number, tier: number, owner: number, mutation: string?, goldenTicket: boolean): Cage
	local species = Species.byTier[tier]
	return {
		id = id,
		tier = tier,
		speciesId = species.id,
		rarity = Rarities.forTier(tier).id,
		mutation = mutation,
		owner = owner,
		price = Economy.price(tier),
		goldenTicket = goldenTicket,
	}
end

function Manifest.roll(seed: number, cycle: number, players: { PlayerSlot }, options: Options?): Manifest
	local opts = options or {}
	local rng = Rng.new(Rng.derive(seed, cycle))
	local golden = opts.golden == true
	local eventLuck = if golden then Train.goldenExpress.luck else 1
	local sharedLuck = Luck.shared(opts.sharedLuck, eventLuck)

	local cages: { Cage } = {}
	local nextId = 1

	-- One reserved cage per player present.
	for _, slot in players do
		local luck = slot.personalLuck * eventLuck
		local deltaIndex = rng:weighted(Luck.reservedDeltaWeights(luck))
		local delta = Train.reservedDeltas[deltaIndex]
		local cap = Manifest.maxTierForActivity(slot.activeMinutes)
		local tier = math.clamp(slot.bandTier + delta, 1, math.min(cap, Rarities.maxTier))
		local mutation = rollMutation(rng, luck, opts.weatherMutation)
		table.insert(cages, makeCage(nextId, tier, slot.userId, mutation, delta >= Train.goldenTicketDelta))
		nextId += 1
	end

	-- Wild cages fill the rest of the train (at least minWildCages).
	local total = Train.cars * Train.cagesPerCar
	local wildCount = math.max(Train.minWildCages, total - #players)
	local rarityWeights = Luck.rarityWeights(sharedLuck)
	for _ = 1, wildCount do
		local rarity = Rarities.list[rng:weighted(rarityWeights)]
		local tier = rng:int(rarity.minTier, rarity.maxTier)
		local mutation = rollMutation(rng, sharedLuck, opts.weatherMutation)
		table.insert(cages, makeCage(nextId, tier, 0, mutation, false))
		nextId += 1
	end

	return {
		cycle = cycle,
		seed = seed,
		golden = golden,
		strongbox = cycle % Train.strongboxEvery == Train.strongboxEvery - 1,
		cages = cages,
	}
end

return Manifest
