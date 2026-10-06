--!strict
-- Trail Skills (masteries): six skills fed by things players already do. Levels 1..50, a perk
-- every 10 levels, an untradable cape at 50. Perks are small and never buyable: masteries are
-- the long-term "almost next perk" bar, not pay-to-win.

export type Skill = {
	id: string,
	name: string,
	blurb: string,
	color: string,
	-- quest-event kind -> xp per unit
	kinds: { [string]: number },
	-- perk text with {n} for the value at the given number of perks
	perk: string,
	perkPer: number,
}

local list: { Skill } = {
	{
		id = "Rustler",
		name = "Rustler",
		blurb = "Steal from ranches and rob the Bandit Camp.",
		color = "#E2463A",
		kinds = { steal = 25, bandit = 10 },
		perk = "+{n}% carry speed while loaded",
		perkPer = 3,
	},
	{
		id = "Wrangler",
		name = "Wrangler",
		blurb = "Lasso thieves and lock your gate.",
		color = "#E2A93B",
		kinds = { lasso = 20, lock = 2 },
		perk = "+{n} studs lasso range",
		perkPer = 2,
	},
	{
		id = "Trader",
		name = "Trader",
		blurb = "Trade with players and sell critters.",
		color = "#3FB7B0",
		kinds = { trade = 30, sell = 5 },
		perk = "+{n}% cash when selling",
		perkPer = 4,
	},
	{
		id = "Rancher",
		name = "Rancher",
		blurb = "Collect your cash and buy from the train.",
		color = "#4E9A4B",
		kinds = { collect = 2, buy = 4 },
		perk = "+{n}% ranch income",
		perkPer = 1,
	},
	{
		id = "Gambler",
		name = "Gambler",
		blurb = "Crack strongboxes, hatch eggs, spin the wheel.",
		color = "#9A5AFF",
		kinds = { crack = 10, hatch = 12, spin = 8 },
		perk = "-{n}% egg hatch time",
		perkPer = 5,
	},
	{
		id = "Ranger",
		name = "Ranger",
		blurb = "Run heist crates home and use your gear.",
		color = "#FF8C28",
		kinds = { heist = 6, crateRain = 6, heistRare = 15, gear = 1 },
		perk = "-{n}s guard tackle stun",
		perkPer = 0.15,
	},
}

local byId: { [string]: Skill } = {}
for _, skill in list do
	byId[skill.id] = skill
end

return {
	list = list,
	byId = byId,
	MAX_LEVEL = 50,
	PERK_EVERY = 10,
	-- XP to go from level L to L+1.
	costBase = 40,
	costGrowth = 1.08,
}
