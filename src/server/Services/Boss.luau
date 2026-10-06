--!strict
-- The Bandit King (Config/Boss), started by the Events service. A big bandit in Ghost Town with a
-- shared health bar. Players lasso him (HitBoss); he leaps to a new spot every few seconds and
-- stomps where he lands (a red ring warns everyone first). Defeat him in time and every helper gets
-- cash, Gold Nuggets and a free spin; the top lassoer also gets a rare critter.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local BossConfig = require("@game/ReplicatedStorage/Shared/Config/Boss")
local HeistConfig = require("@game/ReplicatedStorage/Shared/Config/Heist")
local Progression = require("@game/ReplicatedStorage/Shared/Config/Progression")
local Species = require("@game/ReplicatedStorage/Shared/Config/Species")
local NumberFormat = require("@game/ReplicatedStorage/Shared/Sim/NumberFormat")
local Profile = require("@game/ReplicatedStorage/Shared/Sim/Profile")
local Net = require("@game/ReplicatedStorage/Shared/Net/Net")
local Registry = require("../Registry")

local Boss = {}

type Fight = {
	model: Model,
	root: BasePart,
	bar: Frame,
	hp: number,
	maxHp: number,
	hits: { [Player]: number },
	order: { Player },
	lastHit: { [Player]: number },
	over: boolean,
}

local fight: Fight? = nil
local random = Random.new()

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	shape: Enum.PartType?,
	material: Enum.Material?
): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Shape = shape or Enum.PartType.Block
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.CFrame = offset
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.Parent = parent
	return p
end

-- A chunky cartoon bandit, built from parts welded to an anchored root.
local function build(at: Vector3, maxHp: number): (Model, BasePart, Frame)
	local model = Instance.new("Model")
	model.Name = "BanditKing"
	local base = CFrame.new(at)
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(7, 10, 5)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CFrame = base * CFrame.new(0, 5, 0)
	root.Parent = model
	model.PrimaryPart = root

	local coat = Color3.fromRGB(70, 40, 90)
	local skin = Color3.fromRGB(235, 180, 130)
	local hat = Color3.fromRGB(40, 28, 22)
	local pieces = {
		part(model, "Body", Vector3.new(7, 6, 5), base * CFrame.new(0, 5, 0), coat),
		part(model, "Belt", Vector3.new(7.2, 1, 5.2), base * CFrame.new(0, 3.2, 0), hat),
		part(
			model,
			"Buckle",
			Vector3.new(1.4, 0.9, 0.4),
			base * CFrame.new(0, 3.2, -2.65),
			Color3.fromRGB(255, 200, 61),
			nil,
			Enum.Material.Neon
		),
		part(model, "LegL", Vector3.new(2.2, 2.4, 2.2), base * CFrame.new(-1.8, 1.2, 0), hat),
		part(model, "LegR", Vector3.new(2.2, 2.4, 2.2), base * CFrame.new(1.8, 1.2, 0), hat),
		part(
			model,
			"ArmL",
			Vector3.new(1.8, 5, 1.8),
			base * CFrame.new(-4.4, 5.5, 0) * CFrame.Angles(0, 0, math.rad(-20)),
			coat
		),
		part(
			model,
			"ArmR",
			Vector3.new(1.8, 5, 1.8),
			base * CFrame.new(4.4, 5.5, 0) * CFrame.Angles(0, 0, math.rad(20)),
			coat
		),
		part(
			model,
			"Head",
			Vector3.new(4.6, 4.6, 4.6),
			base * CFrame.new(0, 10.2, 0),
			skin,
			Enum.PartType.Ball
		),
		part(
			model,
			"Bandana",
			Vector3.new(4.8, 1.8, 4.8),
			base * CFrame.new(0, 9.4, -0.1),
			Color3.fromRGB(226, 70, 58)
		),
		part(
			model,
			"EyeL",
			Vector3.new(0.7, 0.7, 0.3),
			base * CFrame.new(-0.9, 10.9, -2.25),
			Color3.fromRGB(255, 240, 120),
			nil,
			Enum.Material.Neon
		),
		part(
			model,
			"EyeR",
			Vector3.new(0.7, 0.7, 0.3),
			base * CFrame.new(0.9, 10.9, -2.25),
			Color3.fromRGB(255, 240, 120),
			nil,
			Enum.Material.Neon
		),
		part(
			model,
			"Brim",
			Vector3.new(0.5, 9, 9),
			base * CFrame.new(0, 12.4, 0) * CFrame.Angles(0, 0, math.rad(90)),
			hat,
			Enum.PartType.Cylinder
		),
		part(model, "Crown", Vector3.new(4.2, 3, 4.2), base * CFrame.new(0, 14, 0), hat),
		part(
			model,
			"Band",
			Vector3.new(4.4, 0.7, 4.4),
			base * CFrame.new(0, 13, 0),
			Color3.fromRGB(255, 200, 61),
			nil,
			Enum.Material.Neon
		),
	}
	for _, p in pieces do
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = p
		weld.Parent = p
	end
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(180, 110, 255)
	light.Range = 24
	light.Brightness = 2
	light.Parent = root

	-- Name + shared health bar.
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(300, 70)
	gui.StudsOffset = Vector3.new(0, 12, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 400
	gui.Parent = root
	local name = Instance.new("TextLabel")
	name.Size = UDim2.fromScale(1, 0.5)
	name.BackgroundTransparency = 1
	name.Text = "THE BANDIT KING"
	name.TextScaled = true
	name.TextColor3 = Color3.fromRGB(255, 214, 60)
	name.FontFace = Font.fromEnum(Enum.Font.LuckiestGuy)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Parent = name
	name.Parent = gui
	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 0.4)
	back.Position = UDim2.fromScale(0, 0.55)
	back.BackgroundColor3 = Color3.fromRGB(43, 29, 20)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = back
	back.Parent = gui
	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.Size = UDim2.fromScale(1, 1)
	bar.BackgroundColor3 = Color3.fromRGB(226, 70, 58)
	local corner2 = Instance.new("UICorner")
	corner2.CornerRadius = UDim.new(1, 0)
	corner2.Parent = bar
	bar.Parent = back

	model:SetAttribute("Hp", maxHp)
	model:SetAttribute("MaxHp", maxHp)
	model.Parent = Workspace
	return model, root, bar
end

local function zoneCenter(): (Vector3, number)
	local zone = HeistConfig.zone(BossConfig.ZONE) :: HeistConfig.Zone
	return Vector3.new(zone.x, 0, zone.z), zone.radius
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function reward(f: Fight)
	local winners, top = BossConfig.results(f.hits :: any, f.order :: any)
	for _, player in winners do
		local p = player :: Player
		if p.Parent then
			local cash = BossConfig.cashReward(Registry.Ranch.income(p))
			Registry.Wallet.addCash(p, cash, "BanditKing")
			Registry.Wallet.addNuggets(p, BossConfig.REWARD_NUGGETS, "BanditKing")
			Registry.Wheel.addSpins(p, 1, "Bandit King")
			Registry.Progression.giveBoost(p, "Luck", Progression.boosts.bossLuckMinutes, "LUCK POTION")
			Registry.Ui.toast(
				p,
				`Bandit King loot: +{NumberFormat.cash(cash)} and +{BossConfig.REWARD_NUGGETS} Gold Nuggets!`
			)
		end
	end
	local best = top :: Player?
	if best and best.Parent then
		local d = Registry.Data.get(best)
		if d then
			local tier = math.clamp(Profile.bestTier(d) + BossConfig.TOP_CRITTER_BONUS, 5, 38)
			local species = Species.byTier[tier]
			local cid = Registry.Ranch.addCritter(best, { species = species.id, tier = tier, src = "boss" })
			if cid then
				Registry.Ui.reveal(best, { kind = "wheel", species = species.id, tier = tier })
				Registry.Ui.announce(
					`{best.DisplayName} lassoed the Bandit King the most and won a {species.name}!`,
					"golden"
				)
			else
				local cash = BossConfig.cashReward(Registry.Ranch.income(best)) * 3
				Registry.Wallet.addCash(best, cash, "BanditKingTop")
				Registry.Ui.announce(`{best.DisplayName} lassoed the Bandit King the most!`, "golden")
				Registry.Ui.toast(
					best,
					`Top lassoer! Your pens are full, so here's {NumberFormat.cash(cash)} instead.`
				)
			end
		end
	end
	for _, player in Players:GetPlayers() do
		if not table.find(winners, player) and (f.hits[player] or 0) > 0 then
			Registry.Ui.toast(
				player,
				`Lasso him at least {BossConfig.MIN_HITS} times to earn loot next time!`
			)
		end
	end
end

local function finish(f: Fight, defeated: boolean)
	if f.over then
		return
	end
	f.over = true
	local pos = f.root.Position
	if fight == f then
		fight = nil
	end
	Workspace:SetAttribute("BossActive", false)
	if defeated then
		Registry.Ui.fxAll("bossDefeat", 0, pos)
		Registry.Ui.announce("The Bandit King is DEFEATED! Loot for every helper!", "golden")
		local ok, err = pcall(reward :: any, f)
		if not ok then
			warn("[Boss] reward failed:", err)
		end
		-- Topple over, then vanish.
		TweenService:Create(f.root, TweenInfo.new(0.8, Enum.EasingStyle.Bounce), {
			CFrame = f.root.CFrame * CFrame.new(0, -3, 0) * CFrame.Angles(math.rad(85), 0, 0),
		}):Play()
	else
		Registry.Ui.fxAll("bossEscape", 0, pos)
		Registry.Ui.announce("The Bandit King escaped! He'll be back...", "steal")
		TweenService:Create(f.root, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			CFrame = f.root.CFrame + Vector3.new(0, 120, 0),
		}):Play()
	end
	local model = f.model
	task.delay(2.5, function()
		model:Destroy()
	end)
	-- The guards come back out.
	local center, radius = zoneCenter()
	Registry.Heist.stunGuardsNear(center, radius + 40, 0)
end

local function hit(player: Player)
	local f = fight
	local r = rootOf(player)
	if not f or f.over or not r then
		return
	end
	if (r.Position - f.root.Position).Magnitude > BossConfig.HIT_RANGE then
		return
	end
	local t = os.clock()
	if t - (f.lastHit[player] or 0) < BossConfig.HIT_COOLDOWN then
		return
	end
	f.lastHit[player] = t
	if not f.hits[player] then
		table.insert(f.order, player)
	end
	f.hits[player] = (f.hits[player] or 0) + 1
	Registry.Progression.questEvent(player, "boss", 1)
	f.hp -= 1
	f.model:SetAttribute("Hp", f.hp)
	f.bar.Size = UDim2.fromScale(math.max(0, f.hp / f.maxHp), 1)
	Registry.Ui.fxAll("bossHit", player.UserId, f.root.Position)
	if f.hp <= 0 then
		finish(f, true)
	end
end

local function leapLoop(f: Fight)
	local center, radius = zoneCenter()
	while not f.over do
		task.wait(BossConfig.LEAP_EVERY - BossConfig.WARN_SECONDS)
		if f.over then
			return
		end
		local a = random:NextNumber() * math.pi * 2
		local d = random:NextNumber() * radius * 0.6
		local target = center + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d)
		Registry.Ui.fxAll("bossWarn", BossConfig.STOMP_RADIUS, target)
		-- Jump: up, then down onto the target.
		local from = f.root.CFrame
		local landing = target + Vector3.new(0, 5, 0)
		local flat = (landing - from.Position) * Vector3.new(1, 0, 1)
		local look = if flat.Magnitude > 0.5
			then CFrame.lookAt(landing, landing + flat.Unit)
			else CFrame.new(landing) * from.Rotation
		local mid = from:Lerp(look, 0.5) + Vector3.new(0, 18, 0)
		local half = BossConfig.WARN_SECONDS / 2
		TweenService:Create(
			f.root,
			TweenInfo.new(half, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ CFrame = mid }
		):Play()
		task.wait(half)
		if f.over then
			return
		end
		TweenService:Create(
			f.root,
			TweenInfo.new(half, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ CFrame = look }
		):Play()
		task.wait(half)
		if f.over then
			return
		end
		Registry.Ui.fxAll("bossStomp", BossConfig.STOMP_RADIUS, target)
		for _, player in Players:GetPlayers() do
			local r = rootOf(player)
			if r and (r.Position * Vector3.new(1, 0, 1) - target).Magnitude <= BossConfig.STOMP_RADIUS then
				Registry.Steal.stun(player, BossConfig.STOMP_STUN)
			end
		end
	end
end

function Boss.alive(): boolean
	return fight ~= nil and not (fight :: Fight).over
end

-- Starts a fight lasting at most `seconds`. Returns immediately.
function Boss.spawn(seconds: number)
	if fight then
		return
	end
	local center, radius = zoneCenter()
	local maxHp = BossConfig.health(#Players:GetPlayers())
	local model, root, bar = build(center, maxHp)
	local f: Fight = {
		model = model,
		root = root,
		bar = bar,
		hp = maxHp,
		maxHp = maxHp,
		hits = {},
		order = {},
		lastHit = {},
		over = false,
	}
	fight = f
	Workspace:SetAttribute("BossActive", true)
	-- The posse guards hide while the King is in town.
	Registry.Heist.stunGuardsNear(center, radius + 40, seconds)
	Registry.Ui.fxAll("bossSpawn", 0, center)
	task.spawn(leapLoop, f)
	task.delay(seconds, function()
		finish(f, false)
	end)
end

function Boss.init()
	Workspace:SetAttribute("BossActive", false)
end

function Boss.start()
	Net.on("HitBoss", hit)
	Players.PlayerRemoving:Connect(function(player)
		local f = fight
		if f then
			f.lastHit[player] = nil
		end
	end)
end

return Boss
