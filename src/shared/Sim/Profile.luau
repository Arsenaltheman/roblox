--!strict
-- Save-data shape, versioning and migrations. Pure (no Roblox APIs) so every migration is unit-tested
-- against frozen fixtures of old versions.
--
-- Rules:
-- * `V` is the breaking version. Bump it only together with a migration in `Profile.migrations`.
-- * Additive fields just go into the template (ProfileStore's Reconcile fills them in) and bump `Minor`.
-- * Remove a field one release AFTER the code stops reading it (expand, then contract).
-- * A server never writes a profile whose V is newer than its own code (version guard).

local Economy = require("../Config/Economy")

export type Critter = {
	-- species id
	s: string,
	tier: number,
	-- mutation id
	m: string?,
	-- pen index (0 = not placed)
	p: number,
	-- source: "cage" | "egg" | "steal" | "gift" | "robux" | "strongbox"
	src: string,
	-- original owner (userId) for audits
	uid: number,
	-- obtained while a Robux luck boost was active (trading rules)
	pr: boolean,
	-- Branded: bought with Robux, can't be stolen, kept through Frontiers
	br: boolean,
	-- currently being carried by a thief (still owned by this profile)
	it: boolean,
	born: number,
}

export type Data = {
	V: number,
	Minor: number,
	Cash: number,
	Nuggets: number,
	LifetimeCash: number,
	Frontier: number,
	NextCid: number,
	Critters: { [string]: Critter },
	Eggs: { { tier: number, laidAt: number, hatchAt: number } },
	Almanac: { [string]: number },
	Quests: { Day: number, Progress: { [string]: number }, Claimed: { [string]: boolean } },
	-- Bounty Trail campaign (Config/Trail): current chapter/quest and its objective counters.
	Trail: { Chapter: number, Quest: number, Progress: { [string]: number }, Notified: boolean },
	-- Sheriff's Report: who robbed you (steals and AFK raids), newest last.
	RaidLog: { { t: number, by: number, byName: string, species: string, tier: number, kind: string } },
	-- Revenge bounties you posted: thief userId (string) -> expiry (unix).
	Bounties: { [string]: number },
	-- Weekly bounties: progress by pool index for the current week.
	Weekly: { Week: number, Progress: { [string]: number }, Claimed: { [string]: boolean }, Bonus: boolean },
	-- Rail Pass (Config/Season, Sim/Season): season XP, claimed tiers ("f12"/"p7"), the season the pass
	-- was bought for, and this week's contract progress.
	Season: {
		Season: number,
		Xp: number,
		XpDay: number,
		XpToday: number,
		Claimed: { [string]: boolean },
		PremiumFor: number,
		Contracts: { Week: number, Progress: { [string]: number }, Claimed: { [string]: boolean } },
	},
	Streak: { count: number, lastDay: number, graceUsed: boolean },
	Gifts: { Day: number, Seconds: number, Claimed: number },
	LastSeen: number,
	Owned: { [string]: boolean },
	Equipped: { [string]: string },
	Boosts: { [string]: number },
	Receipts: { string },
	RobuxSpent: number,
	Stats: { [string]: number },
	Settings: {
		Quality: string,
		Music: number,
		Sfx: number,
		Voice: number,
		ReducedFx: boolean,
		QuickReveal: boolean,
		Muted: boolean,
	},
	Tutorial: number,
	Strikes: number,
	StrongboxPity: number,
	StarterPack: boolean,
	Meta: { Created: number, Joins: number, LastJoin: number },
}

local Profile = {}

Profile.CURRENT_VERSION = 1
Profile.CURRENT_MINOR = 3
Profile.MAX_RECEIPTS = 100

function Profile.template(): Data
	return {
		V = Profile.CURRENT_VERSION,
		Minor = Profile.CURRENT_MINOR,
		Cash = Economy.startingCash,
		Nuggets = 0,
		LifetimeCash = 0,
		Frontier = 0,
		NextCid = 1,
		Critters = {},
		Eggs = {},
		Almanac = {},
		Quests = { Day = -1, Progress = {}, Claimed = {} },
		Trail = { Chapter = 1, Quest = 1, Progress = {}, Notified = false },
		RaidLog = {},
		Bounties = {},
		Weekly = { Week = -1, Progress = {}, Claimed = {}, Bonus = false },
		Season = {
			Season = 0,
			Xp = 0,
			XpDay = -1,
			XpToday = 0,
			Claimed = {},
			PremiumFor = 0,
			Contracts = { Week = -1, Progress = {}, Claimed = {} },
		},
		Streak = { count = 0, lastDay = -1, graceUsed = false },
		Gifts = { Day = -1, Seconds = 0, Claimed = 0 },
		LastSeen = 0,
		Owned = {},
		Equipped = {},
		Boosts = {},
		Receipts = {},
		RobuxSpent = 0,
		Stats = {
			Buys = 0,
			Steals = 0,
			Robbed = 0,
			Lassos = 0,
			Hatches = 0,
			Cracks = 0,
			PlaySeconds = 0,
		},
		Settings = {
			Quality = "auto",
			Music = 0.7,
			Sfx = 1,
			Voice = 1,
			ReducedFx = false,
			QuickReveal = false,
			Muted = false,
		},
		Tutorial = 0,
		Strikes = 0,
		StrongboxPity = 0,
		StarterPack = false,
		Meta = { Created = 0, Joins = 0, LastJoin = 0 },
	}
end

-- migrations[v] turns a version-v profile into version v+1. Each step must be pure.
Profile.migrations = {} :: { [number]: (any) -> any }

export type MigrateResult = {
	ok: boolean,
	data: any,
	-- "newer" when the profile was written by newer code than this server runs.
	reason: string?,
}

function Profile.migrate(data: any, migrations: { [number]: (any) -> any }?, current: number?): MigrateResult
	local steps = migrations or Profile.migrations
	local target = current or Profile.CURRENT_VERSION
	if type(data) ~= "table" then
		return { ok = false, data = data, reason = "not a table" }
	end
	local version = data.V
	if version == nil then
		-- Brand-new profile from ProfileStore before Reconcile: treat as current.
		data.V = target
		return { ok = true, data = data }
	end
	if version > target then
		return { ok = false, data = data, reason = "newer" }
	end
	while data.V < target do
		local step = steps[data.V]
		if step == nil then
			return { ok = false, data = data, reason = `missing migration from v{data.V}` }
		end
		local fromVersion = data.V
		data = step(data)
		if type(data) ~= "table" or data.V ~= fromVersion + 1 then
			return {
				ok = false,
				data = data,
				reason = `migration from v{fromVersion} did not produce v{fromVersion + 1}`,
			}
		end
	end
	return { ok = true, data = data }
end

-- Keep the last MAX_RECEIPTS purchase ids. Returns false if the id was already processed.
function Profile.recordReceipt(data: Data, purchaseId: string): boolean
	for _, id in data.Receipts do
		if id == purchaseId then
			return false
		end
	end
	table.insert(data.Receipts, purchaseId)
	while #data.Receipts > Profile.MAX_RECEIPTS do
		table.remove(data.Receipts, 1)
	end
	return true
end

function Profile.newCritterId(data: Data): string
	local id = tostring(data.NextCid)
	data.NextCid += 1
	return id
end

-- Best (highest) tier owned, counting only critters that are not being carried away.
function Profile.bestTier(data: Data): number
	local best = 0
	for _, critter in data.Critters do
		if not critter.it and critter.tier > best then
			best = critter.tier
		end
	end
	return best
end

return Profile
