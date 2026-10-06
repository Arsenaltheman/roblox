--!strict
-- Heist zones (the Steal-An-Egg style loop): critter crates sit on nests out in the desert, guarded
-- by NPC posse members. Grab one, run it home to your ranch, and don't get caught: guards tackle
-- carriers (the critter drops back on its nest) and other players can lasso it off you.
-- Deeper zones hold rarer critters and faster guards, so Speed Boots (bought with cash) are the
-- progression that opens the map up.
--
-- Pure data + math (no Roblox APIs) so it is unit-tested in Lune.

export type Zone = {
	id: number,
	name: string,
	-- Where the zone sits (world x/z) and how big it is (studs).
	x: number,
	z: number,
	radius: number,
	-- Critters on its nests come from this tier range (low tiers more likely).
	minTier: number,
	maxTier: number,
	nests: number,
	guards: number,
	-- Guard speeds (studs/s). Walking around vs. chasing a carrier.
	patrolSpeed: number,
	chaseSpeed: number,
	-- Boots level that comfortably outruns this zone's guards while carrying (shown on the sign).
	suggestedBoots: number,
	-- Look of the zone (World builds the terrain and props for it).
	theme: "flats" | "canyon" | "mine" | "ghost",
}

local zones: { Zone } = {
	{
		id = 1,
		name = "Cactus Flats",
		x = -275,
		z = 70,
		radius = 42,
		minTier = 2,
		maxTier = 10,
		nests = 6,
		guards = 2,
		patrolSpeed = 8,
		chaseSpeed = 13,
		suggestedBoots = 0,
		theme = "flats",
	},
	{
		id = 2,
		name = "Rattlesnake Canyon",
		x = -150,
		z = -175,
		radius = 42,
		minTier = 8,
		maxTier = 18,
		nests = 6,
		guards = 3,
		patrolSpeed = 9,
		chaseSpeed = 18,
		suggestedBoots = 3,
		theme = "canyon",
	},
	{
		id = 3,
		name = "Gold Mine",
		x = 285,
		z = 75,
		radius = 44,
		minTier = 16,
		maxTier = 27,
		nests = 6,
		guards = 3,
		patrolSpeed = 10,
		chaseSpeed = 23,
		suggestedBoots = 6,
		theme = "mine",
	},
	{
		id = 4,
		name = "Ghost Town",
		x = 40,
		z = 345,
		radius = 46,
		minTier = 25,
		maxTier = 36,
		nests = 6,
		guards = 4,
		patrolSpeed = 11,
		chaseSpeed = 28,
		suggestedBoots = 9,
		theme = "ghost",
	},
}

local Heist = {}

Heist.zones = zones
Heist.GRAB_SECONDS = 1.0
Heist.GRAB_REACH = 9
Heist.CARRY_MULTIPLIER = 0.85 -- carrying a crate slows you down
Heist.CARRY_TIMEOUT = 90 -- seconds before an undelivered crate escapes back to its nest
Heist.TACKLE_RANGE = 4.5 -- a guard this close to a carrier tackles them
Heist.STUN_SECONDS = 1.2
Heist.AGGRO_RANGE = 26 -- guards notice a carrier (or a grab in progress) this close
Heist.LEASH = 2.4 -- guards give up beyond this many zone radii from the zone centre
Heist.RESPAWN_MIN = 20
Heist.RESPAWN_MAX = 40
-- Chance a deepest-zone nest rolls an Outlaw/Secret-tier critter (37-40).
Heist.JACKPOT_CHANCE = 0.015

Heist.BASE_SPEED = 16
Heist.SPEED_PER_LEVEL = 2
Heist.MAX_BOOTS = 10

function Heist.zone(id: number): Zone?
	return zones[id]
end

-- Walk speed for a boots level (Speed Spurs pass multiplies on top).
function Heist.walkSpeed(level: number, spurs: boolean, carrying: boolean): number
	local speed = Heist.BASE_SPEED + Heist.SPEED_PER_LEVEL * math.clamp(level, 0, Heist.MAX_BOOTS)
	if spurs then
		speed *= 1.2
	end
	if carrying then
		speed *= Heist.CARRY_MULTIPLIER
	end
	return speed
end

-- Cash price of the next boots level (level -> level + 1), tracking the species price curve so
-- each upgrade costs a few minutes of income at the stage you need it.
function Heist.bootsCost(level: number): number?
	if level >= Heist.MAX_BOOTS then
		return nil
	end
	local tier = 3 + level * 3
	return 25 * 2 ^ (tier - 1) * 3
end

-- Tier for a nest. `r1` picks within the zone's range (squared, so low tiers are commoner), `r2`
-- decides the rare jackpot roll in the deepest zone. Both are uniform [0, 1).
function Heist.rollTier(zone: Zone, r1: number, r2: number): number
	if zone.id == #zones and r2 < Heist.JACKPOT_CHANCE then
		return 37 + math.floor(r1 * 4)
	end
	local span = zone.maxTier - zone.minTier + 1
	return zone.minTier + math.min(span - 1, math.floor(span * r1 * r1))
end

-- Positions of a zone's nests, in a ring inside the zone (world x/z).
function Heist.nestPosition(zone: Zone, n: number): (number, number)
	local angle = (n - 1) / zone.nests * math.pi * 2 + zone.id
	local dist = zone.radius * (if n % 2 == 0 then 0.45 else 0.7)
	return zone.x + math.cos(angle) * dist, zone.z + math.sin(angle) * dist
end

-- True when (x, z) is inside any zone grown by `margin` studs (World keeps dunes out of zones).
function Heist.insideAnyZone(x: number, z: number, margin: number): boolean
	for _, zone in zones do
		local dx, dz = x - zone.x, z - zone.z
		if dx * dx + dz * dz < (zone.radius + margin) ^ 2 then
			return true
		end
	end
	return false
end

return Heist
