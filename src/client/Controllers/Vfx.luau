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
local Rarities = require("@game/ReplicatedStorage/Shared/Config/Rarities")
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

-- Fireworks: rockets shoot up from `position` and burst in `color` (plus gold). Used for heist
-- deliveries, big reveals and the login show.
function Vfx.fireworks(position: Vector3, color: Color3, rockets: number?)
	local q = Store.quality()
	local count = math.max(2, math.floor((rockets or 5) * (if q >= 2 then 1 else 0.5)))
	for i = 1, count do
		task.delay((i - 1) * 0.18, function()
			local offset = Vector3.new(math.random(-8, 8), 0, math.random(-8, 8))
			local peak = position + offset + Vector3.new(0, 16 + math.random() * 10, 0)
			local rocket = anchoredPart(
				Vector3.new(0.5, 0.5, 0.5),
				CFrame.new(position + offset),
				Color3.new(1, 0.9, 0.6)
			)
			local trail = Instance.new("Trail")
			local a0 = Instance.new("Attachment")
			a0.Position = Vector3.new(0, 0.25, 0)
			a0.Parent = rocket
			local a1 = Instance.new("Attachment")
			a1.Position = Vector3.new(0, -0.25, 0)
			a1.Parent = rocket
			trail.Attachment0, trail.Attachment1 = a0, a1
			trail.Lifetime = 0.35
			trail.LightEmission = 1
			trail.Color = ColorSequence.new(Color3.fromRGB(255, 220, 140))
			trail.Parent = rocket
			TweenService
				:Create(rocket, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					CFrame = CFrame.new(peak),
				})
				:Play()
			task.delay(0.55, function()
				rocket:Destroy()
				Vfx.burst(peak, if i % 2 == 0 then C("gold") else color, 60, 1.6, 34)
				local flash = anchoredPart(Vector3.new(1, 1, 1), CFrame.new(peak), color)
				flash.Transparency = 1
				local light = Instance.new("PointLight")
				light.Color = color
				light.Range = 40
				light.Brightness = 4
				light.Parent = flash
				TweenService:Create(light, TweenInfo.new(0.6), { Brightness = 0 }):Play()
				task.delay(0.7, function()
					flash:Destroy()
				end)
			end)
		end)
	end
end

-- Camera shake through the humanoid's camera offset (respects Reduced Motion).
function Vfx.shake(strength: number, duration: number)
	if Quality.reducedMotion() then
		return
	end
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local started = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local elapsed = os.clock() - started
		if elapsed >= duration or not humanoid.Parent then
			humanoid.CameraOffset = Vector3.zero
			connection:Disconnect()
			return
		end
		local falloff = 1 - elapsed / duration
		humanoid.CameraOffset = Vector3.new(
			(math.random() - 0.5) * strength * falloff,
			(math.random() - 0.5) * strength * falloff,
			(math.random() - 0.5) * strength * falloff
		)
	end)
end

-- A thick cloud of smoke that hangs for a few seconds (Smoke Bomb).
function Vfx.smoke(position: Vector3, seconds: number)
	local holder = anchoredPart(Vector3.new(6, 1, 6), CFrame.new(position), Color3.new(1, 1, 1))
	holder.Transparency = 1
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(200, 205, 215), Color3.fromRGB(120, 125, 140))
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 4), NumberSequenceKeypoint.new(1, 14) })
	emitter.Transparency =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	emitter.Lifetime = NumberRange.new(2, 3.5)
	emitter.Speed = NumberRange.new(3, 8)
	emitter.SpreadAngle = Vector2.new(180, 30)
	emitter.RotSpeed = NumberRange.new(-40, 40)
	emitter.Rate = if Store.quality() >= 2 then 40 else 18
	emitter.Parent = holder
	emitter:Emit(30)
	task.delay(seconds, function()
		emitter.Enabled = false
	end)
	task.delay(seconds + 4, function()
		holder:Destroy()
	end)
end

-- An expanding ring on the ground (shockwaves).
function Vfx.ring(position: Vector3, color: Color3, radius: number)
	local ring =
		anchoredPart(Vector3.new(0.3, 2, 2), CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)), color)
	ring.Shape = Enum.PartType.Cylinder
	ring.Transparency = 0.2
	TweenService:Create(ring, TweenInfo.new(0.45, Enum.EasingStyle.Quad), {
		Size = Vector3.new(0.3, radius * 2, radius * 2),
		Transparency = 1,
	}):Play()
	task.delay(0.5, function()
		ring:Destroy()
	end)
end

-- "+$1.2K" that pops up and floats away.
function Vfx.floatText(position: Vector3, text: string, color: Color3)
	local holder = anchoredPart(Vector3.new(0.2, 0.2, 0.2), CFrame.new(position), color)
	holder.Transparency = 1
	local gui = Instance.new("BillboardGui")
	-- Studs-sized and not always-on-top, so it stays a small pop in the world instead of a huge
	-- number drawn over the HUD.
	gui.Size = UDim2.fromScale(3.2, 1.1)
	gui.StudsOffset = Vector3.new(1.5, 0, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 80
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
		{ CFrame = holder.CFrame + Vector3.new(0, 2.5, 0) }
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
	elseif kind == "heistGrab" and position then
		Vfx.burst(position + Vector3.new(0, 2, 0), C("gold"), 40, 1.4, 22)
		if value == localPlayer.UserId then
			Sound.play("lassoCatch")
			Sound.play("alarm")
			Vfx.shake(0.6, 0.35)
			Store.toast("RUN IT HOME! Guards are coming!")
		end
	elseif kind == "heistDeliver" and position then
		local rarityColor = C(Rarities.forTier(math.max(1, value)).color)
		local big = Rarities.indexOf(Rarities.forTier(math.max(1, value)).id) >= 4
		Vfx.fireworks(position, rarityColor, if big then 9 else 4)
		Vfx.burst(position + Vector3.new(0, 3, 0), C("gold"), 80, 1.5, 26)
		Sound.play("collect")
		if big then
			Sound.play("frontier")
		end
	elseif kind == "tackle" and position then
		Vfx.burst(position, C("red"), 50, 1.4, 24)
		Sound.play("caught")
		if value == localPlayer.UserId then
			Vfx.shake(2.2, 0.5)
			Vfx.alarm()
		end
	elseif kind == "guardAlert" and position then
		if root and (root.Position - position).Magnitude < 90 then
			Vfx.floatText(position + Vector3.new(0, 7, 0), "!", C("red"))
			Sound.play("whistle", 0.2)
		end
	elseif kind == "smoke" and position then
		Vfx.smoke(position, 5)
		Vfx.burst(position, Color3.fromRGB(220, 220, 230), 40, 2, 16)
		Sound.play("doors", 0.1)
		if value == localPlayer.UserId then
			Store.toast("POOF! Guards lost you. RUN!")
		end
	elseif kind == "tumbleweed" and position then
		Vfx.ring(position, Color3.fromRGB(214, 170, 110), 16)
		Vfx.burst(position, Color3.fromRGB(214, 170, 110), 70, 1.8, 30)
		Vfx.floatText(position + Vector3.new(0, 5, 0), "BOOM!", C("gold"))
		Sound.play("caught")
		if root and (root.Position - position).Magnitude < 40 then
			Vfx.shake(1.6, 0.4)
		end
	elseif kind == "trapSet" then
		if root then
			Vfx.burst(root.Position - Vector3.new(0, 2.5, 0), Color3.fromRGB(150, 150, 160), 20, 1, 10)
		end
		Sound.play("lock")
	elseif kind == "trapSnap" and position then
		Vfx.burst(position + Vector3.new(0, 1, 0), C("red"), 60, 1.5, 26)
		Vfx.ring(position, C("red"), 10)
		Vfx.floatText(position + Vector3.new(0, 5, 0), "SNAP!", C("red"))
		Sound.play("lock")
		Sound.play("caught")
		if value == localPlayer.UserId then
			Vfx.shake(2.5, 0.5)
			Vfx.alarm()
		end
	elseif kind == "gearBought" then
		if root then
			Vfx.fireworks(root.Position, C("gold"), 4)
			Vfx.floatText(root.Position + Vector3.new(0, 5, 0), "NEW GEAR!", C("gold"))
		end
		Sound.play("frontier")
	elseif kind == "crateDrop" and position then
		local rarity = Rarities.forTier(math.max(1, value))
		Vfx.ring(position, C(rarity.color), 12)
		Vfx.burst(position + Vector3.new(0, 2, 0), C(rarity.color), 50, 1.6, 24)
		if root and (root.Position - position).Magnitude < 120 then
			Sound.play("strongboxOpen", 0.1)
		end
	elseif kind == "eventStart" then
		Sound.play("goldenExpress")
		Vfx.fireworks(Vector3.new(0, 14, 72), C("gold"), 10)
		Vfx.shake(0.8, 0.4)
	elseif kind == "spinEarned" then
		Sound.play("giftReady")
		if root then
			Vfx.burst(root.Position + Vector3.new(0, 3, 0), C("gold"), 30, 1.2, 16)
		end
	elseif kind == "bootsUp" then
		if root then
			Vfx.burst(root.Position, C("sky"), 60, 1.3, 22)
			Vfx.floatText(root.Position + Vector3.new(0, 5, 0), "SPEED UP!", C("sky"))
			Vfx.shake(0.5, 0.3)
		end
		Sound.play("frontier")
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
	-- Speed lines: white streaks at the screen edges when you're running fast (boots, carrying).
	local gui = Instance.new("ScreenGui")
	gui.Name = "SpeedLines"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = -1
	local lines: { Frame } = {}
	for i = 1, 16 do
		local line = Instance.new("Frame")
		line.BackgroundColor3 = Color3.new(1, 1, 1)
		line.BorderSizePixel = 0
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		line.BackgroundTransparency = 1
		line.Parent = gui
		lines[i] = line
	end
	gui.Parent = localPlayer:WaitForChild("PlayerGui")
	RunService.RenderStepped:Connect(function()
		local character = localPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local speed = if root
			then Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z).Magnitude
			else 0
		local amount = math.clamp((speed - 21) / 12, 0, 1)
		if Quality.reducedMotion() then
			amount = 0
		end
		for i, line in lines do
			if amount <= 0 then
				line.BackgroundTransparency = 1
			else
				-- Each frame, lines respawn at random spots around the edge, pointing at the centre.
				local angle = (i / #lines) * math.pi * 2 + math.random() * 0.3
				local dist = 0.42 + math.random() * 0.12
				line.Position =
					UDim2.fromScale(0.5 + math.cos(angle) * dist, 0.5 + math.sin(angle) * dist * 1.1)
				line.Size = UDim2.fromOffset(4, 60 + math.random() * 120 * amount)
				line.Rotation = math.deg(angle) + 90
				line.BackgroundTransparency = 1 - amount * (0.25 + math.random() * 0.35)
			end
		end
	end)
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
