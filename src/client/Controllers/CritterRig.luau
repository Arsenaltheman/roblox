--!strict
-- Builds a critter model. If a real mesh exists in ReplicatedStorage.Assets.Critters[speciesId]
-- (uploaded from Blender), it's used; otherwise a procedural "toy" version is assembled from the
-- species' look (Config/CritterLooks). Rarity adds an aura; mutations change material and color.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CritterLooks = require("@game/ReplicatedStorage/Shared/Config/CritterLooks")
local Mutations = require("@game/ReplicatedStorage/Shared/Config/Mutations")
local Palette = require("@game/ReplicatedStorage/Shared/Config/Palette")
local Rarities = require("@game/ReplicatedStorage/Shared/Config/Rarities")
local Species = require("@game/ReplicatedStorage/Shared/Config/Species")

local C = Palette.color

local CritterRig = {}

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"

type Ctx = {
	model: Model,
	root: BasePart,
	r: number,
	shape: { number },
	body: Color3,
	accent: Color3,
	bodyParts: { BasePart },
	tier: number,
	-- Height offset for things worn on the head (crown, flame, lantern): above the hat if there is one.
	crest: number,
}

local function weld(part: BasePart, root: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = root
	w.Part1 = part
	w.Parent = part
end

local function piece(
	ctx: Ctx,
	name: string,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	kind: string?
): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.Anchored = false
	p.CastShadow = size.Magnitude > 1.2
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if kind == "sphere" then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	elseif kind == "cylinder" then
		p.Shape = Enum.PartType.Cylinder
	elseif kind == "wedge" then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Wedge
		mesh.Parent = p
	end
	p.CFrame = ctx.root.CFrame * offset
	p.Parent = ctx.model
	weld(p, ctx.root)
	return p
end

-- Coordinates: +Y up, the critter faces -Z.
local function eyes(ctx: Ctx)
	local r, s = ctx.r, ctx.shape
	for side = -1, 1, 2 do
		local base = CFrame.new(side * r * 0.38 * s[1], r * 0.28 * s[2], -r * 0.82 * s[3])
		piece(ctx, "Eye", Vector3.new(r * 0.46, r * 0.52, r * 0.3), base, Color3.new(1, 1, 1), "sphere")
		piece(
			ctx,
			"Pupil",
			Vector3.new(r * 0.24, r * 0.3, r * 0.2),
			base * CFrame.new(0, -r * 0.04, -r * 0.1),
			C("ink"),
			"sphere"
		)
		piece(
			ctx,
			"Shine",
			Vector3.new(r * 0.08, r * 0.08, r * 0.05),
			base * CFrame.new(-side * r * 0.05, r * 0.06, -r * 0.2),
			Color3.new(1, 1, 1),
			"sphere"
		)
	end
	-- Rosy cheeks sell the cuteness.
	for side = -1, 1, 2 do
		piece(
			ctx,
			"Cheek",
			Vector3.new(r * 0.22, r * 0.12, r * 0.1),
			CFrame.new(side * r * 0.62 * s[1], r * 0.0, -r * 0.78 * s[3]),
			Color3.fromRGB(255, 140, 140),
			"sphere"
		).Transparency =
			0.25
	end
end

local function feet(ctx: Ctx, rig: string)
	local r, s = ctx.r, ctx.shape
	local dark = ctx.accent:Lerp(Color3.new(0, 0, 0), 0.35)
	local spots: { { number } } = if rig == "quadruped"
		then { { -0.5, -0.45 }, { 0.5, -0.45 }, { -0.5, 0.45 }, { 0.5, 0.45 } }
		elseif rig == "biped" then { { -0.38, 0 }, { 0.38, 0 } }
		else {}
	for _, spot in spots do
		piece(
			ctx,
			"Foot",
			Vector3.new(r * 0.36, r * 0.3, r * 0.42),
			CFrame.new(spot[1] * r * s[1], -r * 0.92 * s[2], spot[2] * r * s[3]),
			dark,
			"sphere"
		)
	end
end

local FEATURES: { [string]: (Ctx) -> () } = {
	hat = function(ctx)
		local r, s = ctx.r, ctx.shape
		local top = r * 0.92 * s[2]
		-- Rarity reads on the hat: Outlaws (tiers 35-38) wear black, Mythic and up get a gold band.
		local outlaw = ctx.tier >= 35 and ctx.tier <= 38
		local brimColor = if outlaw then C("#1E1B2E") else ctx.accent:Lerp(C("woodDark"), 0.4)
		piece(
			ctx,
			"HatBrim",
			Vector3.new(r * 0.12, r * 1.7, r * 1.7),
			CFrame.new(0, top, 0) * CFrame.Angles(0, 0, math.rad(90)),
			brimColor,
			"cylinder"
		)
		piece(
			ctx,
			"HatCrown",
			Vector3.new(r * 0.55, r * 0.95, r * 0.95),
			CFrame.new(0, top + r * 0.3, 0) * CFrame.Angles(0, 0, math.rad(90)),
			brimColor:Lerp(Color3.new(1, 1, 1), 0.08),
			"cylinder"
		)
		piece(
			ctx,
			"HatBand",
			Vector3.new(r * 0.14, r * 0.98, r * 0.98),
			CFrame.new(0, top + r * 0.1, 0) * CFrame.Angles(0, 0, math.rad(90)),
			if ctx.tier >= 30 then C("gold") else C("red"),
			"cylinder"
		)
	end,
	mustache = function(ctx)
		local r, s = ctx.r, ctx.shape
		for side = -1, 1, 2 do
			piece(
				ctx,
				"Mustache",
				Vector3.new(r * 0.5, r * 0.16, r * 0.18),
				CFrame.new(side * r * 0.24, -r * 0.08 * s[2], -r * 0.93 * s[3])
					* CFrame.Angles(0, 0, math.rad(side * -14)),
				C("ink"),
				"sphere"
			)
		end
	end,
	spikes = function(ctx)
		local r, s = ctx.r, ctx.shape
		for i = 1, 7 do
			local a = i / 7 * math.pi * 2
			local dir = Vector3.new(math.cos(a) * s[1], 0.35, math.sin(a) * s[3]).Unit
			piece(
				ctx,
				"Spike",
				Vector3.new(r * 0.1, r * 0.1, r * 0.34),
				CFrame.lookAt(Vector3.zero, dir) * CFrame.new(0, 0, -r * 1.02),
				ctx.body:Lerp(Color3.new(1, 1, 1), 0.45),
				"sphere"
			)
		end
	end,
	ears = function(ctx)
		local r, s = ctx.r, ctx.shape
		for side = -1, 1, 2 do
			piece(
				ctx,
				"Ear",
				Vector3.new(r * 0.28, r * 0.7, r * 0.2),
				CFrame.new(side * r * 0.45 * s[1], r * 0.95 * s[2], -r * 0.1)
					* CFrame.Angles(0, 0, math.rad(side * -18)),
				ctx.body,
				"sphere"
			)
		end
	end,
	tail = function(ctx)
		local r, s = ctx.r, ctx.shape
		piece(
			ctx,
			"Tail",
			Vector3.new(r * 0.3, r * 0.3, r * 0.75),
			CFrame.new(0, r * 0.1, r * 1.0 * s[3]) * CFrame.Angles(math.rad(-25), 0, 0),
			ctx.accent,
			"sphere"
		)
	end,
	bandana = function(ctx)
		local r, s = ctx.r, ctx.shape
		piece(
			ctx,
			"Bandana",
			-- The body's cross-section at this height is ~0.91x its widest, so this hugs the surface.
			Vector3.new(r * 0.22, r * 1.9 * s[1], r * 1.9 * s[3]),
			CFrame.new(0, -r * 0.42 * s[2], 0) * CFrame.Angles(0, 0, math.rad(90)),
			C("red"),
			"cylinder"
		)
		piece(
			ctx,
			"BandanaKnot",
			Vector3.new(r * 0.5, r * 0.4, r * 0.15),
			CFrame.new(0, -r * 0.55 * s[2], -r * 0.92 * s[3]) * CFrame.Angles(0, 0, math.rad(180)),
			C("red"),
			"wedge"
		)
	end,
	boots = function(ctx)
		local r, s = ctx.r, ctx.shape
		for side = -1, 1, 2 do
			piece(
				ctx,
				"Boot",
				Vector3.new(r * 0.38, r * 0.4, r * 0.4),
				CFrame.new(side * r * 0.38 * s[1], -r * 0.8 * s[2], 0) * CFrame.Angles(0, 0, math.rad(90)),
				C("woodDark"),
				"cylinder"
			)
		end
	end,
	badge = function(ctx)
		local r, s = ctx.r, ctx.shape
		piece(
			ctx,
			"Badge",
			Vector3.new(r * 0.06, r * 0.36, r * 0.36),
			CFrame.new(r * 0.3, -r * 0.3 * s[2], -r * 0.9 * s[3]) * CFrame.Angles(0, math.rad(90), 0),
			C("gold"),
			"cylinder"
		).Material =
			Enum.Material.Metal
	end,
	horns = function(ctx)
		local r, s = ctx.r, ctx.shape
		for side = -1, 1, 2 do
			piece(
				ctx,
				"Horn",
				Vector3.new(r * 0.6, r * 0.18, r * 0.18),
				CFrame.new(side * r * 0.6 * s[1], r * 0.75 * s[2], -r * 0.2)
					* CFrame.Angles(0, 0, math.rad(side * 35)),
				C("cream"),
				"cylinder"
			)
		end
	end,
	shell = function(ctx)
		local r, s = ctx.r, ctx.shape
		piece(
			ctx,
			"Shell",
			Vector3.new(r * 1.5 * s[1], r * 1.3 * s[2], r * 1.3 * s[3]),
			CFrame.new(0, r * 0.35 * s[2], r * 0.35 * s[3]),
			ctx.accent,
			"sphere"
		)
	end,
	beak = function(ctx)
		local r, s = ctx.r, ctx.shape
		piece(
			ctx,
			"Beak",
			Vector3.new(r * 0.4, r * 0.24, r * 0.45),
			CFrame.new(0, -r * 0.05, -r * 1.02 * s[3]) * CFrame.Angles(math.rad(-90), 0, 0),
			Color3.fromRGB(255, 160, 40),
			"wedge"
		)
	end,
	-- Three fanned feathers per side, raised and swept back, so wings read from far away.
	wings = function(ctx)
		local r, s = ctx.r, ctx.shape
		for side = -1, 1, 2 do
			for i = 0, 2 do
				piece(
					ctx,
					"Wing",
					Vector3.new(r * 0.16, r * (1.15 - i * 0.2), r * 0.42),
					CFrame.new(side * r * 1.0 * s[1], r * (0.35 + i * 0.05) * s[2], r * (0.05 + i * 0.22))
						* CFrame.Angles(math.rad(-15 - i * 18), 0, math.rad(side * -35)),
					ctx.accent:Lerp(Color3.new(1, 1, 1), i * 0.12),
					"sphere"
				)
			end
		end
	end,
	flame = function(ctx)
		local r, s = ctx.r, ctx.shape
		for i, color in { ctx.accent, Color3.fromRGB(255, 200, 70), Color3.fromRGB(255, 245, 190) } do
			local tuft = piece(
				ctx,
				"Flame",
				Vector3.new(r * (0.6 - i * 0.14), r * (0.8 - i * 0.12), r * (0.6 - i * 0.14)),
				CFrame.new(0, r * (0.95 + i * 0.12) * s[2] + ctx.crest, r * 0.15),
				color,
				"sphere"
			)
			tuft.Material = Enum.Material.Neon
		end
		local fire = Instance.new("Fire")
		fire.Size = ctx.r * 1.6
		fire.Heat = 4
		fire.Color = ctx.accent
		fire.SecondaryColor = Color3.fromRGB(255, 230, 120)
		fire.Parent = ctx.root
	end,
	-- Tilted gold band with five points and a ruby.
	crown = function(ctx)
		local r, s = ctx.r, ctx.shape
		local base = CFrame.new(0, r * 1.02 * s[2] + ctx.crest, 0) * CFrame.Angles(0, 0, math.rad(-8))
		local band = piece(
			ctx,
			"Crown",
			Vector3.new(r * 0.3, r * 0.85, r * 0.85),
			base * CFrame.Angles(0, 0, math.rad(90)),
			C("gold"),
			"cylinder"
		)
		band.Material = Enum.Material.Metal
		for i = 1, 5 do
			local a = (i - 1) / 5 * math.pi * 2
			local point = piece(
				ctx,
				"CrownPoint",
				Vector3.new(r * 0.16, r * 0.34, r * 0.16),
				base * CFrame.new(math.cos(a) * r * 0.36, r * 0.24, math.sin(a) * r * 0.36),
				C("gold"),
				"sphere"
			)
			point.Material = Enum.Material.Metal
		end
		local gem = piece(
			ctx,
			"CrownGem",
			Vector3.new(r * 0.18, r * 0.18, r * 0.1),
			base * CFrame.new(0, 0, -r * 0.43),
			C("red"),
			"sphere"
		)
		gem.Material = Enum.Material.Neon
	end,
	-- A puffy cloud to ride on, ringing the bottom of the body.
	cloud = function(ctx)
		local r, s = ctx.r, ctx.shape
		for i = 0, 6 do
			local a = i / 7 * math.pi * 2
			local d = r * (0.84 + 0.16 * math.sin(i * 2.3))
			piece(
				ctx,
				"Cloud",
				Vector3.new(d, d * 0.8, d),
				CFrame.new(math.cos(a) * r * 0.95 * s[1], -r * 0.78 * s[2], math.sin(a) * r * 0.95 * s[3]),
				Color3.new(1, 1, 1),
				"sphere"
			)
		end
	end,
	-- A long tail that sweeps out to one side and curls up (same curve as tools/blender/build_critters.py).
	longtail = function(ctx)
		local r, s = ctx.r, ctx.shape
		local steps = 12
		local tip = Vector3.zero
		for i = 0, steps do
			local t = i / steps
			local a = t * 2.6
			local d = r * (0.68 - t * 0.44)
			tip = Vector3.new(
				r * 0.6 * s[1] + math.sin(a) * r * 0.75,
				r * 0.3 + t * t * r * 1.1 - r * s[2],
				r * 0.55 * s[3] + math.cos(a) * r * 0.2
			)
			piece(
				ctx,
				"Tail",
				Vector3.new(d, d, d),
				CFrame.new(tip),
				ctx.body:Lerp(ctx.accent, t * 0.4),
				"sphere"
			)
		end
		piece(
			ctx,
			"Rattle",
			Vector3.new(r * 0.22, r * 0.36, r * 0.22),
			CFrame.new(tip + Vector3.new(0, r * 0.2, 0)),
			ctx.accent,
			"sphere"
		)
	end,
	glow = function(ctx)
		local light = Instance.new("PointLight")
		light.Color = ctx.accent
		light.Range = ctx.r * 6
		light.Brightness = 1.2
		light.Parent = ctx.root
	end,
	stack = function(ctx)
		local r = ctx.r
		for i = 1, 3 do
			piece(
				ctx,
				"Pancake",
				Vector3.new(r * 0.25, r * 1.9, r * 1.9),
				CFrame.new(0, -r * 0.55 + i * r * 0.28, 0) * CFrame.Angles(0, 0, math.rad(90)),
				C("#E9B26A"):Lerp(C("#8A4E1F"), i * 0.1),
				"cylinder"
			)
		end
		piece(
			ctx,
			"Butter",
			Vector3.new(r * 0.35, r * 0.15, r * 0.35),
			CFrame.new(0, r * 0.4, 0),
			Color3.fromRGB(255, 236, 140)
		)
	end,
	lantern = function(ctx)
		local r, s = ctx.r, ctx.shape
		local bulb = piece(
			ctx,
			"Lantern",
			Vector3.new(r * 0.55, r * 0.7, r * 0.55),
			CFrame.new(0, r * 1.1 * s[2] + ctx.crest, 0),
			Color3.fromRGB(255, 210, 110),
			"sphere"
		)
		bulb.Material = Enum.Material.Neon
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 200, 120)
		light.Range = r * 7
		light.Parent = bulb
	end,
	wheels = function(ctx)
		local r, s = ctx.r, ctx.shape
		for side = -1, 1, 2 do
			piece(
				ctx,
				"Wheel",
				Vector3.new(r * 0.22, r * 1.1, r * 1.1),
				CFrame.new(side * r * 0.95 * s[1], -r * 0.45 * s[2], 0),
				C("woodDark"),
				"cylinder"
			)
		end
	end,
}

local function applyMutation(ctx: Ctx, mutation: string?)
	if not mutation or mutation == "" then
		return
	end
	local m = Mutations.byId[mutation]
	if not m then
		return
	end
	local tint = C(m.color)
	for _, p in ctx.bodyParts do
		if mutation == "Gold" then
			p.Color = tint
			p.Material = Enum.Material.Foil
			p.Reflectance = 0.15
		elseif mutation == "Diamond" then
			p.Color = tint
			p.Material = Enum.Material.Glass
			p.Transparency = 0.15
		elseif mutation == "Frosty" then
			p.Color = tint
			p.Material = Enum.Material.Ice
		elseif mutation == "Electric" then
			p.Color = p.Color:Lerp(tint, 0.6)
		elseif mutation == "Molten" then
			p.Material = Enum.Material.CrackedLava
			p.Color = p.Color:Lerp(Color3.fromRGB(255, 90, 20), 0.5)
		elseif mutation == "Ghost" then
			p.Color = tint
			p.Transparency = 0.45
		elseif mutation == "Cosmic" then
			p.Color = p.Color:Lerp(tint, 0.7)
			p.Material = Enum.Material.Neon
		elseif mutation == "Rainbow" then
			p:SetAttribute("Rainbow", true)
		end
	end
	ctx.model:SetAttribute("Mutation", mutation)
end

-- Particle aura by rarity (and mutation flair). Quality tier scales emission.
local function aura(ctx: Ctx, rarityIndex: number, mutation: string?, quality: number)
	if quality <= 0 then
		return
	end
	local rate = ({ 0, 0, 3, 6, 10, 14, 18, 22 })[rarityIndex] or 0
	local color = C(Rarities.list[rarityIndex].color)
	if mutation and mutation ~= "" and Mutations.byId[mutation] then
		rate = math.max(rate, 6)
		color = C(Mutations.byId[mutation].color)
	end
	if rate <= 0 then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "Aura"
	attachment.Parent = ctx.root
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = SPARKLE
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 1
	emitter.Size =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, ctx.r * 0.35), NumberSequenceKeypoint.new(1, 0) })
	emitter.Transparency =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	emitter.Lifetime = NumberRange.new(0.8, 1.4)
	emitter.Speed = NumberRange.new(0.6, 1.6)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rate = rate * (if quality >= 3 then 1 else 0.5)
	emitter.LockedToPart = false
	emitter.Parent = attachment
	if rarityIndex >= 5 and quality >= 2 then
		-- Legendary+: a soft light column.
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = ctx.r * 8
		light.Brightness = 1.5
		light.Parent = ctx.root
	end
	if (rarityIndex >= 6 or mutation == "Molten") and quality >= 2 then
		local flames = Instance.new("ParticleEmitter")
		flames.Texture = FIRE
		flames.Color = ColorSequence.new(color)
		flames.LightEmission = 0.8
		flames.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, ctx.r * 0.6),
			NumberSequenceKeypoint.new(1, 0),
		})
		flames.Lifetime = NumberRange.new(0.5, 0.9)
		flames.Speed = NumberRange.new(1, 2)
		flames.Rate = 10
		flames.Parent = attachment
	end
end

-- Builds a critter. `size` is the body diameter in studs before tier scaling.
function CritterRig.build(
	speciesId: string,
	tier: number,
	mutation: string?,
	quality: number?,
	size: number?
): Model
	local q = quality or 2
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local meshes = assets and assets:FindFirstChild("Critters")
	local mesh = meshes and meshes:FindFirstChild(speciesId)
	local model = Instance.new("Model")
	model.Name = speciesId
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(0.2, 0.2, 0.2)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.Parent = model
	model.PrimaryPart = root

	local species = Species.byId[speciesId]
	local look: any = CritterLooks[speciesId] or { body = "#C9A26B", accent = "#5B3A26", features = {} }
	local r = (size or 2.4) / 2 * (1 + math.min(tier, 40) * 0.012)
	local ctx: Ctx = {
		model = model,
		root = root,
		r = r,
		shape = look.shape or { 1, 1, 1 },
		body = C(look.body),
		accent = C(look.accent),
		bodyParts = {},
		tier = tier,
		crest = if table.find(look.features, "hat") then r * 0.5 else 0,
	}

	if mesh and mesh:IsA("Model") then
		local clone = mesh:Clone()
		clone:PivotTo(root.CFrame)
		for _, d in clone:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = false
				d.CanCollide = false
				d.Massless = true
				weld(d, root)
				table.insert(ctx.bodyParts, d)
			end
		end
		clone.Parent = model
	else
		local s = ctx.shape
		local body = piece(
			ctx,
			"Body",
			Vector3.new(r * 2 * s[1], r * 2 * s[2], r * 2 * s[3]),
			CFrame.new(),
			ctx.body,
			"sphere"
		)
		table.insert(ctx.bodyParts, body)
		-- Lighter belly patch.
		piece(
			ctx,
			"Belly",
			Vector3.new(r * 1.2 * s[1], r * 1.1 * s[2], r * 0.4),
			CFrame.new(0, -r * 0.2 * s[2], -r * 0.7 * s[3]),
			ctx.body:Lerp(Color3.new(1, 1, 1), 0.35),
			"sphere"
		)
		eyes(ctx)
		feet(ctx, if species then species.rig else "blob")
		for _, feature in look.features do
			local build = FEATURES[feature]
			if build then
				build(ctx)
			end
		end
	end
	applyMutation(ctx, mutation)
	aura(ctx, Rarities.indexOf(Rarities.forTier(math.clamp(tier, 1, Rarities.maxTier)).id), mutation, q)
	model:SetAttribute("Radius", r)
	model:SetAttribute("Species", speciesId)
	return model
end

-- Per-frame idle animation: bob, squash-ish tilt and a slow turn. `t` = time, `seed` desyncs critters.
function CritterRig.pose(base: CFrame, t: number, seed: number, radius: number): CFrame
	local bob = math.abs(math.sin(t * 3 + seed)) * radius * 0.25
	local tilt = math.sin(t * 2.2 + seed) * 0.08
	local turn = math.sin(t * 0.5 + seed) * 0.4
	return base * CFrame.new(0, radius + bob, 0) * CFrame.Angles(0, turn, tilt)
end

-- Rainbow parts cycle hue.
local rainbowParts: { [Model]: { BasePart } } = setmetatable({}, { __mode = "k" }) :: any

function CritterRig.updateRainbow(model: Model, t: number)
	if model:GetAttribute("Mutation") ~= "Rainbow" then
		return
	end
	local hue = (t * 0.25) % 1
	-- The rainbow parts are found once per model and cached (this runs every frame).
	local parts = rainbowParts[model]
	if not parts then
		local found: { BasePart } = {}
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") and d:GetAttribute("Rainbow") then
				table.insert(found, d)
			end
		end
		rainbowParts[model] = found
		parts = found
	end
	for _, p in parts :: { BasePart } do
		p.Color = Color3.fromHSV(hue, 0.75, 1)
	end
end

return CritterRig
