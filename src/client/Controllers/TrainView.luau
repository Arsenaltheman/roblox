--!strict
-- Renders the Critter Express from (epoch, server time): locomotive, 6 cars, cages with critters
-- and price tags, the strongbox car, the Golden Express look. Nothing here is authoritative.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Layout = require("@game/ReplicatedStorage/Shared/Config/Layout")
local Palette = require("@game/ReplicatedStorage/Shared/Config/Palette")
local Rarities = require("@game/ReplicatedStorage/Shared/Config/Rarities")
local Species = require("@game/ReplicatedStorage/Shared/Config/Species")
local TrainConfig = require("@game/ReplicatedStorage/Shared/Config/Train")
local NumberFormat = require("@game/ReplicatedStorage/Shared/Sim/NumberFormat")
local TrainClock = require("@game/ReplicatedStorage/Shared/Sim/TrainClock")
local Net = require("@game/ReplicatedStorage/Shared/Net/Net")
local CritterRig = require("./CritterRig")
local Store = require("../Store")

local C = Palette.color
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"

local TrainView = {}

export type CageInfo = {
	id: number,
	s: string,
	t: number,
	m: string?,
	o: number,
	p: number,
	g: boolean,
}

type Manifest = { cycle: number, cages: { CageInfo }, golden: boolean, strongbox: boolean }

local manifests: { [number]: Manifest } = {}
local sold: { [number]: { [number]: number } } = {}
local folder: Folder
local locomotive: Model
local cars: { Model } = {}
local cageSlots: { [number]: { holder: BasePart, critter: Model?, tag: BillboardGui, key: string } } = {}
local strongbox: Model
local shownCycle = -1

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	if shape then
		p.Shape = shape
	end
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function wheels(model: Model, length: number)
	for _, z in { -length / 2 + 2, length / 2 - 2 } do
		for side = -1, 1, 2 do
			part(model, "Wheel", Vector3.new(0.8, 2.6, 2.6), CFrame.new(side * 2.6, 1.3, z), C("woodDark"), Enum.Material.Metal, Enum.PartType.Cylinder)
			part(model, "Hub", Vector3.new(0.9, 0.8, 0.8), CFrame.new(side * 2.7, 1.3, z), C("brass"), Enum.Material.Metal, Enum.PartType.Cylinder)
		end
	end
end

-- Models are built around the origin facing -Z, then moved every frame with PivotTo.
local function buildLocomotive(): Model
	local m = Instance.new("Model")
	m.Name = "Locomotive"
	local base = part(m, "Base", Vector3.new(6, 1, 13), CFrame.new(0, 2.6, 0), C("iron"), Enum.Material.Metal)
	m.PrimaryPart = base
	part(m, "Boiler", Vector3.new(8, 4.6, 4.6), CFrame.new(0, 5.4, -1.5) * CFrame.Angles(0, math.rad(90), 0), C("red"), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	part(m, "BoilerBand", Vector3.new(0.5, 4.8, 4.8), CFrame.new(0, 5.4, -3.5) * CFrame.Angles(0, math.rad(90), 0), C("brass"), Enum.Material.Metal, Enum.PartType.Cylinder)
	part(m, "Face", Vector3.new(0.4, 4.4, 4.4), CFrame.new(0, 5.4, -5.6) * CFrame.Angles(0, math.rad(90), 0), C("iron"), Enum.Material.Metal, Enum.PartType.Cylinder)
	local lamp = part(m, "Lamp", Vector3.new(1.4, 1.4, 1.4), CFrame.new(0, 6.6, -5.9), Color3.fromRGB(255, 230, 150), Enum.Material.Neon, Enum.PartType.Ball)
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Front
	light.Range = 40
	light.Angle = 50
	light.Brightness = 3
	light.Color = Color3.fromRGB(255, 220, 160)
	light.Parent = lamp
	local stack = part(m, "Stack", Vector3.new(2, 3.2, 2), CFrame.new(0, 9, -3.6), C("iron"), Enum.Material.Metal, Enum.PartType.Cylinder)
	stack.CFrame = CFrame.new(0, 9, -3.6) * CFrame.Angles(0, 0, math.rad(90))
	part(m, "StackTop", Vector3.new(0.8, 3, 3), CFrame.new(0, 10.8, -3.6) * CFrame.Angles(0, 0, math.rad(90)), C("iron"), Enum.Material.Metal, Enum.PartType.Cylinder)
	part(m, "Cab", Vector3.new(6, 5.5, 4.5), CFrame.new(0, 5.8, 4), C("woodDark"), Enum.Material.WoodPlanks)
	part(m, "CabRoof", Vector3.new(7, 0.6, 5.5), CFrame.new(0, 8.8, 4), C("red"))
	part(m, "Cowcatcher", Vector3.new(5.6, 1.6, 2.2), CFrame.new(0, 2, -7.2) * CFrame.Angles(math.rad(25), 0, 0), C("brass"), Enum.Material.Metal)
	wheels(m, 13)
	-- Steam
	local attachment = Instance.new("Attachment")
	attachment.Position = Vector3.new(0, 1.6, 0)
	attachment.Parent = stack
	local smoke = Instance.new("ParticleEmitter")
	smoke.Name = "Smoke"
	smoke.Texture = SMOKE
	smoke.Color = ColorSequence.new(Color3.fromRGB(245, 240, 230))
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 6) })
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1) })
	smoke.Lifetime = NumberRange.new(1.6, 2.6)
	smoke.Speed = NumberRange.new(5, 8)
	smoke.SpreadAngle = Vector2.new(12, 12)
	smoke.Rate = 14
	smoke.Acceleration = Vector3.new(0, 2, 4)
	smoke.Parent = attachment
	-- Golden Express sparkle (enabled only on golden trains)
	local gold = Instance.new("ParticleEmitter")
	gold.Name = "Gold"
	gold.Texture = SPARKLE
	gold.Color = ColorSequence.new(C("gold"))
	gold.LightEmission = 1
	gold.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0) })
	gold.Lifetime = NumberRange.new(0.8, 1.4)
	gold.Speed = NumberRange.new(2, 5)
	gold.SpreadAngle = Vector2.new(180, 180)
	gold.Rate = 0
	gold.Parent = attachment
	m.Parent = folder
	return m
end

local function makeTag(holder: BasePart): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = "Tag"
	gui.Size = UDim2.fromScale(6.5, 2.6)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 5.6, 0)
	gui.MaxDistance = 110
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false
	gui.Adornee = holder
	local frame = Instance.new("Frame")
	frame.Name = "Card"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = C("paper")
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.2, 0)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = C("ink")
	stroke.Parent = frame
	local strip = Instance.new("Frame")
	strip.Name = "Rarity"
	strip.Size = UDim2.fromScale(1, 0.3)
	strip.BackgroundColor3 = Color3.new(1, 1, 1)
	local stripCorner = Instance.new("UICorner")
	stripCorner.CornerRadius = UDim.new(0.4, 0)
	stripCorner.Parent = strip
	strip.Parent = frame
	local function label(name: string, size: UDim2, pos: UDim2, font: Enum.Font, color: Color3, strokeOn: boolean)
		local t = Instance.new("TextLabel")
		t.Name = name
		t.Size = size
		t.Position = pos
		t.BackgroundTransparency = 1
		t.FontFace = Font.fromEnum(font)
		t.TextScaled = true
		t.TextColor3 = color
		t.Text = ""
		if strokeOn then
			local s = Instance.new("UIStroke")
			s.Thickness = 2
			s.Color = C("ink")
			s.Parent = t
		end
		t.Parent = frame
		return t
	end
	label("RarityText", UDim2.fromScale(0.94, 0.3), UDim2.fromScale(0.03, 0), Enum.Font.FredokaOne, Color3.new(1, 1, 1), true)
	label("Name", UDim2.fromScale(0.94, 0.27), UDim2.fromScale(0.03, 0.31), Enum.Font.FredokaOne, C("ink"), false)
	label("Price", UDim2.fromScale(0.94, 0.4), UDim2.fromScale(0.03, 0.58), Enum.Font.LuckiestGuy, Color3.fromRGB(120, 220, 90), true)
	local reserved = label("Reserved", UDim2.fromScale(1.1, 0.42), UDim2.fromScale(-0.05, -0.5), Enum.Font.LuckiestGuy, C("gold"), true)
	reserved.Visible = false
	frame.Parent = gui
	gui.Parent = holder
	return gui
end

local function buildCar(index: number): Model
	local m = Instance.new("Model")
	m.Name = "Car" .. index
	local base = part(m, "Base", Vector3.new(6, 1, 13.5), CFrame.new(0, 2.6, 0), C("woodDark"), Enum.Material.WoodPlanks)
	m.PrimaryPart = base
	part(m, "Trim", Vector3.new(6.2, 0.4, 13.7), CFrame.new(0, 3.2, 0), C("red"))
	wheels(m, 13.5)
	-- Two cages per car (rear = first id, front = second id), facing the platform (+Z side in world;
	-- cars face -Z locally... cage bars on all sides).
	for side = 0, 1 do
		local z = if side == 0 then 3.5 else -3.5
		local floor = part(m, "CageFloor", Vector3.new(5, 0.3, 5.6), CFrame.new(0, 3.3, z), C("woodLight"), Enum.Material.WoodPlanks)
		for _, x in { -2.4, 2.4 } do
			for _, zz in { -2.7, 2.7 } do
				part(m, "Bar", Vector3.new(0.3, 5, 0.3), CFrame.new(x, 5.8, z + zz), C("iron"), Enum.Material.Metal)
			end
		end
		part(m, "CageRoof", Vector3.new(5.2, 0.4, 5.8), CFrame.new(0, 8.4, z), C("iron"), Enum.Material.Metal)
		local cageId = (index - 1) * 2 + side + 1
		local holder = part(m, "CageHolder" .. cageId, Vector3.new(0.2, 0.2, 0.2), CFrame.new(0, 3.5, z), Color3.new(), nil)
		holder.Transparency = 1
		local tag = makeTag(holder)
		cageSlots[cageId] = { holder = holder, critter = nil, tag = tag, key = "" }
		floor:SetAttribute("CageId", cageId)
	end
	m.Parent = folder
	return m
end

local function buildStrongbox(): Model
	local m = Instance.new("Model")
	m.Name = "Strongbox"
	local box = part(m, "Box", Vector3.new(4.4, 3.2, 3.4), CFrame.new(0, 5.2, 0), C("iron"), Enum.Material.Metal)
	m.PrimaryPart = box
	part(m, "Lid", Vector3.new(4.6, 0.8, 3.6), CFrame.new(0, 7, 0), C("brass"), Enum.Material.Metal)
	part(m, "Lock", Vector3.new(1, 1.2, 0.4), CFrame.new(0, 5.6, -1.8), C("gold"), Enum.Material.Neon)
	local glow = Instance.new("PointLight")
	glow.Color = C("gold")
	glow.Range = 14
	glow.Brightness = 2
	glow.Parent = box
	m.Parent = nil
	return m
end

-- Where along the loop the locomotive is.
local function locomotiveS(state: TrainClock.State): number
	local stop = Layout.stationStop
	local L = Layout.track.length
	if state.phase == "arriving" then
		local p = state.progress
		local eased = 1 - (1 - p) * (1 - p)
		return stop - Layout.arriveDistance * (1 - eased)
	elseif state.phase == "dwelling" then
		return stop
	end
	local p = state.progress
	local eased = p ^ 1.5
	return stop + (L - Layout.arriveDistance) * eased
end

local function placeAt(model: Model, s: number)
	local p, dir = Layout.trackPoint(s)
	local pos = Vector3.new(p.x, 0, p.z)
	local look = Vector3.new(dir.x, 0, dir.z)
	model:PivotTo(CFrame.lookAt(pos, pos + look))
end

local function updateTag(slot: any, cage: CageInfo?, cycle: number)
	local tag = slot.tag
	local card = tag:FindFirstChild("Card") :: Frame
	if not cage then
		tag.Enabled = false
		return
	end
	local mine = Players.LocalPlayer.UserId
	local isSold = sold[cycle] and sold[cycle][cage.id]
	tag.Enabled = not isSold
	local rarity = Rarities.forTier(cage.t)
	local color = C(rarity.color);
	(card:FindFirstChild("Rarity") :: Frame).BackgroundColor3 = color
	local rarityText = card:FindFirstChild("RarityText") :: TextLabel
	rarityText.Text = rarity.name .. (if cage.m then "  " .. string.upper(cage.m) else "")
	;(card:FindFirstChild("Name") :: TextLabel).Text = Species.byId[cage.s].name
	;(card:FindFirstChild("Price") :: TextLabel).Text = NumberFormat.cash(cage.p)
	local reserved = card:FindFirstChild("Reserved") :: TextLabel
	if cage.o == mine then
		reserved.Visible = true
		reserved.Text = if cage.g then "★ GOLDEN TICKET ★" else "RESERVED FOR YOU"
	elseif cage.o ~= 0 then
		reserved.Visible = true
		reserved.Text = "RESERVED"
		reserved.TextColor3 = C("paper")
	else
		reserved.Visible = false
	end
	if cage.o == mine then
		reserved.TextColor3 = C("gold")
	end
	-- Rarities you aren't active long enough for show a lock.
	local need = Rarities.byId[rarity.id].minActiveMinutes
	if need > 0 and Store.activeMinutes() < need then
		(card:FindFirstChild("Price") :: TextLabel).Text = `🔒 {need} min`
	end
end

local function fillCages(cycle: number)
	local manifest = manifests[cycle]
	local quality = Store.quality()
	for cageId, slot in cageSlots do
		local cage = manifest and manifest.cages[cageId]
		local isSold = cage and sold[cycle] and sold[cycle][cage.id]
		local key = if cage and not isSold then `{cycle}:{cage.s}:{cage.m or ""}` else ""
		if key ~= slot.key then
			slot.key = key
			if slot.critter then
				slot.critter:Destroy()
				slot.critter = nil
			end
			if cage and not isSold then
				local critter = CritterRig.build(cage.s, cage.t, cage.m, quality, 2.2)
				critter.Parent = slot.holder.Parent
				slot.critter = critter
			end
		end
		updateTag(slot, if isSold then nil else cage, cycle)
	end
	local golden = manifest ~= nil and manifest.golden
	local gold = locomotive:FindFirstChild("Gold", true) :: ParticleEmitter?
	if gold then
		gold.Rate = if golden then 40 else 0
	end
	for _, d in locomotive:GetDescendants() do
		if d:IsA("BasePart") and (d.Name == "Boiler" or d.Name == "CabRoof") then
			d.Color = if golden then C("gold") else C("red")
			d.Material = if golden then Enum.Material.Foil else Enum.Material.SmoothPlastic
		end
	end
	-- Strongbox rides on the last car on strongbox trains.
	if manifest and manifest.strongbox then
		strongbox.Parent = cars[#cars]
	else
		strongbox.Parent = nil
	end
end

function TrainView.manifest(cycle: number): Manifest?
	return manifests[cycle]
end

function TrainView.isSold(cycle: number, cageId: number): boolean
	return sold[cycle] ~= nil and sold[cycle][cageId] ~= nil
end

function TrainView.cageWorldPosition(cageId: number): Vector3?
	local slot = cageSlots[cageId]
	return if slot then slot.holder.Position else nil
end

function TrainView.strongboxPosition(): Vector3?
	if strongbox.Parent then
		return (strongbox.PrimaryPart :: BasePart).Position
	end
	return nil
end

function TrainView.init()
	folder = Instance.new("Folder")
	folder.Name = "TrainView"
	folder.Parent = Workspace
	locomotive = buildLocomotive()
	for i = 1, TrainConfig.cars do
		table.insert(cars, buildCar(i))
	end
	strongbox = buildStrongbox()
end

function TrainView.start()
	Net.listen("TrainManifest", function(cycle: number, cages: { CageInfo }, golden: boolean, hasStrongbox: boolean)
		manifests[cycle] = { cycle = cycle, cages = cages, golden = golden, strongbox = hasStrongbox }
		sold[cycle] = sold[cycle] or {}
		manifests[cycle - 3] = nil
		sold[cycle - 3] = nil
		if cycle == shownCycle then
			fillCages(cycle)
		end
	end)
	Net.listen("CageSold", function(cycle: number, cageId: number, buyer: number)
		sold[cycle] = sold[cycle] or {}
		sold[cycle][cageId] = buyer
		if cycle == shownCycle then
			fillCages(cycle)
		end
	end)

	RunService.RenderStepped:Connect(function()
		local epoch = Workspace:GetAttribute("TrainEpoch") :: number?
		if not epoch then
			return
		end
		local t = Workspace:GetServerTimeNow()
		local state = TrainClock.at(epoch, t)
		-- Show the next train's cages once the current train has looped out of sight.
		local displayCycle = state.cycle
		if state.phase == "departing" and state.progress > 0.45 then
			displayCycle = state.cycle + 1
		end
		if displayCycle ~= shownCycle then
			shownCycle = displayCycle
			fillCages(displayCycle)
		end
		Store.trainCycle(state.cycle)
		local s = locomotiveS(state)
		placeAt(locomotive, s)
		for i, car in cars do
			placeAt(car, s - i * Layout.carSpacing)
		end
		-- Idle bob for caged critters.
		for cageId, slot in cageSlots do
			local critter = slot.critter
			if critter then
				local r = (critter:GetAttribute("Radius") :: number?) or 1
				critter:PivotTo(CritterRig.pose(slot.holder.CFrame, t, cageId, r))
				CritterRig.updateRainbow(critter, t)
			end
		end
		local smoke = locomotive:FindFirstChild("Smoke", true) :: ParticleEmitter?
		if smoke then
			smoke.Rate = if state.phase == "dwelling" then 6 else 18
		end
	end)
end

return TrainView
