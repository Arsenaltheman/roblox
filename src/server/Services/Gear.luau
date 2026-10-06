--!strict
-- Gear: tools bought with cash and unlocked by Frontier (Config/Gear). Owned forever, used from
-- the hotbar with a cooldown.
--   Smoke Bomb      - guards ignore you for a few seconds and you get a speed burst.
--   Tumbleweed Bomb - stuns nearby players and guards.
--   Bear Trap       - placed inside your ranch; the next thief to step in is stuck and drops the loot.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local GearConfig = require("@game/ReplicatedStorage/Shared/Config/Gear")
local HeistConfig = require("@game/ReplicatedStorage/Shared/Config/Heist")
local Layout = require("@game/ReplicatedStorage/Shared/Config/Layout")
local Net = require("@game/ReplicatedStorage/Shared/Net/Net")
local Registry = require("../Registry")

local Gear = {}

local readyAt: { [Player]: { [string]: number } } = {}
local traps: { [Player]: BasePart } = {}

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function root(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

function Gear.owns(player: Player, key: string): boolean
	local d = Registry.Data.get(player)
	return d ~= nil and d.Owned["gear:" .. key] == true
end

-- Mirrors owned gear to attributes ("Gear_<key>" = true) for the client hotbar and shop.
local function mirror(player: Player)
	for _, item in GearConfig.list do
		player:SetAttribute("Gear_" .. item.key, Gear.owns(player, item.key))
	end
end

local function buy(player: Player, key: string)
	local item = GearConfig.byKey[key]
	local d = Registry.Data.get(player)
	if not item or not d then
		return
	end
	if Gear.owns(player, key) then
		Registry.Ui.toast(player, `You already own the {item.name}.`)
		return
	end
	if d.Frontier < item.frontier then
		Registry.Ui.toast(player, `Reach Frontier {item.frontier} to unlock the {item.name}.`)
		return
	end
	if not Registry.Wallet.trySpendCash(player, item.price, "Gear:" .. key) then
		Registry.Ui.toast(player, "Not enough cash yet.")
		return
	end
	d.Owned["gear:" .. key] = true
	mirror(player)
	Registry.Ui.fx(player, "gearBought", 0)
	Registry.Ui.toast(
		player,
		`{item.name} unlocked! Use it from your hotbar ({GearConfig.KEY_LABEL[item.keybind] or "?"}).`
	)
	Registry.Ui.pushState(player)
	Registry.Data.saveNow(player)
end

local function insideOwnRanch(player: Player, position: Vector3): boolean
	local index = Registry.Ranch.indexOf(player)
	if not index then
		return false
	end
	local center = Layout.ranches[index].center
	local half = Layout.ranchSize / 2
	return math.abs(position.X - center.x) <= half and math.abs(position.Z - center.z) <= half
end

local function placeTrap(player: Player, position: Vector3)
	local old = traps[player]
	if old then
		old:Destroy()
	end
	local trap = Instance.new("Part")
	trap.Name = "BearTrap"
	trap.Shape = Enum.PartType.Cylinder
	trap.Size = Vector3.new(0.5, 4, 4)
	trap.CFrame = CFrame.new(position.X, 0.4, position.Z) * CFrame.Angles(0, 0, math.rad(90))
	trap.Color = Color3.fromRGB(70, 70, 76)
	trap.Material = Enum.Material.Metal
	trap.Anchored = true
	trap.CanCollide = false
	trap:SetAttribute("Owner", player.UserId)
	trap.Parent = Workspace
	traps[player] = trap
	-- Checked by the server (a thief's client could simply not report Touched).
	local sprung = false
	task.spawn(function()
		while not sprung and trap.Parent do
			for _, victim in Players:GetPlayers() do
				local vr = if victim ~= player then root(victim) else nil
				if
					vr
					and (vr.Position - trap.Position).Magnitude <= 3
					and Registry.Steal.carryingFrom(victim) == player
				then
					sprung = true
					Registry.Steal.forceReturn(victim)
					Registry.Steal.stun(victim, GearConfig.TRAP_STUN)
					Registry.Ui.fxAll("trapSnap", victim.UserId, trap.Position)
					Registry.Ui.toast(victim, "SNAP! A bear trap! The critter ran home.")
					Registry.Ui.toast(player, `Your bear trap caught {victim.DisplayName}!`)
					task.delay(1, function()
						trap:Destroy()
						if traps[player] == trap then
							traps[player] = nil
						end
					end)
					break
				end
			end
			task.wait(0.1)
		end
	end)
	task.delay(GearConfig.TRAP_LIFETIME, function()
		if traps[player] == trap then
			trap:Destroy()
			traps[player] = nil
		end
	end)
end

local function use(player: Player, key: string)
	local item = GearConfig.byKey[key]
	local r = root(player)
	if not item or not r or not Gear.owns(player, key) then
		return
	end
	local mine = readyAt[player] or {}
	readyAt[player] = mine
	local t = now()
	if t < (mine[key] or 0) then
		return
	end
	-- No gear while stunned (no dashing or bombing your way out of a tackle or trap).
	if Registry.Steal.isStunned(player) then
		return
	end

	if key == "SmokeBomb" then
		player:SetAttribute(
			"HiddenUntil",
			math.max((player:GetAttribute("HiddenUntil") :: number?) or 0, t + GearConfig.SMOKE_SECONDS)
		)
		Registry.Steal.burst(player, GearConfig.SMOKE_SECONDS, GearConfig.SMOKE_SPEED)
		Registry.Ui.fxAll("smoke", player.UserId, r.Position)
	elseif key == "TumbleweedBomb" then
		local hitCount = 0
		for _, other in Players:GetPlayers() do
			local orr = root(other)
			-- Only thieves and crate carriers are knocked out (never bystanders at the station).
			local carrier = (Registry.Steal.isCarrying(other) or Registry.Heist.isCarrying(other))
				and not Registry.Posse.sameGroup(player, other)
			if
				other ~= player
				and orr
				and carrier
				and (orr.Position - r.Position).Magnitude <= GearConfig.TUMBLE_RADIUS
			then
				Registry.Steal.stun(other, GearConfig.TUMBLE_STUN)
				hitCount += 1
			end
		end
		hitCount += Registry.Heist.stunGuardsNear(
			r.Position,
			GearConfig.TUMBLE_RADIUS,
			GearConfig.TUMBLE_STUN + 1
		)
		Registry.Ui.fxAll("tumbleweed", hitCount, r.Position)
	elseif key == "BearTrap" then
		if not insideOwnRanch(player, r.Position) then
			Registry.Ui.toast(player, "Set bear traps inside your own ranch.")
			return
		end
		placeTrap(player, r.Position)
		Registry.Ui.fx(player, "trapSet", 0)
		Registry.Ui.toast(player, "Bear trap set! The next thief who grabs from you gets caught.")
	elseif key == "TinStar" then
		player:SetAttribute("GuardUntil", t + GearConfig.GUARD_SECONDS)
		Registry.Ui.fxAll("tinStar", player.UserId, r.Position)
	elseif key == "GrappleHook" then
		-- The client owns its character's physics, so the dash impulse is applied there.
		Registry.Session.grantDash(player, 2)
		Registry.Ui.fx(player, "dash", GearConfig.DASH_SPEED)
		Registry.Ui.fxAll("dashTrail", player.UserId, r.Position)
	elseif key == "DynamiteDecoy" then
		local look = r.CFrame.LookVector * Vector3.new(1, 0, 1)
		local spot = r.Position + (if look.Magnitude > 0.1 then look.Unit else Vector3.new(0, 0, -1)) * 14
		spot = Vector3.new(spot.X, 0.5, spot.Z)
		Registry.Heist.decoy(spot, GearConfig.DECOY_RANGE, GearConfig.DECOY_SECONDS)
		Registry.Ui.fxAll("decoy", GearConfig.DECOY_SECONDS, spot)
		task.delay(GearConfig.DECOY_SECONDS, function()
			Registry.Heist.stunGuardsNear(spot, 16, GearConfig.DECOY_STUN)
			Registry.Ui.fxAll("tumbleweed", 0, spot)
		end)
	elseif key == "CactusWall" then
		local flat = r.CFrame.LookVector * Vector3.new(1, 0, 1)
		local back = if flat.Magnitude > 0.1 then -flat.Unit else Vector3.new(0, 0, 1)
		local center = r.Position + back * 7
		-- Only out in the heist zones and the desert, never in town (platform, ranches, Main Street).
		if not HeistConfig.insideAnyZone(center.X, center.Z, 30) then
			Registry.Ui.toast(player, "Cactus Walls only grow out in the heist zones.")
			return
		end
		local wall =
			CFrame.lookAt(Vector3.new(center.X, 0, center.Z), Vector3.new(center.X, 0, center.Z) + back)
		local parts = {}
		local blockers = OverlapParams.new()
		blockers.FilterType = Enum.RaycastFilterType.Include
		local characters = {}
		for _, other in Players:GetPlayers() do
			if other.Character then
				table.insert(characters, other.Character)
			end
		end
		blockers.FilterDescendantsInstances = characters
		for i = -2, 2 do
			local spot = wall * CFrame.new(i * 3, 3.5, 0)
			-- Never grow a cactus inside someone (it would fling or trap them).
			if #Workspace:GetPartBoundsInBox(spot, Vector3.new(3, 7, 3), blockers) > 0 then
				continue
			end
			local cactus = Instance.new("Part")
			cactus.Name = "CactusWall"
			cactus.Anchored = true
			cactus.Size = Vector3.new(2.6, 7, 2.6)
			cactus.CFrame = spot
			cactus.Color = Color3.fromRGB(78, 154, 75)
			cactus.Material = Enum.Material.Grass
			cactus.Parent = Workspace
			table.insert(parts, cactus)
		end
		Registry.Ui.fxAll("cactusWall", 0, center)
		task.delay(GearConfig.WALL_SECONDS, function()
			for _, p in parts do
				p:Destroy()
			end
		end)
	elseif key == "StampedeCall" then
		Registry.Heist.stunGuardsNear(r.Position, GearConfig.STAMPEDE_RANGE, GearConfig.STAMPEDE_STUN)
		Registry.Steal.burst(player, GearConfig.STAMPEDE_STUN, GearConfig.STAMPEDE_SPEED)
		Registry.Ui.fxAll("stampede", player.UserId, r.Position)
	elseif key == "GhostLantern" then
		player:SetAttribute(
			"HiddenUntil",
			math.max((player:GetAttribute("HiddenUntil") :: number?) or 0, t + GearConfig.GHOST_SECONDS)
		)
		Registry.Steal.burst(player, GearConfig.GHOST_SECONDS, GearConfig.GHOST_SPEED)
		Registry.Ui.fxAll("ghost", player.UserId, r.Position)
	else
		return
	end
	mine[key] = t + item.cooldown
	player:SetAttribute("GearReady_" .. key, mine[key])
	Registry.Progression.questEvent(player, "gear", 1)
end

function Gear.init() end

function Gear.start()
	Net.on("BuyGear", buy)
	Net.on("UseGear", use)
	Registry.Data.loaded:Connect(function(player: Player)
		mirror(player)
	end)
	-- Tell players when a Frontier unlocks new gear.
	Registry.Ranch.frontierReached:Connect(function(player: Player, n: number)
		for _, item in GearConfig.list do
			if item.frontier == n then
				Registry.Ui.toast(
					player,
					`NEW GEAR UNLOCKED: {item.name}! Get it in the Trading Post (Gear tab).`
				)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		readyAt[player] = nil
		local trap = traps[player]
		if trap then
			trap:Destroy()
			traps[player] = nil
		end
	end)
end

return Gear
