--!strict
-- World effects: coin bursts, floating cash numbers, lasso beams, WANTED glow, alarms, stickers,
-- weather sky moods. Scaled by quality tier and Reduced Motion.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Mutations = require("@game/ReplicatedStorage/Shared/Config/Mutations")
local Palette = require("@game/ReplicatedStorage/Shared/Config/Palette")
local NumberFormat = require("@game/ReplicatedStorage/Shared/Sim/NumberFormat")
local Net = require("@game/ReplicatedStorage/Shared/Net/Net")
local Quality = require("./Quality")
local Sound = require("./Sound")
local Store = require("../Store")

local C = Palette.color
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"

local Vfx = {}

local localPlayer = Players.LocalPlayer
local effects: Folder

local function anchoredPart(size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.Neon
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = effects
	return p
end

-- One-shot particle burst at a position.
function Vfx.burst(position: Vector3, color: Color3, count: number, size: number?, speed: number?)
	local q = Store.quality()
	local holder = anchoredPart(Vector3.new(0.2, 0.2, 0.2), CFrame.new(position), color)
	holder.Transparency = 1
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = SPARKLE
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 1
	emitter.Size =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, size or 1.2), NumberSequenceKeypoint.new(1, 0) })
	emitter.Transparency =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	emitter.Lifetime = NumberRange.new(0.5, 1.1)
	emitter.Speed = NumberRange.new((speed or 14) * 0.5, speed or 14)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = Vector3.new(0, -20, 0)
	emitter.Drag = 2
	emitter.Rate = 0
	emitter.Parent = holder
	emitter:Emit(math.max(4, math.floor(count * (if q >= 3 then 1 elseif q == 2 then 0.6 else 0.3))))
	task.delay(1.5, function()
		holder:Destroy()
	end)
end

-- "+$1.2K" that pops up and floats away.
function Vfx.floatText(position: Vector3, text: string, color: Color3)
	local holder = anchoredPart(Vector3.new(0.2, 0.2, 0.2), CFrame.new(position), color)
	holder.Transparency = 1
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(6, 2)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.FontFace = Font.fromEnum(Enum.Font.LuckiestGuy)
	label.TextScaled = true
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = C("ink")
	stroke.Parent = label
	local scale = Instance.new("UIScale")
	scale.Scale = 0.3
	scale.Parent = label
	label.Parent = gui
	gui.Parent = holder
	TweenService
		:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
	TweenService:Create(
		holder,
		TweenInfo.new(1.4, Enum.EasingStyle.Quad),
		{ CFrame = holder.CFrame + Vector3.new(0, 6, 0) }
	):Play()
	task.delay(0.9, function()
		TweenService:Create(label, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
		TweenService:Create(stroke, TweenInfo.new(0.5), { Transparency = 1 }):Play()
	end)
	task.delay(1.5, function()
		holder:Destroy()
	end)
end

-- Rope beam between two points (the lasso).
function Vfx.lasso(from: Vector3, to: Vector3, color: Color3?)
	local a = anchoredPart(Vector3.new(0.2, 0.2, 0.2), CFrame.new(from), Color3.new())
	local b = anchoredPart(Vector3.new(0.2, 0.2, 0.2), CFrame.new(to), Color3.new())
	a.Transparency, b.Transparency = 1, 1
	local a0 = Instance.new("Attachment")
	a0.Parent = a
	local a1 = Instance.new("Attachment")
	a1.Parent = b
	local beam = Instance.new("Beam")
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Width0 = 0.5
	beam.Width1 = 0.5
	beam.CurveSize0 = 6
	beam.CurveSize1 = -4
	beam.Color = ColorSequence.new(color or C("woodLight"))
	beam.LightEmission = 0.3
	beam.FaceCamera = true
	beam.Segments = 20
	beam.Parent = a
	-- Loop at the target end
	local loop = anchoredPart(
		Vector3.new(0.4, 4, 4),
		CFrame.new(to) * CFrame.Angles(0, 0, math.rad(90)),
		color or C("woodLight"),
		Enum.Material.Fabric
	)
	loop.Shape = Enum.PartType.Cylinder
	loop.Transparency = 0.2
	Vfx.burst(to, C("cream"), 18, 1, 10)
	Sound.play("lassoCatch", 0.08)
	task.delay(0.6, function()
		TweenService:Create(loop, TweenInfo.new(0.3), { Transparency = 1 }):Play()
		beam.Enabled = false
	end)
	task.delay(1, function()
		a:Destroy()
		b:Destroy()
		loop:Destroy()
	end)
end

-- Red edge flash (theft alarm) via ColorCorrection pulse.
local alarmCorrection: ColorCorrectionEffect
function Vfx.alarm()
	if Quality.reducedMotion() then
		Sound.play("alarm")
		return
	end
	alarmCorrection.TintColor = Color3.fromRGB(255, 170, 160)
	TweenService
		:Create(
			alarmCorrection,
			TweenInfo.new(0.9, Enum.EasingStyle.Quad),
			{ TintColor = Color3.new(1, 1, 1) }
		)
		:Play()
	Sound.play("alarm")
end

local function playerRoot(userId: number): BasePart?
	local player = Players:GetPlayerByUserId(userId)
	local character = player and player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- WANTED glow on thieves (Highlight is pooled: toggled, never destroyed per frame).
local highlights: { [Player]: Highlight } = {}
local function updateWanted(player: Player)
	local wanted = player:GetAttribute("Wanted") == true
	local character = player.Character
	local h = highlights[player]
	if wanted and character then
		if not h then
			local created = Instance.new("Highlight")
			created.FillColor = C("red")
			created.OutlineColor = Color3.fromRGB(255, 230, 120)
			created.FillTransparency = 0.6
			created.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			highlights[player] = created
			h = created
		end
		local highlight = h :: Highlight
		highlight.Adornee = character
		highlight.Parent = effects
		highlight.Enabled = true
	elseif h then
		h.Enabled = false
	end
end

local stickerGlyphs = { "🤠", "😂", "😡", "🔥", "💰", "👍", "😱", "🐎" }

local function onFx(kind: string, value: number, position: Vector3?)
	local character = localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if kind == "collect" then
		if root then
			Vfx.burst(root.Position, C("gold"), 30, 1.2, 18)
			Vfx.floatText(
				root.Position + Vector3.new(0, 4, 0),
				"+" .. NumberFormat.cash(value),
				Color3.fromRGB(140, 235, 100)
			)
		end
		Sound.play("collect", 0.06)
	elseif kind == "lasso" then
		local from = playerRoot(value)
		if from and position then
			Vfx.lasso(from.Position, position)
		end
	elseif kind == "wanted" or kind == "stealFailed" then
		local p = Players:GetPlayerByUserId(value)
		if p then
			updateWanted(p)
		end
		if kind == "stealFailed" then
			Sound.play("caught")
		end
	elseif kind == "alarm" then
		Vfx.alarm()
	elseif kind == "robbed" then
		Vfx.alarm()
		Sound.play("stolen")
		Sound.announce("ann_thief")
	elseif kind == "lock" then
		Sound.play("lock")
		if root then
			Vfx.burst(root.Position, C("red"), 16, 1, 8)
		end
	elseif kind == "egg" then
		Sound.play("eggWobble")
	elseif kind == "mutate" then
		if root then
			Vfx.burst(root.Position + Vector3.new(0, 3, 0), C("gold"), 40, 1.5, 20)
		end
	elseif kind == "giftReady" then
		Sound.play("giftReady")
	elseif kind == "grabStart" then
		Store.grab({ started = os.clock(), duration = value })
	elseif kind == "caught" then
		Store.grab(nil)
		Sound.play("caught")
		Vfx.alarm()
	elseif kind == "sticker" and position then
		local glyph = stickerGlyphs[value] or "🤠"
		Vfx.floatText(position, glyph, Color3.new(1, 1, 1))
	elseif kind == "lockpick" then
		Sound.play("lock")
	end
end

-- Weather moods: tint + camera-space particles.
local weatherEmitter: ParticleEmitter
local weatherHolder: Part
local function setWeather(mutation: string)
	Store.weather(mutation)
	local grade = Lighting:FindFirstChild("Grade") :: ColorCorrectionEffect?
	local tint = Color3.new(1, 0.97, 0.92)
	if mutation ~= "" then
		local m = Mutations.byId[mutation]
		if m then
			tint = Color3.new(1, 1, 1):Lerp(C(m.color), 0.25)
			weatherEmitter.Color = ColorSequence.new(C(m.color))
			weatherEmitter.Rate = if Store.quality() >= 2 then 60 else 20
			Sound.play("weatherStart")
			Sound.announce("ann_weather")
		end
	else
		weatherEmitter.Rate = 0
	end
	if grade then
		TweenService:Create(grade, TweenInfo.new(2.5), { TintColor = tint }):Play()
	end
end

function Vfx.init()
	effects = Instance.new("Folder")
	effects.Name = "Effects"
	effects.Parent = Workspace
	alarmCorrection = Instance.new("ColorCorrectionEffect")
	alarmCorrection.Name = "Alarm"
	alarmCorrection.Parent = Lighting
	weatherHolder = anchoredPart(Vector3.new(60, 1, 60), CFrame.new(0, 40, 0), Color3.new())
	weatherHolder.Transparency = 1
	weatherEmitter = Instance.new("ParticleEmitter")
	weatherEmitter.Texture = SPARKLE
	weatherEmitter.LightEmission = 0.8
	weatherEmitter.Size = NumberSequence.new(0.5, 0.2)
	weatherEmitter.Lifetime = NumberRange.new(3, 5)
	weatherEmitter.Speed = NumberRange.new(8, 14)
	weatherEmitter.EmissionDirection = Enum.NormalId.Bottom
	weatherEmitter.Rate = 0
	weatherEmitter.Parent = weatherHolder
end

function Vfx.start()
	Net.listen("Fx", onFx)
	for _, player in Players:GetPlayers() do
		player:GetAttributeChangedSignal("Wanted"):Connect(function()
			updateWanted(player)
		end)
		updateWanted(player)
	end
	Players.PlayerAdded:Connect(function(player)
		player:GetAttributeChangedSignal("Wanted"):Connect(function()
			updateWanted(player)
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		local h = highlights[player]
		if h then
			h:Destroy()
			highlights[player] = nil
		end
	end)
	Workspace:GetAttributeChangedSignal("Weather"):Connect(function()
		setWeather((Workspace:GetAttribute("Weather") :: string?) or "")
	end)
	setWeather((Workspace:GetAttribute("Weather") :: string?) or "")
	local function syncLuck()
		Store.serverLuck((Workspace:GetAttribute("ServerLuck") :: number?) or 1)
	end
	Workspace:GetAttributeChangedSignal("ServerLuck"):Connect(syncLuck)
	syncLuck()
	-- Weather particles follow the camera.
	RunService.RenderStepped:Connect(function()
		local camera = Workspace.CurrentCamera
		if camera then
			weatherHolder.CFrame = CFrame.new(camera.CFrame.Position + Vector3.new(0, 30, 0))
		end
		Store.activeMinutes((localPlayer:GetAttribute("ActiveMinutes") :: number?) or 0)
	end)
end

return Vfx
