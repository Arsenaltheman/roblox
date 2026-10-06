--!strict
-- Rarity ladder. Order matters: index 1 is the most common.
-- Colors are hex strings so this module stays free of Roblox types (it also runs under Lune).

export type Rarity = {
	id: string,
	name: string,
	color: string,
	minTier: number,
	maxTier: number,
	-- Relative weight on Wild cages before luck is applied.
	wildWeight: number,
	-- Luck multiplies this rarity's weight when true (Rare and above).
	luckAffected: boolean,
	-- Minutes of activity in the current server before a player may buy this rarity.
	minActiveMinutes: number,
	-- Shape shown next to the color so rarity never relies on color alone.
	icon: string,
}

local Rarities: { Rarity } = {
	{
		id = "Common",
		name = "Common",
		color = "#A7ADB4",
		minTier = 1,
		maxTier = 6,
		wildWeight = 50,
		luckAffected = false,
		minActiveMinutes = 0,
		icon = "circle",
	},
	{
		id = "Uncommon",
		name = "Uncommon",
		color = "#5FCB4E",
		minTier = 7,
		maxTier = 12,
		wildWeight = 25,
		luckAffected = false,
		minActiveMinutes = 0,
		icon = "triangle",
	},
	{
		id = "Rare",
		name = "Rare",
		color = "#3A9BF0",
		minTier = 13,
		maxTier = 18,
		wildWeight = 13,
		luckAffected = true,
		minActiveMinutes = 0,
		icon = "square",
	},
	{
		id = "Epic",
		name = "Epic",
		color = "#A35BF0",
		minTier = 19,
		maxTier = 24,
		wildWeight = 7,
		luckAffected = true,
		minActiveMinutes = 0,
		icon = "diamond",
	},
	{
		id = "Legendary",
		name = "Legendary",
		color = "#FFB619",
		minTier = 25,
		maxTier = 29,
		wildWeight = 3.5,
		luckAffected = true,
		minActiveMinutes = 0,
		icon = "star",
	},
	{
		id = "Mythic",
		name = "Mythic",
		color = "#FF4757",
		minTier = 30,
		maxTier = 34,
		wildWeight = 1.2,
		luckAffected = true,
		minActiveMinutes = 0,
		icon = "flame",
	},
	{
		id = "Outlaw",
		name = "Outlaw",
		color = "#1C1A17",
		minTier = 35,
		maxTier = 38,
		wildWeight = 0.25,
		luckAffected = true,
		minActiveMinutes = 10,
		icon = "skull_hat",
	},
	{
		id = "Secret",
		name = "Secret",
		color = "#FF5FD2",
		minTier = 39,
		maxTier = 40,
		wildWeight = 0.05,
		luckAffected = true,
		minActiveMinutes = 20,
		icon = "question",
	},
}

local byId: { [string]: Rarity } = {}
for _, rarity in Rarities do
	byId[rarity.id] = rarity
end

local function forTier(tier: number): Rarity
	for _, rarity in Rarities do
		if tier >= rarity.minTier and tier <= rarity.maxTier then
			return rarity
		end
	end
	error(`no rarity covers tier {tier}`)
end

local function indexOf(id: string): number
	for i, rarity in Rarities do
		if rarity.id == id then
			return i
		end
	end
	error(`unknown rarity {id}`)
end

return {
	list = Rarities,
	byId = byId,
	forTier = forTier,
	indexOf = indexOf,
	maxTier = Rarities[#Rarities].maxTier,
}
