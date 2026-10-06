--!strict
-- Bandit Camp "red light", made visible. The server judges grabs with BanditClock; this draws the
-- same clock: a dozing bandit by the fire with "Zzz" while napping, a head turn plus a yellow "!"
-- (the tell) just before he peeks, and wide red eyes plus "WATCHING!" while he peeks.

local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local Layout = require("@game/ReplicatedStorage/Shared/Config/Layout")
local BanditClock = require("@game/ReplicatedStorage/Shared/Sim/BanditClock")

local BanditCampView = {}

local function part(model: Model, size: Vector3, cf: CFrame, color: Color3, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Shape = shape or Enum.PartType.Block
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Parent = model
	return p
end

local function build(): (
	Model,
	BasePart,
	{ BasePart },
	TextLabel,
	TextLabel,
	{ { part: BasePart, offset: CFrame } }
)
	local camp = Layout.landmarks.banditCamp
	-- Sits beside the fire, facing the loot pens.
	local base = CFrame.new(camp.x + 3.5, -1, camp.z - 3.5) * CFrame.Angles(0, math.rad(225), 0)
	local model = Instance.new("Model")
	model.Name = "CampBandit"
	local coat = Color3.fromRGB(110, 60, 50)
	part(model, Vector3.new(2.6, 2.4, 1.8), base * CFrame.new(0, 1.6, 0), coat)
	part(model, Vector3.new(2.8, 0.8, 3), base * CFrame.new(0, 0.4, -0.6), Color3.fromRGB(60, 45, 35))
	local head = part(
		model,
		Vector3.new(1.8, 1.8, 1.8),
		base * CFrame.new(0, 3.6, 0),
		Color3.fromRGB(235, 180, 130),
		Enum.PartType.Ball
	)
	local brim = part(
		model,
		Vector3.new(0.3, 3.4, 3.4),
		base * CFrame.new(0, 4.4, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(40, 28, 22),
		Enum.PartType.Cylinder
	)
	local crown =
		part(model, Vector3.new(1.6, 1, 1.6), base * CFrame.new(0, 4.9, 0), Color3.fromRGB(40, 28, 22))
	local eyes: { BasePart } = {
		part(
			model,
			Vector3.new(0.35, 0.12, 0.1),
			base * CFrame.new(-0.4, 3.8, -0.88),
			Color3.fromRGB(43, 29, 20)
		),
		part(
			model,
			Vector3.new(0.35, 0.12, 0.1),
			base * CFrame.new(0.4, 3.8, -0.88),
			Color3.fromRGB(43, 29, 20)
		),
	}
	-- Status sign over his head.
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(180, 70)
	gui.StudsOffset = Vector3.new(0, 4, 0)
	gui.MaxDistance = 120
	gui.LightInfluence = 0
	gui.AlwaysOnTop = true
	local icon = Instance.new("TextLabel")
	icon.Size = UDim2.fromScale(1, 0.6)
	icon.BackgroundTransparency = 1
	icon.TextScaled = true
	icon.FontFace = Font.fromEnum(Enum.Font.LuckiestGuy)
	icon.Parent = gui
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 0.4)
	label.Position = UDim2.fromScale(0, 0.6)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.FontFace = Font.fromEnum(Enum.Font.LuckiestGuy)
	label.Parent = gui
	for _, l in { icon, label } do
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 3
		stroke.Parent = l
	end
	gui.Parent = head
	model.Parent = Workspace
	-- Everything on the head turns and nods together.
	local group: { { part: BasePart, offset: CFrame } } = {}
	for _, p in { head, brim, crown, eyes[1], eyes[2] } :: { BasePart } do
		table.insert(group, { part = p, offset = head.CFrame:ToObjectSpace(p.CFrame) })
	end
	return model, head, eyes, icon, label, group
end

function BanditCampView.init() end

function BanditCampView.start()
	task.spawn(function()
		Workspace:WaitForChild("Town", 30)
		local _, head, eyes, icon, label, group = build()
		local headHome = head.CFrame
		local function placeHead(cf: CFrame)
			for _, g in group do
				g.part.CFrame = cf * g.offset
			end
		end
		local last: string = ""
		RunService.Heartbeat:Connect(function()
			local state = BanditClock.state(Workspace:GetServerTimeNow())
			if state == "napping" then
				-- Slow nodding while asleep.
				placeHead(headHome * CFrame.new(0, math.sin(os.clock() * 1.5) * 0.08, 0))
			end
			if state == last then
				return
			end
			last = state
			local stashed = (Workspace:GetAttribute("BanditStash") :: number?) or 0
			local loot = if stashed > 0 then ` ({stashed} STOLEN PETS HERE!)` else ""
			if state == "napping" then
				icon.Text, icon.TextColor3 = "Zzz", Color3.fromRGB(150, 230, 255)
				label.Text, label.TextColor3 = "NAPPING - STEAL NOW!" .. loot, Color3.fromRGB(120, 230, 110)
				for _, e in eyes do
					e.Size, e.Color, e.Material =
						Vector3.new(0.35, 0.12, 0.1), Color3.fromRGB(43, 29, 20), Enum.Material.SmoothPlastic
				end
			elseif state == "tell" then
				icon.Text, icon.TextColor3 = "!", Color3.fromRGB(255, 220, 60)
				label.Text, label.TextColor3 = "WAKING UP...", Color3.fromRGB(255, 220, 60)
				placeHead(headHome * CFrame.Angles(0, math.rad(25), 0))
			else
				icon.Text, icon.TextColor3 = "!!", Color3.fromRGB(255, 70, 60)
				label.Text, label.TextColor3 = "WATCHING! DON'T GRAB!", Color3.fromRGB(255, 70, 60)
				placeHead(headHome)
				for _, e in eyes do
					e.Size, e.Color, e.Material =
						Vector3.new(0.4, 0.4, 0.1), Color3.fromRGB(255, 60, 50), Enum.Material.Neon
				end
			end
		end)
	end)
end

return BanditCampView
