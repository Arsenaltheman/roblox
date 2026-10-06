--!strict
-- Server events every ~25 minutes (Config/Events): Crate Rain, Gold Rush, Jackpot Restock.
-- The schedule is mirrored to Workspace attributes so every client shows the same real countdown:
--   EventNextId / EventNextAt   - what's coming and when (server time)
--   EventId / EventEndsAt       - what's running now ("" when nothing)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local EventsConfig = require("@game/ReplicatedStorage/Shared/Config/Events")
local HeistConfig = require("@game/ReplicatedStorage/Shared/Config/Heist")
local Registry = require("../Registry")

local Events = {}

local random = Random.new()
local active: string? = nil

local function now(): number
	return Workspace:GetServerTimeNow()
end

function Events.goldRush(): boolean
	return active == "GoldRush"
end

local function crateRain()
	local street = EventsConfig.STREET
	for i = 1, EventsConfig.CRATE_COUNT do
		task.delay((i - 1) * EventsConfig.CRATE_SPREAD / EventsConfig.CRATE_COUNT, function()
			local zone = HeistConfig.zone(EventsConfig.crateZone(random:NextNumber())) :: HeistConfig.Zone
			local tier = HeistConfig.rollTier(zone, random:NextNumber(), random:NextNumber())
			local position = Vector3.new(
				random:NextNumber(street.minX, street.maxX),
				0,
				random:NextNumber(street.minZ, street.maxZ)
			)
			Registry.Heist.dropBonus(position, tier, EventsConfig.CRATE_LIFETIME)
		end)
	end
end

local function run(event: EventsConfig.Event)
	active = event.id
	Workspace:SetAttribute("EventId", event.id)
	Workspace:SetAttribute("EventEndsAt", now() + event.duration)
	Registry.Ui.announce(`{event.name}! {event.blurb}`, "event")
	Registry.Ui.fxAll("eventStart", 0, nil)
	if event.id == "CrateRain" then
		crateRain()
	elseif event.id == "JackpotRestock" then
		Registry.Heist.restockAll(EventsConfig.RESTOCK_BOOST)
	elseif event.id == "LightningStorm" then
		Registry.Heist.restockAll(0, "Electric")
	elseif event.id == "BanditKing" then
		Registry.Boss.spawn(event.duration)
	elseif event.id == "GoldRush" then
		-- Ranch income reads Events.goldRush() through LiveOps.incomeEventActive; push fresh numbers.
		for _, player in Players:GetPlayers() do
			Registry.Ui.pushState(player)
		end
	end
	local ends = now() + event.duration
	while now() < ends do
		-- The Bandit King event ends early once he's beaten (or escapes).
		if event.id == "BanditKing" and now() > ends - event.duration + 2 and not Registry.Boss.alive() then
			break
		end
		task.wait(1)
	end
	active = nil
	Workspace:SetAttribute("EventId", "")
	if event.id == "GoldRush" then
		Registry.Ui.announce("The Gold Rush is over. Next event soon!", "info")
		for _, player in Players:GetPlayers() do
			Registry.Ui.pushState(player)
		end
	end
end

-- Next Sheriff Hour start (unix) from the weekly UTC schedule.
local function nextSheriffHour(unix: number): number
	local best = math.huge
	for _, slot in EventsConfig.SHERIFF_HOUR do
		local date = os.date("!*t", unix)
		-- Start of this UTC day, then walk to the slot's weekday/hour (0..6 days ahead).
		local dayStart = unix - (date.hour * 3600 + date.min * 60 + date.sec)
		for ahead = 0, 7 do
			local candidate = dayStart + ahead * 86400 + slot.hour * 3600
			local wday = os.date("!*t", candidate).wday
			if wday == slot.weekday and candidate + EventsConfig.SHERIFF_HOUR_SECONDS > unix then
				best = math.min(best, candidate)
				break
			end
		end
	end
	return best
end

local function runSheriffHour()
	local ends = now() + EventsConfig.SHERIFF_HOUR_SECONDS
	Workspace:SetAttribute("SheriffHourUntil", ends)
	Registry.Ui.announce(
		"SHERIFF HOUR! Server Luck x2 for everyone and crates raining every 5 minutes!",
		"golden"
	)
	Registry.Ui.fxAll("eventStart", 0, nil)
	local n = 0
	while now() < ends do
		if n % 3 == 0 then
			Registry.Train.addServerLuck(EventsConfig.SHERIFF_HOUR_LUCK)
		end
		crateRain()
		n += 1
		task.wait(5 * 60)
	end
	Workspace:SetAttribute("SheriffHourUntil", 0)
	Registry.Ui.announce("Sheriff Hour is over. See you next time, partner!", "info")
end

function Events.init()
	Workspace:SetAttribute("EventId", "")
	Workspace:SetAttribute("SheriffHourUntil", 0)
end

function Events.start()
	-- Sheriff Hour on the fixed weekly clock (in Studio the first one comes after 2 minutes for testing).
	task.spawn(function()
		while true do
			local startUnix = if RunService:IsStudio() then os.time() + 120 else nextSheriffHour(os.time())
			Workspace:SetAttribute("SheriffHourAt", now() + math.max(0, startUnix - os.time()))
			task.wait(math.max(0, startUnix - os.time()))
			pcall(runSheriffHour)
			task.wait(60)
		end
	end)
	task.spawn(function()
		-- In Studio the first event comes quickly so it can be tested.
		local first = if RunService:IsStudio() then 45 else EventsConfig.FIRST_DELAY
		local nextAt = now() + first
		local previous: string? = nil
		while true do
			local event = EventsConfig.pick(random:NextNumber(), previous)
			previous = event.id
			Workspace:SetAttribute("EventNextId", event.id)
			Workspace:SetAttribute("EventNextAt", nextAt)
			task.wait(math.max(0, nextAt - now()))
			local ok, err = pcall(run :: any, event)
			if not ok then
				warn("[Events]", err)
				active = nil
				Workspace:SetAttribute("EventId", "")
			end
			nextAt += EventsConfig.INTERVAL
			if nextAt < now() then
				nextAt = now() + EventsConfig.INTERVAL
			end
		end
	end)
end

return Events
