--!strict
-- Gear: tools bought with in-game cash (never Robux) and unlocked by Frontier, like Steal a
-- Brainrot's coin shop. Owned forever; each has a cooldown. Pure data (unit-tested in Lune).

export type GearItem = {
	key: string,
	name: string,
	description: string,
	glyph: string,
	icon: string, -- assets/ui icon name
	price: number, -- cash
	frontier: number, -- Frontier level needed to buy
	cooldown: number, -- seconds between uses
	keybind: string, -- keyboard key shown on the hotbar
}

local list: { GearItem } = {
	{
		key = "SmokeBomb",
		name = "Smoke Bomb",
		description = "Vanish in smoke: guards lose you and you get a speed burst.",
		glyph = "☁",
		icon = "smokebomb",
		price = 2500,
		frontier = 0,
		cooldown = 25,
		keybind = "One",
	},
	{
		key = "TumbleweedBomb",
		name = "Tumbleweed Bomb",
		description = "Knocks out nearby players and guards for 2 seconds.",
		glyph = "✺",
		icon = "tumbleweed",
		price = 400000,
		frontier = 1,
		cooldown = 20,
		keybind = "Two",
	},
	{
		key = "BearTrap",
		name = "Bear Trap",
		description = "Set it in your ranch. The next thief who steps in is stuck and drops the loot.",
		glyph = "⚠",
		icon = "beartrap",
		price = 4000000,
		frontier = 2,
		cooldown = 60,
		keybind = "Three",
	},
	{
		key = "TinStar",
		name = "Tin Star",
		description = "Flash the badge: for 15 seconds the next lasso or tackle on you bounces off.",
		glyph = "✦",
		icon = "sheriffstar",
		price = 1500000,
		frontier = 1,
		cooldown = 45,
		keybind = "Nine",
	},
	{
		key = "GrappleHook",
		name = "Grapple Hook",
		description = "Hook the horizon and DASH forward. Great for escaping guards.",
		glyph = "➹",
		icon = "lasso",
		price = 20000000,
		frontier = 3,
		cooldown = 10,
		keybind = "Four",
	},
	{
		key = "DynamiteDecoy",
		name = "Dynamite Decoy",
		description = "Toss a lit decoy: nearby guards chase it, then it blows and knocks them out.",
		glyph = "✹",
		icon = "firework",
		price = 150000000,
		frontier = 4,
		cooldown = 30,
		keybind = "Five",
	},
	{
		key = "CactusWall",
		name = "Cactus Wall",
		description = "A wall of cacti springs up behind you and blocks chasers for a few seconds.",
		glyph = "▥",
		icon = "crate",
		price = 1200000000,
		frontier = 5,
		cooldown = 25,
		keybind = "Six",
	},
	{
		key = "StampedeCall",
		name = "Stampede Call",
		description = "Whistle up a stampede: every guard nearby scatters and you ride the dust.",
		glyph = "♞",
		icon = "horseshoe",
		price = 9000000000,
		frontier = 6,
		cooldown = 45,
		keybind = "Seven",
	},
	{
		key = "GhostLantern",
		name = "Ghost Lantern",
		description = "Turn ghostly for 8 seconds: guards can't see you and you glide faster.",
		glyph = "☼",
		icon = "key",
		price = 70000000000,
		frontier = 7,
		cooldown = 50,
		keybind = "Eight",
	},
}

local byKey: { [string]: GearItem } = {}
for _, item in list do
	byKey[item.key] = item
end

return {
	list = list,
	byKey = byKey,
	SMOKE_SECONDS = 5,
	SMOKE_SPEED = 1.45,
	TUMBLE_RADIUS = 16,
	TUMBLE_STUN = 2,
	TRAP_STUN = 3,
	TRAP_LIFETIME = 180,
	-- Hotbar key shown for each keybind.
	KEY_LABEL = {
		One = "1",
		Two = "2",
		Three = "3",
		Four = "4",
		Five = "5",
		Six = "6",
		Seven = "7",
		Eight = "8",
		Nine = "9",
	} :: { [string]: string },
	GUARD_SECONDS = 15,
	DASH_SPEED = 95, -- studs/s burst the client applies
	DECOY_SECONDS = 5,
	DECOY_RANGE = 70,
	DECOY_STUN = 3,
	WALL_SECONDS = 6,
	STAMPEDE_RANGE = 60,
	STAMPEDE_STUN = 4,
	STAMPEDE_SPEED = 1.4,
	GHOST_SECONDS = 8,
	GHOST_SPEED = 1.3,
}
