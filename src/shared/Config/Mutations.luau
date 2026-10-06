--!strict
-- Mutations multiply a critter's income. A critter has at most one; a better roll replaces a worse one.

export type Mutation = {
	id: string,
	name: string,
	multiplier: number,
	-- Relative weight when a cage rolls a random mutation.
	weight: number,
	color: string,
}

local Mutations: { Mutation } = {
	{ id = "Gold", name = "Gold", multiplier = 1.5, weight = 40, color = "#FFD34D" },
	{ id = "Diamond", name = "Diamond", multiplier = 2, weight = 22, color = "#9FF3FF" },
	{ id = "Frosty", name = "Frosty", multiplier = 2.5, weight = 12, color = "#CFE9FF" },
	{ id = "Electric", name = "Electric", multiplier = 3, weight = 10, color = "#FFF15C" },
	{ id = "Molten", name = "Molten", multiplier = 4, weight = 7, color = "#FF6A1F" },
	{ id = "Ghost", name = "Ghost", multiplier = 5, weight = 5, color = "#B8F5E0" },
	{ id = "Cosmic", name = "Cosmic", multiplier = 7, weight = 3, color = "#7B5CFF" },
	{ id = "Rainbow", name = "Rainbow", multiplier = 10, weight = 1, color = "#FF5FD2" },
}

local byId: { [string]: Mutation } = {}
for _, mutation in Mutations do
	byId[mutation.id] = mutation
end

local function multiplierOf(id: string?): number
	if id == nil then
		return 1
	end
	local mutation = byId[id]
	return if mutation then mutation.multiplier else 1
end

return {
	list = Mutations,
	byId = byId,
	multiplierOf = multiplierOf,
}
