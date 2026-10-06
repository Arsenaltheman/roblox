--!strict
-- Draws the heist zones' crates from nest attributes (set by the server): the critter bobbing on its
-- nest, a rarity-coloured light beam into the sky for Rare and up (visible across the map), a
-- restock countdown on empty nests, and a glowing arc guiding you home while you carry a crate.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local HeistConfig = require("@game/ReplicatedStorage/Shared/Config/Heist")
local Layout = require("@game/ReplicatedStorage/Shared/Config/Layout")
local Palette = require("@game/ReplicatedStorage/Shared/Config/Palette")
local Rarities = require("@game/ReplicatedStorage/Shared/Config/Rarities")
local Species = require("@game/ReplicatedStorage/Shared/Config/Species")
local CritterRig = require("./CritterRig")
local Store = require("../Store")
local TrainView = require("./TrainView")
local TrainClock = require("@game/ReplicatedStorage/Shared/Sim/TrainClock")

local ANIMATE_DISTANCE = 120

local HeistView = {}

local tutorialGuide: (any) -> { key: string, position: Vector3 }?

type Entry = {
	pad: BasePart,
	zone: number,
	nest: number,
	model: Model?,
	beam: Beam?,
	timer: BillboardGui?,
	key: string,
	seed: number,
}

local entries: { [BasePart]: Entry } = {}
local localPlayer = Players.LocalPlayer

local function attachment(parent: BasePart, offset: Vector3): Attachment
	local a = Instance.new("Attachment")
	a.Position = offset
	a.Parent = parent
	return a
end

local function makeBeam(entry: Entry, color: Color3)
	local pad = entry.pad
	-- The pad is a cylinder lying on its side: its local X axis points up.
	local a0 = attachment(pad, Vector3.new(0.4, 0, 0))
	local a1 = attachment(pad, Vector3.new(140, 0, 0))
	local beam = Instance.new("Beam")
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Width0 = 4.5
	beam.Width1 = 1.5
	beam.FaceCamera = true
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.Color = ColorSequence.new(color)
	beam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(0.7, 0.75),
		NumberSequenceKeypoint.new(1, 1),
	})
	beam.Segments = 2
	beam.Parent = pad
	entry.beam = beam
end

local function makeTimer(entry: Entry)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(5, 1.6)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 4, 0)
	gui.MaxDistance = 70
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.FontFace = Font.fromEnum(Enum.Font.LuckiestGuy)
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 236, 200)
	label.Text = "RESTOCKING..."
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2.5
	stroke.Color = Palette.color("ink")
	stroke.Parent = label
	label.Parent = gui
	gui.Adornee = entry.pad
	gui.Parent = entry.pad
	entry.timer = gui
end

local function clear(entry: Entry)
	if entry.model then
		entry.model:Destroy()
		entry.model = nil
	end
	if entry.beam then
		local a0, a1 = entry.beam.Attachment0, entry.beam.Attachment1
		entry.beam:Destroy()
		if a0 then
			a0:Destroy()
		end
		if a1 then
			a1:Destroy()
		end
		entry.beam = nil
	end
	if entry.timer then
		entry.timer:Destroy()
		entry.timer = nil
	end
end

local function refresh(entry: Entry)
	local pad = entry.pad
	local species = pad:GetAttribute("Species") :: string?
	local tier = (pad:GetAttribute("Tier") :: number?) or 0
	local mutation = pad:GetAttribute("Mutation") :: string?
	local key = if species and species ~= "" then `{species}:{tier}:{mutation or ""}` else ""
	if key == entry.key then
		return
	end
	entry.key = key
	clear(entry)
	if key == "" then
		makeTimer(entry)
		return
	end
	local model = CritterRig.build(species :: string, tier, mutation, Store.quality(), 2.6)
	local r = (model:GetAttribute("Radius") :: number?) or 1
	model:PivotTo(CritterRig.pose(CFrame.new(pad.Position + Vector3.new(0, 0.3, 0)), 0, entry.seed, r))
	model.Parent = pad
	entry.model = model
	local rarity = Rarities.forTier(tier)
	if Rarities.indexOf(rarity.id) >= 3 then
		makeBeam(entry, Palette.color(rarity.color))
	end
end

local function watchPad(pad: Instance)
	if not pad:IsA("BasePart") or entries[pad] then
		return
	end
	local zone = pad:GetAttribute("HeistZone") :: number?
	local nest = pad:GetAttribute("HeistNest") :: number?
	if not zone or not nest then
		return
	end
	local entry: Entry = {
		pad = pad,
		zone = zone,
		nest = nest,
		model = nil,
		beam = nil,
		timer = nil,
		key = "-",
		seed = math.random() * 10,
	}
	entries[pad] = entry
	refresh(entry)
	pad.AttributeChanged:Connect(function()
		refresh(entry)
	end)
	pad.Destroying:Connect(function()
		clear(entry)
		entries[pad] = nil
	end)
end

-- Nearest nest with a crate within reach of `position` (used by the action button).
function HeistView.nearestCrate(position: Vector3): (number?, number?, string?, number?)
	local best: Entry? = nil
	local bestDist = HeistConfig.GRAB_REACH
	for _, entry in entries do
		if entry.model then
			local d = (entry.pad.Position - position).Magnitude
			if d <= bestDist then
				best, bestDist = entry, d
			end
		end
	end
	if not best then
		return nil, nil, nil, nil
	end
	return best.zone,
		best.nest,
		best.pad:GetAttribute("Species") :: string?,
		(best.pad:GetAttribute("Tier") :: number?) or 0
end

-- The glowing guide arc: gold "this way home" while carrying a crate, and teal "go here" toward
-- Cactus Flats until you've done your first heist (after the tutorial).
local guide: Beam? = nil
local guideTarget: Part? = nil
local guideKey = ""
local function clearGuide()
	if guide then
		guide:Destroy()
		guide = nil
	end
	if guideTarget then
		guideTarget:Destroy()
		guideTarget = nil
	end
	guideKey = ""
end

-- Where the tutorial wants you: your reserved cage (step 0, and the golden ticket in step 1), your
-- collect plate (step 1 before your first collect), the tutorial bandit (step 2).
local function myReservedCage(): Vector3?
	local epoch = Workspace:GetAttribute("TrainEpoch") :: number?
	if not epoch then
		return nil
	end
	local train = TrainClock.at(epoch, Workspace:GetServerTimeNow())
	if not train.doorsOpen then
		return nil
	end
	local manifest = TrainView.manifest(train.cycle)
	if not manifest then
		return nil
	end
	for _, cage in manifest.cages do
		if cage.o == localPlayer.UserId and not TrainView.isSold(train.cycle, cage.id) then
			return TrainView.cageWorldPosition(cage.id)
		end
	end
	return nil
end

local function myRanchPart(name: string): BasePart?
	local index = localPlayer:GetAttribute("Ranch") :: number?
	local town = Workspace:FindFirstChild("Town")
	local ranches = town and town:FindFirstChild("Ranches")
	if not index or not ranches then
		return nil
	end
	for _, ranch in ranches:GetChildren() do
		if ranch:GetAttribute("Index") == index then
			return ranch:FindFirstChild(name, true) :: BasePart?
		end
	end
	return nil
end

tutorialGuide = function(state: any): { key: string, position: Vector3 }?
	local step = state.tutorial or 0
	if step == 1 and not state.collected then
		local plate = myRanchPart("CollectPlate")
		return if plate then { key = "plate", position = plate.Position + Vector3.new(0, 2, 0) } else nil
	end
	if step <= 1 then
		local cage = myReservedCage()
		if cage then
			return { key = "cage", position = cage }
		end
		local p = Layout.platform.center
		return { key = "platform", position = Vector3.new(p.x, 4, p.z) }
	end
	local npcs = Workspace:FindFirstChild("NPCs")
	if npcs then
		for _, model in npcs:GetChildren() do
			if model:GetAttribute("TutorialFor") == localPlayer.UserId then
				local r = model:FindFirstChild("HumanoidRootPart") :: BasePart?
				if r then
					return {
						key = "bandit" .. math.floor(r.Position.X / 8) .. math.floor(r.Position.Z / 8),
						position = r.Position,
					}
				end
			end
		end
	end
	return nil
end

local function updateGuide()
	local carrying = localPlayer:GetAttribute("HeistCarry") == true
	local character = localPlayer.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local ranch = localPlayer:GetAttribute("Ranch") :: number?
	local state = Store.state()
	local key, position, color = "", Vector3.zero, Palette.color("gold")
	if carrying and ranch and Layout.ranches[ranch] then
		local center = Layout.ranches[ranch].center
		key, position = "home" .. ranch, Vector3.new(center.x, 3, center.z)
	elseif state and (state.tutorial or 0) < 3 then
		-- Tutorial: point at exactly what the hint asks for.
		local tutorialTarget = tutorialGuide(state)
		if tutorialTarget then
			key, position, color = tutorialTarget.key, tutorialTarget.position, Palette.color("red")
		end
	elseif state and (state.heists or 0) == 0 then
		local zone = HeistConfig.zone(1)
		if zone then
			key, position, color = "zone1", Vector3.new(zone.x, 3, zone.z), Palette.color("sky")
		end
	end
	if key == "" or not rootPart then
		clearGuide()
		return
	end
	if key == guideKey and guide and guide.Attachment0 and guide.Attachment0.Parent == rootPart then
		return
	end
	-- Same kind of target that moved (the bandit running): slide the target instead of rebuilding.
	local category = string.match(key, "^%a+")
	if
		guide
		and guideTarget
		and category == string.match(guideKey, "^%a+")
		and guide.Attachment0
		and guide.Attachment0.Parent == rootPart
	then
		guideTarget.Position = position
		guideKey = key
		return
	end
	clearGuide()
	guideKey = key
	local target = Instance.new("Part")
	target.Anchored = true
	target.CanCollide = false
	target.CanQuery = false
	target.Transparency = 1
	target.Size = Vector3.new(1, 1, 1)
	target.Position = position
	target.Parent = Workspace
	local a0 = Instance.new("Attachment")
	a0.Parent = rootPart
	local a1 = Instance.new("Attachment")
	a1.Parent = target
	local beam = Instance.new("Beam")
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.CurveSize0 = 30
	beam.CurveSize1 = -30
	beam.Width0 = 1.2
	beam.Width1 = 3
	beam.FaceCamera = true
	beam.LightEmission = 1
	beam.Segments = 24
	beam.Color = ColorSequence.new(color)
	beam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.85),
		NumberSequenceKeypoint.new(0.5, 0.35),
		NumberSequenceKeypoint.new(1, 0.1),
	})
	beam.Parent = target
	-- A big bouncing arrow over the target so it's obvious even at a glance.
	local arrow = Instance.new("BillboardGui")
	arrow.Size = UDim2.fromOffset(70, 70)
	arrow.StudsOffset = Vector3.new(0, 5, 0)
	arrow.AlwaysOnTop = true
	arrow.LightInfluence = 0
	local glyph = Instance.new("TextLabel")
	glyph.Size = UDim2.fromScale(1, 1)
	glyph.BackgroundTransparency = 1
	glyph.Text = "▼"
	glyph.TextScaled = true
	glyph.TextColor3 = color
	glyph.FontFace = Font.fromEnum(Enum.Font.LuckiestGuy)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Parent = glyph
	glyph.Parent = arrow
	arrow.Parent = target
	task.spawn(function()
		while arrow.Parent do
			arrow.StudsOffset = Vector3.new(0, 5 + math.abs(math.sin(os.clock() * 4)) * 1.5, 0)
			task.wait()
		end
	end)
	beam.Destroying:Once(function()
		a0:Destroy()
	end)
	guide, guideTarget = beam, target
end

function HeistView.init() end

function HeistView.start()
	task.spawn(function()
		local folder = Workspace:WaitForChild("Heist")
		for _, pad in folder:GetChildren() do
			watchPad(pad)
		end
		folder.ChildAdded:Connect(watchPad)
	end)
	localPlayer:GetAttributeChangedSignal("HeistCarry"):Connect(updateGuide)
	localPlayer.CharacterAdded:Connect(function()
		task.wait(0.2)
		updateGuide()
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			updateGuide()
		end
	end)

	RunService.RenderStepped:Connect(function()
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local camPos = camera.CFrame.Position
		local t = os.clock()
		local serverNow = Workspace:GetServerTimeNow()
		for _, entry in entries do
			local near = (entry.pad.Position - camPos).Magnitude < ANIMATE_DISTANCE
			if entry.model and near then
				local r = (entry.model:GetAttribute("Radius") :: number?) or 1
				local base = CFrame.new(entry.pad.Position + Vector3.new(0, 0.3, 0))
					* CFrame.Angles(0, t * 0.8, 0)
				entry.model:PivotTo(CritterRig.pose(base, t, entry.seed, r))
				CritterRig.updateRainbow(entry.model, t)
			elseif entry.timer and near then
				local at = (entry.pad:GetAttribute("RespawnAt") :: number?) or 0
				local left = math.max(0, math.ceil(at - serverNow))
				local label = entry.timer:FindFirstChild("Text") :: TextLabel?
				if label then
					label.Text = if left > 0 then `RESTOCK {left}s` else "RESTOCKING..."
				end
			end
		end
	end)
end

-- Species display name for the action button.
function HeistView.speciesName(id: string?): string
	local s = id and Species.byId[id]
	return if s then s.name else "Critter"
end

return HeistView
