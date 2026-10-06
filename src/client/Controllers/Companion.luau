--!strict
-- Companion critters: the critter a player picked in the Wardrobe (server attributes
-- Equip_companion / CompanionTier / CompanionMutation) trots along behind-left of them, bobbing and
-- facing the way they walk. Legendary+ companions sparkle. On the lowest quality tier only your own
-- companion is drawn.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Rarities = require("@game/ReplicatedStorage/Shared/Config/Rarities")
local Store = require("../Store")
local CritterRig = require("./CritterRig")

local Companion = {}

local SCALE = 0.6
local BODY = 2.4 -- CritterRig's default body diameter; scaled below
local OFFSET = Vector3.new(-2.5, 0, 2.5) -- behind-left in the player's local frame (~3.5 studs)
local FOLLOW = 7 -- lerp rate per second
local SNAP_DISTANCE = 60 -- teleport instead of lerping across the map
local SPARKLE = "rbxassetid://6490035152"

type Entry = {
	model: Model,
	key: string,
	seed: number,
	position: Vector3,
	look: Vector3,
	radius: number,
}

local entries: { [Player]: Entry } = {}
local localPlayer = Players.LocalPlayer
local folder: Folder? = nil

local function container(): Folder
	if folder and folder.Parent then
		return folder
	end
	local f = Instance.new("Folder")
	f.Name = "Companions"
	f.Parent = Workspace
	folder = f
	return f
end

local function sparkle(model: Model, tier: number)
	local root = model.PrimaryPart
	if not root then
		return
	end
	local rarity = Rarities.forTier(math.clamp(tier, 1, Rarities.maxTier))
	if Rarities.indexOf(rarity.id) < 5 then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "CompanionSparkle"
	attachment.Parent = root
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = SPARKLE
	emitter.Color = ColorSequence.new(Color3.fromHex(rarity.color), Color3.new(1, 1, 1))
	emitter.LightEmission = 1
	emitter.Size =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 0) })
	emitter.Transparency =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	emitter.Lifetime = NumberRange.new(0.6, 1.1)
	emitter.Speed = NumberRange.new(1, 2.5)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rate = 8
	emitter.Parent = attachment
end

local function clear(player: Player)
	local entry = entries[player]
	if entry then
		entry.model:Destroy()
		entries[player] = nil
	end
end

local function wanted(player: Player): boolean
	-- Other players' companions are skipped on the lowest quality tier.
	return player == localPlayer or Store.quality() > 1
end

local function refresh(player: Player)
	local species = player:GetAttribute("Equip_companion") :: string?
	local tier = (player:GetAttribute("CompanionTier") :: number?) or 1
	local mutation = player:GetAttribute("CompanionMutation") :: string?
	if mutation == "" then
		mutation = nil
	end
	local key = if species
			and species ~= ""
			and wanted(player)
		then `{species}:{tier}:{mutation or ""}`
		else ""
	local current = entries[player]
	if current and current.key == key then
		return
	end
	clear(player)
	if key == "" then
		return
	end
	local ok, model =
		pcall(CritterRig.build, species :: string, tier, mutation, Store.quality(), BODY * SCALE)
	if not ok then
		warn(`[Companion] build failed for {species}: {model}`)
		return
	end
	local m = model :: Model
	pcall(sparkle, m, tier)
	m.Name = `{player.Name}_Companion`
	m.Parent = container()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local start = if root then (root.CFrame * CFrame.new(OFFSET)).Position else Vector3.zero
	entries[player] = {
		model = m,
		key = key,
		seed = math.random() * 10,
		position = start,
		look = if root then root.CFrame.LookVector else Vector3.zAxis,
		radius = (m:GetAttribute("Radius") :: number?) or 0.7,
	}
end

local function watchPlayer(player: Player)
	refresh(player)
	player.AttributeChanged:Connect(function(name)
		if name == "Equip_companion" or name == "CompanionTier" or name == "CompanionMutation" then
			refresh(player)
		end
	end)
end

local function step(dt: number)
	local t = os.clock()
	local alpha = 1 - math.exp(-FOLLOW * dt)
	for player, entry in entries do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local model = entry.model
		if not root or not model.Parent then
			continue
		end
		local target = (root.CFrame * CFrame.new(OFFSET)).Position
		if (target - entry.position).Magnitude > SNAP_DISTANCE then
			entry.position = target
		else
			entry.position = entry.position:Lerp(target, alpha)
		end
		-- Face the way we're moving; keep the last heading while standing still.
		local velocity = root.AssemblyLinearVelocity
		local flat = Vector3.new(velocity.X, 0, velocity.Z)
		if flat.Magnitude > 1 then
			entry.look = entry.look:Lerp(flat.Unit, alpha)
		end
		-- Hug the ground under the player's feet so the companion doesn't float on slopes.
		local floor = entry.position.Y - 3
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			floor = root.Position.Y - humanoid.HipHeight - root.Size.Y / 2
		end
		local base = CFrame.lookAt(
			Vector3.new(entry.position.X, floor, entry.position.Z),
			Vector3.new(entry.position.X + entry.look.X, floor, entry.position.Z + entry.look.Z)
		)
		model:PivotTo(CritterRig.pose(base, t, entry.seed, entry.radius))
		CritterRig.updateRainbow(model, t)
	end
end

function Companion.init() end

function Companion.start()
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	Players.PlayerAdded:Connect(watchPlayer)
	Players.PlayerRemoving:Connect(clear)
	-- Quality changes add or drop other players' companions.
	local Vide = require("@game/ReplicatedStorage/Packages/Vide")
	Vide.root(function()
		Vide.effect(function()
			Store.quality()
			for _, player in Players:GetPlayers() do
				task.defer(refresh, player)
			end
		end)
	end)
	RunService.RenderStepped:Connect(step)
end

return Companion
