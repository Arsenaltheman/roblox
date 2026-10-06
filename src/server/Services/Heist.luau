--!strict
-- Heist zones: the active loop. Critter crates sit on nests in four desert zones, each guarded by a
-- posse of NPC guards. Hold GRAB at a nest, then run the crate home to your ranch. Guards chase
-- carriers and tackle them (the crate goes back on its nest); other players can lasso a carrier to
-- take the crate (handled in Steal via Heist.transfer). Speed Boots, bought with cash, make you
-- faster so the deeper, richer zones become reachable. Numbers live in Config/Heist.
--
-- Crates are not in anyone's save while carried: they only become a critter on delivery, so a
-- disconnect, death or timeout simply puts the crate back on its nest. Nothing can be duplicated.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local HeistConfig = require("@game/ReplicatedStorage/Shared/Config/Heist")
local Layout = require("@game/ReplicatedStorage/Shared/Config/Layout")
local Mutations = require("@game/ReplicatedStorage/Shared/Config/Mutations")
local Rarities = require("@game/ReplicatedStorage/Shared/Config/Rarities")
local Species = require("@game/ReplicatedStorage/Shared/Config/Species")
local Economy = require("@game/ReplicatedStorage/Shared/Sim/Economy")
local Net = require("@game/ReplicatedStorage/Shared/Net/Net")
local Registry = require("../Registry")

local Heist = {}

type Crate = { species: string, tier: number, mutation: string? }
type Nest = { zone: number, index: number, pad: BasePart, crate: Crate?, respawnAt: number }
-- origin: where the carry began (the nest, or where it was snatched); deliveries need plausible travel.
type Carry = { zone: number, nest: number, crate: Crate, started: number, origin: Vector3 }
type Guard = {
	zone: number,
	model: Model,
	root: BasePart,
	humanoid: Humanoid,
	alert: BillboardGui,
	target: Player?,
	nextWander: number,
	stunnedUntil: number,
	-- Dynamite Decoy: chase this spot instead of players until decoyUntil.
	decoyUntil: number?,
	decoyPos: Vector3?,
}

local nests: { [number]: { Nest } } = {}
local guards: { Guard } = {}
local carrying: { [Player]: Carry } = {}
local grabbing: { [Player]: boolean } = {}
local folder: Folder
-- Bonus nests from server events live under this pseudo-zone id.
local BONUS_ZONE = 0
local bonusCount = 0

local random = Random.new()

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function root(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

function Heist.isCarrying(player: Player): boolean
	return carrying[player] ~= nil
end

-- ------------------------------------------------------------------ nests

local function rollCrate(zone: HeistConfig.Zone): Crate
	local tier = HeistConfig.rollTier(zone, random:NextNumber(), random:NextNumber())
	local species = Species.byTier[tier] or Species.byTier[zone.minTier]
	local mutation: string? = nil
	-- Deeper zones mutate more often (2% / 4% / 6% / 8%).
	if random:NextNumber() < 0.02 * zone.id then
		local pick = Mutations.list[random:NextInteger(1, math.min(#Mutations.list, 2 + zone.id))]
		mutation = pick and pick.id
	end
	return { species = species.id, tier = tier, mutation = mutation }
end

-- Mirrors the crate onto the nest pad's attributes; the client draws it from these.
local function showCrate(nest: Nest)
	local crate = nest.crate
	nest.pad:SetAttribute("Species", if crate then crate.species else "")
	nest.pad:SetAttribute("Tier", if crate then crate.tier else 0)
	nest.pad:SetAttribute("Mutation", if crate then crate.mutation or "" else "")
	nest.pad:SetAttribute("RespawnAt", if crate then 0 else nest.respawnAt)
end

local function fillNest(nest: Nest, crate: Crate?)
	local zone = HeistConfig.zone(nest.zone) :: HeistConfig.Zone
	nest.crate = crate or rollCrate(zone)
	showCrate(nest)
	local c = nest.crate :: Crate
	-- A jackpot appearing is a server-wide moment.
	if c.tier >= 37 then
		Registry.Ui.announce(`A {Rarities.forTier(c.tier).name} crate appeared in {zone.name}!`, "golden")
	end
end

local function emptyNest(nest: Nest)
	nest.crate = nil
	nest.respawnAt = now() + random:NextNumber(HeistConfig.RESPAWN_MIN, HeistConfig.RESPAWN_MAX)
	showCrate(nest)
end

local function buildNests()
	nests[BONUS_ZONE] = {}
	for _, zone in HeistConfig.zones do
		nests[zone.id] = {}
		for n = 1, zone.nests do
			local x, z = HeistConfig.nestPosition(zone, n)
			local pad = Instance.new("Part")
			pad.Name = `Nest{zone.id}_{n}`
			pad.Shape = Enum.PartType.Cylinder
			pad.Size = Vector3.new(0.6, 6, 6)
			pad.CFrame = CFrame.new(x, 0.3, z) * CFrame.Angles(0, 0, math.rad(90))
			pad.Color = Color3.fromRGB(140, 96, 60)
			pad.Material = Enum.Material.WoodPlanks
			pad.Anchored = true
			pad.CanCollide = false
			pad:SetAttribute("HeistZone", zone.id)
			pad:SetAttribute("HeistNest", n)
			pad.Parent = folder
			local nest: Nest = { zone = zone.id, index = n, pad = pad, crate = nil, respawnAt = 0 }
			nests[zone.id][n] = nest
			fillNest(nest)
		end
	end
end

-- ------------------------------------------------------------------ guards

local function guardPart(
	model: Model,
	name: string,
	size: Vector3,
	color: Color3,
	shape: Enum.PartType?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	if shape then
		p.Shape = shape
	end
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

local function weldTo(part: BasePart, rootPart: BasePart, offset: CFrame)
	part.CFrame = rootPart.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = rootPart
	weld.Part1 = part
	weld.Parent = part
end

-- A chunky posse guard: barrel body, bandana, black hat and glowing eyes. A legless Humanoid with
-- a hip height walks with MoveTo and replicates smoothly.
local function buildGuard(zone: HeistConfig.Zone, at: Vector3): Guard
	local model = Instance.new("Model")
	model.Name = "PosseGuard"
	local rootPart = Instance.new("Part")
	rootPart.Name = "HumanoidRootPart"
	rootPart.Size = Vector3.new(2.6, 2.6, 1.6)
	rootPart.Transparency = 1
	rootPart.CanCollide = false
	rootPart.CFrame = CFrame.new(at + Vector3.new(0, 3.2, 0))
	rootPart.Parent = model
	model.PrimaryPart = rootPart

	local dark = zone.theme == "ghost"
	local bodyColor = if dark then Color3.fromRGB(150, 230, 210) else Color3.fromRGB(150, 95, 60)
	local body = guardPart(model, "Body", Vector3.new(3.4, 3, 3), bodyColor, Enum.PartType.Cylinder)
	weldTo(body, rootPart, CFrame.Angles(0, 0, math.rad(90)))
	if dark then
		body.Transparency = 0.35
		body.Material = Enum.Material.Neon
	end
	local head = guardPart(
		model,
		"Head",
		Vector3.new(2.2, 2.2, 2.2),
		Color3.fromRGB(235, 190, 140),
		Enum.PartType.Ball
	)
	weldTo(head, rootPart, CFrame.new(0, 2.4, 0))
	local bandana = guardPart(
		model,
		"Bandana",
		Vector3.new(2.3, 0.9, 2.3),
		Color3.fromRGB(200, 40, 40),
		Enum.PartType.Cylinder
	)
	weldTo(bandana, rootPart, CFrame.new(0, 1.9, 0) * CFrame.Angles(0, 0, math.rad(90)))
	local brim = guardPart(
		model,
		"HatBrim",
		Vector3.new(0.25, 3.6, 3.6),
		Color3.fromRGB(30, 26, 34),
		Enum.PartType.Cylinder
	)
	weldTo(brim, rootPart, CFrame.new(0, 3.35, 0) * CFrame.Angles(0, 0, math.rad(90)))
	local crown = guardPart(
		model,
		"HatCrown",
		Vector3.new(1.2, 2, 2),
		Color3.fromRGB(30, 26, 34),
		Enum.PartType.Cylinder
	)
	weldTo(crown, rootPart, CFrame.new(0, 3.95, 0) * CFrame.Angles(0, 0, math.rad(90)))
	for side = -1, 1, 2 do
		local eye = guardPart(model, "Eye", Vector3.new(0.35, 0.35, 0.2), Color3.fromRGB(255, 70, 50))
		eye.Material = Enum.Material.Neon
		weldTo(eye, rootPart, CFrame.new(side * 0.45, 2.55, -1.05))
	end

	-- "!" pops over their head while chasing.
	local alert = Instance.new("BillboardGui")
	alert.Name = "Alert"
	alert.Size = UDim2.fromScale(3, 3)
	alert.StudsOffset = Vector3.new(0, 6.5, 0)
	alert.AlwaysOnTop = true
	alert.MaxDistance = 160
	alert.Enabled = false
	local mark = Instance.new("TextLabel")
	mark.Size = UDim2.fromScale(1, 1)
	mark.BackgroundTransparency = 1
	mark.Text = "!"
	mark.TextScaled = true
	mark.TextColor3 = Color3.fromRGB(255, 60, 60)
	mark.FontFace = Font.fromEnum(Enum.Font.LuckiestGuy)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 4
	stroke.Color = Color3.fromRGB(43, 29, 20)
	stroke.Parent = mark
	mark.Parent = alert
	alert.Parent = head

	local humanoid = Instance.new("Humanoid")
	humanoid.HipHeight = 3.2
	humanoid.WalkSpeed = zone.patrolSpeed
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.BreakJointsOnDeath = false
	humanoid.MaxHealth = math.huge
	humanoid.Health = math.huge
	humanoid.Parent = model

	model:SetAttribute("HeistGuard", zone.id)
	model.Parent = folder
	rootPart:SetNetworkOwner(nil)
	return {
		zone = zone.id,
		model = model,
		root = rootPart,
		humanoid = humanoid,
		alert = alert,
		target = nil,
		nextWander = 0,
		stunnedUntil = 0,
	}
end

local function buildGuards()
	for _, zone in HeistConfig.zones do
		for i = 1, zone.guards do
			local angle = i / zone.guards * math.pi * 2
			local at = Vector3.new(
				zone.x + math.cos(angle) * zone.radius * 0.5,
				0,
				zone.z + math.sin(angle) * zone.radius * 0.5
			)
			table.insert(guards, buildGuard(zone, at))
		end
	end
end

-- ------------------------------------------------------------------ carrying

local function setCarryAttributes(player: Player, carry: Carry?)
	player:SetAttribute("Carrying", if carry then carry.crate.species else "")
	player:SetAttribute("CarryingTier", if carry then carry.crate.tier else 0)
	player:SetAttribute("CarryingMutation", if carry then carry.crate.mutation or "" else "")
	player:SetAttribute("CarryingFrom", 0)
	player:SetAttribute("HeistCarry", carry ~= nil)
	player:SetAttribute("Wanted", carry ~= nil)
	Registry.Steal.refreshSpeed(player)
end

-- The crate goes back on its nest (if the nest is still empty), or is lost if it has refilled.
local function dropCarry(player: Player, reason: string)
	local carry = carrying[player]
	if not carry then
		return
	end
	carrying[player] = nil
	local nest = nests[carry.zone][carry.nest]
	if nest and not nest.crate then
		nest.crate = carry.crate
		showCrate(nest)
	end
	if player.Parent == Players then
		setCarryAttributes(player, nil)
		if carry.zone == BONUS_ZONE then
			Registry.Ui.toast(player, "You dropped the crate and it's gone!")
		elseif reason == "tackled" then
			Registry.Ui.toast(player, "TACKLED! The crate went back to its nest.")
		elseif reason == "timeout" then
			Registry.Ui.toast(player, "Too slow! The crate escaped back to its nest.")
		end
	end
end

local function startCarry(player: Player, nest: Nest)
	local crate = nest.crate :: Crate
	if nest.zone == BONUS_ZONE then
		-- Bonus crates are one-offs: the nest disappears once grabbed.
		nests[BONUS_ZONE][nest.index] = nil
		nest.crate = nil
		nest.pad:Destroy()
	else
		emptyNest(nest)
	end
	carrying[player] =
		{ zone = nest.zone, nest = nest.index, crate = crate, started = now(), origin = nest.pad.Position }
	setCarryAttributes(player, carrying[player])
	Registry.Ui.fxAll("heistGrab", player.UserId, nest.pad.Position)
	local name = Species.byId[crate.species].name
	Registry.Ui.toast(player, `Got a {Rarities.forTier(crate.tier).name} {name}! RUN IT HOME!`)
end

-- Another player lassoed this carrier: the crate changes hands (the lasso-er must not be carrying).
function Heist.transfer(from: Player, to: Player): boolean
	local carry = carrying[from]
	if not carry or carrying[to] or Registry.Steal.isCarrying(to) then
		return false
	end
	carrying[from] = nil
	setCarryAttributes(from, nil)
	carry.started = now()
	local fromRoot = root(from)
	if fromRoot then
		carry.origin = fromRoot.Position
	end
	carrying[to] = carry
	setCarryAttributes(to, carry)
	Registry.Ui.toast(from, `{to.DisplayName} lassoed your crate!`)
	Registry.Ui.toast(to, "You snatched the crate! RUN IT HOME!")
	return true
end

local function insideOwnRanch(player: Player): boolean
	local index = Registry.Ranch.indexOf(player)
	local r = root(player)
	if not index or not r then
		return false
	end
	local center = Layout.ranches[index].center
	local half = Layout.ranchSize / 2
	return math.abs(r.Position.X - center.x) <= half and math.abs(r.Position.Z - center.z) <= half
end

local function deliver(player: Player)
	local carry = carrying[player]
	if not carry then
		return
	end
	carrying[player] = nil
	setCarryAttributes(player, nil)
	local crate = carry.crate
	local name = Species.byId[crate.species].name
	local cid = nil
	if Registry.Ranch.canAccept(player, crate.tier, crate.mutation) then
		cid = Registry.Ranch.addCritter(player, {
			species = crate.species,
			tier = crate.tier,
			mutation = crate.mutation,
			src = "heist",
		})
	end
	if not cid then
		local value = Economy.sellValue({ tier = crate.tier, mutation = crate.mutation })
		Registry.Wallet.addCash(player, value, "HeistSold")
		Registry.Ui.toast(player, `Your pens are full of better critters, so the {name} was sold.`)
	else
		Registry.Ui.reveal(
			player,
			{ kind = "heist", species = crate.species, tier = crate.tier, mutation = crate.mutation }
		)
	end
	local d = Registry.Data.get(player)
	if d then
		d.Stats.Heists = (d.Stats.Heists or 0) + 1
		Registry.Progression.questEvent(player, "heist", 1)
		if carry.zone == BONUS_ZONE then
			Registry.Progression.questEvent(player, "crateRain", 1)
		elseif carry.zone >= 2 then
			Registry.Progression.questEvent(player, "heist_z" .. carry.zone, 1)
		end
		if Rarities.indexOf(Rarities.forTier(crate.tier).id) >= 3 then
			Registry.Progression.questEvent(player, "heistRare", 1)
		end
	end
	Registry.Wheel.heistDelivered(player)
	Registry.Posse.onHeist(player)
	Registry.Data.saveNow(player)
	local r = root(player)
	Registry.Ui.fxAll("heistDeliver", crate.tier, r and r.Position)
	if Rarities.indexOf(Rarities.forTier(crate.tier).id) >= 5 then
		local zone = HeistConfig.zone(carry.zone)
		local where = if zone then zone.name else "the Crate Rain"
		Registry.Ui.announce(
			`{player.DisplayName} pulled off a heist: a {Rarities.forTier(crate.tier).name} {name} from {where}!`,
			Rarities.forTier(crate.tier).id
		)
	end
end

-- ------------------------------------------------------------------ remotes

local function grab(player: Player, zoneId: number, nestIndex: number)
	local zoneNests = nests[zoneId]
	local nest = zoneNests and zoneNests[nestIndex]
	local r = root(player)
	if not nest or not nest.crate or not r or grabbing[player] then
		return
	end
	if carrying[player] or Registry.Steal.isBusy(player) or Registry.Session.isSuspicious(player) then
		return
	end
	if (r.Position - nest.pad.Position).Magnitude > HeistConfig.GRAB_REACH then
		return
	end
	grabbing[player] = true
	Registry.Ui.fx(player, "grabStart", HeistConfig.GRAB_SECONDS)
	-- Grabbing is loud: the zone's guards come running.
	for _, guard in guards do
		if
			guard.zone == zoneId
			and (guard.root.Position - nest.pad.Position).Magnitude < HeistConfig.AGGRO_RANGE * 1.5
		then
			guard.target = player
		end
	end
	task.delay(HeistConfig.GRAB_SECONDS, function()
		grabbing[player] = nil
		local rr = root(player)
		if player.Parent ~= Players or not rr or not nest.crate or carrying[player] then
			return
		end
		if (rr.Position - nest.pad.Position).Magnitude > HeistConfig.GRAB_REACH + 3 then
			Registry.Ui.toast(player, "You let go too early!")
			return
		end
		startCarry(player, nest)
	end)
end

local function buyBoots(player: Player)
	local d = Registry.Data.get(player)
	if not d then
		return
	end
	local level = d.Stats.Boots or 0
	local cost = HeistConfig.bootsCost(level)
	if not cost then
		Registry.Ui.toast(player, "Your boots are maxed out!")
		return
	end
	if not Registry.Wallet.trySpendCash(player, cost, "Boots") then
		Registry.Ui.toast(player, "Not enough cash for the next boots yet.")
		return
	end
	d.Stats.Boots = level + 1
	player:SetAttribute("Boots", level + 1)
	Registry.Steal.refreshSpeed(player)
	Registry.Ui.fx(player, "bootsUp", level + 1)
	Registry.Ui.toast(player, `Speed Boots level {level + 1}! You run faster now.`)
	Registry.Ui.pushState(player)
end

function Heist.bootsLevel(player: Player): number
	local d = Registry.Data.get(player)
	return if d then d.Stats.Boots or 0 else 0
end

-- ------------------------------------------------------------------ loop

local function hidden(player: Player): boolean
	return ((player:GetAttribute("HiddenUntil") :: number?) or 0) > now()
end

function Heist.stunGuardsNear(position: Vector3, radius: number, seconds: number): number
	local count = 0
	for _, guard in guards do
		if (guard.root.Position - position).Magnitude <= radius then
			-- 0 releases; otherwise never shorten a longer stun (e.g. the Bandit King's).
			guard.stunnedUntil = if seconds <= 0 then now() else math.max(guard.stunnedUntil, now() + seconds)
			guard.target = nil
			guard.humanoid:MoveTo(guard.root.Position)
			count += 1
		end
	end
	return count
end

-- Dynamite Decoy: guards within `radius` chase `position` for `seconds`. Returns how many.
function Heist.decoy(position: Vector3, radius: number, seconds: number): number
	local count = 0
	for _, guard in guards do
		if (guard.root.Position - position).Magnitude <= radius then
			guard.decoyUntil = now() + seconds
			guard.decoyPos = position
			guard.target = nil
			count += 1
		end
	end
	return count
end

-- Every heist nest refills now, `boost` tiers richer than normal (server event).
function Heist.restockAll(boost: number, mutation: string?)
	for zoneId, zoneNests in nests do
		if zoneId == BONUS_ZONE then
			continue
		end
		for _, nest in zoneNests do
			local zone = HeistConfig.zone(nest.zone) :: HeistConfig.Zone
			local crate = rollCrate(zone)
			if mutation then
				crate.mutation = mutation -- event-only mutation (Lightning Storm)
			end
			-- Never above the top non-secret tier (Secrets come from the train only).
			crate.tier = math.min(38, crate.tier + boost)
			crate.species = (Species.byTier[crate.tier] or Species.byTier[zone.maxTier]).id
			nest.crate = crate
			showCrate(nest)
		end
	end
end

-- A temporary, unguarded bonus nest (Crate Rain). It vanishes when grabbed or after `lifetime`.
function Heist.dropBonus(position: Vector3, tier: number, lifetime: number)
	if not nests[BONUS_ZONE] then
		return -- heists are switched off
	end
	local pad = Instance.new("Part")
	pad.Name = "BonusNest"
	pad.Shape = Enum.PartType.Cylinder
	pad.Size = Vector3.new(0.6, 6, 6)
	pad.CFrame = CFrame.new(position.X, 0.3, position.Z) * CFrame.Angles(0, 0, math.rad(90))
	pad.Color = Color3.fromRGB(255, 200, 61)
	pad.Material = Enum.Material.Neon
	pad.Anchored = true
	pad.CanCollide = false
	-- Bonus nests live in zone 0 with their own index (grab looks them up there).
	bonusCount += 1
	local index = bonusCount
	pad:SetAttribute("HeistZone", BONUS_ZONE)
	pad:SetAttribute("HeistNest", index)
	pad.Parent = folder
	local species = Species.byTier[math.clamp(tier, 1, 40)]
	local nest: Nest = { zone = BONUS_ZONE, index = index, pad = pad, crate = nil, respawnAt = math.huge }
	nests[BONUS_ZONE][index] = nest
	nest.crate = { species = species.id, tier = species.tier, mutation = nil }
	showCrate(nest)
	Registry.Ui.fxAll("crateDrop", species.tier, pad.Position)
	task.delay(lifetime, function()
		nest.crate = nil
		if nests[BONUS_ZONE][index] == nest then
			nests[BONUS_ZONE][index] = nil
			pad:Destroy()
		end
	end)
end

local function updateGuard(guard: Guard, t: number)
	local zone = HeistConfig.zone(guard.zone) :: HeistConfig.Zone
	local center = Vector3.new(zone.x, guard.root.Position.Y, zone.z)
	local leash = zone.radius * HeistConfig.LEASH
	local pos = guard.root.Position
	if t < guard.stunnedUntil then
		guard.alert.Enabled = false
		return
	end
	if guard.decoyUntil and t < guard.decoyUntil and guard.decoyPos then
		guard.target = nil
		guard.alert.Enabled = true
		guard.humanoid.WalkSpeed = zone.chaseSpeed
		guard.humanoid:MoveTo(guard.decoyPos)
		return
	end

	-- Pick up the nearest carrier (or grabber) in range. Smoke-bombed players are invisible to them.
	local best: Player? = guard.target
	local bestDist = math.huge
	if best then
		local br = root(best)
		if
			not br
			or hidden(best)
			or not (carrying[best] or grabbing[best])
			or (br.Position - center).Magnitude > leash
		then
			best = nil
		else
			bestDist = (br.Position - pos).Magnitude
		end
	end
	for player in carrying do
		local pr = root(player)
		if pr and not hidden(player) then
			local d = (pr.Position - pos).Magnitude
			if d < HeistConfig.AGGRO_RANGE and d < bestDist and (pr.Position - center).Magnitude <= leash then
				best, bestDist = player, d
			end
		end
	end
	guard.target = best

	if best then
		local br = root(best) :: BasePart
		guard.humanoid.WalkSpeed = zone.chaseSpeed
		guard.humanoid:MoveTo(br.Position)
		if not guard.alert.Enabled then
			guard.alert.Enabled = true
			Registry.Ui.fxAll("guardAlert", guard.zone, guard.root.Position)
		end
		if bestDist <= HeistConfig.TACKLE_RANGE and carrying[best] then
			if ((best:GetAttribute("GuardUntil") :: number?) or 0) > t then
				-- Tin Star: the badge bounces one tackle.
				best:SetAttribute("GuardUntil", nil)
				Registry.Ui.fxAll("guardPop", best.UserId, br.Position)
				Registry.Ui.toast(best, "Your Tin Star bounced a tackle!")
				guard.target = nil
				guard.nextWander = t + 2
				return
			end
			dropCarry(best, "tackled")
			-- Ranger mastery: shorter guard stuns.
			Registry.Steal.stun(
				best,
				math.max(0.5, HeistConfig.STUN_SECONDS - Registry.Skills.perkValue(best, "Ranger"))
			)
			Registry.Ui.fxAll("tackle", best.UserId, br.Position)
			guard.target = nil
			guard.nextWander = t + 1.5
		end
		return
	end

	guard.alert.Enabled = false
	guard.humanoid.WalkSpeed = zone.patrolSpeed
	if (pos - center).Magnitude > zone.radius * 1.1 then
		guard.humanoid:MoveTo(center)
	elseif t >= guard.nextWander then
		local angle = random:NextNumber() * math.pi * 2
		local dist = random:NextNumber() * zone.radius * 0.85
		guard.humanoid:MoveTo(
			Vector3.new(zone.x + math.cos(angle) * dist, 0, zone.z + math.sin(angle) * dist)
		)
		guard.nextWander = t + random:NextNumber(3, 6)
	end
end

function Heist.init()
	folder = Instance.new("Folder")
	folder.Name = "Heist"
	folder.Parent = Workspace
end

function Heist.start()
	if not Registry.LiveConfig.enabled("ff.heist") then
		return
	end
	buildNests()
	buildGuards()
	Net.on("HeistGrab", grab)
	Net.on("BuyBoots", buyBoots)

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			dropCarry(player, "died")
		end)
	end)
	for _, player in Players:GetPlayers() do
		player.CharacterAdded:Connect(function()
			dropCarry(player, "died")
		end)
	end
	Players.PlayerRemoving:Connect(function(player)
		dropCarry(player, "left")
		grabbing[player] = nil
	end)
	Registry.Data.loaded:Connect(function(player: Player)
		player:SetAttribute("Boots", Heist.bootsLevel(player))
		Registry.Steal.refreshSpeed(player)
	end)

	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.2 then
			return
		end
		accumulator = 0
		local t = now()
		for _, guard in guards do
			updateGuard(guard, t)
		end
		for zoneId, zoneNests in nests do
			if zoneId == BONUS_ZONE then
				continue
			end
			for _, nest in zoneNests do
				if not nest.crate and t >= nest.respawnAt then
					fillNest(nest)
				end
			end
		end
		for player, carry in carrying do
			if insideOwnRanch(player) then
				-- Travel-time gate: nobody covers nest-to-ranch faster than ~110 studs/s; a position
				-- jump also marks the player suspicious for a few seconds.
				local index = Registry.Ranch.indexOf(player)
				local center = index and Layout.ranches[index].center
				local dist = if center
					then (carry.origin - Vector3.new(center.x, carry.origin.Y, center.z)).Magnitude
					else 0
				local minimum = math.max(1.5, dist / 110)
				if Registry.Session.isSuspicious(player) or t - carry.started < minimum then
					if Registry.Session.isSuspicious(player) then
						dropCarry(player, "cheat")
						Registry.Guard.strike(player, "heist:teleport")
					end
				else
					deliver(player)
				end
			elseif t - carry.started > HeistConfig.CARRY_TIMEOUT then
				dropCarry(player, "timeout")
			end
		end
	end)
end

return Heist
