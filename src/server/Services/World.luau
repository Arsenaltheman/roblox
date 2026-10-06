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
			cframe = CFrame.new(at + Vector3.new(side * 1.8, height * 0.62, 0))
				* CFrame.Angles(0, 0, math.rad(90)),
			color = "cactusDark",
			shape = Enum.PartType.Cylinder,
			parent = parent,
		})
	end
end

local function building(
	parent: Instance,
	name: string,
	title: string,
	at: Vector3,
	size: Vector3,
	wall: string
)
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

-- Deterministic random numbers so every server builds the same map.
local function rng(seed: number): () -> number
	local state = seed
	return function()
		state = (state * 69069 + 12345) % 4294967296
		return state / 4294967296
	end
end

-- Real Roblox Terrain instead of plastic slabs: textured sand, a packed-dirt street, rolling dunes,
-- a ring of layered sandstone cliffs, an oasis pond and 3D clouds.
local function buildTerrain()
	local terrain = Workspace.Terrain
	terrain:Clear()
	-- Base sand layer, top at y = 0.
	terrain:FillBlock(CFrame.new(0, -6, 75), Vector3.new(1200, 12, 1200), Enum.Material.Sand)
	-- Main street and the area around the station: packed dirt, so paths read at a glance.
	terrain:FillBlock(CFrame.new(0, -2, 75), Vector3.new(232, 4, 16), Enum.Material.Ground)
	terrain:FillBlock(CFrame.new(0, -2, 14), Vector3.new(124, 4, 20), Enum.Material.Ground)
	-- Dirt aprons in front of the landmark buildings.
	for _, at: Layout.V3 in Layout.landmarks :: { [string]: Layout.V3 } do
		terrain:FillBlock(CFrame.new(at.x, -2, at.z), Vector3.new(30, 4, 24), Enum.Material.Ground)
	end

	local rand = rng(11)
	-- Rolling dunes between the town and the cliffs (kept clear of the track loop).
	for _ = 1, 70 do
		local angle = rand() * math.pi * 2
		local dist = 250 + rand() * 120
		local radius = 18 + rand() * 30
		local at = Vector3.new(math.cos(angle) * dist, -radius * 0.7, 75 + math.sin(angle) * dist)
		terrain:FillBall(at, radius, Enum.Material.Sand)
	end
	-- Canyon cliffs: stacked, slightly offset blocks with alternating rock layers (strata), so the
	-- horizon has the striped mesas of the Wild West.
	for i = 1, 30 do
		local angle = i / 30 * math.pi * 2 + rand() * 0.08
		local dist = 400 + rand() * 60
		local center = Vector3.new(math.cos(angle) * dist, 0, 75 + math.sin(angle) * dist)
		local height = 50 + rand() * 60
		local width = 70 + rand() * 40
		local layers = math.floor(height / 12)
		for layer = 0, layers do
			local y = layer * 12
			local shrink = 1 - layer / (layers + 3) * 0.5
			local material = if layer % 3 == 2 then Enum.Material.Rock else Enum.Material.Sandstone
			terrain:FillBlock(
				CFrame.new(center + Vector3.new(0, y + 6, 0)) * CFrame.Angles(0, angle + rand() * 0.3, 0),
				Vector3.new(width * shrink, 12, 50 * shrink),
				material
			)
		end
		-- Rubble at the cliff foot.
		for _ = 1, 3 do
			local off = Vector3.new((rand() - 0.5) * width, 0, (rand() - 0.5) * 40)
			terrain:FillBall(center + off, 6 + rand() * 8, Enum.Material.Rock)
		end
	end
	-- Natural rock outcrops scattered in the desert.
	for _ = 1, 26 do
		local angle = rand() * math.pi * 2
		local dist = 220 + rand() * 150
		local at = Vector3.new(math.cos(angle) * dist, 0, 75 + math.sin(angle) * dist)
		terrain:FillBall(at, 4 + rand() * 7, Enum.Material.Rock)
		terrain:FillBall(at + Vector3.new(4, -1, 3), 3 + rand() * 4, Enum.Material.Sandstone)
	end
	-- Oasis pond with grass around it, north of the station (outside the train loop).
	local pond = Vector3.new(70, 0, -120)
	terrain:FillCylinder(CFrame.new(pond + Vector3.new(0, -1, 0)), 3, 34, Enum.Material.LeafyGrass)
	terrain:FillCylinder(CFrame.new(pond + Vector3.new(0, -1.5, 0)), 4, 24, Enum.Material.Water)
	terrain:FillCylinder(CFrame.new(pond + Vector3.new(0, -5, 0)), 4, 24, Enum.Material.Mud)
	for _ = 1, 12 do
		local a = rand() * math.pi * 2
		local d = 26 + rand() * 14
		terrain:FillBall(
			pond + Vector3.new(math.cos(a) * d, -2, math.sin(a) * d),
			4 + rand() * 3,
			Enum.Material.Grass
		)
	end
	-- Sky: soft volumetric clouds.
	local clouds = terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	clouds.Cover = 0.55
	clouds.Density = 0.6
	clouds.Color = Color3.fromRGB(255, 236, 214)
	clouds.Parent = terrain
end

local function buildGround(root: Instance)
	buildTerrain()
	-- An invisible floor just under the terrain surface keeps physics stable if terrain ever fails.
	part({
		name = "SafetyFloor",
		size = Vector3.new(900, 2, 900),
		cframe = CFrame.new(0, -3, 75),
		color = "sand",
		transparency = 1,
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
			cframe = CFrame.new(c + Vector3.new(math.cos(angle) * 12, 3.5, math.sin(angle) * 12))
				* CFrame.Angles(0, angle, 0),
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
			cframe = CFrame.new(c + Vector3.new(math.cos(angle) * 6, 0.3, math.sin(angle) * 6))
				* CFrame.Angles(0, 0, math.rad(90)),
			color = "woodLight",
			shape = Enum.PartType.Cylinder,
			parent = pens,
		})
		pad:SetAttribute("BanditPen", i)
	end
	pens.Parent = camp
	camp.Parent = root
end

-- Small wooden props so the town looks lived-in.
local function barrel(parent: Instance, at: Vector3)
	part({
		name = "Barrel",
		size = Vector3.new(3.2, 2.6, 2.6),
		cframe = CFrame.new(at + Vector3.new(0, 1.6, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		color = "wood",
		material = Enum.Material.WoodPlanks,
		shape = Enum.PartType.Cylinder,
		parent = parent,
	})
	for _, y in { 0.5, 2.7 } do
		part({
			name = "Hoop",
			size = Vector3.new(0.3, 2.75, 2.75),
			cframe = CFrame.new(at + Vector3.new(0, y, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			color = "iron",
			material = Enum.Material.Metal,
			shape = Enum.PartType.Cylinder,
			collide = false,
			parent = parent,
		})
	end
end

local function crate(parent: Instance, at: Vector3, size: number, turn: number)
	part({
		name = "Crate",
		size = Vector3.new(size, size, size),
		cframe = CFrame.new(at + Vector3.new(0, size / 2, 0)) * CFrame.Angles(0, turn, 0),
		color = "woodLight",
		material = Enum.Material.WoodPlanks,
		parent = parent,
	})
end

local function hayBale(parent: Instance, at: Vector3, turn: number)
	part({
		name = "HayBale",
		size = Vector3.new(4, 2.4, 2.4),
		cframe = CFrame.new(at + Vector3.new(0, 1.2, 0)) * CFrame.Angles(0, turn, 0),
		color = "gold",
		material = Enum.Material.Grass,
		parent = parent,
	})
end

-- Lantern post with a warm light (it glows at golden hour).
local function lantern(parent: Instance, at: Vector3)
	part({
		name = "LanternPost",
		size = Vector3.new(0.6, 9, 0.6),
		cframe = CFrame.new(at + Vector3.new(0, 4.5, 0)),
		color = "woodDark",
		material = Enum.Material.Wood,
		parent = parent,
	})
	part({
		name = "LanternArm",
		size = Vector3.new(2, 0.4, 0.4),
		cframe = CFrame.new(at + Vector3.new(0.9, 8.8, 0)),
		color = "woodDark",
		material = Enum.Material.Wood,
		collide = false,
		parent = parent,
	})
	local glass = part({
		name = "Lantern",
		size = Vector3.new(0.9, 1.2, 0.9),
		cframe = CFrame.new(at + Vector3.new(1.7, 8, 0)),
		color = "gold",
		material = Enum.Material.Neon,
		collide = false,
		parent = parent,
	})
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 190, 110)
	light.Range = 18
	light.Brightness = 1.4
	light.Shadows = false
	light.Parent = glass
end

local function buildScenery(root: Instance)
	local scenery = Instance.new("Folder")
	scenery.Name = "Scenery"
	local rand = rng(7)
	-- Cacti dotted through the desert outside the loop.
	for _ = 1, 45 do
		local angle = rand() * math.pi * 2
		local dist = 220 + rand() * 160
		cactus(scenery, Vector3.new(math.cos(angle) * dist, 0, 75 + math.sin(angle) * dist), 6 + rand() * 7)
	end
	-- Lantern posts along both sides of the main street and the platform.
	for x = -105, 105, 30 do
		lantern(scenery, Vector3.new(x, 0, 66))
		lantern(scenery, Vector3.new(x + 15, 0, 84))
	end
	-- Clutter by each landmark building: barrels, crates, hay.
	for name, at: Layout.V3 in Layout.landmarks :: { [string]: Layout.V3 } do
		local base = Vector3.new(at.x, 0, at.z)
		if name ~= "banditCamp" then
			barrel(scenery, base + Vector3.new(-12, 0, 9))
			barrel(scenery, base + Vector3.new(-9.5, 0, 10))
			crate(scenery, base + Vector3.new(12, 0, 9), 3, rand())
			crate(scenery, base + Vector3.new(12.5, 3, 9), 2.2, rand())
			hayBale(scenery, base + Vector3.new(9, 0, 12), rand() * 3)
		end
	end
	-- Freight on the platform ends.
	for _, x in { -52, 52 } do
		crate(scenery, Vector3.new(x, 2, 8), 3, 0.2)
		crate(scenery, Vector3.new(x + 3.5, 2, 9), 2.4, 0.6)
		barrel(scenery, Vector3.new(x - 3, 2, 10))
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
