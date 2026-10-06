--!strict
-- Server events (our take on "admin abuse" moments): every ~25 minutes the whole server gets a
-- big shared moment, announced with a real countdown. Pure data + picking logic (unit-tested).
--   Crate Rain      - bonus critter crates fall along Main Street; first to grab one keeps it.
--   Gold Rush       - all ranch income is doubled for a few minutes.
--   Jackpot Restock - every heist nest refills one rarity higher.

export type Event = {
	id: string,
	name: string,
	blurb: string,
	duration: number, -- seconds the event stays active
	color: string, -- Palette colour name
	weight: number,
}

local list: { Event } = {
	{
		id = "CrateRain",
		name = "CRATE RAIN",
		blurb = "Critter crates are falling on Main Street! Grab one and run it home!",
		duration = 75,
		color = "gold",
		weight = 40,
	},
	{
		id = "GoldRush",
		name = "GOLD RUSH",
		blurb = "All ranch income +50% for five minutes!",
		duration = 5 * 60,
		color = "gold",
		weight = 35,
	},
	{
		id = "JackpotRestock",
		name = "JACKPOT RESTOCK",
		blurb = "Every heist nest just refilled one rarity higher!",
		duration = 90,
		color = "red",
		weight = 25,
	},
	{
		id = "LightningStorm",
		name = "LIGHTNING STORM",
		blurb = "Every heist nest just refilled with an ELECTRIC critter. 90 seconds!",
		duration = 90,
		color = "sky",
		weight = 20,
	},
	{
		id = "BanditKing",
		name = "BANDIT KING",
		blurb = "The Bandit King is raiding Ghost Town! Everyone lasso him for loot!",
		duration = 150,
		color = "purple",
		weight = 25,
	},
}

local byId: { [string]: Event } = {}
for _, e in list do
	byId[e.id] = e
end

-- Picks the next event from r in [0, 1), never repeating `previous` back to back.
local function pick(r: number, previous: string?): Event
	local pool = {}
	local total = 0
	for _, e in list do
		if e.id ~= previous then
			table.insert(pool, e)
			total += e.weight
		end
	end
	local x = r * total
	for _, e in pool do
		x -= e.weight
		if x < 0 then
			return e
		end
	end
	return pool[#pool]
end

-- Crate Rain: which heist zone's rarity range each falling crate uses (weights per zone 1..4).
local CRATE_ZONE_WEIGHTS = { 50, 30, 15, 5 }
local function crateZone(r: number): number
	local x = r * 100
	for zone, w in CRATE_ZONE_WEIGHTS do
		x -= w
		if x < 0 then
			return zone
		end
	end
	return #CRATE_ZONE_WEIGHTS
end

return {
	list = list,
	byId = byId,
	pick = pick,
	crateZone = crateZone,
	FIRST_DELAY = 3 * 60, -- first event this long after the server starts
	INTERVAL = 10 * 60, -- start to start: something is live or about to start most of the time
	WARNING = 90, -- countdown banner shows this long before
	CRATE_COUNT = 14,
	CRATE_SPREAD = 30, -- seconds over which crates fall
	CRATE_LIFETIME = 75,
	-- Main Street drop area (between the two ranch rows).
	STREET = { minX = -105, maxX = 105, minZ = 71, maxZ = 79 },
	RESTOCK_BOOST = 1,
	-- Sheriff Hour: a fixed weekly appointment (UTC). 30 minutes of Server Luck x2 for everyone and a
	-- Crate Rain every 5 minutes.
	SHERIFF_HOUR = {
		{ weekday = 3, hour = 22 }, -- Tuesday 22:00 UTC
		{ weekday = 7, hour = 18 }, -- Saturday 18:00 UTC
	},
	SHERIFF_HOUR_SECONDS = 30 * 60,
	SHERIFF_HOUR_LUCK = 2,
}
