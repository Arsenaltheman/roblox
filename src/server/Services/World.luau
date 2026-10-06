--!strict
-- Builds the town blockout in code at server start: ground, station, track, 8 ranches, landmarks.
-- This is the playable greybox; Blender meshes replace the pieces later without changing gameplay
-- (gameplay only depends on the named instances and attributes created here).

local Workspace = game:GetService("Workspace")

local Layout = require("@game/ReplicatedStorage/Shared/Config/Layout")
local Palette = require("@game/ReplicatedStorage/Shared/Config/Palette")

local World = {}

local C = Palette.color

type PartProps = {
	name: string?,
	size: Vector3,
	cframe: CFrame,
	color: string,
	material: Enum.Material?,
	shape: Enum.PartType?,
	collide: boolean?,
	parent: Instance,
	transparency: number?,
}

local function part(p: PartProps): Part
	local inst = Instance.new("Part")
	inst.Name = p.name or "Part"
	inst.Anchored = true
	inst.Size = p.size
	inst.CFrame = p.cframe
	inst.Color = C(p.color)
	inst.Material = p.material or Enum.Material.SmoothPlastic
	if p.shape then
		inst.Shape = p.shape
	end
	inst.CanCollide = if p.collide == nil then true else p.collide
	inst.Transparency = p.transparency or 0
	inst.TopSurface = Enum.SurfaceType.Smooth
	inst.BottomSurface = Enum.SurfaceType.Smooth
	inst.CastShadow = p.size.Magnitude > 6
	inst.Parent = p.parent
	return inst
end

local function v3(t: Layout.V3): Vector3
	return Vector3.new(t.x, t.y, t.z)
end

local function label(parent: BasePart, text: string, face: Enum.NormalId, textColor: string?)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.2
	local text_ = Instance.new("TextLabel")
	text_.Name = "Text"
	text_.Size = UDim2.fromScale(1, 1)
	text_.BackgroundTransparency = 1
	text_.FontFace = Font.fromEnum(Enum.Font.LuckiestGuy)
	text_.TextScaled = true
	text_.TextColor3 = C(textColor or "ink")
	text_.Text = text
	text_.Parent = gui
	gui.Parent = parent
end

local function cactus(parent: Instance, at: Vector3, height: number)
	local trunk = part({
		name = "Cactus",
		size = Vector3.new(height, 2.4, 2.4),
		cframe = CFrame.new(at + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		color = "cactus",
		material = Enum.Material.SmoothPlastic,
		shape = Enum.PartType.Cylinder,
		parent = parent,
	})
	trunk.CastShadow = true
	for side = -1, 1, 2 do
		part({
			name = "Arm",
			size = Vector3.new(height * 0.35, 1.5, 1.5),
			cframe = CFrame.new(at + Vector3.new(side * 1.8, height * 0.62, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			color = "cactusDark",
			shape = Enum.PartType.Cylinder,
			parent = parent,
		})
	end
end

local function rock(parent: Instance, at: Vector3, size: number, seed: number)
	part({
		name = "Rock",
		size = Vector3.new(size * 1.4, size, size * 1.1),
		cframe = CFrame.new(at + Vector3.new(0, size * 0.35, 0)) * CFrame.Angles(0, seed, math.rad(8)),
		color = if seed % 2 < 1 then "rock" else "rockDark",
		material = Enum.Material.Slate,
		parent = parent,
	})
end

local function building(parent: Instance, name: string, title: string, at: Vector3, size: Vector3, wall: string)
	local model = Instance.new("Model")
	model.Name = name
	local body = part({
		name = "Body",
		size = size,
		cframe = CFrame.new(at + Vector3.new(0, size.Y / 2, 0)),
		color = wall,
		material = Enum.Material.WoodPlanks,
		parent = model,
	})
	part({
		name = "Roof",
		size = Vector3.new(size.X + 2, 1, size.Z + 2),
		cframe = CFrame.new(at + Vector3.new(0, size.Y + 0.5, 0)),
		color = "woodDark",
		material = Enum.Material.WoodPlanks,
		parent = model,
	})
	local sign = part({
		name = "Sign",
		size = Vector3.new(size.X * 0.8, 3, 0.4),
		cframe = CFrame.new(at + Vector3.new(0, size.Y + 2.5, size.Z / 2 + 0.3)),
		color = "paper",
		parent = model,
	})
	label(sign, title, Enum.NormalId.Front)
	model.PrimaryPart = body
	model.Parent = parent
	return model
end

local function buildGround(root: Instance)
	part({
		name = "Ground",
		size = Vector3.new(900, 2, 900),
		cframe = CFrame.new(0, -1, 75),
		color = "sand",
		material = Enum.Material.Sand,
		parent = root,
	})
	-- Main street
	part({
		name = "Street",
		size = Vector3.new(230, 0.2, 14),
		cframe = CFrame.new(0, 0.1, 75),
		color = "dirt",
		material = Enum.Material.Ground,
		parent = root,
	})
end

local function buildTrack(root: Instance)
	local track = Instance.new("Folder")
	track.Name = "Track"
	local L = Layout.track.length
	local step = 5
	local s = 0
	while s < L do
		local p0, _ = Layout.trackPoint(s)
		local p1, _ = Layout.trackPoint(s + step)
		local a = Vector3.new(p0.x, 0.4, p0.z)
		local b = Vector3.new(p1.x, 0.4, p1.z)
		local mid = (a + b) / 2
		local look = CFrame.lookAt(mid, b)
		-- Sleeper
		part({
			name = "Sleeper",
			size = Vector3.new(7, 0.5, 1.2),
			cframe = look,
			color = "woodDark",
			material = Enum.Material.WoodPlanks,
			collide = false,
			parent = track,
		})
		-- Two rails
		for side = -1, 1, 2 do
			part({
				name = "Rail",
				size = Vector3.new(0.4, 0.5, (b - a).Magnitude + 0.05),
				cframe = look * CFrame.new(side * 2.4, 0.4, 0),
				color = "rail",
				material = Enum.Material.Metal,
				collide = false,
				parent = track,
			})
		end
		s += step
	end
	track.Parent = root
end

local function buildStation(root: Instance)
	local station = Instance.new("Model")
	station.Name = "Station"
	local p = Layout.platform
	local platform = part({
		name = "Platform",
		size = v3(p.size),
		cframe = CFrame.new(v3(p.center)),
		color = "woodLight",
		material = Enum.Material.WoodPlanks,
		parent = station,
	})
	platform:SetAttribute("Platform", true)
	-- Canopy posts + roof
	for x = -50, 50, 25 do
		part({
			name = "Post",
			size = Vector3.new(1, 10, 1),
			cframe = CFrame.new(x, 7, 16),
			color = "woodDark",
			material = Enum.Material.Wood,
			parent = station,
		})
	end
	part({
		name = "Canopy",
		size = Vector3.new(112, 1, 9),
		cframe = CFrame.new(0, 12.5, 14) * CFrame.Angles(math.rad(-6), 0, 0),
		color = "red",
		material = Enum.Material.Fabric,
		parent = station,
	})
	local sign = part({
		name = "Sign",
		size = Vector3.new(36, 5, 0.6),
		cframe = CFrame.new(0, 16, 17.5),
		color = "paper",
		parent = station,
	})
	label(sign, "CRITTER EXPRESS", Enum.NormalId.Front, "red")
	label(sign, "CRITTER EXPRESS", Enum.NormalId.Back, "red")

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(10, 1, 6)
	spawn.CFrame = CFrame.new(v3(Layout.spawn) - Vector3.new(0, 1.5, 0))
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Parent = station
	station.Parent = root
end

local function buildRanch(root: Instance, info: { index: number, center: Layout.V3, facing: number })
	local ranch = Instance.new("Model")
	ranch.Name = "Ranch" .. info.index
	ranch:SetAttribute("Index", info.index)
	ranch:SetAttribute("Owner", 0)
	ranch:SetAttribute("LockedUntil", 0)

	local center = v3(info.center)
	local facing = info.facing
	-- Local frame: +z points out of the gate toward the street.
	local frame = CFrame.new(center) * CFrame.Angles(0, if facing == 1 then 0 else math.pi, 0)
	local half = Layout.ranchSize / 2

	local base = part({
		name = "Base",
		size = Vector3.new(Layout.ranchSize, 0.6, Layout.ranchSize),
		cframe = frame * CFrame.new(0, 0.3, 0),
		color = "sandDark",
		material = Enum.Material.Ground,
		parent = ranch,
	})
	ranch.PrimaryPart = base

	-- Fence with a gate gap at the front (local +z).
	local function fence(x0: number, z0: number, x1: number, z1: number)
		local a = (frame * CFrame.new(x0, 2, z0)).Position
		local b = (frame * CFrame.new(x1, 2, z1)).Position
		part({
			name = "Fence",
			size = Vector3.new(0.6, 2.4, (b - a).Magnitude),
			cframe = CFrame.lookAt((a + b) / 2, b),
			color = "wood",
			material = Enum.Material.WoodPlanks,
			parent = ranch,
		})
	end
	fence(-half, -half, half, -half)
	fence(-half, -half, -half, half)
	fence(half, -half, half, half)
	fence(-half, half, -6, half)
	fence(6, half, half, half)

	-- Gate barrier (shown when locked; theft is refused server-side while locked).
	local gate = part({
		name = "Gate",
		size = Vector3.new(12, 6, 0.4),
		cframe = frame * CFrame.new(0, 3, half),
		color = "red",
		material = Enum.Material.Neon,
		collide = false,
		transparency = 1,
		parent = ranch,
	})
	gate:SetAttribute("Gate", true)

	-- Pens
	local pens = Instance.new("Folder")
	pens.Name = "Pens"
	for i = 1, Layout.maxPens do
		local o = Layout.penOffset(i)
		local pad = part({
			name = "Pen" .. i,
			size = Vector3.new(0.4, 5, 5),
			cframe = frame * CFrame.new(o.x, 0.7, o.z) * CFrame.Angles(0, 0, math.rad(90)),
			color = "woodLight",
			material = Enum.Material.WoodPlanks,
			shape = Enum.PartType.Cylinder,
			parent = pens,
		})
		pad:SetAttribute("Pen", i)
		pad:SetAttribute("Critter", "")
	end
	pens.Parent = ranch

	-- Collect plate (golden) and lock plate (red) by the gate.
	local collect = part({
		name = "CollectPlate",
		size = Vector3.new(6, 0.4, 6),
		cframe = frame * CFrame.new(-11, 0.8, half - 7),
		color = "gold",
		material = Enum.Material.Neon,
		collide = false,
		parent = ranch,
	})
	collect:SetAttribute("CollectPlate", true)
	local lock = part({
		name = "LockPlate",
		size = Vector3.new(5, 0.4, 5),
		cframe = frame * CFrame.new(11, 0.8, half - 7),
		color = "red",
		material = Enum.Material.Neon,
		collide = false,
		parent = ranch,
	})
	lock:SetAttribute("LockPlate", true)

	-- Name sign above the gate.
	for side = -1, 1, 2 do
		part({
			name = "GatePost",
			size = Vector3.new(1, 9, 1),
			cframe = frame * CFrame.new(side * 6.5, 4.5, half),
			color = "woodDark",
			material = Enum.Material.Wood,
			parent = ranch,
		})
	end
	local sign = part({
		name = "Sign",
		size = Vector3.new(14, 3, 0.4),
		cframe = frame * CFrame.new(0, 9.5, half),
		color = "paper",
		parent = ranch,
	})
	label(sign, "OPEN RANCH", Enum.NormalId.Front)
	label(sign, "OPEN RANCH", Enum.NormalId.Back)

	-- Ranch house placeholder (grows with Frontier tier; see Ranch service).
	local house = part({
		name = "House",
		size = Vector3.new(14, 8, 8),
		cframe = frame * CFrame.new(0, 4.6, -half + 6),
		color = "wood",
		material = Enum.Material.WoodPlanks,
		parent = ranch,
	})
	house:SetAttribute("House", true)

	ranch.Parent = root
end

local function buildLandmarks(root: Instance)
	local L = Layout.landmarks
	building(root, "Saloon", "SALOON", v3(L.saloon), Vector3.new(20, 12, 12), "woodLight")
	building(root, "TradingPost", "TRADING POST", v3(L.tradingPost), Vector3.new(20, 11, 12), "wood")
	building(root, "Hatchery", "HATCHERY", v3(L.hatchery), Vector3.new(18, 10, 14), "cream")
	building(root, "Stables", "STABLES", v3(L.stables), Vector3.new(20, 9, 14), "woodDark")
	-- Bandit camp: tents and a fire pit (the PvE stealing tutorial happens here).
	local camp = Instance.new("Model")
	camp.Name = "BanditCamp"
	local c = v3(L.banditCamp)
	for i = 0, 2 do
		local angle = i * math.pi * 2 / 3
		part({
			name = "Tent",
			size = Vector3.new(8, 7, 8),
			cframe = CFrame.new(c + Vector3.new(math.cos(angle) * 12, 3.5, math.sin(angle) * 12)) * CFrame.Angles(0, angle, 0),
			color = "paper",
			material = Enum.Material.Fabric,
			parent = camp,
		})
	end
	local fire = part({
		name = "FirePit",
		size = Vector3.new(1, 5, 5),
		cframe = CFrame.new(c + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		color = "rockDark",
		material = Enum.Material.Slate,
		shape = Enum.PartType.Cylinder,
		parent = camp,
	})
	local flame = Instance.new("Fire")
	flame.Size = 6
	flame.Heat = 8
	flame.Parent = fire
	local pens = Instance.new("Folder")
	pens.Name = "Loot"
	for i = 1, 3 do
		local angle = i * math.pi * 2 / 3 + 0.5
		local pad = part({
			name = "LootPen" .. i,
			size = Vector3.new(0.4, 5, 5),
			cframe = CFrame.new(c + Vector3.new(math.cos(angle) * 6, 0.3, math.sin(angle) * 6)) * CFrame.Angles(0, 0, math.rad(90)),
			color = "woodLight",
			shape = Enum.PartType.Cylinder,
			parent = pens,
		})
		pad:SetAttribute("BanditPen", i)
	end
	pens.Parent = camp
	camp.Parent = root
end

local function buildScenery(root: Instance)
	local scenery = Instance.new("Folder")
	scenery.Name = "Scenery"
	-- Deterministic scatter outside the loop so the town feels like a canyon oasis.
	local seed = 7
	local function rand(): number
		seed = (seed * 69069 + 12345) % 4294967296
		return seed / 4294967296
	end
	for _ = 1, 60 do
		local angle = rand() * math.pi * 2
		local dist = 230 + rand() * 180
		local at = Vector3.new(math.cos(angle) * dist, 0, 75 + math.sin(angle) * dist)
		if rand() < 0.45 then
			cactus(scenery, at, 6 + rand() * 6)
		else
			rock(scenery, at, 4 + rand() * 14, rand() * 6)
		end
	end
	-- Mesas on the horizon
	for i = 1, 8 do
		local angle = i / 8 * math.pi * 2 + 0.2
		local at = Vector3.new(math.cos(angle) * 420, 0, 75 + math.sin(angle) * 420)
		part({
			name = "Mesa",
			size = Vector3.new(90, 40 + (i % 3) * 18, 70),
			cframe = CFrame.new(at + Vector3.new(0, 20, 0)) * CFrame.Angles(0, angle, 0),
			color = if i % 2 == 0 then "rock" else "rockDark",
			material = Enum.Material.Sandstone,
			parent = scenery,
		})
	end
	scenery.Parent = root
end

function World.init()
	local existing = Workspace:FindFirstChild("Town")
	if existing then
		existing:Destroy()
	end
	local town = Instance.new("Folder")
	town.Name = "Town"
	buildGround(town)
	buildTrack(town)
	buildStation(town)
	local ranches = Instance.new("Folder")
	ranches.Name = "Ranches"
	for _, info in Layout.ranches do
		buildRanch(ranches, info)
	end
	ranches.Parent = town
	buildLandmarks(town)
	buildScenery(town)
	town.Parent = Workspace
end

function World.ranchModel(index: number): Model?
	local town = Workspace:FindFirstChild("Town")
	local ranches = town and town:FindFirstChild("Ranches")
	return ranches and ranches:FindFirstChild("Ranch" .. index) :: Model?
end

function World.start() end

return World
