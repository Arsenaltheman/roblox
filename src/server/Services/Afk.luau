--!strict
-- AFK raids. Nobody farms while away from the keyboard: after 5 idle minutes Bandit Bart raids the
-- idle player's ranch and takes one critter, then another every 3 minutes while they stay idle.
-- Stolen critters go to the Bandit Camp stash, where active players rob them back (the red-light
-- game). A big countdown with alarms warns the idle player from the first minute; any real action
-- cancels it. Tutorial players and shielded newcomers are left alone.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Layout = require("@game/ReplicatedStorage/Shared/Config/Layout")
local Progression = require("@game/ReplicatedStorage/Shared/Config/Progression")
local Economy = require("@game/ReplicatedStorage/Shared/Sim/Economy")
local Species = require("@game/ReplicatedStorage/Shared/Config/Species")
local Registry = require("../Registry")

local Afk = {}

Afk.WARN_AFTER = 60 -- seconds idle before the countdown shows
Afk.FIRST_RAID = 5 * 60 -- seconds idle until the first raid
Afk.RAID_EVERY = 3 * 60 -- seconds between raids while still idle

-- Server time of each player's next raid (nil = not idle enough to be warned).
local nextRaidAt: { [Player]: number } = {}

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function exempt(player: Player, d: any): boolean
	if d.Tutorial < 3 then
		return true
	end
	if (d.Stats.PlaySeconds or 0) < Progression.newbieShieldSeconds then
		return true
	end
	local index = Registry.Ranch.indexOf(player)
	return index == nil
end

-- A random placed critter that isn't branded, in transit or in a safe pen.
local function pickVictim(d: any): string?
	local safe = Economy.safePens(d.Frontier)
	local candidates = {}
	for cid, critter in d.Critters do
		if critter.p > safe and not critter.br and not critter.it then
			table.insert(candidates, cid)
		end
	end
	if #candidates == 0 then
		return nil
	end
	return candidates[math.random(1, #candidates)]
end

local function raid(player: Player, d: any)
	local cid = pickVictim(d)
	if not cid then
		return
	end
	local critter = Registry.Ranch.removeCritter(player, cid)
	if not critter then
		return
	end
	Registry.Steal.stashAdd({ s = critter.s, tier = critter.tier, m = critter.m })
	local name = Species.byId[critter.s] and Species.byId[critter.s].name or "critter"
	local index = Registry.Ranch.indexOf(player)
	local c = index and Layout.ranches[index].center
	Registry.Ui.fxAll("afkRaid", player.UserId, if c then Vector3.new(c.x, 3, c.z) else nil)
	Registry.Ui.toast(player, `BANDIT BART raided your ranch while you were AFK and took your {name}!`)
	Registry.Ui.announce(
		`Bandit Bart robbed {player.DisplayName}'s ranch while they were AFK. The {name} is at the Bandit Camp!`,
		"steal"
	)
	Registry.Telemetry.custom(player, "AfkRaid", critter.tier)
	Registry.Data.saveNow(player)
end

local function tick()
	for _, player in Players:GetPlayers() do
		local d = Registry.Data.get(player)
		if not d then
			continue
		end
		local idle = Registry.Session.idleSeconds(player)
		if idle < Afk.WARN_AFTER or exempt(player, d) then
			if nextRaidAt[player] then
				nextRaidAt[player] = nil
				player:SetAttribute("AfkRaidAt", nil)
			end
			continue
		end
		local at = nextRaidAt[player]
		if not at then
			at = now() + (Afk.FIRST_RAID - idle)
			nextRaidAt[player] = at
			player:SetAttribute("AfkRaidAt", at)
		end
		if now() >= at then
			raid(player, d)
			nextRaidAt[player] = now() + Afk.RAID_EVERY
			player:SetAttribute("AfkRaidAt", nextRaidAt[player])
		end
	end
end

function Afk.init() end

function Afk.start()
	Players.PlayerRemoving:Connect(function(player)
		nextRaidAt[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			pcall(tick)
		end
	end)
end

return Afk
