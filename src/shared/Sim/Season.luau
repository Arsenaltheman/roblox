--!strict
-- Rail Pass state maths over the profile's `Season` table (Config/Season). Pure: the server passes
-- the clock in, so every rule (season rollover, daily XP cap, claim order, contract progress) is
-- unit-tested without Roblox.

local SeasonConfig = require("../Config/Season")

local Season = {}

export type State = {
	Season: number,
	Xp: number,
	XpDay: number,
	XpToday: number,
	-- "f12" / "p7": claimed free / premium tiers.
	Claimed: { [string]: boolean },
	-- The season number the Rail Pass was bought for (a Developer Product, so it's per season).
	PremiumFor: number,
	Contracts: { Week: number, Progress: { [string]: number }, Claimed: { [string]: boolean } },
}

function Season.new(): State
	return {
		Season = 0,
		Xp = 0,
		XpDay = -1,
		XpToday = 0,
		Claimed = {},
		PremiumFor = 0,
		Contracts = { Week = -1, Progress = {}, Claimed = {} },
	}
end

-- New season: XP and claims reset. PremiumFor stays (it's compared to the current season).
function Season.ensureSeason(state: State, unix: number): boolean
	local season = SeasonConfig.seasonOf(unix)
	if state.Season == season then
		return false
	end
	state.Season = season
	state.Xp = 0
	state.XpDay = -1
	state.XpToday = 0
	state.Claimed = {}
	return true
end

function Season.ensureWeek(state: State, unix: number): boolean
	local week = SeasonConfig.week(unix)
	if state.Contracts.Week == week then
		return false
	end
	state.Contracts.Week = week
	state.Contracts.Progress = {}
	state.Contracts.Claimed = {}
	return true
end

function Season.hasPremium(state: State, unix: number): boolean
	return state.PremiumFor == SeasonConfig.seasonOf(unix)
end

-- Adds XP under the daily cap. Returns how much was actually added.
function Season.addXp(state: State, amount: number, unix: number): number
	Season.ensureSeason(state, unix)
	local day = math.floor(unix / 86400)
	if state.XpDay ~= day then
		state.XpDay = day
		state.XpToday = 0
	end
	local room = math.max(0, SeasonConfig.XP_DAY_CAP - state.XpToday)
	local added = math.max(0, math.min(amount, room))
	state.XpToday += added
	state.Xp += added
	return added
end

function Season.tier(state: State): number
	local tier = SeasonConfig.tierAt(state.Xp)
	return tier
end

local function key(tier: number, premium: boolean): string
	return (if premium then "p" else "f") .. tostring(tier)
end

-- A tier is claimable when it's been reached, has a reward on that track, isn't claimed yet, and
-- (premium) the pass is owned for this season.
function Season.canClaim(state: State, tier: number, premium: boolean, unix: number): boolean
	if tier < 1 or tier % 1 ~= 0 then
		return false
	end
	local reward = if premium then SeasonConfig.premiumReward(tier) else SeasonConfig.freeReward(tier)
	if not reward then
		return false
	end
	if premium and not Season.hasPremium(state, unix) then
		return false
	end
	return Season.tier(state) >= tier and not state.Claimed[key(tier, premium)]
end

-- Marks a tier claimed and returns its reward (nil if it couldn't be claimed).
function Season.claim(state: State, tier: number, premium: boolean, unix: number): SeasonConfig.Reward?
	if not Season.canClaim(state, tier, premium, unix) then
		return nil
	end
	state.Claimed[key(tier, premium)] = true
	return if premium then SeasonConfig.premiumReward(tier) else SeasonConfig.freeReward(tier)
end

-- Every claimable tier on a track, lowest first (so "claim all" pays in order).
function Season.claimable(state: State, premium: boolean, unix: number): { number }
	local out = {}
	local top = if premium then SeasonConfig.PREMIUM_TIERS else SeasonConfig.FREE_TIERS
	for tier = 1, top do
		if Season.canClaim(state, tier, premium, unix) then
			table.insert(out, tier)
		end
	end
	return out
end

-- This week's contract pool indices for the player (4, or 6 with the pass).
function Season.activeContracts(state: State, unix: number): { number }
	local all = SeasonConfig.contracts(SeasonConfig.seasonOf(unix), SeasonConfig.week(unix))
	local count = if Season.hasPremium(state, unix)
		then SeasonConfig.CONTRACTS_PREMIUM
		else SeasonConfig.CONTRACTS_FREE
	local out = {}
	for i = 1, math.min(count, #all) do
		table.insert(out, all[i])
	end
	return out
end

-- Counts an event toward every active contract of that kind. Progress is kept for all 6 picks so
-- buying the pass mid-week shows the work already done on contracts 5 and 6.
function Season.contractEvent(state: State, kind: string, amount: number, unix: number): boolean
	Season.ensureWeek(state, unix)
	local changed = false
	local all = SeasonConfig.contracts(SeasonConfig.seasonOf(unix), SeasonConfig.week(unix))
	for _, index in all do
		local contract = SeasonConfig.contractPool[index]
		if contract.kind == kind then
			-- String keys: data stores don't keep sparse number keys reliably.
			local k = tostring(index)
			local before = state.Contracts.Progress[k] or 0
			if before < contract.goal then
				state.Contracts.Progress[k] = math.min(contract.goal, before + amount)
				changed = true
			end
		end
	end
	return changed
end

-- Claims contract `slot` (1..6 within the player's active list). Returns the contract or nil.
function Season.claimContract(state: State, slot: number, unix: number): SeasonConfig.Contract?
	Season.ensureWeek(state, unix)
	local index = Season.activeContracts(state, unix)[slot]
	if not index then
		return nil
	end
	local contract = SeasonConfig.contractPool[index]
	local k = tostring(index)
	if state.Contracts.Claimed[k] or (state.Contracts.Progress[k] or 0) < contract.goal then
		return nil
	end
	state.Contracts.Claimed[k] = true
	return contract
end

return Season
