--!strict
-- Weather events: every 12 minutes a 2-minute event brings one mutation. During it, cages roll that
-- mutation more often, and at the start every ranch critter gets a chance to catch it.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Mutations = require("@game/ReplicatedStorage/Shared/Config/Mutations")
local Progression = require("@game/ReplicatedStorage/Shared/Config/Progression")
local Loot = require("@game/ReplicatedStorage/Shared/Sim/Loot")
local Rng = require("@game/ReplicatedStorage/Shared/Sim/Rng")
local Registry = require("../Registry")

-- First weather comes early so new servers see one in the first few minutes.
local FIRST_WEATHER_SECONDS = 4 * 60

local NAMES = {
	Gold = "GOLD RUSH",
	Diamond = "DIAMOND DUST",
	Frosty = "BLIZZARD",
	Electric = "THUNDERSTORM",
	Molten = "HEATWAVE",
	Ghost = "GHOST TRAIN NIGHT",
	Cosmic = "STARFALL",
	Rainbow = "RAINBOW SKIES",
}

local Weather = {}

local rng = Rng.new(os.time() + 99)
local active: string? = nil
local activeUntil = 0
local nextAt = 0

local function now(): number
	return Workspace:GetServerTimeNow()
end

function Weather.current(): string?
	if active and now() < activeUntil then
		return active
	end
	return nil
end

function Weather.start_(mutation: string, durationSeconds: number?)
	if not Registry.LiveConfig.enabled("ff.weather") then
		return
	end
	active = mutation
	activeUntil = now() + (durationSeconds or Progression.weather.durationSeconds)
	Workspace:SetAttribute("Weather", mutation)
	Workspace:SetAttribute("WeatherUntil", activeUntil)
	Registry.Ui.announce(
		`{NAMES[mutation] or mutation}! {Mutations.byId[mutation].name} critters for 2 minutes!`,
		"weather"
	)
	-- Each placed critter rolls to catch the mutation.
	for _, player in Players:GetPlayers() do
		local d = Registry.Data.get(player)
		if d then
			local caught = 0
			for cid, critter in d.Critters do
				if critter.p > 0 and not critter.it and rng:chance(Progression.weather.ranchRollChance) then
					if Loot.betterMutation(critter.m, mutation) then
						critter.m = mutation
						caught += 1
						Registry.Ranch.syncCritter(player, cid)
					end
				end
			end
			if caught > 0 then
				Registry.Ui.toast(player, `{caught} of your critters turned {Mutations.byId[mutation].name}!`)
				Registry.Ui.fx(player, "mutate", caught)
			end
		end
	end
end

function Weather.init()
	nextAt = now() + FIRST_WEATHER_SECONDS
	Workspace:SetAttribute("Weather", "")
	Workspace:SetAttribute("WeatherNext", nextAt)
end

function Weather.start()
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 1 then
			return
		end
		accumulator = 0
		local t = now()
		if active and t >= activeUntil then
			active = nil
			Workspace:SetAttribute("Weather", "")
		end
		if t >= nextAt then
			nextAt = t + Progression.weather.everySeconds
			Workspace:SetAttribute("WeatherNext", nextAt)
			Weather.start_(Loot.weather(rng))
		end
	end)
end

return Weather
