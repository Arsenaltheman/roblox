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
	elseif event.id == "GoldRush" then
		-- Ranch income reads Events.goldRush() through LiveOps.incomeEventActive; push fresh numbers.
		for _, player in Players:GetPlayers() do
			Registry.Ui.pushState(player)
		end
	end
	task.wait(event.duration)
	active = nil
	Workspace:SetAttribute("EventId", "")
	if event.id == "GoldRush" then
		Registry.Ui.announce("The Gold Rush is over. Next event soon!", "info")
		for _, player in Players:GetPlayers() do
			Registry.Ui.pushState(player)
		end
	end
end

function Events.init()
	Workspace:SetAttribute("EventId", "")
end

function Events.start()
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
