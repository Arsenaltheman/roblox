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
}
