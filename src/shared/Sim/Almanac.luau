--!strict
-- Almanac sets: discovering every species of a rarity completes that rarity's set, and each
-- completed set permanently adds to ranch income (Config/Economy.almanacSetBonus). Pure (tested).

local Rarities = require("../Config/Rarities")
local Species = require("../Config/Species")

local Almanac = {}

export type SetProgress = { rarity: string, have: number, total: number, done: boolean }

-- Progress per rarity, in rarity order. `almanac` maps species id -> discovery bitmask.
function Almanac.sets(almanac: { [string]: number }): { SetProgress }
	local byRarity: { [string]: SetProgress } = {}
	local out: { SetProgress } = {}
	for _, rarity in Rarities.list do
		local p = { rarity = rarity.id, have = 0, total = 0, done = false }
		byRarity[rarity.id] = p
		table.insert(out, p)
	end
	for _, species in Species.list do
		local p = byRarity[Rarities.forTier(species.tier).id]
		if p then
			p.total += 1
			if (almanac[species.id] or 0) ~= 0 then
				p.have += 1
			end
		end
	end
	for _, p in out do
		p.done = p.total > 0 and p.have >= p.total
	end
	return out
end

function Almanac.completedSets(almanac: { [string]: number }): number
	local n = 0
	for _, p in Almanac.sets(almanac) do
		if p.done then
			n += 1
		end
	end
	return n
end

return Almanac
