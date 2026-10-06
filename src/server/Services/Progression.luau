--!strict
-- Retention systems: playtime gifts, login streak, offline earnings, daily quests, tutorial and
-- onboarding funnel. All timers are real (no fake countdowns).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Progression = require("@game/ReplicatedStorage/Shared/Config/Progression")
local SeasonConfig = require("@game/ReplicatedStorage/Shared/Config/Season")
local Economy = require("@game/ReplicatedStorage/Shared/Sim/Economy")
local Rng = require("@game/ReplicatedStorage/Shared/Sim/Rng")
local Streak = require("@game/ReplicatedStorage/Shared/Sim/Streak")
local Net = require("@game/ReplicatedStorage/Shared/Net/Net")
local Signal = require("@game/ReplicatedStorage/Shared/Util/Signal")
local Species = require("@game/ReplicatedStorage/Shared/Config/Species")
local Registry = require("../Registry")

local ProgressionService = {}

type Pending = {
	offline: number,
	streakSlot: number?,
	raids: { any }?,
}

local pending: { [Player]: Pending } = {}
-- Per-session playtime gifts.
local giftSeconds: { [Player]: number } = {}
local giftClaimed: { [Player]: { [number]: boolean } } = {}

local function today(): number
	return Streak.dayOf(os.time())
end

-- The day's 3 quests (same for everyone on a UTC day).
local function dailyQuests(day: number): { any }
	local rng = Rng.new(Rng.derive("quests", day % 1000000))
	local pool = table.clone(Progression.quests.pool)
	local picked = {}
	for _ = 1, Progression.quests.dailyCount do
		local i = rng:int(1, #pool)
		table.insert(picked, table.remove(pool, i))
	end
	return picked
end

local function ensureQuestDay(player: Player)
	local d = Registry.Data.get(player)
	if d and d.Quests.Day ~= today() then
		d.Quests.Day = today()
		d.Quests.Progress = {}
		d.Quests.Claimed = {}
	end
end

function ProgressionService.questView(player: Player): { any }
	local d = Registry.Data.get(player)
	if not d then
		return {}
	end
	ensureQuestDay(player)
	local view = {}
	for i, quest in dailyQuests(today()) do
		table.insert(view, {
			index = i,
			id = quest.id,
			text = quest.text,
			goal = quest.goal,
			progress = math.min(d.Quests.Progress[quest.id] or 0, quest.goal),
			claimed = d.Quests.Claimed[quest.id] == true,
		})
	end
	return view
end

function ProgressionService.questEvent(player: Player, kind: string, amount: number)
	local d = Registry.Data.get(player)
	if not d then
		return
	end
	Registry.Trail.event(player, kind, amount)
	Registry.Season.event(player, kind, amount)
	Registry.Skills.event(player, kind, amount)
	ensureQuestDay(player)
	for _, quest in dailyQuests(today()) do
		if quest.kind == kind and not d.Quests.Claimed[quest.id] then
			local before = d.Quests.Progress[quest.id] or 0
			d.Quests.Progress[quest.id] = before + amount
			if before < quest.goal and before + amount >= quest.goal then
				Registry.Ui.toast(player, `Quest done: {quest.text}! Claim it at the Wanted Board.`)
			end
		end
	end
	Registry.Ui.pushState(player)
end

-- Adds a timed boost (stacks by extending). `key` is a Boosts entry: "DoubleCash" or "Luck".
function ProgressionService.giveBoost(player: Player, key: string, minutes: number, label: string)
	local d = Registry.Data.get(player)
	if not d then
		return
	end
	d.Boosts[key] = math.max(d.Boosts[key] or 0, os.time()) + minutes * 60
	Registry.Ui.toast(player, `{label} boost for {minutes} minutes!`)
	Registry.Ui.fx(player, "boost", minutes)
	Registry.Ui.pushState(player)
end

function ProgressionService.giftView(player: Player): { any }
	local seconds = giftSeconds[player] or 0
	local claimed = giftClaimed[player] or {}
	local view = {}
	for i, gift in Progression.gifts do
		table.insert(view, {
			index = i,
			minute = gift.minute,
			kind = gift.kind,
			ready = seconds >= gift.minute * 60,
			claimed = claimed[i] == true,
			secondsLeft = math.max(0, gift.minute * 60 - seconds),
		})
	end
	return view
end

function ProgressionService.pendingView(player: Player): { any }
	local p = pending[player]
	return {
		offline = if p then p.offline else 0,
		streakSlot = if p then p.streakSlot else nil,
		raids = if p then p.raids else nil,
	}
end

function ProgressionService.tutorialStep(player: Player): number
	local d = Registry.Data.get(player)
	return if d then d.Tutorial else 99
end

-- Fired after the step is stored (Steal spawns the tutorial bandit on step 2).
ProgressionService.tutorialAdvanced = Signal.new() :: Signal.Signal<Player, number>

function ProgressionService.advanceTutorial(player: Player, to: number)
	local d = Registry.Data.get(player)
	if d and d.Tutorial < to then
		d.Tutorial = to
		Registry.Ui.pushState(player)
		ProgressionService.tutorialAdvanced:Fire(player, to)
	end
end

-- Onboarding funnel step (logged once per player, ever).
function ProgressionService.onboard(player: Player, step: string)
	local d = Registry.Data.get(player)
	if not d then
		return
	end
	local key = "ob_" .. step
	if (d.Stats[key] or 0) > 0 then
		return
	end
	d.Stats[key] = 1
	Registry.Telemetry.onboarding(player, step)
	if step == "FirstBuy" then
		ProgressionService.advanceTutorial(player, 1)
	end
end

local function grantReward(player: Player, kind: string, amount: number, reason: string, floor: number?)
	if kind == "cash" then
		local income = Registry.Ranch.income(player)
		Registry.Wallet.addCash(player, math.max(floor or 0, income * amount), reason)
	elseif kind == "nuggets" then
		Registry.Wallet.addNuggets(player, amount, reason)
	elseif kind == "egg" then
		local band = Registry.Ranch.band(player)
		for _ = 1, amount do
			Registry.Eggs.give(player, band, reason)
		end
	end
end

local function claim(player: Player, what: string, index: number)
	local d = Registry.Data.get(player)
	if not d then
		return
	end
	if what == "gift" then
		local gift = Progression.gifts[index]
		local claimed = giftClaimed[player]
		if not gift or not claimed or claimed[index] or (giftSeconds[player] or 0) < gift.minute * 60 then
			return
		end
		claimed[index] = true
		-- The first egg gift ever is guaranteed Uncommon or better (disclosed in the UI).
		if gift.kind == "egg" and (d.Stats.Hatches or 0) == 0 then
			Registry.Eggs.give(player, math.max(7, Registry.Ranch.band(player)), "Gift")
		else
			grantReward(player, gift.kind, gift.amount, "Gift", gift.floor)
		end
		Registry.Ui.reveal(player, { kind = "gift", gift = gift.kind, index = index })
	elseif what == "streak" then
		local p = pending[player]
		if not p or not p.streakSlot then
			return
		end
		local reward = Progression.streak.rewards[p.streakSlot]
		p.streakSlot = nil
		d.Stats.PendingStreakSlot = 0
		grantReward(player, reward.kind, reward.amount, "Streak", 300)
		Registry.Ui.reveal(player, { kind = "streak", slot = d.Streak.count })
		-- Every 30 days in a row: a Legendary critter and the "Regular" title.
		if d.Streak.count % 30 == 0 then
			local tier = 25
			local species = Species.byTier[tier]
			local cid =
				Registry.Ranch.addCritter(player, { species = species.id, tier = tier, src = "streak" })
			if cid then
				Registry.Ui.reveal(player, { kind = "wheel", species = species.id, tier = tier })
			else
				Registry.Wallet.addCash(player, Economy.price(tier), "Streak30")
			end
			d.Owned.title_regular = true
			Registry.Ui.announce(
				`{player.DisplayName} logged in 30 days in a row and earned a Legendary!`,
				"golden"
			)
		end
	elseif what == "report" then
		local p = pending[player]
		if p then
			p.raids = nil
		end
	elseif what == "offline" then
		local p = pending[player]
		if not p or p.offline <= 0 then
			return
		end
		local amount = p.offline
		p.offline = 0
		d.Stats.PendingOffline = 0
		Registry.Wallet.addCash(player, amount, "Offline")
		Registry.Ui.fx(player, "collect", amount)
	elseif what == "trail" or what == "weekly" then
		Registry.Trail.claim(player, what, index)
	elseif what == "quest" then
		ensureQuestDay(player)
		local quest = dailyQuests(today())[index]
		if not quest or d.Quests.Claimed[quest.id] or (d.Quests.Progress[quest.id] or 0) < quest.goal then
			return
		end
		d.Quests.Claimed[quest.id] = true
		grantReward(player, "cash", Progression.quests.cashSeconds, "Quest", 500)
		Registry.Wallet.addNuggets(player, Progression.quests.nuggets, "Quest")
		Registry.Season.addXp(player, SeasonConfig.DAILY_QUEST_XP, "daily quest")
		ProgressionService.onboard(player, "FirstQuest")
		-- All of today's quests claimed: a free 2x Cash boost.
		local all = true
		for _, q in dailyQuests(today()) do
			if not d.Quests.Claimed[q.id] then
				all = false
			end
		end
		if all then
			ProgressionService.giveBoost(
				player,
				"DoubleCash",
				Progression.boosts.questsDoneCashMinutes,
				"2x CASH"
			)
		end
	end
	Registry.Ui.pushState(player)
end

-- Called by Ranch once the player has a plot.
function ProgressionService.playerReady(player: Player)
	local d = Registry.Data.get(player)
	if not d then
		return
	end
	giftSeconds[player] = 0
	giftClaimed[player] = {}
	local p: Pending = { offline = 0 }
	-- Offline earnings since last visit (based on the income they left with).
	if d.LastSeen > 0 and Registry.LiveConfig.enabled("ff.offline") then
		local away = os.time() - d.LastSeen
		if away > 120 then
			local income = Registry.Ranch.income(player)
			p.offline = Economy.offlineEarnings(income, away, d.Frontier)
		end
	end
	-- Sheriff's Report: robberies since the last visit (and drop entries older than a week).
	local kept = {}
	local raids = {}
	for _, entry in d.RaidLog do
		if os.time() - entry.t < 7 * 86400 then
			table.insert(kept, entry)
			if d.LastSeen > 0 and entry.t >= d.LastSeen then
				table.insert(raids, entry)
			end
		end
	end
	d.RaidLog = kept
	if #raids > 0 then
		p.raids = raids
	end
	-- Login streak.
	local result = Streak.login(d.Streak, os.time())
	d.Streak = result.state
	if result.reward then
		p.streakSlot = result.slot
	end
	-- Unclaimed rewards from a previous visit are saved, so leaving or a crash never loses them.
	p.offline += d.Stats.PendingOffline or 0
	if not p.streakSlot and (d.Stats.PendingStreakSlot or 0) > 0 then
		p.streakSlot = d.Stats.PendingStreakSlot
	end
	d.Stats.PendingOffline = p.offline
	d.Stats.PendingStreakSlot = p.streakSlot or 0
	pending[player] = p
	ensureQuestDay(player)
	ProgressionService.onboard(player, "Spawned")
	Registry.Ui.pushState(player)
end

function ProgressionService.init() end

local fifteen: { [Player]: boolean } = {}

function ProgressionService.start()
	Net.on("Claim", claim)
	Players.PlayerRemoving:Connect(function(player)
		pending[player] = nil
		giftSeconds[player] = nil
		giftClaimed[player] = nil
		fifteen[player] = nil
	end)
	-- Gift timers advance only while the player is active (paused when idle).
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 1 then
			return
		end
		local step = accumulator
		accumulator = 0
		for player, seconds in giftSeconds do
			if Registry.Session.isActive(player) then
				local before = seconds
				giftSeconds[player] = seconds + step
				-- Tell the client when a gift becomes ready.
				for _, gift in Progression.gifts do
					local t = gift.minute * 60
					if before < t and seconds + step >= t then
						Registry.Ui.pushState(player)
						Registry.Ui.fx(player, "giftReady", gift.minute)
					end
				end
				if not fifteen[player] and seconds + step >= 15 * 60 then
					fifteen[player] = true
					ProgressionService.onboard(player, "Played15Min")
				end
			end
		end
	end)
end

return ProgressionService
