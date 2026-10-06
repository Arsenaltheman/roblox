--!strict
-- The Bounty Trail campaign and weekly bounties (Config/Trail, Sim/Trail). Every quest event in the
-- game already flows through Progression.questEvent, which forwards here. Checked objectives (reach
-- Frontier, boots level, income...) are re-evaluated every few seconds.

local Players = game:GetService("Players")

local Cosmetics = require("@game/ReplicatedStorage/Shared/Config/Cosmetics")
local Species = require("@game/ReplicatedStorage/Shared/Config/Species")
local SeasonConfig = require("@game/ReplicatedStorage/Shared/Config/Season")
local TrailConfig = require("@game/ReplicatedStorage/Shared/Config/Trail")
local Almanac = require("@game/ReplicatedStorage/Shared/Sim/Almanac")
local NumberFormat = require("@game/ReplicatedStorage/Shared/Sim/NumberFormat")
local Profile = require("@game/ReplicatedStorage/Shared/Sim/Profile")
local TrailSim = require("@game/ReplicatedStorage/Shared/Sim/Trail")
local Registry = require("../Registry")

local Trail = {}

local function facts(player: Player, d: any): TrailSim.Facts
	-- Regular species only (Robux exclusives don't count toward discovery goals).
	local almanac = 0
	for id in d.Almanac do
		local species = Species.byId[id]
		if species and not species.exclusive then
			almanac += 1
		end
	end
	local gearOwned = 0
	for key, owned in d.Owned do
		if owned and string.sub(key, 1, 5) == "gear:" then
			gearOwned += 1
		end
	end
	local mutated = 0
	for _, critter in d.Critters do
		if critter.m and not critter.it then
			mutated += 1
		end
	end
	return {
		frontier = d.Frontier,
		boots = d.Stats.Boots or 0,
		income = Registry.Ranch.income(player),
		almanac = almanac,
		sets = Almanac.completedSets(d.Almanac),
		gearOwned = gearOwned,
		bestTier = Profile.bestTier(d),
		mutated = mutated,
	}
end

local function ensureWeek(d: any)
	local week = TrailSim.week(os.time())
	if d.Weekly.Week ~= week then
		d.Weekly.Week = week
		d.Weekly.Progress = {}
		d.Weekly.Claimed = {}
		d.Weekly.Bonus = false
	end
end

-- Toasts once when the current Trail quest becomes claimable.
local function checkReady(player: Player, d: any)
	local quest = TrailSim.quest(d.Trail.Chapter, d.Trail.Quest)
	if not quest or d.Trail.Notified then
		return
	end
	local _, done = TrailSim.view(quest, d.Trail.Progress, facts(player, d))
	if done then
		d.Trail.Notified = true
		Registry.Ui.toast(player, `BOUNTY TRAIL: "{quest.name}" complete! Claim your reward in Quests.`)
		Registry.Ui.fx(player, "trailReady", 0)
		Registry.Ui.pushState(player)
	end
end

function Trail.event(player: Player, kind: string, amount: number)
	local d = Registry.Data.get(player)
	if not d or not TrailConfig.counted[kind] then
		return
	end
	local quest = TrailSim.quest(d.Trail.Chapter, d.Trail.Quest)
	if quest then
		TrailSim.event(quest, d.Trail.Progress, kind, amount)
	end
	ensureWeek(d)
	for _, index in TrailSim.weekly(d.Weekly.Week) do
		local objective = TrailConfig.weeklyPool[index]
		if objective.kind == kind then
			local key = tostring(index)
			d.Weekly.Progress[key] = math.min(objective.goal, (d.Weekly.Progress[key] or 0) + amount)
		end
	end
	checkReady(player, d)
end

function Trail.view(player: Player): any
	local d = Registry.Data.get(player)
	if not d then
		return nil
	end
	ensureWeek(d)
	local f = facts(player, d)
	local chapter = TrailConfig.chapters[d.Trail.Chapter]
	local quest = TrailSim.quest(d.Trail.Chapter, d.Trail.Quest)
	local objectives, done = {}, false
	if quest then
		objectives, done = TrailSim.view(quest, d.Trail.Progress, f)
	end
	local weekly = {}
	for slot, index in TrailSim.weekly(d.Weekly.Week) do
		local objective = TrailConfig.weeklyPool[index]
		local key = tostring(index)
		table.insert(weekly, {
			slot = slot,
			text = objective.text,
			have = d.Weekly.Progress[key] or 0,
			goal = objective.goal,
			claimed = d.Weekly.Claimed[key] == true,
		})
	end
	return {
		chapter = d.Trail.Chapter,
		quest = d.Trail.Quest,
		chapters = #TrailConfig.chapters,
		chapterName = chapter and chapter.name or "",
		blurb = chapter and chapter.blurb or "",
		questName = quest and quest.name or "",
		finale = TrailSim.isFinale(d.Trail.Chapter, d.Trail.Quest),
		objectives = objectives,
		done = done,
		finished = quest == nil,
		weekly = weekly,
		weeklyBonus = d.Weekly.Bonus,
		weekEndsAt = (d.Weekly.Week + 1) * 7 * 86400 - 3 * 86400,
	}
end

local function claimTrail(player: Player, d: any)
	local c, q = d.Trail.Chapter, d.Trail.Quest
	local quest = TrailSim.quest(c, q)
	if not quest then
		return
	end
	local _, done = TrailSim.view(quest, d.Trail.Progress, facts(player, d))
	if not done then
		return
	end
	-- Advance first so a double claim can't pay twice.
	local nc, nq = TrailSim.after(c, q)
	d.Trail.Chapter = nc or (#TrailConfig.chapters + 1)
	d.Trail.Quest = nq or 1
	d.Trail.Progress = {}
	d.Trail.Notified = false

	local income = Registry.Ranch.income(player)
	local cash = math.max(TrailConfig.questCashFloor, income * TrailConfig.questCashSeconds(c))
	local nuggets = TrailConfig.questNuggets(c)
	Registry.Wallet.addCash(player, cash, "Trail")
	Registry.Wallet.addNuggets(player, nuggets, "Trail")
	local lines = { `+{NumberFormat.cash(cash)}`, `+{nuggets} Gold Nuggets` }
	if q == 3 then
		Registry.Wheel.addSpins(player, 1, "Bounty Trail")
	end
	if TrailSim.isFinale(c, q) then
		local chapter = TrailConfig.chapters[c]
		Registry.Wallet.addNuggets(player, TrailConfig.finaleNuggets(c), "TrailFinale")
		Registry.Wheel.addSpins(player, TrailConfig.finaleSpins, "Chapter complete")
		Registry.Progression.giveBoost(player, "DoubleCash", TrailConfig.finaleBoostMinutes, "2x CASH")
		if Cosmetics.byId[chapter.title] then
			d.Owned[chapter.title] = true
			d.Equipped.title = chapter.title
			Registry.Shop.applyEquipped(player)
		end
		table.insert(lines, `+{TrailConfig.finaleNuggets(c)} bonus Nuggets`)
		Registry.Ui.reveal(
			player,
			{ kind = "chapter", chapter = c, name = chapter.name, title = chapter.title }
		)
		Registry.Ui.announce(
			`{player.DisplayName} finished Chapter {c} of the Bounty Trail: {chapter.name}!`,
			"golden"
		)
	else
		Registry.Ui.fx(player, "trailClaim", c)
	end
	Registry.Ui.toast(player, `Trail reward: {table.concat(lines, ", ")}`)
	Registry.Data.saveNow(player)
end

local function claimWeekly(player: Player, d: any, slot: number)
	ensureWeek(d)
	local index = TrailSim.weekly(d.Weekly.Week)[slot]
	if not index then
		return
	end
	local objective = TrailConfig.weeklyPool[index]
	local key = tostring(index)
	if d.Weekly.Claimed[key] or (d.Weekly.Progress[key] or 0) < objective.goal then
		return
	end
	d.Weekly.Claimed[key] = true
	Registry.Wallet.addNuggets(player, TrailConfig.weeklyNuggets, "Weekly")
	Registry.Wheel.addSpins(player, TrailConfig.weeklySpins, "Weekly bounty")
	Registry.Season.addXp(player, SeasonConfig.WEEKLY_BOUNTY_XP, "weekly bounty")
	Registry.Ui.fx(player, "trailClaim", 0)
	Registry.Ui.toast(
		player,
		`Weekly bounty done: +{TrailConfig.weeklyNuggets} Gold Nuggets and {TrailConfig.weeklySpins} spins!`
	)
	-- All of this week's bounties: a big bonus.
	local all = true
	for _, i in TrailSim.weekly(d.Weekly.Week) do
		if not d.Weekly.Claimed[tostring(i)] then
			all = false
		end
	end
	if all and not d.Weekly.Bonus then
		d.Weekly.Bonus = true
		Registry.Wallet.addNuggets(player, TrailConfig.weeklyAllNuggets, "WeeklyAll")
		Registry.Progression.giveBoost(player, "Luck", TrailConfig.weeklyAllLuckMinutes, "LUCK POTION")
		Registry.Ui.announce(`{player.DisplayName} cleared every weekly bounty!`, "golden")
	end
	Registry.Data.saveNow(player)
end

function Trail.claim(player: Player, what: string, index: number)
	local d = Registry.Data.get(player)
	if not d then
		return
	end
	if what == "trail" then
		claimTrail(player, d)
	elseif what == "weekly" then
		claimWeekly(player, d, index)
	end
end

function Trail.init() end

function Trail.start()
	task.spawn(function()
		while true do
			task.wait(5)
			for _, player in Players:GetPlayers() do
				local d = Registry.Data.get(player)
				if d then
					pcall(checkReady, player, d)
				end
			end
		end
	end)
end

return Trail
