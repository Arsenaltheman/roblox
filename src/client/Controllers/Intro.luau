--!strict
-- The login show: a sweeping camera fly-over of the canyon and town, the train whistle, fireworks
-- over the station and a giant title slam, then the camera settles behind your character and the
-- Prize Wheel opens if you have a free spin waiting. Skippable at any time; Reduced Motion skips
-- the camera moves and just shows the title.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Palette = require("@game/ReplicatedStorage/Shared/Config/Palette")
local Quality = require("./Quality")
local Sound = require("./Sound")
local Vfx = require("./Vfx")
local Store = require("../Store")

local Intro = {}

local localPlayer = Players.LocalPlayer
local C = Palette.color

local skipped = false

local function label(
	parent: Instance,
	text: string,
	size: UDim2,
	pos: UDim2,
	color: Color3,
	font: Enum.Font
): TextLabel
	local l = Instance.new("TextLabel")
	l.Size = size
	l.Position = pos
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextScaled = true
	l.TextColor3 = color
	l.FontFace = Font.fromEnum(font)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 6
	stroke.Color = C("ink")
	stroke.Parent = l
	l.Parent = parent
	return l
end

local function buildTitle(): (ScreenGui, TextButton)
	local gui = Instance.new("ScreenGui")
	gui.Name = "IntroTitle"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 50

	-- Cinematic letterbox bars.
	for _, top in { true, false } do
		local bar = Instance.new("Frame")
		bar.BackgroundColor3 = Color3.new(0, 0, 0)
		bar.BorderSizePixel = 0
		bar.Size = UDim2.fromScale(1, 0)
		bar.Position = if top then UDim2.fromScale(0, 0) else UDim2.fromScale(0, 1)
		bar.AnchorPoint = if top then Vector2.new(0, 0) else Vector2.new(0, 1)
		bar.Name = if top then "BarTop" else "BarBottom"
		bar.Parent = gui
		TweenService:Create(bar, TweenInfo.new(0.6), { Size = UDim2.fromScale(1, 0.11) }):Play()
	end

	local title = label(
		gui,
		"CRITTER EXPRESS",
		UDim2.fromScale(0.8, 0.2),
		UDim2.fromScale(0.5, 0.42),
		C("gold"),
		Enum.Font.LuckiestGuy
	)
	title.Name = "Title"
	title.Visible = false
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 245, 170)),
		ColorSequenceKeypoint.new(0.5, C("gold")),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 120, 40)),
	})
	gradient.Parent = title
	local sub = label(
		gui,
		"ROB THE TRAIN · RAID THE DESERT · DON'T GET CAUGHT",
		UDim2.fromScale(0.62, 0.06),
		UDim2.fromScale(0.5, 0.56),
		Color3.new(1, 1, 1),
		Enum.Font.FredokaOne
	)
	sub.Name = "Sub"
	sub.Visible = false

	local skip = Instance.new("TextButton")
	skip.Name = "Skip"
	skip.Size = UDim2.fromOffset(120, 44)
	skip.Position = UDim2.new(1, -20, 1, -20)
	skip.AnchorPoint = Vector2.new(1, 1)
	skip.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	skip.BackgroundTransparency = 0.3
	skip.Text = "SKIP ▶"
	skip.TextColor3 = Color3.new(1, 1, 1)
	skip.FontFace = Font.fromEnum(Enum.Font.LuckiestGuy)
	skip.TextScaled = true
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = skip
	skip.Parent = gui
	gui.Parent = localPlayer:WaitForChild("PlayerGui")
	return gui, skip
end

local function slam(gui: ScreenGui)
	local title = gui:FindFirstChild("Title") :: TextLabel
	local sub = gui:FindFirstChild("Sub") :: TextLabel
	title.Visible = true
	local scale = Instance.new("UIScale")
	scale.Scale = 3
	scale.Parent = title
	title.Rotation = -6
	TweenService
		:Create(scale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
	TweenService
		:Create(
			title,
			TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Rotation = -2 }
		)
		:Play()
	Sound.play("revealLegendary")
	-- The camera is Scriptable here, so shake its CFrame directly (Vfx.shake uses CameraOffset).
	local camera = Workspace.CurrentCamera
	if camera and not Quality.reducedMotion() then
		task.spawn(function()
			local base = camera.CFrame
			local started = os.clock()
			while os.clock() - started < 0.4 and camera.CameraType == Enum.CameraType.Scriptable do
				local k = 1 - (os.clock() - started) / 0.4
				camera.CFrame = base * CFrame.new((math.random() - 0.5) * k, (math.random() - 0.5) * k, 0)
				task.wait()
			end
			if camera.CameraType == Enum.CameraType.Scriptable then
				camera.CFrame = base
			end
		end)
	end
	task.delay(0.35, function()
		sub.Visible = true
		local s = Instance.new("UIScale")
		s.Scale = 0.2
		s.Parent = sub
		TweenService:Create(s, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end)
end

-- Moves the camera through a shot; returns early if skipped.
local function shot(camera: Camera, from: CFrame, to: CFrame, seconds: number)
	if skipped then
		return
	end
	camera.CFrame = from
	local tween = TweenService:Create(
		camera,
		TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
		{ CFrame = to }
	)
	tween:Play()
	local started = os.clock()
	while os.clock() - started < seconds and not skipped do
		task.wait()
	end
	tween:Cancel()
end

local function look(from: Vector3, at: Vector3): CFrame
	return CFrame.lookAt(from, at)
end

local function play()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local gui, skip = buildTitle()
	skip.Activated:Connect(function()
		skipped = true
	end)

	local reduced = Quality.reducedMotion()
	if not reduced then
		camera.CameraType = Enum.CameraType.Scriptable
		-- 1. High over the canyon rim, gliding toward town.
		shot(
			camera,
			look(Vector3.new(330, 170, -260), Vector3.new(0, 0, 75)),
			look(Vector3.new(170, 95, -150), Vector3.new(0, 0, 60)),
			3.2
		)
		-- 2. Low and fast along the track into the station; whistle and fireworks.
		if not skipped then
			Sound.play("whistle")
			task.delay(1.2, function()
				Vfx.fireworks(Vector3.new(0, 14, 14), C("red"), 8)
			end)
		end
		shot(
			camera,
			look(Vector3.new(-170, 10, -14), Vector3.new(0, 8, 10)),
			look(Vector3.new(-45, 9, -10), Vector3.new(0, 8, 12)),
			2.6
		)
	end
	if not skipped then
		slam(gui)
		Vfx.fireworks(Vector3.new(0, 16, 14), C("gold"), 10)
		local waitUntil = os.clock() + 2.2
		while os.clock() < waitUntil and not skipped do
			task.wait()
		end
	end
	-- 3. Settle behind the player.
	local character = localPlayer.Character
	local head = character and character:FindFirstChild("Head") :: BasePart?
	if head and not reduced and not skipped then
		local behind = head.CFrame * CFrame.new(0, 3, 11)
		shot(camera, camera.CFrame, CFrame.lookAt(behind.Position, head.Position), 1.2)
	end
	camera.CameraType = Enum.CameraType.Custom
	for _, child in gui:GetChildren() do
		if child:IsA("GuiObject") then
			TweenService:Create(child, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
			if child:IsA("TextLabel") or child:IsA("TextButton") then
				TweenService:Create(child, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
			end
		end
	end
	task.delay(0.45, function()
		gui:Destroy()
	end)
	-- Free spin waiting? Straight into the wheel.
	task.delay(0.6, function()
		local state = Store.state()
		local tutorialDone = state ~= nil and (state.tutorial or 0) >= 3
		if
			tutorialDone
			and ((localPlayer:GetAttribute("Spins") :: number?) or 0) > 0
			and Store.menu() == ""
		then
			Store.menu("wheel")
		end
	end)
end

function Intro.init() end

function Intro.start()
	task.spawn(function()
		local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
		character:WaitForChild("HumanoidRootPart", 10)
		-- Let the town and the first state arrive so there's something to fly over.
		Workspace:WaitForChild("Town", 10)
		task.wait(1)
		local ok, err = pcall(play :: any)
		if not ok then
			warn("[Intro]", err)
			local camera = Workspace.CurrentCamera
			if camera then
				camera.CameraType = Enum.CameraType.Custom
			end
		end
	end)
end

return Intro
