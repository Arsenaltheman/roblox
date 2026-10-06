--!strict
-- Free random rewards: eggs, strongboxes and weather. None of these can be bought with Robux or with
-- Robux-buyable currency, so they are not "paid random items" (odds are still shown in-game).

local Rng = require("./Rng")
local Mutations = require("../Config/Mutations")
local Progression = require("../Config/Progression")
local Rarities = require("../Config/Rarities")

local Loot = {}

-- Tier hatched from an egg laid by (or matched to) `parentTier`, capped at `maxTier`.
function Loot.hatch(rng: Rng.Rng, parentTier: number, maxTier: number?): number
	local eggs = Progression.eggs
	local offset = eggs.offsets[rng:weighted(eggs.offsetWeights)]
	local cap = math.min(maxTier or Rarities.maxTier, Rarities.maxTier)
	return math.clamp(parentTier + offset, 1, cap)
end

export type StrongboxLoot = {
	kind: "cash" | "nuggets" | "egg" | "cosmetic",
	-- cash: seconds of income; nuggets: amount; egg: tier offset; cosmetic: unused.
	amount: number,
	-- True when the lucky-streak meter forced this result.
	pity: boolean,
}

-- `cracksSinceEgg` is the player's lucky-streak meter; the caller resets it when an egg drops.
function Loot.strongbox(rng: Rng.Rng, cracksSinceEgg: number): StrongboxLoot
	local box = Progression.strongbox
	if cracksSinceEgg + 1 >= box.pity then
		return { kind = "egg", amount = 1, pity = true }
	end
	local kind = box.kinds[rng:weighted(box.weights)]
	if kind == "cash" then
		return { kind = "cash", amount = rng:int(box.cashSecondsMin, box.cashSecondsMax), pity = false }
	elseif kind == "nuggets" then
		return { kind = "nuggets", amount = rng:int(box.nuggetsMin, box.nuggetsMax), pity = false }
	elseif kind == "egg" then
		return { kind = "egg", amount = 0, pity = false }
	end
	return { kind = "cosmetic", amount = 0, pity = false }
end

-- Which mutation the next weather event brings (same weights as cage mutations).
function Loot.weather(rng: Rng.Rng): string
	local weights = {}
	for _, mutation in Mutations.list do
		table.insert(weights, mutation.weight)
	end
	return Mutations.list[rng:weighted(weights)].id
end

-- Whether a critter with `current` mutation should take `incoming` (only if it's better).
function Loot.betterMutation(current: string?, incoming: string): boolean
	return Mutations.multiplierOf(incoming) > Mutations.multiplierOf(current)
end

return Loot
