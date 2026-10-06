--!strict
-- The reveal overlay for eggs, strongboxes, steals, Frontiers and exclusives.
-- Beats: dim -> wobble x3 (rising) -> crack/flash -> rarity ladder climbs and STOPS AT THE TRUE RESULT
-- (never a fake near-miss) -> rays + burst -> critter + name card slam -> income/caption.
-- Duration scales with rarity; tap to skip; "Quick reveal" setting and Reduced Motion shorten it.

local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local Cosmetics = require("@game/ReplicatedStorage/Shared/Config/Cosmetics")
local Rarities = require("@game/ReplicatedStorage/Shared/Config/Rarities")
local Species = require("@game/ReplicatedStorage/Shared/Config/Species")
local Economy = require("@game/ReplicatedStorage/Shared/Sim/Economy")
local NumberFormat = require("@game/ReplicatedStorage/Shared/Sim/NumberFormat")
local CritterRig = require("../Controllers/CritterRig")
local Quality = require("../Controllers/Quality")
local Sound = require("../Controllers/Sound")
local Store = require("../Store")
local Theme = require("./Theme")

local Reveal = {}

local queue: { any } = {}
local playing = false
local gui: ScreenGui
local skip = false

local REVEAL_SOUND = {
	"revealCommon",
	"revealCommon",
	"revealRare",
	"revealEpic",
	"revealLegendary",
	"revealMythic",
	"revealMythic",
	"revealSecret",
}
-- Seconds of build-up by rarity index (Common .. Secret).
local DURATION = { 1.2, 1.4, 2.5, 3, 4, 5, 6, 7 }

local function tween(instance: Instance, seconds: number, props: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?)
	local t = TweenService:Create(instance, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

local function wait(seconds: number)
	local t0 = os.clock()
	while os.clock() - t0 < seconds and not skip do
		task.wait()
	end
end

local function make(className: string, props: { [string]: any }, parent: Instance?): any
	local inst = Instance.new(className)
	for k, v in props do
		(inst :: any)[k] = v
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function label(parent: Instance, text: string, font: Font, color: Color3, size: UDim2, pos: UDim2): TextLabel
	local t = make("TextLabel", {
		Size = size,
		Position = pos,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = color,
		FontFace = font,
		TextScaled = true,
	}, parent)
	make("UIStroke", { Thickness = 3, Color = Theme.color.ink }, t)
	return t
end

-- Spinning light rays behind the reward.
local function rays(parent: Instance, color: Color3): Frame
	local holder = make("Frame", {
		Size = UDim2.fromScale(0.9, 0.9),
		Position = UDim2.fromScale(0.5, 0.45),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
	}, parent)
	make("UIAspectRatioConstraint", { AspectRatio = 1 }, holder)
	for i = 1, 12 do
		local ray = make("Frame", {
			Size = UDim2.new(0.07, 0, 0.5, 0),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			Rotation = i * 30,
		}, holder)
		make("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.6, 0.55), NumberSequenceKeypoint.new(1, 0.85) }),
		}, ray)
	end
	task.spawn(function()
		while holder.Parent do
			holder.Rotation += 0.6
			task.wait()
		end
	end)
	return holder
end

local function critterViewport(parent: Instance, speciesId: string, tier: number, mutation: string?): ViewportFrame
	local vp = make("ViewportFrame", {
		Size = UDim2.fromScale(0.42, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(200, 190, 180),
		LightColor = Color3.fromRGB(255, 240, 220),
		LightDirection = Vector3.new(-0.6, -1, -0.8),
	}, parent)
	make("UIAspectRatioConstraint", { AspectRatio = 1 }, vp)
	local model = CritterRig.build(speciesId, tier, mutation, 1, 4)
	model.Parent = vp
	local camera = make("Camera", { FieldOfView = 35 }, vp)
	vp.CurrentCamera = camera
	local r = (model:GetAttribute("Radius") :: number?) or 2
	camera.CFrame = CFrame.lookAt(Vector3.new(0, r * 1.2, -r * 6), Vector3.new(0, r * 0.9, 0))
	local scale = make("UIScale", { Scale = 0.1 }, vp)
	tween(scale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
	task.spawn(function()
		local t0 = os.clock()
		while vp.Parent do
			local t = os.clock() - t0
			model:PivotTo(CFrame.new(0, r + math.abs(math.sin(t * 3)) * r * 0.2, 0) * CFrame.Angles(0, math.pi + t * 1.2, 0))
			CritterRig.updateRainbow(model, t)
			task.wait()
		end
	end)
	return vp
end

local function buildEgg(parent: Instance, color: Color3): Frame
	local egg = make("Frame", {
		Size = UDim2.fromScale(0.18, 0.3),
		Position = UDim2.fromScale(0.5, 0.45),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = color,
	}, parent)
	make("UIAspectRatioConstraint", { AspectRatio = 0.78 }, egg)
	make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, egg)
	make("UIStroke", { Thickness = 5, Color = Theme.color.ink }, egg)
	make("UIGradient", {
		Rotation = 70,
		Color = ColorSequence.new(Theme.lighten(color, 0.5), Theme.darken(color, 0.15)),
	}, egg)
	-- Spots
	for i = 1, 4 do
		local spot = make("Frame", {
			Size = UDim2.fromScale(0.18, 0.14),
			Position = UDim2.fromScale(0.2 + (i % 2) * 0.45, 0.2 + i * 0.15),
			BackgroundColor3 = Theme.lighten(color, 0.6),
			BackgroundTransparency = 0.2,
		}, egg)
		make("UICorner", { CornerRadius = UDim.new(1, 0) }, spot)
	end
	return egg
end

local function play(data: any)
	skip = false
	local reduced = Quality.reducedMotion()
	local quick = (Store.state() and Store.state().settings and Store.state().settings.QuickReveal) or reduced

	local tier = data.tier or 1
	local rarity = Rarities.forTier(math.clamp(tier, 1, Rarities.maxTier))
	local rarityIndex = Rarities.indexOf(rarity.id)
	local color = Theme.rarityColor(rarity.id)
	local isCritter = data.species ~= nil and (data.kind == "egg" or data.kind == "stolen" or data.kind == "exclusive")

	local root = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 50 }, gui)
	local dim = make("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
	}, root)
	dim.Activated:Connect(function()
		skip = true
	end)
	tween(dim, 0.25, { BackgroundTransparency = 0.35 })
	local blur = make("BlurEffect", { Size = 0 }, Lighting)
	tween(blur, 0.3, { Size = 14 })

	-- Build-up
	local buildup = if quick then 0.4 else DURATION[rarityIndex] or 1.5
	if data.kind == "egg" or data.kind == "strongbox" or data.kind == "gift" then
		local eggColor = if data.kind == "strongbox" then Theme.color.brass else Theme.color.cream
		local egg = buildEgg(root, eggColor)
		local beats = 3
		for beat = 1, beats do
			Sound.play("eggWobble", 0.02)
			local angle = 6 + beat * 5
			for _ = 1, 2 do
				tween(egg, buildup / beats / 4, { Rotation = angle })
				wait(buildup / beats / 4)
				tween(egg, buildup / beats / 4, { Rotation = -angle })
				wait(buildup / beats / 4)
			end
			-- Rarity ladder: the egg glows through each rarity color up to the TRUE one, then stops.
			if data.kind == "egg" then
				local step = math.min(rarityIndex, math.ceil(rarityIndex * beat / beats))
				egg.BackgroundColor3 = Theme.rarityColor(Rarities.list[math.max(1, step)].id)
			end
		end
		Sound.play(if data.kind == "strongbox" then "strongboxOpen" else "eggCrack")
		egg:Destroy()
	elseif data.kind == "frontier" then
		Sound.play("frontier")
		Sound.announce("ann_frontier")
		wait(if quick then 0.2 else 0.8)
	end

	-- Flash (max one per reveal, well under 3/s)
	if not reduced then
		local flash = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.1 }, root)
		tween(flash, 0.4, { BackgroundTransparency = 1 })
		task.delay(0.45, function()
			flash:Destroy()
		end)
	end
	if not reduced and Store.quality() >= 2 then
		rays(root, color)
	end
	Sound.play(REVEAL_SOUND[rarityIndex] or "revealCommon")

	-- Content
	local title = ""
	local caption = ""
	if isCritter then
		local species = Species.byId[data.species]
		critterViewport(root, data.species, tier, data.mutation)
		title = (if data.mutation then string.upper(data.mutation) .. " " else "") .. string.upper(species and species.name or "?")
		if data.kind == "stolen" then
			caption = "STOLEN! It's yours now."
		elseif data.kind == "exclusive" then
			caption = "BRANDED: can't be stolen, kept through Frontiers"
		elseif data.kept == false then
			caption = `Pens full — sold for {NumberFormat.cash(data.soldFor or 0)}`
		else
			caption = `Earns {NumberFormat.perSecond(Economy.income(tier))} (before boosts)`
		end
		-- Legendary and up get the full announcer: "Yeeeehaw! It's..." then the name.
		if rarityIndex >= 5 and not quick then
			Sound.announce("ann_itsA")
			task.delay(1.4, Sound.voice, data.species)
		else
			Sound.voice(data.species)
		end
	elseif data.kind == "strongbox" then
		if data.loot == "cash" then
			title = "+" .. NumberFormat.cash(data.amount or 0)
		elseif data.loot == "nuggets" then
			title = `+{data.amount or 0} GOLD NUGGETS`
		elseif data.loot == "egg" then
			title = if data.pity then "LUCKY STREAK EGG!" else "AN EGG!"
		else
			local cosmetic = data.cosmetic and Cosmetics.byId[data.cosmetic]
			title = if cosmetic then string.upper(cosmetic.name) else "NUGGETS (DUPLICATE)"
		end
		caption = `Lucky streak: {data.pityCount or 0}/6`
	elseif data.kind == "frontier" then
		title = `FRONTIER {data.level}!`
		caption = `Income x{data.level + 1} · +1 pen · new unlocks`
	elseif data.kind == "gift" then
		title = "GIFT!"
	elseif data.kind == "streak" then
		title = `DAY {data.slot} STREAK!`
	elseif data.kind == "cosmetic" then
		local cosmetic = Cosmetics.byId[data.id]
		title = if cosmetic then string.upper(cosmetic.name) else "NEW COSMETIC"
		caption = "Equipped!"
	end

	local card = make("Frame", {
		Size = UDim2.fromScale(0.5, 0.13),
		Position = UDim2.fromScale(0.5, 0.74),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = color,
	}, root)
	make("UISizeConstraint", { MaxSize = Vector2.new(620, 110) }, card)
	make("UICorner", { CornerRadius = UDim.new(0, 16) }, card)
	make("UIStroke", { Thickness = 5, Color = Theme.color.ink }, card)
	make("UIGradient", { Rotation = 90, Color = ColorSequence.new(Theme.lighten(color, 0.3), Theme.darken(color, 0.15)) }, card)
	local cardScale = make("UIScale", { Scale = 2.2 }, card)
	tween(cardScale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	label(card, title, Theme.font.title, Theme.color.white, UDim2.fromScale(0.94, 0.62), UDim2.fromScale(0.5, 0.38))
	if isCritter then
		label(card, `{Theme.glyphFor(rarity.id)} {string.upper(rarity.name)}`, Theme.font.heading, Theme.color.white, UDim2.fromScale(0.9, 0.3), UDim2.fromScale(0.5, 0.82))
	end
	if caption ~= "" then
		label(root, caption, Theme.font.heading, Theme.color.cream, UDim2.fromScale(0.6, 0.05), UDim2.fromScale(0.5, 0.86))
	end
	label(root, "tap to continue", Theme.font.body, Theme.color.paper, UDim2.fromScale(0.3, 0.03), UDim2.fromScale(0.5, 0.94))

	-- Hold, then exit (tap skips).
	skip = false
	wait(if quick then 0.8 else 1.6 + rarityIndex * 0.25)
	tween(dim, 0.25, { BackgroundTransparency = 1 })
	tween(blur, 0.25, { Size = 0 })
	for _, d in root:GetDescendants() do
		if d:IsA("GuiObject") then
			tween(d, 0.2, { BackgroundTransparency = 1 })
		end
	end
	task.wait(0.25)
	root:Destroy()
	blur:Destroy()
end

local function pump()
	if playing then
		return
	end
	playing = true
	task.spawn(function()
		while #queue > 0 do
			local data = table.remove(queue, 1)
			local ok, err = pcall(play :: any, data)
			if not ok then
				warn("[Reveal] " .. tostring(err))
			end
		end
		playing = false
	end)
end

function Reveal.push(data: any)
	table.insert(queue, data)
	pump()
end

function Reveal.mount(parent: ScreenGui)
	gui = parent
end

return Reveal
