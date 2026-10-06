--!strict
-- Ambient life and light, all client-side:
--   * a slow golden-hour day cycle (ClockTime 16.0 -> 18.5 -> 16.0 every 20 minutes, derived from
--     server time so every client sees the same sky), with lanterns fading up toward dusk;
--   * per-zone atmosphere: entering a heist zone blends the Atmosphere and a "ZoneGrade" colour
--     correction toward that zone's mood (Vfx owns "Grade" for weather, so the two never fight);
--   * ambient life: dust motes and dusk fireflies around the camera, tumbleweeds, circling
--     buzzards, a spinning windmill and flickering ghost lanterns.
-- Everything is anchored and CFrame-driven (no physics), and scaled by quality tier: Low keeps only
-- the light changes (day cycle, lanterns, zone grade) and turns the moving life off.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local HeistConfig = require("@game/ReplicatedStorage/Shared/Config/Heist")
local Quality = require("./Quality")
local Store = require("../Store")

local Ambience = {}

local localPlayer = Players.LocalPlayer

-- Day cycle ------------------------------------------------------------------------------------

local CYCLE_SECONDS = 20 * 60
local CLOCK_MID = 17.25
local CLOCK_SWING = 1.25 -- 16.0 (warm afternoon) .. 18.5 (sun just under the horizon)

local function clockAt(serverTime: number): number
	return CLOCK_MID - CLOCK_SWING * math.cos(serverTime / CYCLE_SECONDS * math.pi * 2)
end

local function smoothstep(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

-- 0 in the afternoon, 1 at the dusky end of the cycle.
local function duskAt(clock: number): number
	return smoothstep((clock - 17.2) / (18.5 - 17.2))
end

-- Zone moods -----------------------------------------------------------------------------------

type Mood = {
	density: number,
	offset: number,
	color: Color3,
	decay: Color3,
	glare: number,
	haze: number,
	tint: Color3,
	saturation: number,
	contrast: number,
	brightness: number,
}

-- Cactus Flats ("flats") has no entry: it keeps the town look.
local MOODS: { [string]: Mood } = {
	ghost = {
		-- Cold green-grey fog that swallows the far shacks.
		density = 0.46,
		offset = 0.05,
		color = Color3.fromRGB(150, 172, 162),
		decay = Color3.fromRGB(86, 108, 102),
		glare = 0,
		haze = 2.6,
		tint = Color3.fromRGB(214, 240, 228),
		saturation = -0.25,
		contrast = 0.06,
		brightness = -0.02,
	},
	mine = {
		-- Warm golden glow, like dust lit by the ore.
		density = 0.34,
		offset = 0.2,
		color = Color3.fromRGB(255, 208, 132),
		decay = Color3.fromRGB(222, 142, 62),
		glare = 0.8,
		haze = 2,
		tint = Color3.fromRGB(255, 238, 200),
		saturation = 0.1,
		contrast = 0.04,
		brightness = 0.03,
	},
	canyon = {
		-- Redder rock and a rusty haze between the walls.
		density = 0.32,
		offset = 0.15,
		color = Color3.fromRGB(238, 156, 116),
		decay = Color3.fromRGB(192, 82, 52),
		glare = 0.4,
		haze = 1.8,
		tint = Color3.fromRGB(255, 230, 218),
		saturation = 0.14,
		contrast = 0.06,
		brightness = 0,
	},
}

-- Full mood inside the zone radius, fading out over this many studs beyond it.
local ZONE_FADE = 40

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

-- Quality helpers ------------------------------------------------------------------------------

local function tier(): number
	return math.clamp(Store.quality(), 1, 4)
end

local function perTier(low: number, medium: number, high: number): number
	local q = tier()
	return if q <= 1 then low elseif q == 2 then medium else high
end

local function makeHolder(name: string, size: Vector3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Transparency = 1
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	return p
end

local function livePart(
	folder: Instance,
	name: string,
	size: Vector3,
	color: Color3,
	material: Enum.Material,
	shape: Enum.PartType?
): BasePart
	local p = makeHolder(name, size)
	p.Transparency = 0
	p.Color = color
	p.Material = material
	if shape then
		p.Shape = shape
	end
	p.Parent = folder
	return p
end

-- State ----------------------------------------------------------------------------------------

local folder: Folder
local zoneGrade: ColorCorrectionEffect
local atmosphere: Atmosphere?
local base = {
	exposure = 0,
	outdoor = Color3.new(0.7, 0.6, 0.56),
	density = 0.3,
	offset = 0.15,
	color = Color3.new(0.95, 0.78, 0.62),
	decay = Color3.new(0.86, 0.54, 0.4),
	glare = 0.35,
	haze = 1.5,
}

-- Lanterns (tagged by World) and their light, faded with dusk.
local lanterns: { [BasePart]: PointLight } = {}
local LANTERN_DIM = Color3.fromRGB(214, 160, 78)
local LANTERN_BRIGHT = Color3.fromRGB(255, 206, 110)
local lastDusk = -1

local function applyLantern(glass: BasePart, light: PointLight, dusk: number)
	light.Brightness = lerp(0.6, 2.2, dusk)
	light.Range = lerp(12, 20, dusk)
	glass.Color = LANTERN_DIM:Lerp(LANTERN_BRIGHT, dusk)
end

local function addLantern(inst: Instance)
	if not inst:IsA("BasePart") then
		return
	end
	local light = inst:FindFirstChildOfClass("PointLight")
	if light then
		lanterns[inst] = light
		applyLantern(inst, light, math.max(lastDusk, 0))
	end
end

-- Ghost lanterns (flicker) and their mist (off on Low).
type FogLantern = { light: PointLight, base: number, phase: number, mist: ParticleEmitter? }
local fogLanterns: { [BasePart]: FogLantern } = {}

local function addFogLantern(inst: Instance)
	if not inst:IsA("BasePart") then
		return
	end
	local light = inst:FindFirstChildOfClass("PointLight")
	if light then
		fogLanterns[inst] = {
			light = light,
			base = light.Brightness,
			phase = math.random() * 10,
			mist = inst:FindFirstChildOfClass("ParticleEmitter"),
		}
	end
end

-- Windmill rotors (tagged Models): every part keeps its offset from the hub pivot.
type Rotor = { pivot: CFrame, parts: { BasePart }, offsets: { CFrame }, angle: number }
local rotors: { Rotor } = {}

local function addRotor(inst: Instance)
	if not inst:IsA("Model") then
		return
	end
	local pivot = inst:GetPivot()
	local rotor: Rotor = { pivot = pivot, parts = {}, offsets = {}, angle = 0 }
	for _, d in inst:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(rotor.parts, d)
			table.insert(rotor.offsets, pivot:ToObjectSpace(d.CFrame))
		end
	end
	table.insert(rotors, rotor)
end

-- A tagged instance can arrive before its children finish replicating, so each add waits a moment.
local function watchTag(tag: string, add: (Instance) -> ())
	local function later(inst: Instance)
		task.delay(1, function()
			if inst.Parent then
				add(inst)
			end
		end)
	end
	for _, inst in CollectionService:GetTagged(tag) do
		later(inst)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(later)
end

-- Focus point for zone moods and spawns: the character if there is one, else the camera.
local function focus(): Vector3
	local character = localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		return root.Position
	end
	local camera = Workspace.CurrentCamera
	return if camera then camera.CFrame.Position else Vector3.new(0, 10, 75)
end

-- Light: day cycle + zone mood (one writer for Atmosphere and ZoneGrade) ----------------------

local zoneWeights: { [string]: number } = {}
local lastClockWrite = -math.huge
local lastMoodWrite = -math.huge

local function updateLight(dt: number, now: number): number
	local clock = clockAt(now)
	local dusk = duskAt(clock)
	-- ClockTime moves ~0.004 h per second at most; writing it twice a second is invisible and
	-- keeps shadow-map updates cheap.
	if os.clock() - lastClockWrite > 0.5 then
		lastClockWrite = os.clock()
		Lighting.ClockTime = clock
		-- As the sun dips, lift exposure and cool the fill so phones still read every shadow.
		Lighting.ExposureCompensation = base.exposure + 0.25 * dusk
		Lighting.OutdoorAmbient = base.outdoor:Lerp(Color3.fromRGB(160, 150, 182), 0.35 * dusk)
	end
	if math.abs(dusk - lastDusk) > 0.01 then
		lastDusk = dusk
		for glass, light in lanterns do
			if glass.Parent then
				applyLantern(glass, light, dusk)
			else
				lanterns[glass] = nil
			end
		end
	end

	-- Zone weights ease toward their target (about a 1.5 s blend).
	local at = focus()
	local blend = 1 - math.exp(-dt * 1.4)
	local total = 0
	for _, zone in HeistConfig.zones do
		local mood = MOODS[zone.theme]
		if mood then
			local d = Vector2.new(at.X - zone.x, at.Z - zone.z).Magnitude
			local target = math.clamp((zone.radius + ZONE_FADE - d) / ZONE_FADE, 0, 1)
			local w = zoneWeights[zone.theme] or 0
			w += (target - w) * blend
			if w < 0.001 and target == 0 then
				w = 0
			end
			zoneWeights[zone.theme] = w
			total += w
		end
	end

	-- Atmosphere and grade are written 10 times a second: blends take ~1.5 s, so steps are invisible.
	if os.clock() - lastMoodWrite < 0.1 then
		return dusk
	end
	lastMoodWrite = os.clock()
	-- Dusk warms the haze a touch; the zone mood is layered on top of that.
	local density, offset, glare, haze = base.density, base.offset, base.glare, base.haze
	local color = base.color:Lerp(Color3.fromRGB(242, 170, 142), 0.35 * dusk)
	local decay = base.decay:Lerp(Color3.fromRGB(196, 104, 92), 0.3 * dusk)
	local tint, saturation, contrast, brightness = Color3.new(1, 1, 1), 0, 0, 0
	for theme, w in zoneWeights do
		if w > 0 then
			local m = MOODS[theme]
			density = lerp(density, m.density, w)
			offset = lerp(offset, m.offset, w)
			glare = lerp(glare, m.glare, w)
			haze = lerp(haze, m.haze, w)
			color = color:Lerp(m.color, w)
			decay = decay:Lerp(m.decay, w)
			tint = tint:Lerp(m.tint, w)
			saturation = lerp(saturation, m.saturation, w)
			contrast = lerp(contrast, m.contrast, w)
			brightness = lerp(brightness, m.brightness, w)
		end
	end
	local atm = atmosphere
	if atm then
		atm.Density = density
		atm.Offset = offset
		atm.Glare = glare
		atm.Haze = haze
		atm.Color = color
		atm.Decay = decay
	end
	zoneGrade.Enabled = total > 0.001
	if zoneGrade.Enabled then
		zoneGrade.TintColor = tint
		zoneGrade.Saturation = saturation
		zoneGrade.Contrast = contrast
		zoneGrade.Brightness = brightness
	end
	return dusk
end

-- Dust motes and fireflies ---------------------------------------------------------------------

local dustHolder: Part
local dust: ParticleEmitter
local fireflyHolder: Part
local fireflies: ParticleEmitter

local function buildParticles()
	dustHolder = makeHolder("DustMotes", Vector3.new(56, 18, 56))
	dust = Instance.new("ParticleEmitter")
	dust.Shape = Enum.ParticleEmitterShape.Box
	dust.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	dust.Texture = "rbxasset://textures/particles/smoke_main.dds"
	dust.Color = ColorSequence.new(Color3.fromRGB(255, 228, 186))
	dust.LightEmission = 0.5
	dust.LightInfluence = 0.5
	dust.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.12),
		NumberSequenceKeypoint.new(1, 0.2),
	})
	dust.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, 0.4),
		NumberSequenceKeypoint.new(0.7, 0.4),
		NumberSequenceKeypoint.new(1, 1),
	})
	dust.Lifetime = NumberRange.new(6, 10)
	dust.Speed = NumberRange.new(0.2, 0.6)
	dust.SpreadAngle = Vector2.new(180, 180)
	-- A gentle drift with the prevailing (westerly) wind the tumbleweeds also follow.
	dust.Acceleration = Vector3.new(0.12, 0.02, 0.04)
	dust.Drag = 0.4
	dust.Rate = 0
	dust.Parent = dustHolder
	dustHolder.Parent = folder

	fireflyHolder = makeHolder("Fireflies", Vector3.new(48, 5, 48))
	fireflies = Instance.new("ParticleEmitter")
	fireflies.Shape = Enum.ParticleEmitterShape.Box
	fireflies.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	fireflies.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	fireflies.Color = ColorSequence.new(Color3.fromRGB(226, 255, 130))
	fireflies.LightEmission = 1
	fireflies.LightInfluence = 0
	fireflies.Size = NumberSequence.new(0.22)
	-- Blinking: the keypoints switch the glow on and off a few times in each life.
	fireflies.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.15, 0.1),
		NumberSequenceKeypoint.new(0.3, 0.9),
		NumberSequenceKeypoint.new(0.45, 0.1),
		NumberSequenceKeypoint.new(0.6, 0.15),
		NumberSequenceKeypoint.new(0.75, 0.9),
		NumberSequenceKeypoint.new(0.88, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	fireflies.Lifetime = NumberRange.new(4, 7)
	fireflies.Speed = NumberRange.new(0.4, 1.2)
	fireflies.SpreadAngle = Vector2.new(180, 180)
	fireflies.RotSpeed = NumberRange.new(-30, 30)
	fireflies.Drag = 0.8
	fireflies.Rate = 0
	fireflies.Parent = fireflyHolder
	fireflyHolder.Parent = folder
end

local function updateParticles(dusk: number)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local cf = camera.CFrame
	-- Centre the dust box a little ahead of the camera, where the eye actually looks.
	dustHolder.CFrame = CFrame.new(cf.Position + cf.LookVector * 14)
	local reduced = Quality.reducedMotion()
	dust.Rate = if reduced then perTier(0, 2, 4) else perTier(0, 5, 10)
	local evening = math.clamp((dusk - 0.4) / 0.6, 0, 1)
	fireflyHolder.CFrame = CFrame.new(focus() + Vector3.new(0, 1.5, 0))
	fireflies.Rate = evening * perTier(0, 3, 6)
end

-- Tumbleweeds ----------------------------------------------------------------------------------

type Tumbleweed = {
	parts: { BasePart },
	offsets: { CFrame },
	from: Vector3,
	dir: Vector3,
	length: number,
	speed: number,
	travelled: number,
	radius: number,
	spin: CFrame,
	hop: number,
	groundY: number,
	probe: number,
}

local WIND = Vector3.new(1, 0, 0.18).Unit
local MAIN_STREET = Vector3.new(0, 0, 75)
local tumbleweeds: { Tumbleweed } = {}
local nextTumbleweed = 6
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
groundParams.IgnoreWater = true

local function groundHeight(x: number, z: number, fallback: number): number
	local hit = Workspace:Raycast(Vector3.new(x, 80, z), Vector3.new(0, -140, 0), groundParams)
	return if hit then hit.Position.Y else fallback
end

local function spawnTumbleweed()
	local at = focus()
	local from: Vector3
	local dir = WIND
	local length: number
	local nearTown = math.abs(at.X) < 230 and at.Z > -40 and at.Z < 190
	if nearTown then
		-- Down Main Street from the Bandit Camp side; the street is open, so nothing to clip.
		from = Vector3.new(-128, 0, 70 + math.random() * 10)
		dir = Vector3.new(1, 0, (math.random() - 0.5) * 0.04).Unit
		length = 256
		if (at - MAIN_STREET).Magnitude > 170 then
			return
		end
	else
		-- Out in the desert: cross the player's view 40-90 studs away, upwind to downwind.
		local side = math.random() * math.pi * 2
		local mid = at + Vector3.new(math.cos(side), 0, math.sin(side)) * (40 + math.random() * 50)
		length = 150
		from = mid - dir * (length / 2)
	end
	local radius = 1.5 + math.random() * 0.6
	local color = Color3.fromRGB(168, 128, 82):Lerp(Color3.fromRGB(196, 160, 104), math.random())
	local ball = livePart(
		folder,
		"Tumbleweed",
		Vector3.one * radius * 2,
		color,
		Enum.Material.Grass,
		Enum.PartType.Ball
	)
	ball.CastShadow = tier() >= 3
	local parts: { BasePart } = { ball }
	local offsets: { CFrame } = { CFrame.identity }
	-- Two crossed twig hoops poke out of the ball, so the silhouette reads as brush, not a rock.
	for i = 1, 2 do
		local hoop = livePart(
			folder,
			"Twigs",
			Vector3.new(0.15, radius * 2.3, radius * 2.3),
			color:Lerp(Color3.fromRGB(110, 80, 50), 0.4),
			Enum.Material.Wood,
			Enum.PartType.Cylinder
		)
		table.insert(parts, hoop)
		table.insert(offsets, CFrame.Angles(0, i * math.pi / 2.6, math.rad(30 * i)))
	end
	table.insert(tumbleweeds, {
		parts = parts,
		offsets = offsets,
		from = from,
		dir = dir,
		length = length,
		speed = 9 + math.random() * 5,
		travelled = 0,
		radius = radius,
		spin = CFrame.identity,
		hop = math.random() * math.pi,
		groundY = groundHeight(from.X, from.Z, -1),
		probe = 0,
	})
end

local moveParts: { BasePart } = {}
local moveFrames: { CFrame } = {}

local function updateTumbleweeds(dt: number)
	local maxActive = if Quality.reducedMotion() then perTier(0, 1, 1) else perTier(0, 1, 2)
	nextTumbleweed -= dt
	if nextTumbleweed <= 0 then
		nextTumbleweed = 9 + math.random() * 14
		if #tumbleweeds < maxActive then
			spawnTumbleweed()
		end
	end
	for i = #tumbleweeds, 1, -1 do
		local t = tumbleweeds[i]
		local step = t.speed * dt
		t.travelled += step
		if t.travelled >= t.length then
			for _, p in t.parts do
				p:Destroy()
			end
			table.remove(tumbleweeds, i)
			continue
		end
		local pos = t.from + t.dir * t.travelled
		-- Ground probe a few times a second; the height eases between probes (dunes are smooth).
		t.probe -= dt
		if t.probe <= 0 then
			t.probe = 0.2
			t.groundY = groundHeight(pos.X, pos.Z, t.groundY)
		end
		-- Roll: rotate about the axis across the travel direction by distance / radius.
		local axis = Vector3.yAxis:Cross(t.dir).Unit
		t.spin = CFrame.fromAxisAngle(axis, step / t.radius) * t.spin
		-- Bouncy hops that fade in and out at the ends of the run.
		t.hop += dt * 7
		local edge = math.min(t.travelled, t.length - t.travelled)
		local fade = math.clamp(edge / 12, 0, 1)
		local lift = math.abs(math.sin(t.hop)) * 1.3 * fade
		local center = CFrame.new(pos.X, t.groundY + t.radius - 0.2 + lift, pos.Z) * t.spin
		for k, p in t.parts do
			table.insert(moveParts, p)
			table.insert(moveFrames, center * t.offsets[k])
			p.Transparency = 1 - fade
		end
	end
end

-- Buzzards -------------------------------------------------------------------------------------

type Buzzard = {
	body: BasePart,
	wings: { BasePart },
	center: Vector3,
	radius: number,
	height: number,
	speed: number,
	phase: number,
	flapAt: number,
}

local buzzards: { Buzzard } = {}
local BUZZARD_CENTERS = {
	Vector3.new(-40, 0, 40),
	Vector3.new(-150, 0, -175),
	Vector3.new(285, 0, 75),
	Vector3.new(40, 0, 345),
}
local BUZZARD_COLOR = Color3.fromRGB(46, 34, 30)

local function syncBuzzards()
	local want = if Quality.reducedMotion() then perTier(0, 1, 2) else perTier(0, 2, 4)
	while #buzzards > want do
		local b = table.remove(buzzards) :: Buzzard
		b.body:Destroy()
		for _, w in b.wings do
			w:Destroy()
		end
	end
	while #buzzards < want do
		local index = #buzzards + 1
		local body =
			livePart(folder, "Buzzard", Vector3.new(1, 0.8, 3), BUZZARD_COLOR, Enum.Material.SmoothPlastic)
		local wings: { BasePart } = {}
		for _ = 1, 2 do
			table.insert(
				wings,
				livePart(
					folder,
					"Wing",
					Vector3.new(4.4, 0.2, 1.6),
					BUZZARD_COLOR,
					Enum.Material.SmoothPlastic
				)
			)
		end
		table.insert(buzzards, {
			body = body,
			wings = wings,
			center = BUZZARD_CENTERS[(index - 1) % #BUZZARD_CENTERS + 1],
			radius = 55 + math.random() * 35,
			height = 115 + math.random() * 30,
			speed = 10 + math.random() * 4,
			phase = math.random() * math.pi * 2,
			flapAt = math.random() * 6,
		})
	end
end

local function updateBuzzards(now: number)
	for i, b in buzzards do
		-- Lazy thermal circles, alternate birds turning the other way.
		local dirSign = if i % 2 == 0 then -1 else 1
		local angle = b.phase + dirSign * now * b.speed / b.radius
		local pos = b.center
			+ Vector3.new(
				math.cos(angle) * b.radius,
				b.height + math.sin(now * 0.3 + b.phase) * 4,
				math.sin(angle) * b.radius
			)
		local tangent = Vector3.new(-math.sin(angle), 0, math.cos(angle)) * dirSign
		-- Bank into the turn (the inner wing dips).
		local cf = CFrame.lookAt(pos, pos + tangent) * CFrame.Angles(0, 0, -math.rad(18) * dirSign)
		-- Mostly gliding with a slight dihedral; a short burst of flaps every few seconds.
		local cycle = (now + b.flapAt) % 7
		local flap = if cycle < 1.2 then math.sin(cycle * 14) * math.rad(28) else 0
		local lift = math.rad(10) + flap
		table.insert(moveParts, b.body)
		table.insert(moveFrames, cf)
		for k, wing in b.wings do
			local s = if k == 1 then -1 else 1
			table.insert(moveParts, wing)
			table.insert(moveFrames, cf * CFrame.Angles(0, 0, s * lift) * CFrame.new(s * 2.4, 0, 0.2))
		end
	end
end

-- Windmill and ghost lanterns ------------------------------------------------------------------

local function updateRotors(dt: number, at: Vector3)
	if tier() < 2 then
		return
	end
	for _, rotor in rotors do
		if (rotor.pivot.Position - at).Magnitude < 450 then
			rotor.angle = (rotor.angle + dt * 0.9) % (math.pi * 2)
			local spun = rotor.pivot * CFrame.Angles(0, 0, rotor.angle)
			for k, p in rotor.parts do
				table.insert(moveParts, p)
				table.insert(moveFrames, spun * rotor.offsets[k])
			end
		end
	end
end

local lastFogQuality = -1
local function updateFogLanterns(now: number, at: Vector3)
	local q = tier()
	if q ~= lastFogQuality then
		lastFogQuality = q
		for _, f in fogLanterns do
			local mist = f.mist
			if mist then
				mist.Enabled = q >= 2
			end
		end
	end
	if q < 2 then
		return
	end
	for glass, f in fogLanterns do
		if (glass.Position - at).Magnitude < 220 then
			-- Two out-of-step sines read as an uneasy flicker, never a strobe.
			local wobble = math.sin(now * 3.1 + f.phase) * 0.15 + math.sin(now * 7.3 + f.phase * 2) * 0.08
			f.light.Brightness = f.base * (1 + wobble)
		end
	end
end

-- Lifecycle ------------------------------------------------------------------------------------

function Ambience.init()
	folder = Instance.new("Folder")
	folder.Name = "Ambience"
	folder.Parent = Workspace
	zoneGrade = Instance.new("ColorCorrectionEffect")
	zoneGrade.Name = "ZoneGrade"
	zoneGrade.Enabled = false
	zoneGrade.Parent = Lighting
	groundParams.FilterDescendantsInstances = { Workspace.Terrain }
	base.exposure = Lighting.ExposureCompensation
	base.outdoor = Lighting.OutdoorAmbient
	local atm = Lighting:FindFirstChildOfClass("Atmosphere")
	atmosphere = atm
	if atm then
		base.density, base.offset, base.glare, base.haze = atm.Density, atm.Offset, atm.Glare, atm.Haze
		base.color, base.decay = atm.Color, atm.Decay
	end
	buildParticles()
end

function Ambience.start()
	watchTag("Lantern", addLantern)
	watchTag("FogLantern", addFogLantern)
	watchTag("WindmillRotor", addRotor)
	local lastBuzzardSync = -math.huge
	RunService.Heartbeat:Connect(function(dt)
		local now = Workspace:GetServerTimeNow()
		local dusk = updateLight(dt, now)
		updateParticles(dusk)
		if os.clock() - lastBuzzardSync > 2 then
			lastBuzzardSync = os.clock()
			syncBuzzards()
		end
		local at = focus()
		table.clear(moveParts)
		table.clear(moveFrames)
		updateTumbleweeds(dt)
		updateBuzzards(now)
		updateRotors(dt, at)
		updateFogLanterns(now, at)
		if #moveParts > 0 then
			-- One bulk move for every ambient part this frame (no per-part property events).
			Workspace:BulkMoveTo(moveParts, moveFrames, Enum.BulkMoveMode.FireCFrameChanged)
		end
	end)
end

return Ambience
