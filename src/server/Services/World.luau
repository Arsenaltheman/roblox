--!strict
-- Builds the town blockout in code at server start: ground, station, track, 8 ranches, landmarks.
-- This is the playable greybox; Blender meshes replace the pieces later without changing gameplay
-- (gameplay only depends on the named instances and attributes created here).

local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local HeistConfig = require("@game/ReplicatedStorage/Shared/Config/Heist")
local Layout = require("@game/ReplicatedStorage/Shared/Config/Layout")
local Palette = require("@game/ReplicatedStorage/Shared/Config/Palette")
local Rarities = require("@game/ReplicatedStorage/Shared/Config/Rarities")

local World = {}

local C = Palette.color

-- Where the terrain surface renders (the sand fill tops out ~1 stud under y = 0). Free-standing props
-- start here so they sit IN the sand instead of hovering a stud above it.
local GROUND = -1

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
		cframe = CFrame.new(at + Vector3.new(0, height / 2 - 1.5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
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
			cframe = CFrame.new(at + Vector3.new(side * 1.8, height * 0.62 - 1.5, 0))
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
	-- The walls run 1.5 studs below y = 0 so no sliver of sky shows under them.
	local body = part({
		name = "Body",
		size = size + Vector3.new(0, 1.5, 0),
		cframe = CFrame.new(at + Vector3.new(0, size.Y / 2 - 0.75, 0)),
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
	-- Base sand layer. Its surface sits ~1 stud BELOW y = 0 so the town's floors, pens and plates
	-- (built at y = 0) always show on top of it instead of being swallowed.
	terrain:FillBlock(CFrame.new(0, -7, 75), Vector3.new(960, 12, 960), Enum.Material.Sand)
	-- Main street and the area around the station: packed dirt, so paths read at a glance.
	terrain:FillBlock(CFrame.new(0, -3, 75), Vector3.new(232, 4, 16), Enum.Material.Ground)
	terrain:FillBlock(CFrame.new(0, -3, 14), Vector3.new(124, 4, 20), Enum.Material.Ground)
	-- Dirt aprons in front of the landmark buildings.
	for _, at: Layout.V3 in Layout.landmarks :: { [string]: Layout.V3 } do
		terrain:FillBlock(CFrame.new(at.x, -3, at.z), Vector3.new(30, 4, 24), Enum.Material.Ground)
	end

	local rand = rng(11)
	-- Rolling dunes between the town and the cliffs (kept clear of the track loop).
	for _ = 1, 70 do
		local angle = rand() * math.pi * 2
		local dist = 250 + rand() * 120
		local radius = 18 + rand() * 30
		local at = Vector3.new(math.cos(angle) * dist, -radius * 0.7, 75 + math.sin(angle) * dist)
		if not HeistConfig.insideAnyZone(at.X, at.Z, radius + 12) then
			terrain:FillBall(at, radius, Enum.Material.Sand)
		end
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
		if not HeistConfig.insideAnyZone(at.X, at.Z, 14) then
			terrain:FillBall(at, 4 + rand() * 7, Enum.Material.Rock)
			terrain:FillBall(at + Vector3.new(4, -1, 3), 3 + rand() * 4, Enum.Material.Sandstone)
		end
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
		cframe = CFrame.new(0, -2.2, 75),
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
			-- A raised pedestal (cylinder on its side: X is its height) so critters sit on display.
			size = Vector3.new(1.6, 5.2, 5.2),
			cframe = frame * CFrame.new(o.x, 0.8, o.z) * CFrame.Angles(0, 0, math.rad(90)),
			color = "paper",
			material = Enum.Material.Sandstone,
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
			cframe = CFrame.new(c + Vector3.new(math.cos(angle) * 12, 3, math.sin(angle) * 12))
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

-- Lantern post with a warm light. The glass is tagged "Lantern": the client's Ambience controller
-- fades the light up as the day cycle drifts toward dusk. The arm points along the local +x axis.
local function lantern(parent: Instance, at: Vector3, yaw: number?)
	local frame = CFrame.new(at) * CFrame.Angles(0, yaw or 0, 0)
	part({
		name = "LanternPost",
		size = Vector3.new(0.6, 9, 0.6),
		cframe = frame * CFrame.new(0, 4.5, 0),
		color = "woodDark",
		material = Enum.Material.Wood,
		parent = parent,
	})
	part({
		name = "LanternArm",
		size = Vector3.new(2, 0.4, 0.4),
		cframe = frame * CFrame.new(0.9, 8.8, 0),
		color = "woodDark",
		material = Enum.Material.Wood,
		collide = false,
		parent = parent,
	})
	local glass = part({
		name = "Lantern",
		size = Vector3.new(0.9, 1.2, 0.9),
		cframe = frame * CFrame.new(1.7, 8, 0),
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
	CollectionService:AddTag(glass, "Lantern")
end

-- A thin part spanning two points (rails, ropes, braces). Never pass two points straight above
-- each other (lookAt has no sideways axis then).
local function span(
	parent: Instance,
	name: string,
	a: Vector3,
	b: Vector3,
	thickness: number,
	color: string,
	material: Enum.Material?,
	collide: boolean?
): Part
	return part({
		name = name,
		size = Vector3.new(thickness, thickness, (b - a).Magnitude),
		cframe = CFrame.lookAt((a + b) / 2, b),
		color = color,
		material = material or Enum.Material.Wood,
		collide = collide,
		parent = parent,
	})
end

local BONE = "#EFE5CF"
local GHOST_WOOD = "#5E5558"
local GHOST_GREEN = Color3.fromRGB(120, 255, 190)

-- Bleached cow skull lying in the sand (non-colliding: purely decoration you can walk over).
local function cowSkull(parent: Instance, at: Vector3, turn: number)
	local frame = CFrame.new(at) * CFrame.Angles(0, turn, 0)
	part({
		name = "Skull",
		size = Vector3.new(1.6, 1.1, 1.5),
		cframe = frame * CFrame.new(0, 0.45, 0) * CFrame.Angles(math.rad(-10), 0, 0),
		color = BONE,
		collide = false,
		parent = parent,
	})
	part({
		name = "Snout",
		size = Vector3.new(1, 0.7, 1.5),
		cframe = frame * CFrame.new(0, 0.25, -1.2) * CFrame.Angles(math.rad(-6), 0, 0),
		color = BONE,
		collide = false,
		parent = parent,
	})
	for _, side in { -1, 1 } do
		part({
			name = "Horn",
			size = Vector3.new(2, 0.35, 0.35),
			cframe = frame * CFrame.new(side * 1.5, 0.95, 0.1) * CFrame.Angles(0, 0, side * math.rad(28)),
			color = "#D8C9A8",
			collide = false,
			parent = parent,
		})
	end
end

-- A tall saguaro with two round barrel cacti (one in flower) at its foot.
local function cactusCluster(parent: Instance, at: Vector3, rand: () -> number)
	cactus(parent, at, 6 + rand() * 4)
	for i = 1, 2 do
		local a = rand() * math.pi * 2
		local d = 3 + rand() * 1.5
		local s = 1.6 + rand() * 1.2
		local ball = at + Vector3.new(math.cos(a) * d, s * 0.3, math.sin(a) * d)
		part({
			name = "BarrelCactus",
			size = Vector3.new(s, s, s),
			cframe = CFrame.new(ball),
			color = "cactusDark",
			shape = Enum.PartType.Ball,
			collide = false,
			parent = parent,
		})
		if i == 1 then
			part({
				name = "Flower",
				size = Vector3.new(0.6, 0.6, 0.6),
				cframe = CFrame.new(ball + Vector3.new(0, s * 0.5, 0)),
				color = "#FF7FA6",
				shape = Enum.PartType.Ball,
				collide = false,
				parent = parent,
			})
		end
	end
end

-- Natural sandstone arch made of terrain (two pillars and a lintel), opening along local x.
local function rockArch(terrain: Terrain, at: Vector3, yaw: number, opening: number, height: number)
	local frame = CFrame.new(at) * CFrame.Angles(0, yaw, 0)
	for _, side in { -1, 1 } do
		terrain:FillBlock(
			frame * CFrame.new(side * (opening / 2 + 4), height / 2 - 2, 0),
			Vector3.new(8, height + 4, 9),
			Enum.Material.Sandstone
		)
		terrain:FillBall((frame * CFrame.new(side * (opening / 2 + 6), 0, 2)).Position, 5, Enum.Material.Rock)
	end
	terrain:FillBlock(
		frame * CFrame.new(0, height + 3, 0),
		Vector3.new(opening + 16, 7, 9),
		Enum.Material.Sandstone
	)
	terrain:FillBlock(
		frame * CFrame.new(0, height + 7, 0),
		Vector3.new(opening + 6, 3, 7),
		Enum.Material.Rock
	)
end

-- Rickety plank-and-rope bridge sagging between two points (a few planks are missing).
local function ropeBridge(parent: Instance, a: Vector3, b: Vector3, sag: number, rand: () -> number)
	local function along(t: number): Vector3
		return a:Lerp(b, t) - Vector3.new(0, sag * (1 - (2 * t - 1) ^ 2), 0)
	end
	local side = (b - a).Unit:Cross(Vector3.yAxis).Unit
	local planks = 14
	for i = 1, planks - 1 do
		local t = i / planks
		if i == 1 or i == planks - 1 or rand() > 0.18 then
			local p = along(t)
			part({
				name = "Plank",
				size = Vector3.new(5, 0.3, 1.3),
				cframe = CFrame.lookAt(p, along(t + 0.01))
					* CFrame.Angles(0, 0, math.rad((rand() - 0.5) * 10)),
				color = if i % 3 == 0 then "woodDark" else "wood",
				material = Enum.Material.WoodPlanks,
				parent = parent,
			})
		end
	end
	-- Hand ropes and the ropes under the plank ends, four segments each.
	for _, s in { -2.6, 2.6 } do
		for _, lift in { 2.4, -0.2 } do
			for k = 0, 3 do
				local rope = span(
					parent,
					"Rope",
					along(k / 4) + side * s + Vector3.new(0, lift, 0),
					along((k + 1) / 4) + side * s + Vector3.new(0, lift, 0),
					0.22,
					"#C9A66B",
					Enum.Material.Fabric,
					false
				)
				rope.CastShadow = false
			end
		end
		for _, endPoint in { a, b } do
			part({
				name = "RopePost",
				size = Vector3.new(0.5, 3.6, 0.5),
				cframe = CFrame.new(endPoint + side * s + Vector3.new(0, 1, 0)),
				color = "woodDark",
				material = Enum.Material.Wood,
				parent = parent,
			})
		end
	end
end

-- Mine-cart rails from `a` to `b` on the ground (flat and non-colliding, so they never trip anyone).
local function mineRails(parent: Instance, a: Vector3, b: Vector3)
	local length = (b - a).Magnitude
	local look = CFrame.lookAt(a, b)
	for _, side in { -2.1, 2.1 } do
		part({
			name = "MineRail",
			size = Vector3.new(0.3, 0.3, length),
			cframe = look * CFrame.new(side, 0.45, -length / 2),
			color = "rail",
			material = Enum.Material.Metal,
			collide = false,
			parent = parent,
		})
	end
	for d = 1.2, length, 2.6 do
		part({
			name = "Sleeper",
			size = Vector3.new(5.4, 0.3, 0.9),
			cframe = look * CFrame.new(0, 0.2, -d),
			color = "woodDark",
			material = Enum.Material.WoodPlanks,
			collide = false,
			parent = parent,
		})
	end
end

-- Rusty ore cart heaped with gold. `cf` is on the ground; the cart runs along local z.
local function mineCart(parent: Instance, cf: CFrame)
	part({
		name = "Cart",
		size = Vector3.new(4, 2.4, 5.4),
		cframe = cf * CFrame.new(0, 2.4, 0),
		color = "#7A4A30",
		material = Enum.Material.Metal,
		parent = parent,
	})
	part({
		name = "OreLoad",
		size = Vector3.new(3.4, 1, 4.8),
		cframe = cf * CFrame.new(0, 3.7, 0) * CFrame.Angles(0, 0, math.rad(4)),
		color = "gold",
		material = Enum.Material.Foil,
		collide = false,
		parent = parent,
	})
	for _, x in { -2.1, 2.1 } do
		for _, z in { -1.8, 1.8 } do
			part({
				name = "Wheel",
				size = Vector3.new(0.4, 1.6, 1.6),
				cframe = cf * CFrame.new(x, 0.9, z),
				color = "iron",
				material = Enum.Material.Metal,
				shape = Enum.PartType.Cylinder,
				collide = false,
				parent = parent,
			})
		end
	end
end

-- A clump of glowing gold ore; only some clumps carry a light (lights cost the most on phones).
local function oreCluster(parent: Instance, at: Vector3, rand: () -> number, withLight: boolean)
	local first: Part? = nil
	for _ = 1, 3 do
		local s = 1 + rand() * 1.2
		local chunk = part({
			name = "GlowOre",
			size = Vector3.new(s, s * 0.8, s),
			cframe = CFrame.new(at + Vector3.new((rand() - 0.5) * 3, s * 0.2, (rand() - 0.5) * 3))
				* CFrame.Angles(rand() * 3, rand() * 3, rand() * 3),
			color = "#FFD45A",
			material = Enum.Material.Neon,
			collide = false,
			parent = parent,
		})
		first = first or chunk
	end
	if withLight and first then
		local glow = Instance.new("PointLight")
		glow.Color = Color3.fromRGB(255, 200, 90)
		glow.Range = 12
		glow.Brightness = 1.2
		glow.Parent = first
	end
end

-- Crooked post with a hanging green ghost lantern and a curl of mist. Tagged "FogLantern" so the
-- client can make it flicker (and drop the mist on low quality).
local function fogLantern(parent: Instance, at: Vector3, rand: () -> number)
	local frame = CFrame.new(at)
		* CFrame.Angles(math.rad((rand() - 0.5) * 16), rand() * math.pi * 2, math.rad((rand() - 0.5) * 16))
	part({
		name = "FogPost",
		size = Vector3.new(0.5, 8, 0.5),
		cframe = frame * CFrame.new(0, 3.5, 0),
		color = GHOST_WOOD,
		material = Enum.Material.Wood,
		collide = false,
		parent = parent,
	})
	part({
		name = "FogArm",
		size = Vector3.new(1.8, 0.3, 0.3),
		cframe = frame * CFrame.new(0.8, 7.4, 0),
		color = GHOST_WOOD,
		material = Enum.Material.Wood,
		collide = false,
		parent = parent,
	})
	local glass = part({
		name = "FogLantern",
		size = Vector3.new(0.8, 1.1, 0.8),
		cframe = frame * CFrame.new(1.5, 6.5, 0),
		color = "sky",
		material = Enum.Material.Neon,
		collide = false,
		parent = parent,
	})
	glass.Color = GHOST_GREEN
	local light = Instance.new("PointLight")
	light.Color = GHOST_GREEN
	light.Range = 16
	light.Brightness = 1.2
	light.Shadows = false
	light.Parent = glass
	local mist = Instance.new("ParticleEmitter")
	mist.Name = "FogMist"
	mist.Texture = "rbxasset://textures/particles/smoke_main.dds"
	mist.Color = ColorSequence.new(Color3.fromRGB(170, 230, 205))
	mist.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0.8),
		NumberSequenceKeypoint.new(1, 1),
	})
	mist.Size = NumberSequence.new(5, 9)
	mist.Lifetime = NumberRange.new(4, 6)
	mist.Rate = 1.5
	mist.Speed = NumberRange.new(0.3, 0.8)
	mist.LightInfluence = 0.6
	mist.Parent = glass
	CollectionService:AddTag(glass, "FogLantern")
end

local function gravestone(parent: Instance, at: Vector3, rand: () -> number)
	local frame = CFrame.new(at)
		* CFrame.Angles(math.rad((rand() - 0.5) * 18), (rand() - 0.5) * 0.6, math.rad((rand() - 0.5) * 18))
	if rand() < 0.5 then
		part({
			name = "Gravestone",
			size = Vector3.new(2, 2.8, 0.5),
			cframe = frame * CFrame.new(0, 0.9, 0),
			color = "#8C8A86",
			material = Enum.Material.Slate,
			collide = false,
			parent = parent,
		})
	else
		part({
			name = "GraveCross",
			size = Vector3.new(0.4, 3.2, 0.4),
			cframe = frame * CFrame.new(0, 1, 0),
			color = GHOST_WOOD,
			material = Enum.Material.Wood,
			collide = false,
			parent = parent,
		})
		part({
			name = "GraveCross",
			size = Vector3.new(1.8, 0.4, 0.4),
			cframe = frame * CFrame.new(0, 1.8, 0),
			color = GHOST_WOOD,
			material = Enum.Material.Wood,
			collide = false,
			parent = parent,
		})
	end
end

-- Half-collapsed building: three walls, a broken front and a roof slab that slid off. `cf` is on
-- the ground and its front (the door gap) faces local -z.
local function brokenHouse(parent: Instance, cf: CFrame, rand: () -> number)
	local function wall(size: Vector3, offset: CFrame)
		part({
			name = "Ruin",
			size = size,
			cframe = cf * offset,
			color = GHOST_WOOD,
			material = Enum.Material.WoodPlanks,
			parent = parent,
		})
	end
	wall(Vector3.new(14, 11, 0.8), CFrame.new(0, 4.5, 5))
	wall(Vector3.new(0.8, 11, 10), CFrame.new(-7, 4.5, 0))
	wall(Vector3.new(0.8, 6, 10), CFrame.new(7, 2, 0) * CFrame.Angles(0, 0, math.rad(-6)))
	wall(Vector3.new(6, 9, 0.8), CFrame.new(-4, 3.5, -5))
	part({
		name = "FallenRoof",
		size = Vector3.new(15, 0.6, 11),
		cframe = cf * CFrame.new(1, 6.2, 0) * CFrame.Angles(0, 0, math.rad(-24)),
		color = "#3B3436",
		material = Enum.Material.WoodPlanks,
		parent = parent,
	})
	for _ = 1, 2 do
		part({
			name = "LoosePlank",
			size = Vector3.new(0.5, 0.25, 5),
			cframe = cf
				* CFrame.new(4 + rand() * 4, -0.8, -7 - rand() * 3)
				* CFrame.Angles(0, rand() * 3, math.rad(8)),
			color = GHOST_WOOD,
			material = Enum.Material.WoodPlanks,
			collide = false,
			parent = parent,
		})
	end
end

-- Crooked old church; the steeple leans even further. `cf` is on the ground, door toward local -z.
local function crookedChurch(parent: Instance, cf: CFrame)
	local frame = cf * CFrame.Angles(0, 0, math.rad(4))
	local function piece(name: string, size: Vector3, offset: CFrame, color: string, material: Enum.Material?)
		return part({
			name = name,
			size = size,
			cframe = offset,
			color = color,
			material = material or Enum.Material.WoodPlanks,
			parent = parent,
		})
	end
	piece("Nave", Vector3.new(14, 13, 22), frame * CFrame.new(0, 5.5, 0), GHOST_WOOD)
	for _, s in { -1, 1 } do
		piece(
			"Roof",
			Vector3.new(9.6, 0.8, 23),
			frame * CFrame.new(s * 3.6, 14.9, 0) * CFrame.Angles(0, 0, -s * math.rad(40)),
			"#3B3436"
		)
	end
	local steeple = frame * CFrame.new(0, -1, -11) * CFrame.Angles(math.rad(-3), 0, math.rad(-7))
	piece("Tower", Vector3.new(6, 19, 6), steeple * CFrame.new(0, 9.5, 0), GHOST_WOOD)
	piece(
		"Spire",
		Vector3.new(3.4, 9, 3.4),
		steeple * CFrame.new(0, 23.5, 0) * CFrame.Angles(0, math.rad(45), 0),
		"#3B3436"
	)
	piece("Cross", Vector3.new(0.5, 3.4, 0.5), steeple * CFrame.new(0, 29.6, 0), "iron", Enum.Material.Metal)
	piece("Cross", Vector3.new(2, 0.5, 0.5), steeple * CFrame.new(0, 30.2, 0), "iron", Enum.Material.Metal)
	piece(
		"Door",
		Vector3.new(3.4, 6, 0.3),
		steeple * CFrame.new(0, 3, -3.05),
		"ink",
		Enum.Material.SmoothPlastic
	)
	-- Dim green glow in the side windows: something is home.
	for _, s in { -1, 1 } do
		local window = piece(
			"Window",
			Vector3.new(0.3, 3.4, 1.8),
			frame * CFrame.new(s * 7.05, 6, 2),
			"sky",
			Enum.Material.Neon
		)
		window.Color = Color3.fromRGB(60, 130, 100)
		window.CanCollide = false
	end
end

-- Railway water tower: four legs, a hooped wooden tank with a cap, and a spout toward `spoutDir`.
local function waterTower(parent: Instance, at: Vector3, spoutDir: Vector3)
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			span(
				parent,
				"Leg",
				at + Vector3.new(x * 4.6, -0.5, z * 4.6),
				at + Vector3.new(x * 3.6, 16, z * 3.6),
				1,
				"woodDark"
			)
		end
	end
	local corners = {
		Vector3.new(-4.1, 8, -4.1),
		Vector3.new(4.1, 8, -4.1),
		Vector3.new(4.1, 8, 4.1),
		Vector3.new(-4.1, 8, 4.1),
	}
	for i, p in corners do
		local brace = span(parent, "Brace", at + p, at + corners[i % 4 + 1], 0.5, "woodDark", nil, false)
		brace.CastShadow = false
	end
	part({
		name = "Deck",
		size = Vector3.new(10.5, 0.6, 10.5),
		cframe = CFrame.new(at + Vector3.new(0, 16.2, 0)),
		color = "woodDark",
		material = Enum.Material.WoodPlanks,
		parent = parent,
	})
	part({
		name = "Tank",
		size = Vector3.new(9, 9.6, 9.6),
		cframe = CFrame.new(at + Vector3.new(0, 21, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		color = "wood",
		material = Enum.Material.WoodPlanks,
		shape = Enum.PartType.Cylinder,
		parent = parent,
	})
	for _, y in { 18.4, 23.6 } do
		part({
			name = "Hoop",
			size = Vector3.new(0.4, 9.9, 9.9),
			cframe = CFrame.new(at + Vector3.new(0, y, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			color = "iron",
			material = Enum.Material.Metal,
			shape = Enum.PartType.Cylinder,
			collide = false,
			parent = parent,
		})
	end
	for i, size in { 11, 6 } do
		part({
			name = "Cap",
			size = Vector3.new(1.2, size, size),
			cframe = CFrame.new(at + Vector3.new(0, 25.5 + (i - 1) * 1.2, 0))
				* CFrame.Angles(0, 0, math.rad(90)),
			color = "woodDark",
			material = Enum.Material.WoodPlanks,
			shape = Enum.PartType.Cylinder,
			parent = parent,
		})
	end
	local dir = Vector3.new(spoutDir.X, 0, spoutDir.Z).Unit
	span(
		parent,
		"Spout",
		at + dir * 4.6 + Vector3.new(0, 18.5, 0),
		at + dir * 10 + Vector3.new(0, 14, 0),
		0.8,
		"iron",
		Enum.Material.Metal,
		false
	)
end

-- Farm windmill on a lattice tower. The rotor is its own Model tagged "WindmillRotor" (pivot at the
-- hub, spin axis = pivot's look vector) so clients spin it locally without any server traffic.
local function windmill(parent: Instance, at: Vector3, yaw: number)
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			span(
				parent,
				"Leg",
				at + Vector3.new(x * 4, -0.5, z * 4),
				at + Vector3.new(x * 1, 24, z * 1),
				0.6,
				"iron",
				Enum.Material.Metal
			)
		end
	end
	local ring = {
		Vector3.new(-2.5, 12, -2.5),
		Vector3.new(2.5, 12, -2.5),
		Vector3.new(2.5, 12, 2.5),
		Vector3.new(-2.5, 12, 2.5),
	}
	for i, p in ring do
		local brace =
			span(parent, "Brace", at + p, at + ring[i % 4 + 1], 0.35, "iron", Enum.Material.Metal, false)
		brace.CastShadow = false
	end
	local head = CFrame.new(at + Vector3.new(0, 25, 0)) * CFrame.Angles(0, yaw, 0)
	part({
		name = "Head",
		size = Vector3.new(1.6, 1.6, 3),
		cframe = head,
		color = "iron",
		material = Enum.Material.Metal,
		parent = parent,
	})
	span(
		parent,
		"TailBoom",
		(head * CFrame.new(0, 0, 1.4)).Position,
		(head * CFrame.new(0, 0, 7)).Position,
		0.4,
		"iron",
		Enum.Material.Metal,
		false
	)
	part({
		name = "TailVane",
		size = Vector3.new(0.2, 3, 3.6),
		cframe = head * CFrame.new(0, 0.4, 7.6),
		color = "red",
		material = Enum.Material.Metal,
		collide = false,
		parent = parent,
	})
	local rotor = Instance.new("Model")
	rotor.Name = "WindmillRotor"
	local hub = head * CFrame.new(0, 0, -1.9)
	part({
		name = "Hub",
		size = Vector3.new(0.9, 1.4, 1.4),
		cframe = hub * CFrame.Angles(0, math.rad(90), 0),
		color = "iron",
		material = Enum.Material.Metal,
		shape = Enum.PartType.Cylinder,
		collide = false,
		parent = rotor,
	})
	for k = 0, 7 do
		local blade = part({
			name = "Blade",
			size = Vector3.new(1.3, 4.6, 0.15),
			cframe = hub
				* CFrame.Angles(0, 0, k * math.pi / 4)
				* CFrame.new(0, 3.4, 0)
				* CFrame.Angles(0, math.rad(22), 0),
			color = "cream",
			material = Enum.Material.Metal,
			collide = false,
			parent = rotor,
		})
		blade.CastShadow = true
	end
	rotor.WorldPivot = hub
	rotor.Parent = parent
	CollectionService:AddTag(rotor, "WindmillRotor")
	-- Stock trough at the foot.
	part({
		name = "Trough",
		size = Vector3.new(6, 1.8, 2.6),
		cframe = CFrame.new(at + Vector3.new(5.5, 0.4, 0)),
		color = "wood",
		material = Enum.Material.WoodPlanks,
		parent = parent,
	})
	local water = part({
		name = "TroughWater",
		size = Vector3.new(5.4, 0.2, 2),
		cframe = CFrame.new(at + Vector3.new(5.5, 1.25, 0)),
		color = "skyDeep",
		material = Enum.Material.Glass,
		collide = false,
		parent = parent,
	})
	water.Transparency = 0.2
	water.Reflectance = 0.15
end

-- Split-rail fence between two ground points: posts every ~6.5 studs and two long rails.
local function railFence(parent: Instance, a: Vector3, b: Vector3)
	local count = math.max(2, math.floor((b - a).Magnitude / 6.5) + 1)
	for i = 0, count - 1 do
		part({
			name = "FencePost",
			size = Vector3.new(0.7, 4, 0.7),
			cframe = CFrame.new(a:Lerp(b, i / (count - 1)) + Vector3.new(0, 1.4, 0)),
			color = "woodDark",
			material = Enum.Material.Wood,
			parent = parent,
		})
	end
	for _, y in { 1.4, 2.8 } do
		local rail = part({
			name = "FenceRail",
			size = Vector3.new(0.35, 0.45, (b - a).Magnitude),
			cframe = CFrame.lookAt((a + b) / 2 + Vector3.new(0, y, 0), b + Vector3.new(0, y, 0)),
			color = "wood",
			material = Enum.Material.WoodPlanks,
			parent = parent,
		})
		rail.CastShadow = true
	end
end

-- Signpost with one arrow per heist zone, pointing at it, with the distance in studs.
local function signpost(parent: Instance, at: Vector3)
	part({
		name = "SignPost",
		size = Vector3.new(0.8, 14.5, 0.8),
		cframe = CFrame.new(at + Vector3.new(0, 6.75, 0)),
		color = "woodDark",
		material = Enum.Material.Wood,
		parent = parent,
	})
	for i, zone in HeistConfig.zones do
		local flat = Vector3.new(zone.x - at.X, 0, zone.z - at.Z)
		local dir = flat.Unit
		local distance = math.floor(flat.Magnitude / 10 + 0.5) * 10
		-- Arms start above head height, so they never clip a player walking past.
		local center = at + Vector3.new(0, 13 - (i - 1) * 1.9, 0) + dir * 4
		local cf = CFrame.lookAt(center, center + dir)
		local ghost = zone.theme == "ghost"
		local board = part({
			name = "Arrow",
			size = Vector3.new(0.3, 1.7, 6.4),
			cframe = cf,
			color = if ghost then "iron" else "paper",
			collide = false,
			parent = parent,
		})
		-- A square turned 45 degrees, half sticking out of the board end, makes the arrow tip.
		part({
			name = "ArrowTip",
			size = Vector3.new(0.28, 1.2, 1.2),
			cframe = cf * CFrame.new(0, 0, -3.2) * CFrame.Angles(math.rad(45), 0, 0),
			color = if ghost then "iron" else "paper",
			collide = false,
			parent = parent,
		})
		for _, face in { Enum.NormalId.Left, Enum.NormalId.Right } do
			local gui = Instance.new("SurfaceGui")
			gui.Face = face
			gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			gui.PixelsPerStud = 40
			gui.LightInfluence = 0.2
			local name = Instance.new("TextLabel")
			name.Size = UDim2.fromScale(1, 0.62)
			name.Position = UDim2.fromScale(0, 0.04)
			name.BackgroundTransparency = 1
			name.FontFace = Font.fromEnum(Enum.Font.LuckiestGuy)
			name.TextScaled = true
			name.Text = string.upper(zone.name)
			name.TextColor3 = if ghost then Color3.fromRGB(150, 255, 210) else C("red")
			name.Parent = gui
			local far = Instance.new("TextLabel")
			far.Size = UDim2.fromScale(1, 0.32)
			far.Position = UDim2.fromScale(0, 0.64)
			far.BackgroundTransparency = 1
			far.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
			far.TextScaled = true
			far.Text = `{distance} studs`
			far.TextColor3 = if ghost then Color3.fromRGB(220, 255, 240) else C("ink")
			far.Parent = gui
			gui.Parent = board
		end
	end
end

-- Covered wagon (or a broken one with a fallen wheel and no canvas). `cf` is on the ground and the
-- wagon's tongue points along local -z.
local function wagon(parent: Instance, cf: CFrame, broken: boolean)
	local frame = if broken then cf * CFrame.Angles(math.rad(3), 0, math.rad(-9)) else cf
	part({
		name = "WagonBed",
		size = Vector3.new(5, 2.6, 9),
		cframe = frame * CFrame.new(0, 2.4, 0),
		color = "wood",
		material = Enum.Material.WoodPlanks,
		parent = parent,
	})
	for _, x in { -2.75, 2.75 } do
		for _, z in { -3, 3 } do
			if not (broken and x > 0 and z > 0) then
				part({
					name = "WagonWheel",
					size = Vector3.new(0.5, 3.4, 3.4),
					cframe = frame * CFrame.new(x, 1.5, z),
					color = "woodDark",
					material = Enum.Material.Wood,
					shape = Enum.PartType.Cylinder,
					collide = false,
					parent = parent,
				})
			end
		end
	end
	if broken then
		part({
			name = "FallenWheel",
			size = Vector3.new(0.5, 3.4, 3.4),
			cframe = cf * CFrame.new(4.8, -0.6, 4) * CFrame.Angles(0, 0.4, math.rad(90)),
			color = "woodDark",
			material = Enum.Material.Wood,
			shape = Enum.PartType.Cylinder,
			collide = false,
			parent = parent,
		})
	else
		part({
			name = "Canvas",
			size = Vector3.new(8, 4.8, 4.8),
			cframe = frame * CFrame.new(0, 3.7, 0.2) * CFrame.Angles(0, math.rad(90), 0),
			color = "paper",
			material = Enum.Material.Fabric,
			shape = Enum.PartType.Cylinder,
			parent = parent,
		})
	end
	span(
		parent,
		"Tongue",
		(frame * CFrame.new(0, 1.6, -4.5)).Position,
		(frame * CFrame.new(0, 0, -9)).Position,
		0.5,
		"woodDark",
		Enum.Material.Wood,
		false
	)
end

local function buildScenery(root: Instance)
	local scenery = Instance.new("Folder")
	scenery.Name = "Scenery"
	local rand = rng(7)
	-- Cacti dotted through the desert outside the loop.
	for _ = 1, 45 do
		local angle = rand() * math.pi * 2
		local dist = 220 + rand() * 160
		local at = Vector3.new(math.cos(angle) * dist, 0, 75 + math.sin(angle) * dist)
		if not HeistConfig.insideAnyZone(at.X, at.Z, 6) then
			cactus(scenery, at, 6 + rand() * 7)
		end
	end
	-- Lantern posts lining Main Street, in the strip between the ranch fences (z = 68 / 82) and the
	-- street. They stand in front of fence panels, never in a ranch gate (ranch x +-6) or an alley.
	for _, x in { -90, -60, -40, -10, 10, 40, 60, 90 } do
		lantern(scenery, Vector3.new(x, GROUND, 69.4), -math.pi / 2)
		lantern(scenery, Vector3.new(x, GROUND, 80.6), math.pi / 2)
	end
	-- Clutter by each landmark building: barrels, crates, hay.
	for name, at: Layout.V3 in Layout.landmarks :: { [string]: Layout.V3 } do
		local base = Vector3.new(at.x, GROUND, at.z)
		-- Buildings north of the ranches (Saloon, Trading Post) get their clutter on the track side,
		-- so it never lands inside ranches 1 and 4.
		local side = if at.z < 46 then -1 else 1
		if name ~= "banditCamp" then
			barrel(scenery, base + Vector3.new(-12, 0, 9 * side))
			barrel(scenery, base + Vector3.new(-9.5, 0, 10 * side))
			crate(scenery, base + Vector3.new(12, 0, 9 * side), 3, rand())
			crate(scenery, base + Vector3.new(12.5, 3, 9 * side), 2.2, rand())
			hayBale(scenery, base + Vector3.new(9, 0, 12 * side), rand() * 3)
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

-- Town dressing: a railway water tower and a windmill north of the track, split-rail fences where
-- Main Street runs past the ranches, zone signposts and wagons. Positions are chosen to stay off
-- the track loop (z = 0 / 150 and the end curves), out of ranches, the street, the platform and
-- the leaderboards.
local function buildTownProps(root: Instance)
	local props = Instance.new("Folder")
	props.Name = "TownProps"
	-- North of the front straight, facing the station: the tower's spout leans over the rails.
	waterTower(props, Vector3.new(-70, GROUND, -26), Vector3.new(0, 0, 1))
	windmill(props, Vector3.new(100, GROUND, -42), math.rad(200))
	-- Split-rail fences flanking the street past the last ranches (x +-97), with gaps left at the
	-- ranch corners, the Hatchery apron and the Bandit Camp leaderboard.
	for _, z in { 67.2, 82.8 } do
		railFence(props, Vector3.new(-128, GROUND, z), Vector3.new(-103, GROUND, z))
		railFence(props, Vector3.new(103, GROUND, z), Vector3.new(132, GROUND, z))
	end
	-- Signposts: station forecourt (first thing new players see) and both ends of Main Street.
	signpost(props, Vector3.new(-30, GROUND, 21))
	signpost(props, Vector3.new(-104, GROUND, 62))
	signpost(props, Vector3.new(104, GROUND, 88))
	-- Wagons: one by the Saloon, one by the Stables and a wreck out on the trail to Cactus Flats.
	wagon(props, CFrame.new(-110, GROUND, 33) * CFrame.Angles(0, math.rad(8), 0), false)
	wagon(props, CFrame.new(121, GROUND, 110) * CFrame.Angles(0, math.rad(170), 0), false)
	wagon(props, CFrame.new(-214, GROUND, 38) * CFrame.Angles(0, math.rad(-35), 0), true)
	cowSkull(props, Vector3.new(-206, GROUND, 44), 0.8)
	props.Parent = root
end

-- Heist zones: each gets its own ground, props and a big sign facing town (Heist service adds the
-- nests and guards). Themes: cactus flats, red canyon walls, a gold mine, a spooky ghost town.
local function zoneSign(parent: Instance, zone: HeistConfig.Zone)
	local toTown = (Vector3.new(0, 0, 75) - Vector3.new(zone.x, 0, zone.z)).Unit
	local at = Vector3.new(zone.x, 0, zone.z) + toTown * (zone.radius + 6)
	local face = CFrame.lookAt(at, at + toTown)
	for side = -1, 1, 2 do
		part({
			name = "SignPost",
			size = Vector3.new(0.8, 13, 0.8),
			cframe = face * CFrame.new(side * 9, 5.5, 0),
			color = "woodDark",
			material = Enum.Material.Wood,
			parent = parent,
		})
	end
	local board = part({
		name = "ZoneSign",
		size = Vector3.new(20, 5, 0.6),
		cframe = face * CFrame.new(0, 10, 0),
		color = if zone.theme == "ghost" then "iron" else "paper",
		parent = parent,
	})
	-- Front faces town (the board's -Z side points along `toTown`).
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(400, 100)
	gui.LightInfluence = 0.3
	local title = Instance.new("TextLabel")
	title.Size = UDim2.fromScale(1, 0.62)
	title.BackgroundTransparency = 1
	title.FontFace = Font.fromEnum(Enum.Font.LuckiestGuy)
	title.TextScaled = true
	title.Text = string.upper(zone.name)
	title.TextColor3 = if zone.theme == "ghost" then Color3.fromRGB(150, 255, 210) else C("red")
	title.Parent = gui
	local sub = Instance.new("TextLabel")
	sub.Size = UDim2.fromScale(1, 0.34)
	sub.Position = UDim2.fromScale(0, 0.64)
	sub.BackgroundTransparency = 1
	sub.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
	sub.TextScaled = true
	sub.Text = `{string.upper(Rarities.forTier(zone.maxTier).name)} CRITTERS · BOOTS {zone.suggestedBoots}+`
	sub.TextColor3 = if zone.theme == "ghost" then Color3.fromRGB(220, 255, 240) else C("ink")
	sub.Parent = gui
	gui.Parent = board
end

-- True when a prop at `at` keeps `margin` studs from every nest of `zone`. With `lane`, it must
-- also stay out of the zone's middle and the walking lane toward town (a 35-degree wedge).
local function zoneClear(zone: HeistConfig.Zone, at: Vector3, margin: number, lane: boolean): boolean
	for n = 1, zone.nests do
		local nx, nz = HeistConfig.nestPosition(zone, n)
		if Vector2.new(at.X - nx, at.Z - nz).Magnitude < margin then
			return false
		end
	end
	if not lane then
		return true
	end
	local off = Vector3.new(at.X - zone.x, 0, at.Z - zone.z)
	if off.Magnitude < 8 then
		return false
	end
	local toTown = Vector3.new(-zone.x, 0, 75 - zone.z).Unit
	return off.Unit:Dot(toTown) < math.cos(math.rad(35))
end

-- Leaning dead tree: a trunk and three bare branches.
local function deadTree(parent: Instance, at: Vector3, rand: () -> number, color: string)
	local lean = CFrame.new(at)
		* CFrame.Angles(math.rad((rand() - 0.5) * 14), rand() * math.pi * 2, math.rad((rand() - 0.5) * 14))
	part({
		name = "DeadTree",
		size = Vector3.new(1.1, 11, 1.1),
		cframe = lean * CFrame.new(0, 4.5, 0),
		color = color,
		material = Enum.Material.Wood,
		parent = parent,
	})
	for i = 1, 3 do
		local from = (lean * CFrame.new(0, 4 + i * 1.8, 0)).Position
		local a = i * 2.1 + rand()
		local branch = span(
			parent,
			"Branch",
			from,
			from + Vector3.new(math.cos(a) * 3.6, 2.4 + rand(), math.sin(a) * 3.6),
			0.45,
			color,
			Enum.Material.Wood,
			false
		)
		branch.CastShadow = true
	end
end

-- Angle between two headings, 0..pi.
local function angleGap(a: number, b: number): number
	return math.abs((a - b + math.pi) % (math.pi * 2) - math.pi)
end

local function buildZones(root: Instance)
	local terrain = Workspace.Terrain
	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "HeistZones"
	local rand = rng(23)
	for _, zone in HeistConfig.zones do
		local c = Vector3.new(zone.x, 0, zone.z)
		local model = Instance.new("Model")
		model.Name = zone.name
		-- Heading and unit vectors toward town; props keep the lane along `toTown` open.
		local townAngle = math.atan2(75 - zone.z, -zone.x)
		local toTown = Vector3.new(math.cos(townAngle), 0, math.sin(townAngle))
		local across = toTown:Cross(Vector3.yAxis).Unit
		local function ground(angle: number, dist: number): Vector3
			return Vector3.new(zone.x + math.cos(angle) * dist, GROUND, zone.z + math.sin(angle) * dist)
		end
		if zone.theme == "flats" then
			terrain:FillCylinder(CFrame.new(c + Vector3.new(0, -3, 0)), 4, zone.radius, Enum.Material.Ground)
			for _ = 1, 14 do
				local a, d = rand() * math.pi * 2, zone.radius * (0.75 + rand() * 0.45)
				local h = 7 + rand() * 6
				local at = c + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d)
				if zoneClear(zone, at, 6, true) then
					cactus(model, at, h)
				end
			end
			-- Saguaro clusters around the rim and bleached cow skulls on the flats.
			for _ = 1, 8 do
				local at = ground(rand() * math.pi * 2, zone.radius * (1 + rand() * 0.45))
				if zoneClear(zone, at, 9, true) then
					cactusCluster(model, at, rand)
				end
			end
			for _ = 1, 7 do
				local at = ground(rand() * math.pi * 2, zone.radius * (0.3 + rand() * 0.9))
				if zoneClear(zone, at, 5, false) then
					cowSkull(model, at, rand() * math.pi * 2)
				end
			end
			deadTree(model, ground(townAngle + math.pi * 0.7, zone.radius + 6), rand, "#8A7158")
		elseif zone.theme == "canyon" then
			terrain:FillCylinder(
				CFrame.new(c + Vector3.new(0, -3, 0)),
				4,
				zone.radius,
				Enum.Material.Sandstone
			)
			-- Red rock walls around the far side; the 54-degree gap faces town, where players walk in.
			for i = 0, 10 do
				local a = townAngle + math.pi * (0.15 + i / 10 * 1.7)
				local at = c + Vector3.new(math.cos(a), 0, math.sin(a)) * (zone.radius + 10)
				terrain:FillBlock(
					CFrame.new(at + Vector3.new(0, 14, 0)) * CFrame.Angles(0, -a, 0),
					Vector3.new(16, 28 + rand() * 18, 22),
					if i % 2 == 0 then Enum.Material.Sandstone else Enum.Material.Rock
				)
			end
			-- Two rock spires frame the entrance with a rickety rope bridge strung high between them.
			local gate = c + toTown * (zone.radius + 12)
			for _, s in { -1, 1 } do
				local pillar = gate + across * (s * 21)
				terrain:FillBlock(
					CFrame.new(pillar + Vector3.new(0, 14, 0)) * CFrame.Angles(0, -townAngle, 0),
					Vector3.new(10, 32, 10),
					Enum.Material.Sandstone
				)
				terrain:FillBlock(
					CFrame.new(pillar + Vector3.new(0, 20, 0)) * CFrame.Angles(0, -townAngle, 0),
					Vector3.new(11, 4, 11),
					Enum.Material.Rock
				)
			end
			ropeBridge(
				model,
				gate - across * 17 + Vector3.new(0, 30, 0),
				gate + across * 17 + Vector3.new(0, 30, 0),
				3,
				rand
			)
			-- Free-standing natural arches out on either flank.
			for _, s in { -1, 1 } do
				local a = townAngle + s * math.rad(70)
				rockArch(terrain, ground(a, zone.radius + 34), -a, 14, 20)
			end
			for _ = 1, 3 do
				local at = ground(rand() * math.pi * 2, zone.radius * (0.3 + rand() * 0.6))
				if zoneClear(zone, at, 5, false) then
					cowSkull(model, at, rand() * math.pi * 2)
				end
			end
		elseif zone.theme == "mine" then
			terrain:FillCylinder(CFrame.new(c + Vector3.new(0, -3, 0)), 4, zone.radius, Enum.Material.Slate)
			-- A rocky hill on the far side with a timbered tunnel cut into its cliff face. `face` sits at
			-- the cliff, local -z runs into the hill, local +z back toward the nests.
			local faceAt = c - toTown * (zone.radius + 3) + Vector3.new(0, GROUND, 0)
			local face = CFrame.lookAt(faceAt, faceAt - toTown)
			terrain:FillBlock(face * CFrame.new(0, 10, -12), Vector3.new(46, 24, 24), Enum.Material.Rock)
			terrain:FillBall((face * CFrame.new(0, -6, -34)).Position, 36, Enum.Material.Rock)
			terrain:FillBall((face * CFrame.new(-26, -8, -16)).Position, 16, Enum.Material.Sandstone)
			terrain:FillBall((face * CFrame.new(26, -8, -18)).Position, 18, Enum.Material.Rock)
			terrain:FillBlock(face * CFrame.new(0, 7.5, -8), Vector3.new(11, 15, 18), Enum.Material.Air)
			for _, s in { -1, 1 } do
				part({
					name = "MineBeam",
					size = Vector3.new(1.4, 14.5, 1.4),
					cframe = face * CFrame.new(s * 6.2, 6.25, -0.6),
					color = "woodDark",
					material = Enum.Material.WoodPlanks,
					parent = model,
				})
			end
			part({
				name = "MineLintel",
				size = Vector3.new(14.6, 1.6, 1.6),
				cframe = face * CFrame.new(0, 13.6, -0.6),
				color = "woodDark",
				material = Enum.Material.WoodPlanks,
				parent = model,
			})
			local sign = part({
				name = "MineSign",
				size = Vector3.new(8, 2, 0.3),
				cframe = face * CFrame.new(0, 15.6, -0.2) * CFrame.Angles(0, math.pi, math.rad(-3)),
				color = "paper",
				collide = false,
				parent = model,
			})
			label(sign, "GOLD MINE", Enum.NormalId.Front)
			-- The tunnel fades into darkness.
			part({
				name = "MineDark",
				size = Vector3.new(11, 15, 1),
				cframe = face * CFrame.new(0, 6.5, -16.5),
				color = "ink",
				parent = model,
			})
			-- Rails run out of the tunnel toward the nests, with an ore cart parked by the entrance.
			mineRails(model, (face * CFrame.new(0, 0, -15)).Position, (face * CFrame.new(0, 0, 21)).Position)
			mineCart(model, face * CFrame.new(0, 0, 6))
			for _, s in { -1, 1 } do
				-- Lanterns flank the portal with their arms reaching toward it.
				local post = (face * CFrame.new(s * 9.5, 0, 2)).Position
				local arm = face.RightVector * -s
				lantern(model, post, math.atan2(-arm.Z, arm.X))
				oreCluster(model, (face * CFrame.new(s * 14, 0, 1.5)).Position, rand, true)
				oreCluster(model, (face * CFrame.new(s * 20, 1, -1)).Position, rand, false)
			end
			barrel(model, (face * CFrame.new(-12, 0, 6)).Position)
			barrel(model, (face * CFrame.new(-14.5, 0, 7)).Position)
			crate(model, (face * CFrame.new(13, 0, 7)).Position, 3, 0.3)
			for i = 1, 8 do
				local a = rand() * math.pi * 2
				local d = zone.radius * (0.8 + rand() * 0.3)
				local nugget = part({
					name = "GoldVein",
					size = Vector3.new(2 + rand() * 2, 1.5 + rand(), 2 + rand() * 2),
					cframe = CFrame.new(c + Vector3.new(math.cos(a) * d, -0.6, math.sin(a) * d))
						* CFrame.Angles(rand(), rand() * 3, rand()),
					color = "gold",
					material = Enum.Material.Foil,
					collide = false,
					parent = model,
				})
				if i % 3 == 0 then
					local glow = Instance.new("PointLight")
					glow.Color = C("gold")
					glow.Range = 10
					glow.Brightness = 1
					glow.Parent = nugget
				end
			end
		elseif zone.theme == "ghost" then
			terrain:FillCylinder(CFrame.new(c + Vector3.new(0, -3, 0)), 4, zone.radius + 6, Enum.Material.Mud)
			-- Crooked, broken shacks and green ghost lanterns (none in the lane toward town).
			for i = 1, 6 do
				local a = i / 6 * math.pi * 2 + 0.3
				local h = 9 + rand() * 4
				local tilt = math.rad(rand() * 10 - 5)
				local glow = 11 + rand() * 2
				if angleGap(a, townAngle) > 0.5 then
					local at = c + Vector3.new(math.cos(a), 0, math.sin(a)) * (zone.radius + 2)
					local shack = part({
						name = "Shack",
						size = Vector3.new(12, h, 10),
						cframe = CFrame.new(at + Vector3.new(0, h / 2 - 1.5, 0))
							* CFrame.Angles(0, a + math.pi / 2, tilt),
						color = "woodDark",
						material = Enum.Material.WoodPlanks,
						parent = model,
					})
					shack.Color = Color3.fromRGB(70, 62, 66)
					local ghostLight = part({
						name = "GhostLantern",
						size = Vector3.new(1, 1.4, 1),
						cframe = CFrame.new(at + Vector3.new(0, glow, 0)),
						color = "sky",
						material = Enum.Material.Neon,
						collide = false,
						parent = model,
					})
					ghostLight.Color = GHOST_GREEN
					local light = Instance.new("PointLight")
					light.Color = GHOST_GREEN
					light.Range = 22
					light.Brightness = 1.6
					light.Parent = ghostLight
				end
			end
			-- A crooked church and its graveyard behind the town, ruins on the flanks.
			local churchAt = c - toTown * (zone.radius + 26) + Vector3.new(0, GROUND, 0)
			local church = CFrame.lookAt(churchAt, Vector3.new(zone.x, GROUND, zone.z))
			crookedChurch(model, church)
			for i = 1, 8 do
				local s = if i % 2 == 0 then 1 else -1
				gravestone(
					model,
					(church * CFrame.new(s * (11 + rand() * 6), 0, -6 + rand() * 16)).Position,
					rand
				)
			end
			for _, a in { townAngle + 1.9, townAngle - 1.9, townAngle + 2.5, townAngle - 2.5 } do
				local at = ground(a, zone.radius + 16)
				brokenHouse(model, CFrame.lookAt(at, Vector3.new(zone.x, GROUND, zone.z)), rand)
			end
			-- Fog lanterns: a pair marking the way in, more around the rim.
			for _, s in { -1, 1 } do
				fogLantern(
					model,
					c + toTown * (zone.radius + 2) + across * (s * 12) + Vector3.new(0, GROUND, 0),
					rand
				)
			end
			for _ = 1, 6 do
				local at = ground(rand() * math.pi * 2, zone.radius * (0.85 + rand() * 0.12))
				if zoneClear(zone, at, 7, true) then
					fogLantern(model, at, rand)
				end
			end
			for _, a in { townAngle + 1.2, townAngle - 1.4 } do
				deadTree(model, ground(a, zone.radius + 7), rand, "#4A4245")
			end
			-- Drifting ghost mist.
			local mistHolder = part({
				name = "Mist",
				size = Vector3.new(zone.radius * 2, 1, zone.radius * 2),
				cframe = CFrame.new(c + Vector3.new(0, 1, 0)),
				color = "cream",
				transparency = 1,
				collide = false,
				parent = model,
			})
			local mist = Instance.new("ParticleEmitter")
			mist.Texture = "rbxasset://textures/particles/smoke_main.dds"
			mist.Color = ColorSequence.new(Color3.fromRGB(170, 255, 220))
			mist.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.4, 0.75),
				NumberSequenceKeypoint.new(1, 1),
			})
			mist.Size = NumberSequence.new(14)
			mist.Lifetime = NumberRange.new(6, 9)
			mist.Rate = 6
			mist.Speed = NumberRange.new(0.5, 1.5)
			mist.Parent = mistHolder
		end
		zoneSign(model, zone)
		model.Parent = zonesFolder
	end
	zonesFolder.Parent = root
end

function World.init()
	local existing = Workspace:FindFirstChild("Town")
	if existing then
		existing:Destroy()
	end
	local town = Instance.new("Folder")
	town.Name = "Town"
	-- Gameplay pieces first; each decorative step is isolated so a failure in one (an engine API
	-- change, a bad terrain call) can never stop the town from appearing. Failures are logged.
	local function step(name: string, fn: (Instance) -> ())
		local ok, err = pcall(fn :: any, town)
		if not ok then
			warn(`[World] {name} failed: {err}`)
		end
	end
	step("ground", buildGround)
	step("track", buildTrack)
	step("station", buildStation)
	local ranches = Instance.new("Folder")
	ranches.Name = "Ranches"
	for _, info in Layout.ranches do
		buildRanch(ranches, info)
	end
	ranches.Parent = town
	step("landmarks", buildLandmarks)
	step("scenery", buildScenery)
	step("townProps", buildTownProps)
	step("zones", buildZones)
	town.Parent = Workspace
end

function World.ranchModel(index: number): Model?
	local town = Workspace:FindFirstChild("Town")
	local ranches = town and town:FindFirstChild("Ranches")
	return ranches and ranches:FindFirstChild("Ranch" .. index) :: Model?
end

function World.start() end

return World
