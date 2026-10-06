--!strict
-- Renders critters on every ranch's pen pads from the pads' attributes (set by the server), plus the
-- critter a thief is carrying. Level of detail: only critters near the camera animate.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CritterRig = require("./CritterRig")
local Store = require("../Store")

local ANIMATE_DISTANCE = 90

local Pens = {}

type Entry = { pad: BasePart, model: Model?, key: string, seed: number }

local entries: { [BasePart]: Entry } = {}
local carried: { [Player]: { model: Model, key: string } } = {}

local function refresh(entry: Entry)
	local pad = entry.pad
	local species = pad:GetAttribute("Critter") :: string?
	local tier = (pad:GetAttribute("Tier") :: number?) or 0
	local mutation = pad:GetAttribute("Mutation") :: string?
	local inTransit = pad:GetAttribute("InTransit") == true
	local key = if species
			and species ~= ""
			and not inTransit
		then `{species}:{tier}:{mutation or ""}`
		else ""
	if key == entry.key then
		return
	end
	entry.key = key
	if entry.model then
		entry.model:Destroy()
		entry.model = nil
	end
	if key ~= "" then
		local model = CritterRig.build(species :: string, tier, mutation, Store.quality(), 2.6)
		model:PivotTo(pad.CFrame)
		model.Parent = pad
		entry.model = model
		-- Branded (Robux) critters wear a gold ring so thieves know not to bother.
		if pad:GetAttribute("Branded") then
			local ring = Instance.new("Part")
			ring.Name = "Brand"
			ring.Shape = Enum.PartType.Cylinder
			ring.Size = Vector3.new(0.2, 4.8, 4.8)
			ring.Color = Color3.fromRGB(255, 200, 61)
			ring.Material = Enum.Material.Neon
			ring.Transparency = 0.3
			ring.Anchored = true
			ring.CanCollide = false
			ring.CanQuery = false
			ring.CFrame = pad.CFrame * CFrame.new(0.25, 0, 0)
			ring.Parent = model
		end
	end
end

local function watchPad(pad: BasePart)
	if entries[pad] then
		return
	end
	local entry: Entry = { pad = pad, model = nil, key = "", seed = math.random() * 10 }
	entries[pad] = entry
	refresh(entry)
	pad.AttributeChanged:Connect(function()
		refresh(entry)
	end)
end

local function watchTown()
	local town = Workspace:WaitForChild("Town")
	local ranches = town:WaitForChild("Ranches")
	for _, ranch in ranches:GetChildren() do
		local pens = ranch:WaitForChild("Pens")
		for _, pad in pens:GetChildren() do
			if pad:IsA("BasePart") then
				watchPad(pad)
			end
		end
	end
end

-- Thieves carry their loot overhead.
local function updateCarried(player: Player)
	local species = player:GetAttribute("Carrying") :: string?
	local tier = (player:GetAttribute("CarryingTier") :: number?) or 0
	local mutation = player:GetAttribute("CarryingMutation") :: string?
	local key = if species and species ~= "" then `{species}:{tier}:{mutation or ""}` else ""
	local current = carried[player]
	if current and current.key == key then
		return
	end
	if current then
		current.model:Destroy()
		carried[player] = nil
	end
	if key ~= "" then
		local model = CritterRig.build(species :: string, tier, mutation, Store.quality(), 2)
		model.Parent = Workspace
		carried[player] = { model = model, key = key }
	end
end

local function watchPlayer(player: Player)
	updateCarried(player)
	player.AttributeChanged:Connect(function(name)
		if string.sub(name, 1, 8) == "Carrying" then
			updateCarried(player)
		end
	end)
end

function Pens.init() end

function Pens.start()
	task.spawn(watchTown)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	Players.PlayerAdded:Connect(watchPlayer)
	Players.PlayerRemoving:Connect(function(player)
		local current = carried[player]
		if current then
			current.model:Destroy()
			carried[player] = nil
		end
	end)

	RunService.RenderStepped:Connect(function()
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local camPos = camera.CFrame.Position
		local t = os.clock()
		for _, entry in entries do
			local model = entry.model
			if model then
				local pad = entry.pad
				if (pad.Position - camPos).Magnitude < ANIMATE_DISTANCE then
					local r = (model:GetAttribute("Radius") :: number?) or 1
					-- Pads are cylinders lying on their side; build an upright frame at the pad.
					local base = CFrame.new(pad.Position + Vector3.new(0, 0.2, 0))
					model:PivotTo(CritterRig.pose(base, t, entry.seed, r))
					CritterRig.updateRainbow(model, t)
				end
			end
		end
		for player, current in carried do
			local character = player.Character
			local head = character and character:FindFirstChild("Head") :: BasePart?
			if head then
				local wiggle = math.sin(t * 9) * 0.15
				current.model:PivotTo(head.CFrame * CFrame.new(0, 3.2, 0) * CFrame.Angles(0, t * 2, wiggle))
			end
		end
	end)
end

return Pens
