--!strict
-- Argument schemas for every client -> server message. The server drops any request whose arguments
-- don't match (wrong type, out of range, too long) before game code ever sees it. Pure: unit-tested.

export type Validator = (value: any) -> boolean

local V = {}

function V.int(min: number, max: number): Validator
	return function(value)
		return type(value) == "number" and value == value and value % 1 == 0 and value >= min and value <= max
	end
end

function V.number(min: number, max: number): Validator
	return function(value)
		return type(value) == "number" and value == value and value >= min and value <= max
	end
end

function V.str(maxLen: number): Validator
	return function(value)
		return type(value) == "string" and #value <= maxLen and utf8.len(value) ~= nil
	end
end

function V.oneOf(options: { string }): Validator
	local set = {}
	for _, option in options do
		set[option] = true
	end
	return function(value)
		return type(value) == "string" and set[value] == true
	end
end

function V.bool(): Validator
	return function(value)
		return type(value) == "boolean"
	end
end

-- critter ids are small decimal strings
local critterId = function(value: any): boolean
	return type(value) == "string" and #value >= 1 and #value <= 10 and string.match(value, "^%d+$") ~= nil
end

local Schemas: { [string]: { Validator } } = {
	BuyCage = { V.int(0, 1e7), V.int(1, 64) }, -- train cycle, cage id
	Collect = {},
	Sell = { critterId },
	Place = { critterId, V.int(0, 32) },
	Lock = {},
	StealStart = { V.int(1, 9), critterId }, -- ranch slot (9 = Bandit Camp), critter id (or loot pen)
	StealCancel = {},
	Lasso = { V.int(-1e12, 1e12) }, -- target userId (negative in Studio test servers)
	CrackStart = { V.int(0, 1e7) }, -- train cycle
	Hatch = { V.int(1, 16) }, -- egg slot
	Claim = { V.oneOf({ "gift", "streak", "quest", "offline", "trail", "weekly" }), V.int(0, 64) },
	Frontier = {},
	ShopBuy = { V.str(32), V.int(1, 10) },
	Equip = {
		V.oneOf({ "lassoTrail", "horse", "ranchTheme", "poster", "hat", "title", "companion" }),
		V.str(32),
	},
	Setting = {
		V.oneOf({ "Quality", "Music", "Sfx", "Voice", "ReducedFx", "QuickReveal", "Muted" }),
		function(value: any): boolean
			return type(value) == "boolean"
				or (type(value) == "number" and value == value and value >= 0 and value <= 1)
				or (type(value) == "string" and #value <= 8)
		end,
	},
	Sticker = { V.int(1, 32) },
	SheriffPower = { V.oneOf({ "GoldenExpress", "Weather", "Stampede" }), V.str(16) },
	Lockpick = { V.int(1, 8) },
	ClientLog = { V.int(1, 4), V.str(160) },
	BugReport = { V.oneOf({ "stuck", "lost_item", "purchase", "visual", "other" }), V.str(200) },
	HeistGrab = { V.int(0, 4), V.int(1, 100000) }, -- zone (0 = event bonus crate), nest
	BuyGear = { V.str(24) },
	UseGear = { V.str(24) },
	BuyBoots = {},
	SpinWheel = {},
	HitBoss = {},
	GroupReward = {},
	PrivateSteal = { V.bool() },
	PosseInvite = { V.int(-1e12, 1e12) },
	PosseRespond = { V.int(-1e12, 1e12), V.bool() },
	PosseLeave = {},
	Sprint = { V.bool() }, -- held on / let go
	TradeInvite = { V.int(-1e12, 1e12) }, -- target userId
	TradeRespond = { V.int(-1e12, 1e12), V.bool() }, -- inviter userId, accept
	TradeOffer = { critterId, V.bool() }, -- critter id, include
	TradeNuggets = { V.int(0, 1e9) },
	TradeReady = { V.bool() },
	TradeCancel = {},
	SeasonClaim = { V.int(0, 40), V.bool() }, -- tier (0 = every claimable tier), premium track
	ContractClaim = { V.int(1, 6) }, -- contract slot
	GetOdds = { V.oneOf({ "wild", "reserved", "mutations", "egg", "species" }) },
	GetManifests = {},
}

-- True when `args` exactly match the schema for `name` (no missing, no extra arguments).
local function validate(name: string, args: { any }, count: number): boolean
	local schema = Schemas[name]
	if schema == nil then
		return false
	end
	if count ~= #schema then
		return false
	end
	for i, check in schema do
		if not check(args[i]) then
			return false
		end
	end
	return true
end

return {
	schemas = Schemas,
	validate = validate,
	V = V,
}
