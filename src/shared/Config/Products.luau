--!strict
-- Robux catalogue (owner decision: Steal a Brainrot-level pay-to-win).
-- Roblox asset IDs are filled in once the passes/products exist in Creator Hub (see docs/STATUS.md).
-- Prices here are the intended list prices; the game reads live prices at runtime.
--
-- `random = true` marks products that change random outcomes. Those MUST show live odds before
-- purchase and are hidden for players where PolicyService says paid random items are restricted.

export type Product = {
	key: string,
	kind: "pass" | "product" | "privateServer",
	name: string,
	price: number,
	description: string,
	random: boolean?,
	id: number?,
}

local list: { Product } = {
	-- Game passes (permanent)
	{ key = "VIP", kind = "pass", price = 499, name = "Sheriff's Badge (VIP)", description = "x1.5 cash, +10s ranch lock, gold lasso trail, VIP tag." },
	{ key = "DoubleCash", kind = "pass", price = 299, name = "2x Cash", description = "Double all ranch income." },
	{ key = "AutoCollect", kind = "pass", price = 149, name = "Auto-Collect", description = "Ranch cash goes straight to your wallet." },
	{ key = "LuckyHorseshoe", kind = "pass", price = 399, name = "Lucky Horseshoe", description = "x1.5 luck on your reserved cage.", random = true },
	{ key = "GoldenLasso", kind = "pass", price = 499, name = "Golden Lasso", description = "+50% lasso range, faster cooldown." },
	{ key = "SpeedSpurs", kind = "pass", price = 349, name = "Speed Spurs", description = "+20% run speed, +15% while carrying." },
	{ key = "IronLock", kind = "pass", price = 299, name = "Iron Lock", description = "+60s ranch lock." },
	{ key = "HeavySaddlebag", kind = "pass", price = 399, name = "Heavy Saddlebag", description = "Carry critters 5 tiers rarer when stealing." },
	{ key = "BigRanch", kind = "pass", price = 349, name = "Bigger Ranch", description = "+2 pens." },
	{ key = "SheriffStar", kind = "pass", price = 4999, name = "Sheriff's Star", description = "Sheriff Powers: call the Golden Express, summon weather, start a stampede (cooldowns apply).", random = true },

	-- Developer products (consumable)
	{ key = "ServerLuck2", kind = "product", price = 249, name = "Server Luck x2 (15 min)", description = "Better cage odds for everyone in the server.", random = true },
	{ key = "ServerLuck3", kind = "product", price = 499, name = "Server Luck x3 (15 min)", description = "Better cage odds for everyone in the server.", random = true },
	{ key = "ServerLuck5", kind = "product", price = 999, name = "Server Luck x5 (15 min)", description = "Better cage odds for everyone in the server.", random = true },
	{ key = "Lockpick", kind = "product", price = 79, name = "Lockpick", description = "Open a locked ranch gate for 8 seconds." },
	{ key = "CashBag10m", kind = "product", price = 39, name = "Small Cash Bag", description = "10 minutes of your income." },
	{ key = "CashBag1h", kind = "product", price = 129, name = "Cash Bag", description = "1 hour of your income." },
	{ key = "CashBag6h", kind = "product", price = 349, name = "Big Cash Bag", description = "6 hours of your income." },
	{ key = "CashBag24h", kind = "product", price = 899, name = "Vault of Cash", description = "24 hours of your income." },
	{ key = "StarterPack", kind = "product", price = 99, name = "Starter Pack", description = "Deputy Duck (exclusive), 30 min of 2x cash and a hat. Once per player." },
	{ key = "GoldenLocomotive", kind = "product", price = 1499, name = "Golden Locomotive", description = "Exclusive critter. Can't be stolen. Kept through Frontiers." },
	{ key = "DiamondDesperado", kind = "product", price = 2499, name = "Diamond Desperado", description = "Exclusive critter. Can't be stolen. Kept through Frontiers." },

	{ key = "PrivateServer", kind = "privateServer", price = 79, name = "Private Server", description = "Monthly. Stealing can be toggled." },
}

local byKey: { [string]: Product } = {}
for _, product in list do
	byKey[product.key] = product
end

return {
	list = list,
	byKey = byKey,
	cashBagSeconds = {
		CashBag10m = 600,
		CashBag1h = 3600,
		CashBag6h = 6 * 3600,
		CashBag24h = 24 * 3600,
	},
	sheriffPowers = {
		cooldownSeconds = 30 * 60,
		stampedeSeconds = 5 * 60,
		stampedeLuck = 3,
		weatherSeconds = 2 * 60,
	},
	lockpickSeconds = 8,
	-- Owner decision: no purchase prompts right after a loss (robbed / bad reveal).
	noPromptAfterLossSeconds = 120,
}
