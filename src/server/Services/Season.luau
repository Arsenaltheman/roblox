--!strict
-- The Rail Pass (Config/Season, Sim/Season): season XP from quest events, tier claims on the free and
-- premium tracks, weekly contracts, and the per-season pass grant. Every quest event already flows
-- through Progression.questEvent, which forwards here (like Trail).

local Players = game:GetService("Players")

local Cosmetics = require("@game/ReplicatedStorage/Shared/Config/Cosmetics")
local SeasonConfig = require("@game/ReplicatedStorage/Shared/Config/Season")
local Economy = require("@game/ReplicatedStorage/Shared/Sim/Economy")
local NumberFormat = require("@game/ReplicatedStorage/Shared/Sim/NumberFormat")
local SeasonSim = require("@game/ReplicatedStorage/Shared/Sim/Season")
local Net = require("@game/ReplicatedStorage/Shared/Net/Net")
local Registry = require("../Registry")

local Season = {}

local function state(d: any): SeasonSim.State
	local s = d.Season :: SeasonSim.State
	local now = os.time()
	SeasonSim.ensureSeason(s, now)
	SeasonSim.ensureWeek(s, now)
	return s
end

function Season.hasPremium(player: Player): boolean
	local d = Registry.Data.get(player)
	return d ~= nil and SeasonSim.hasPremium(state(d), os.time())
end

-- Toasts once per tier reached; XP beyond the daily cap is dropped (shown in the UI).
function Season.addXp(player: Player, amount: number, reason: string)
	local d = Registry.Data.get(player)
	if not d or amount <= 0 then
		return
	end
	local s = state(d)
	local before = SeasonSim.tier(s)
	local added = SeasonSim.addXp(s, amount, os.time())
	if added <= 0 then
		return
	end
	local after = SeasonSim.tier(s)
	if after > before then
		Registry.Ui.toast(player, `RAIL PASS tier {after} reached ({reason})! Claim it in Quests.`)
		Registry.Ui.fx(player, "trailReady", 0)
	end
	Registry.Ui.pushState(player)
end

function Season.event(player: Player, kind: string, amount: number)
	local d = Registry.Data.get(player)
	if not d then
		return
	end
	local s = state(d)
	if SeasonSim.contractEvent(s, kind, amount, os.time()) then
		Registry.Ui.pushState(player)
	end
	local xp = SeasonConfig.xpFor[kind]
	if xp then
		Season.addXp(player, xp * math.max(1, amount), kind)
	end
end

-- Called by Monetization when the Rail Pass product is granted (or re-bought next season).
function Season.grantPremium(player: Player): boolean
	local d = Registry.Data.get(player)
	if not d then
		return false
	end
	local s = state(d)
	s.PremiumFor = s.Season
	Registry.Ui.announce(`{player.DisplayName} got the Rail Pass for season {s.Season}!`, "golden")
	Registry.Ui.pushState(player)
	return true
end

local function rewardView(reward: SeasonConfig.Reward?): any
	if not reward then
		return nil
	end
	return { kind = reward.kind, amount = reward.amount, id = reward.id, text = reward.text }
end

function Season.view(player: Player): any
	local d = Registry.Data.get(player)
	if not d then
		return nil
	end
	local s = state(d)
	local now = os.time()
	local tier, into, size = SeasonConfig.tierAt(s.Xp)
	local premium = SeasonSim.hasPremium(s, now)
	local tiers = {}
	for t = 1, SeasonConfig.PREMIUM_TIERS do
		table.insert(tiers, {
			tier = t,
			free = rewardView(SeasonConfig.freeReward(t)),
			premium = rewardView(SeasonConfig.premiumReward(t)),
			freeClaimed = s.Claimed["f" .. t] == true,
			premiumClaimed = s.Claimed["p" .. t] == true,
		})
	end
	local contracts = {}
	for slot, index in SeasonSim.activeContracts(s, now) do
		local contract = SeasonConfig.contractPool[index]
		local k = tostring(index)
		table.insert(contracts, {
			slot = slot,
			text = contract.text,
			have = s.Contracts.Progress[k] or 0,
			goal = contract.goal,
			nuggets = contract.nuggets,
			claimed = s.Contracts.Claimed[k] == true,
		})
	end
	local day = math.floor(now / 86400)
	return {
		season = s.Season,
		endsAt = SeasonConfig.seasonEndsAt(now),
		weekEndsAt = SeasonConfig.weekEndsAt(SeasonConfig.week(now)),
		xp = s.Xp,
		tier = tier,
		into = into,
		next = size,
		xpToday = if s.XpDay == day then s.XpToday else 0,
		premium = premium,
		freeClaimable = #SeasonSim.claimable(s, false, now),
		premiumClaimable = #SeasonSim.claimable(s, true, now),
		tiers = tiers,
		contracts = contracts,
		color = SeasonConfig.color(s.Season),
	}
end

local function pay(player: Player, d: any, reward: SeasonConfig.Reward): string
	if reward.kind == "cash" then
		local cash = Economy.cashBag(reward.amount, Registry.Ranch.income(player))
		Registry.Wallet.addCash(player, cash, "RailPass")
		return `+{NumberFormat.cash(cash)}`
	elseif reward.kind == "nuggets" then
		Registry.Wallet.addNuggets(player, reward.amount, "RailPass")
		return `+{reward.amount} Gold Nuggets`
	elseif reward.kind == "spins" then
		Registry.Wheel.addSpins(player, reward.amount, "Rail Pass")
		return `+{reward.amount} spin{if reward.amount == 1 then "" else "s"}`
	elseif reward.kind == "luck" then
		Registry.Progression.giveBoost(player, "Luck", reward.amount, "LUCK POTION")
		return "Luck Potion"
	elseif reward.kind == "doubleCash" then
		Registry.Progression.giveBoost(player, "DoubleCash", reward.amount, "2x CASH")
		return "2x Cash"
	elseif (reward.kind == "title" or reward.kind == "hat") and reward.id then
		local cosmetic = Cosmetics.byId[reward.id]
		if cosmetic then
			d.Owned[reward.id] = true
			-- Wear it right away (the player can swap in the Wardrobe).
			d.Equipped[cosmetic.slot] = reward.id
			Registry.Shop.applyEquipped(player)
			Registry.Ui.announce(
				`{player.DisplayName} earned the {cosmetic.name} on the Rail Pass!`,
				"golden"
			)
			return cosmetic.name
		end
	end
	return reward.text
end

-- tier 0 = every claimable tier on that track, lowest first.
local function claimTier(player: Player, tier: number, premium: boolean)
	local d = Registry.Data.get(player)
	if not d then
		return
	end
	local s = state(d)
	local now = os.time()
	local tiers: { number } = if tier == 0 then SeasonSim.claimable(s, premium, now) else { tier }
	local lines = {}
	for _, t in tiers do
		-- Sim marks the tier claimed before anything is paid, so a double request can't pay twice.
		local reward = SeasonSim.claim(s, t, premium, now)
		if reward then
			table.insert(lines, pay(player, d, reward))
		end
	end
	if #lines == 0 then
		return
	end
	Registry.Ui.fx(player, "trailClaim", 0)
	Registry.Ui.toast(player, `Rail Pass: {table.concat(lines, ", ")}`)
	Registry.Data.saveNow(player)
	Registry.Ui.pushState(player)
end

local function claimContract(player: Player, slot: number)
	local d = Registry.Data.get(player)
	if not d then
		return
	end
	local s = state(d)
	local contract = SeasonSim.claimContract(s, slot, os.time())
	if not contract then
		return
	end
	Registry.Wallet.addNuggets(player, contract.nuggets, "Contract")
	Registry.Ui.fx(player, "trailClaim", 0)
	Registry.Ui.toast(
		player,
		`Contract done: +{contract.nuggets} Gold Nuggets and {SeasonConfig.CONTRACT_XP} season XP!`
	)
	Season.addXp(player, SeasonConfig.CONTRACT_XP, "contract")
	Registry.Data.saveNow(player)
	Registry.Ui.pushState(player)
end

function Season.init() end

function Season.start()
	Net.on("SeasonClaim", function(player, tier: number, premium: boolean)
		claimTier(player, tier, premium)
	end)
	Net.on("ContractClaim", function(player, slot: number)
		claimContract(player, slot)
	end)
	-- Season / week rollovers happen while players are online too; refresh their view each minute.
	task.spawn(function()
		while true do
			task.wait(60)
			for _, player in Players:GetPlayers() do
				local d = Registry.Data.get(player)
				if d then
					local s = d.Season :: SeasonSim.State
					local now = os.time()
					if SeasonSim.ensureSeason(s, now) or SeasonSim.ensureWeek(s, now) then
						Registry.Ui.pushState(player)
					end
				end
			end
		end
	end)
end

return Season
