--!strict
-- Shows everyone's equipped cosmetics (the server publishes them as "Equip_<slot>" attributes):
--   title      - a name tag over the head with the title in its colour (replaces the default name)
--   hat        - a little hat built from parts, welded to the head
--   ranchTheme - recolours the owner's ranch fence and hangs coloured lanterns
-- Lasso trail and WANTED poster colours are read by Vfx where those effects are drawn.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Cosmetics = require("@game/ReplicatedStorage/Shared/Config/Cosmetics")
local SeasonConfig = require("@game/ReplicatedStorage/Shared/Config/Season")

local Looks = {}

-- Rail Pass cosmetics take the current season's accent so each season's set looks different.
local function cosmeticHex(cosmetic: Cosmetics.Cosmetic): string
	if cosmetic.id == "title_season" or cosmetic.id == "hat_season" then
		return SeasonConfig.color(SeasonConfig.seasonOf(Workspace:GetServerTimeNow()))
	end
	return cosmetic.color
end

local function color(id: string?): Color3?
	local cosmetic = id and Cosmetics.byId[id]
	return if cosmetic then Color3.fromHex(cosmeticHex(cosmetic)) else nil
end

function Looks.colorOf(player: Player?, slot: string): Color3?
	if not player then
		return nil
	end
	return color(player:GetAttribute("Equip_" .. slot) :: string?)
end

-- ---------------------------------------------------------------- name tag + title

local function nameTag(player: Player, character: Model)
	local head = character:FindFirstChild("Head") :: BasePart?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not head or not humanoid then
		return
	end
	local old = head:FindFirstChild("LooksTag")
	if old then
		old:Destroy()
	end
	local titleId = player:GetAttribute("Equip_title") :: string?
	local cosmetic = titleId and Cosmetics.byId[titleId]
	local bountyBy = player:GetAttribute("Bounty") :: number?
	if not cosmetic and not bountyBy then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
		return
	end
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	local gui = Instance.new("BillboardGui")
	gui.Name = "LooksTag"
	gui.Size = UDim2.fromOffset(220, 52)
	gui.StudsOffset = Vector3.new(0, 2.6, 0)
	gui.MaxDistance = 80
	gui.LightInfluence = 0
	local function label(text: string, y: number, h: number, c: Color3, font: Enum.Font)
		local l = Instance.new("TextLabel")
		l.Size = UDim2.new(1, 0, h, 0)
		l.Position = UDim2.fromScale(0, y)
		l.BackgroundTransparency = 1
		l.Text = text
		l.TextScaled = true
		l.TextColor3 = c
		l.FontFace = Font.fromEnum(font)
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Color = Color3.fromRGB(43, 29, 20)
		stroke.Parent = l
		l.Parent = gui
	end
	if bountyBy then
		-- Revenge bounty: red for the one who posted it, orange for everyone else.
		local mine = bountyBy == Players.LocalPlayer.UserId
		label(
			if mine then "★ YOUR BOUNTY ★" else "WANTED: BOUNTY",
			0,
			0.42,
			if mine then Color3.fromRGB(255, 80, 70) else Color3.fromRGB(255, 170, 60),
			Enum.Font.LuckiestGuy
		)
	elseif cosmetic then
		label(
			string.upper(cosmetic.name),
			0,
			0.42,
			Color3.fromHex(cosmeticHex(cosmetic)),
			Enum.Font.LuckiestGuy
		)
	end
	label(player.DisplayName, 0.44, 0.56, Color3.new(1, 1, 1), Enum.Font.FredokaOne)
	gui.Parent = head
end

-- ---------------------------------------------------------------- hats

local function hatPart(
	parent: Model,
	size: Vector3,
	offset: CFrame,
	c: Color3,
	shape: Enum.PartType?,
	material: Enum.Material?
): Part
	local p = Instance.new("Part")
	p.Size = size
	p.Shape = shape or Enum.PartType.Block
	p.Color = c
	p.Material = material or Enum.Material.SmoothPlastic
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.CFrame = offset
	p.Parent = parent
	return p
end

local function buildHat(id: string, head: BasePart): Model?
	local top = head.CFrame * CFrame.new(0, head.Size.Y / 2, 0)
	local hat = Instance.new("Model")
	hat.Name = "LooksHat"
	local flat = CFrame.Angles(0, 0, math.rad(90))
	if id == "hat_StarterStetson" or id == "hat_sheriff" or id == "hat_club" or id == "hat_season" then
		local brown = if id == "hat_sheriff"
			then Color3.fromRGB(226, 169, 59)
			elseif id == "hat_club" then Color3.fromRGB(255, 200, 61)
			elseif id == "hat_season" then color(id) or Color3.fromRGB(63, 183, 176)
			else Color3.fromRGB(138, 90, 59)
		hatPart(
			hat,
			Vector3.new(0.18, 3, 3),
			top * CFrame.new(0, 0.1, 0) * flat,
			brown,
			Enum.PartType.Cylinder
		)
		hatPart(hat, Vector3.new(1.5, 0.9, 1.5), top * CFrame.new(0, 0.6, 0), brown)
		hatPart(hat, Vector3.new(1.55, 0.2, 1.55), top * CFrame.new(0, 0.3, 0), Color3.fromRGB(43, 29, 20))
		if id == "hat_sheriff" then
			hatPart(
				hat,
				Vector3.new(0.5, 0.5, 0.1),
				top * CFrame.new(0, 0.6, -0.78),
				Color3.fromRGB(255, 225, 120),
				nil,
				Enum.Material.Neon
			)
		end
	elseif id == "hat_cactus" then
		local green = Color3.fromRGB(78, 154, 75)
		hatPart(hat, Vector3.new(1, 1.6, 1), top * CFrame.new(0, 0.8, 0), green)
		hatPart(hat, Vector3.new(0.5, 0.9, 0.5), top * CFrame.new(0.6, 0.9, 0), green)
		hatPart(hat, Vector3.new(0.5, 0.7, 0.5), top * CFrame.new(-0.6, 0.6, 0), green)
	elseif id == "hat_premium" then
		local black = Color3.fromRGB(43, 29, 20)
		hatPart(
			hat,
			Vector3.new(0.18, 2.8, 2.8),
			top * CFrame.new(0, 0.1, 0) * flat,
			black,
			Enum.PartType.Cylinder
		)
		hatPart(hat, Vector3.new(1.6, 1.8, 1.6), top * CFrame.new(0, 1.0, 0), black)
		hatPart(
			hat,
			Vector3.new(1.65, 0.3, 1.65),
			top * CFrame.new(0, 0.4, 0),
			Color3.fromRGB(255, 200, 61),
			nil,
			Enum.Material.Neon
		)
	elseif id == "hat_flower" then
		hatPart(
			hat,
			Vector3.new(0.18, 2.6, 2.6),
			top * CFrame.new(0, 0.1, 0) * flat,
			Color3.fromRGB(240, 220, 170),
			Enum.PartType.Cylinder
		)
		hatPart(hat, Vector3.new(1.3, 0.7, 1.3), top * CFrame.new(0, 0.45, 0), Color3.fromRGB(240, 220, 170))
		hatPart(
			hat,
			Vector3.new(0.7, 0.7, 0.7),
			top * CFrame.new(0.5, 0.6, -0.5),
			Color3.fromRGB(255, 143, 177),
			Enum.PartType.Ball
		)
	else
		hat:Destroy()
		return nil
	end
	for _, p in hat:GetChildren() do
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = head
		weld.Part1 = p :: BasePart
		weld.Parent = p
	end
	return hat
end

local function hat(player: Player, character: Model)
	local head = character:FindFirstChild("Head") :: BasePart?
	if not head then
		return
	end
	local old = character:FindFirstChild("LooksHat")
	if old then
		old:Destroy()
	end
	local id = player:GetAttribute("Equip_hat") :: string?
	local wearing = id ~= nil and id ~= ""
	-- Hide the avatar's own hats while a cosmetic hat is on (so they don't clip), show them otherwise.
	for _, accessory in character:GetChildren() do
		if accessory:IsA("Accessory") and accessory.AccessoryType == Enum.AccessoryType.Hat then
			local handle = accessory:FindFirstChild("Handle") :: BasePart?
			if handle then
				handle.LocalTransparencyModifier = if wearing then 1 else 0
			end
		end
	end
	if not wearing then
		return
	end
	local model = buildHat(id :: string, head)
	if model then
		model.Parent = character
	end
end

-- ---------------------------------------------------------------- capes

local function cape(player: Player, character: Model)
	local torso = (character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")) :: BasePart?
	local old = character:FindFirstChild("LooksCape")
	if old then
		old:Destroy()
	end
	local id = player:GetAttribute("Equip_cape") :: string?
	local cosmetic = if id and id ~= "" then Cosmetics.byId[id] else nil
	if not torso or not cosmetic then
		return
	end
	local c = Color3.fromHex(cosmeticHex(cosmetic))
	local model = Instance.new("Model")
	model.Name = "LooksCape"
	-- A flat panel hanging off the back, slightly flared, with a dark collar band.
	local panel = hatPart(
		model,
		Vector3.new(2.2, 3.1, 0.14),
		torso.CFrame * CFrame.new(0, -0.55, 0.62) * CFrame.Angles(math.rad(-8), 0, 0),
		c,
		nil,
		Enum.Material.Fabric
	)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = torso
	weld.Part1 = panel
	weld.Parent = panel
	local collar = hatPart(
		model,
		Vector3.new(2.3, 0.3, 0.3),
		torso.CFrame * CFrame.new(0, 0.95, 0.5),
		Color3.fromRGB(43, 29, 20),
		nil,
		Enum.Material.SmoothPlastic
	)
	local weld2 = Instance.new("WeldConstraint")
	weld2.Part0 = torso
	weld2.Part1 = collar
	weld2.Parent = collar
	local star = hatPart(
		model,
		Vector3.new(0.5, 0.5, 0.08),
		torso.CFrame * CFrame.new(0, -1.5, 0.72),
		Color3.fromRGB(255, 225, 120),
		nil,
		Enum.Material.Neon
	)
	local weld3 = Instance.new("WeldConstraint")
	weld3.Part0 = torso
	weld3.Part1 = star
	weld3.Parent = star
	model.Parent = character
end

-- ---------------------------------------------------------------- ranch themes

local originalColors: { [BasePart]: Color3 } = {}

local function applyTheme(ranch: Instance)
	local ownerId = (ranch:GetAttribute("Owner") :: number?) or 0
	local owner = if ownerId ~= 0 then Players:GetPlayerByUserId(ownerId) else nil
	local themeId = owner and owner:GetAttribute("Equip_ranchTheme") :: string?
	local themeColor = color(themeId)
	for _, d in ranch:GetDescendants() do
		if d:IsA("BasePart") and (d.Name == "Fence" or d.Name == "Gate") then
			if not originalColors[d] then
				originalColors[d] = d.Color
			end
			d.Color = themeColor or originalColors[d]
			local glow = d:FindFirstChild("ThemeGlow") :: PointLight?
			if themeColor and d.Name == "Gate" then
				if not glow then
					local light = Instance.new("PointLight")
					light.Name = "ThemeGlow"
					light.Range = 14
					light.Brightness = 1.4
					light.Parent = d
					glow = light
				end
				(glow :: PointLight).Color = themeColor
			elseif glow then
				glow:Destroy()
			end
		end
	end
end

local function refreshRanches()
	local town = Workspace:FindFirstChild("Town")
	local ranches = town and town:FindFirstChild("Ranches")
	if not ranches then
		return
	end
	for _, ranch in ranches:GetChildren() do
		applyTheme(ranch)
	end
end

-- ---------------------------------------------------------------- wiring

local function watchPlayer(player: Player)
	local function refresh()
		local character = player.Character
		if character then
			pcall(nameTag, player, character)
			pcall(hat, player, character)
			pcall(cape, player, character)
		end
	end
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("Head", 10)
		task.wait(0.5) -- let accessories load
		refresh()
	end)
	player.AttributeChanged:Connect(function(name)
		if name == "Equip_title" or name == "Equip_hat" or name == "Equip_cape" or name == "Bounty" then
			refresh()
		elseif name == "Equip_ranchTheme" then
			pcall(refreshRanches)
		end
	end)
	task.defer(refresh)
end

function Looks.init() end

function Looks.start()
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	Players.PlayerAdded:Connect(watchPlayer)
	task.spawn(function()
		local town = Workspace:WaitForChild("Town", 30)
		local ranches = town and town:WaitForChild("Ranches", 30)
		if not ranches then
			return
		end
		for _, ranch in ranches:GetChildren() do
			ranch:GetAttributeChangedSignal("Owner"):Connect(function()
				applyTheme(ranch)
			end)
		end
		refreshRanches()
	end)
end

return Looks
