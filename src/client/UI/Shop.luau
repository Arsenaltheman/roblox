--!strict
-- The Trading Post. Every item sits in the tab where you'd look for it (Passes, Boosts, Cash,
-- Critters, Gear, Nugget Stock) as a picture card with its price tag. Tapping a card opens a big
-- preview: the item's picture (or the live 3D critter) on a stage with an effect that matches what
-- it does: a coin shower for cash, speed lines for spurs, clovers for luck, a shield pulse for
-- locks, smoke for the smoke bomb, a rolling tumbleweed, a snapping trap... and the buy button.
--
-- Robux buttons say "View Item" (Roblox shows the real price prompt); gear costs cash and unlocks by
-- Frontier; cosmetics cost Gold Nuggets and rotate every few minutes.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Vide = require("@game/ReplicatedStorage/Packages/Vide")
local Cosmetics = require("@game/ReplicatedStorage/Shared/Config/Cosmetics")
local GearConfig = require("@game/ReplicatedStorage/Shared/Config/Gear")
local Products = require("@game/ReplicatedStorage/Shared/Config/Products")
local Progression = require("@game/ReplicatedStorage/Shared/Config/Progression")
local Species = require("@game/ReplicatedStorage/Shared/Config/Species")
local NumberFormat = require("@game/ReplicatedStorage/Shared/Sim/NumberFormat")
local Net = require("@game/ReplicatedStorage/Shared/Net/Net")
local Quality = require("../Controllers/Quality")
local Sound = require("../Controllers/Sound")
local Store = require("../Store")
local Components = require("./Components")
local Theme = require("./Theme")

local create = Vide.create :: any
local show = Vide.show
local values = Vide.values :: any
local source = Vide.source
local derive = Vide.derive
local action = Vide.action
local cleanup = Vide.cleanup

local localPlayer = Players.LocalPlayer

local Shop = {}

export type Item = {
	id: string,
	name: string,
	description: string,
	tab: string,
	icon: string, -- assets/ui/<icon>.png
	glyph: string, -- shown until the icon image is uploaded
	color: Color3,
	fx: string,
	currency: "robux" | "cash" | "nuggets",
	price: number,
	monthly: boolean?,
	species: string?, -- show this critter in 3D instead of the icon
	random: boolean?,
	owned: () -> boolean,
	locked: () -> string?,
	buy: () -> (),
}

local TABS = {
	{ id = "passes", label = "PASSES", icon = "ticket", glyph = "★", color = Theme.color.yellow },
	{ id = "boosts", label = "BOOSTS", icon = "clover", glyph = "♣", color = Theme.color.green },
	{ id = "cash", label = "CASH", icon = "moneybag", glyph = "$", color = Theme.color.cash },
	{ id = "critters", label = "CRITTERS", icon = "crate", glyph = "♛", color = Theme.color.purple },
	{ id = "gear", label = "GEAR", icon = "smokebomb", glyph = "☁", color = Theme.color.orange },
	{ id = "stock", label = "NUGGETS", icon = "nugget", glyph = "◆", color = Theme.color.nugget },
}

local FX_COLOR: { [string]: Color3 } = {
	coins = Theme.color.cash,
	gold = Theme.color.yellow,
	luck = Theme.color.green,
	speed = Theme.color.blue,
	shield = Theme.color.purple,
	snap = Theme.color.pink,
	smoke = Color3.fromRGB(120, 130, 150),
	dust = Theme.color.orange,
	trap = Theme.color.red,
	egg = Theme.color.sky,
}

local GLYPH: { [string]: string } = {
	VIP = "★",
	DoubleCash = "2x",
	AutoCollect = "$",
	LuckyHorseshoe = "∩",
	GoldenLasso = "◎",
	SpeedSpurs = "»",
	IronLock = "■",
	HeavySaddlebag = "▲",
	BigRanch = "+2",
	SheriffStar = "✦",
	ServerLuck2 = "x2",
	ServerLuck3 = "x3",
	ServerLuck5 = "x5",
	Lockpick = "!",
	CashBag10m = "$",
	CashBag1h = "$$",
	CashBag6h = "$$$",
	CashBag24h = "$$$$",
	InstantHatch = "◯",
	StreakSaver = "↻",
	SheriffClub = "✪",
}

local CRITTER_OF: { [string]: string } = {
	StarterPack = "DeputyDuck",
	GoldenLocomotive = "GoldenLocomotive",
	DiamondDesperado = "DiamondDesperado",
}

local GEAR_FX: { [string]: string } = {
	SmokeBomb = "smoke",
	TumbleweedBomb = "dust",
	BearTrap = "trap",
	GrappleHook = "speed",
	DynamiteDecoy = "snap",
	CactusWall = "shield",
	StampedeCall = "dust",
	GhostLantern = "smoke",
	TinStar = "shield",
}

-- Bumps whenever a player attribute changes, so "owned" badges update live.
local attrTick = source(0)
localPlayer.AttributeChanged:Connect(function()
	attrTick(attrTick() + 1)
end)

local function state(): any
	return Store.state() or {}
end

local function tween(instance: Instance, time: number, goal: { [string]: any }, style: Enum.EasingStyle?)
	TweenService:Create(instance, TweenInfo.new(time, style or Enum.EasingStyle.Quad), goal):Play()
end

local function text(props: { [any]: any }): Instance
	local base: { [any]: any } = {
		BackgroundTransparency = 1,
		TextColor3 = Theme.color.ink,
		FontFace = Theme.font.body,
		TextScaled = true,
	}
	for k, v in props do
		base[k] = v
	end
	return create("TextLabel")(base)
end

local function priceText(item: Item): string
	if item.currency == "robux" then
		return if item.monthly then `R$ {item.price}/mo` else `R$ {item.price}`
	elseif item.currency == "cash" then
		return `${NumberFormat.short(item.price)}`
	end
	return `{item.price}`
end

-- ---------------------------------------------------------------- the catalogue

local function productItems(): { Item }
	local items = {}
	local restricted = localPlayer:GetAttribute("RandomRestricted") == true
	for _, product in Products.list do
		if product.kind == "privateServer" or (product.random and restricted) then
			continue
		end
		local species = CRITTER_OF[product.key]
		local color = FX_COLOR[product.fx] or Theme.color.blue
		if species and Species.byId[species] then
			color = Theme.rarityForTier(Species.byId[species].tier)
		end
		table.insert(
			items,
			{
				id = product.key,
				name = product.name,
				description = product.description,
				tab = product.category,
				icon = product.icon,
				glyph = GLYPH[product.key] or "★",
				color = color,
				fx = product.fx,
				currency = "robux",
				price = product.price,
				monthly = product.kind == "subscription",
				species = species,
				random = product.random,
				owned = function()
					attrTick()
					if product.kind == "pass" then
						return localPlayer:GetAttribute("Pass_" .. product.key) == true
					elseif product.kind == "subscription" then
						return localPlayer:GetAttribute("Club") == true
					end
					if product.key == "RailPass" then
						local season = state().season
						return season ~= nil and season.premium == true
					end
					return product.key == "StarterPack" and state().starterPack == true
				end,
				locked = function(): string?
					return nil
				end,
				buy = function()
					Net.request("ShopBuy", product.key, 1)
				end,
			} :: Item
		)
	end
	return items
end

local function gearItems(): { Item }
	local items = {}
	for _, gear in GearConfig.list do
		table.insert(
			items,
			{
				id = gear.key,
				name = gear.name,
				description = `{gear.description} Cooldown {gear.cooldown}s. Hotbar key {GearConfig.KEY_LABEL[gear.keybind] or "?"}.`,
				tab = "gear",
				icon = gear.icon,
				glyph = gear.glyph,
				color = FX_COLOR[GEAR_FX[gear.key]] or Theme.color.orange,
				fx = GEAR_FX[gear.key] or "smoke",
				currency = "cash",
				price = gear.price,
				owned = function()
					attrTick()
					return localPlayer:GetAttribute("Gear_" .. gear.key) == true
				end,
				locked = function(): string?
					if (state().frontier or 0) < gear.frontier then
						return `FRONTIER {gear.frontier}`
					end
					return nil
				end,
				buy = function()
					Net.request("BuyGear", gear.key)
				end,
			} :: Item
		)
	end
	return items
end

local hatchery: Item = {
	id = "HatcheryEgg",
	name = "Hatchery Egg",
	description = "A fresh egg for your ranch. Hatch it in the Eggs menu (odds are shown there).",
	tab = "stock",
	icon = "egg",
	glyph = "◯",
	color = Theme.color.sky,
	fx = "egg",
	currency = "nuggets",
	price = Progression.eggs.hatcheryCost,
	owned = function()
		return false
	end,
	locked = function(): string?
		return nil
	end,
	buy = function()
		Net.request("ShopBuy", "HatcheryEgg", 1)
	end,
}

local SLOT_ICON: { [string]: { string } } = {
	lassoTrail = { "lasso", "◎" },
	hat = { "sheriffstar", "▲" },
	poster = { "scroll", "▤" },
	ranchTheme = { "barn", "⌂" },
	title = { "crown", "♛" },
	horse = { "horseshoe", "∩" },
}

local function cosmeticItem(id: string): Item?
	local cosmetic = Cosmetics.byId[id]
	if not cosmetic then
		return nil
	end
	local look = SLOT_ICON[cosmetic.slot] or { "gift", "✦" }
	return {
		id = id,
		name = cosmetic.name,
		description = "A cosmetic: it changes how you look, not how you play. In stock until the next restock.",
		tab = "stock",
		icon = look[1],
		glyph = look[2],
		color = Color3.fromHex(cosmetic.color),
		fx = "gold",
		currency = "nuggets",
		price = cosmetic.nuggets or 0,
		owned = function()
			return (state().owned or {})[id] == true
		end,
		locked = function(): string?
			return nil
		end,
		buy = function()
			Net.request("ShopBuy", id, 1)
		end,
	}
end

-- ---------------------------------------------------------------- picture + effects

-- The item's picture: the live 3D critter, or its icon image (glyph until uploaded).
local function picture(item: Item, size: UDim2, idle: boolean?): Instance
	if item.species then
		return Components.mascot({
			species = item.species,
			tier = Species.byId[item.species] and Species.byId[item.species].tier or 5,
			size = size,
			position = UDim2.fromScale(0.5, 0.5),
		})
	end
	return create("Frame")({
		Name = "Picture",
		Size = size,
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		ZIndex = 6,
		Components.icon(item.icon, item.glyph, Theme.color.white),
		if idle then Components.idle(5, 2.4) else nil,
	})
end

-- One-shot particle: created at `from`, tweened to `to`, then removed.
local function particle(
	layer: GuiObject,
	gui: GuiObject,
	from: UDim2,
	to: UDim2,
	seconds: number,
	goal: { [string]: any }?
)
	gui.Position = from
	gui.AnchorPoint = Vector2.new(0.5, 0.5)
	gui.Parent = layer
	local props: { [string]: any } = { Position = to }
	for k, v in (goal or {}) :: { [string]: any } do
		props[k] = v
	end
	TweenService:Create(gui, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In), props)
		:Play()
	task.delay(seconds, function()
		gui:Destroy()
	end)
end

local function glyphLabel(glyph: string, color: Color3, px: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromOffset(px, px)
	label.BackgroundTransparency = 1
	label.Text = glyph
	label.TextScaled = true
	label.TextColor3 = color
	label.FontFace = Theme.font.title
	label.ZIndex = 4
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Theme.color.ink
	stroke.Parent = label
	return label
end

local function iconParticle(name: string, glyph: string, color: Color3, px: number): GuiObject
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromOffset(px, px)
	frame.BackgroundTransparency = 1
	frame.ZIndex = 4
	local icon = Components.icon(name, glyph, color) :: GuiObject
	icon.Parent = frame
	return frame
end

local function circle(color: Color3, px: number, transparency: number): Frame
	local f = Instance.new("Frame")
	f.Size = UDim2.fromOffset(px, px)
	f.BackgroundColor3 = color
	f.BackgroundTransparency = transparency
	f.BorderSizePixel = 0
	f.ZIndex = 3
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = f
	return f
end

local function ring(color: Color3): Frame
	local f = Instance.new("Frame")
	f.Size = UDim2.fromScale(0.3, 0.3)
	f.SizeConstraint = Enum.SizeConstraint.RelativeYY
	f.BackgroundTransparency = 1
	f.ZIndex = 3
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = f
	local s = Instance.new("UIStroke")
	s.Thickness = 8
	s.Color = color
	s.Parent = f
	return f
end

local function rand(a: number, b: number): number
	return a + math.random() * (b - a)
end

-- Runs the item's effect inside `layer` (behind the picture) and moves the picture to match.
-- `pic` is the picture's holder frame; `stage` is the whole stage (for shakes).
local function runEffect(fx: string, color: Color3, layer: GuiObject, pic: GuiObject, stage: GuiObject)
	local alive = true
	local t0 = os.clock()
	local function every(seconds: number, fn: () -> ())
		task.spawn(function()
			task.wait(math.min(seconds, 0.6))
			while alive and layer.Parent do
				fn()
				task.wait(seconds)
			end
		end)
	end
	local function punch(scale: number)
		local s = pic:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
		s.Parent = pic
		s.Scale = scale
		tween(s, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
	end
	local function shake(px: number)
		if Quality.reducedMotion() then
			return
		end
		task.spawn(function()
			for _ = 1, 6 do
				stage.Position = UDim2.new(0, math.random(-px, px), 0, math.random(-px, px))
				task.wait(0.03)
			end
			stage.Position = UDim2.new()
		end)
	end

	if fx == "coins" then
		-- A coin shower that piles up, with cash numbers popping.
		every(0.07, function()
			local px = math.random(26, 46)
			local coin = iconParticle("coin", "$", Theme.color.yellow, px)
			coin.Rotation = math.random(-40, 40)
			local x = rand(0.05, 0.95)
			particle(
				layer,
				coin,
				UDim2.fromScale(x, -0.1),
				UDim2.fromScale(x + rand(-0.08, 0.08), 1.1),
				rand(0.9, 1.5),
				{ Rotation = coin.Rotation + math.random(-200, 200) }
			)
		end)
		every(0.9, function()
			punch(1.12)
			local label = glyphLabel(
				`+${math.random(2, 9)}{({ "K", "M", "B" })[math.random(1, 3)]}`,
				Theme.color.cash,
				44
			)
			label.Size = UDim2.fromOffset(110, 44)
			local x = rand(0.25, 0.75)
			particle(
				layer,
				label,
				UDim2.fromScale(x, 0.65),
				UDim2.fromScale(x, 0.2),
				0.9,
				{ TextTransparency = 1 }
			)
		end)
	elseif fx == "gold" then
		-- Gold glitter rising and a shine sweep across the picture.
		every(0.12, function()
			local s = glyphLabel("✦", Color3.fromRGB(255, 240, 160), math.random(14, 30))
			local x = rand(0.05, 0.95)
			particle(
				layer,
				s,
				UDim2.fromScale(x, rand(0.6, 1)),
				UDim2.fromScale(x, rand(0, 0.4)),
				rand(0.8, 1.4),
				{
					TextTransparency = 1,
					Rotation = 180,
				}
			)
		end)
		every(1.6, function()
			punch(1.08)
			local sweep = Instance.new("Frame")
			sweep.Size = UDim2.fromScale(0.25, 1.6)
			sweep.Rotation = 20
			sweep.BackgroundColor3 = Color3.new(1, 1, 1)
			sweep.BackgroundTransparency = 0.55
			sweep.BorderSizePixel = 0
			sweep.ZIndex = 30
			particle(
				layer.Parent :: GuiObject,
				sweep,
				UDim2.fromScale(-0.2, 0.5),
				UDim2.fromScale(1.2, 0.5),
				0.7,
				{
					BackgroundTransparency = 0.8,
				}
			)
		end)
	elseif fx == "luck" then
		-- Four-leaf clovers float up and sway; the picture glows green.
		every(0.16, function()
			local clover = iconParticle("clover", "♣", Theme.color.green, math.random(24, 44))
			local x = rand(0.05, 0.95)
			particle(
				layer,
				clover,
				UDim2.fromScale(x, 1.1),
				UDim2.fromScale(x + rand(-0.15, 0.15), -0.1),
				rand(1.4, 2.2),
				{
					Rotation = math.random(-90, 90),
				}
			)
		end)
		every(1.3, function()
			punch(1.1)
		end)
	elseif fx == "speed" then
		-- Speed lines streak past and the picture leans into the wind.
		pic.Rotation = -8
		every(0.04, function()
			local line = Instance.new("Frame")
			line.Size = UDim2.new(rand(0.2, 0.45), 0, 0, math.random(3, 7))
			line.BackgroundColor3 = Color3.new(1, 1, 1)
			line.BackgroundTransparency = rand(0.1, 0.5)
			line.BorderSizePixel = 0
			line.ZIndex = 3
			local y = rand(0.05, 0.95)
			particle(layer, line, UDim2.fromScale(1.3, y), UDim2.fromScale(-0.3, y), rand(0.25, 0.45))
		end)
		every(0.08, function()
			pic.Position = UDim2.new(0.5, math.random(-3, 3), 0.5, math.random(-3, 3))
		end)
		every(0.9, function()
			local puff = circle(Color3.fromRGB(230, 200, 150), math.random(30, 50), 0.3)
			particle(layer, puff, UDim2.fromScale(0.62, 0.78), UDim2.fromScale(0.95, 0.75), 0.6, {
				BackgroundTransparency = 1,
				Size = UDim2.fromOffset(90, 90),
			})
		end)
	elseif fx == "shield" then
		-- Shield rings pulse out from the item.
		every(0.55, function()
			local r = ring(color)
			particle(layer, r, UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.5, 0.5), 1.1, {
				Size = UDim2.fromScale(1.4, 1.4),
			})
			local stroke = r:FindFirstChildOfClass("UIStroke")
			if stroke then
				tween(stroke, 1.1, { Transparency = 1 })
			end
		end)
		every(1.1, function()
			punch(1.06)
		end)
	elseif fx == "snap" or fx == "trap" then
		-- SNAP: the item clamps shut with a punch, a shake and a burst of sparks.
		every(1.3, function()
			punch(1.25)
			shake(if fx == "trap" then 8 else 4)
			for i = 1, 10 do
				local spark = glyphLabel("✦", Theme.color.yellow, math.random(16, 28))
				local a = (i / 10) * math.pi * 2 + rand(-0.2, 0.2)
				particle(
					layer,
					spark,
					UDim2.fromScale(0.5, 0.5),
					UDim2.fromScale(0.5 + math.cos(a) * 0.45, 0.5 + math.sin(a) * 0.45),
					0.5,
					{ TextTransparency = 1 }
				)
			end
			if fx == "trap" then
				local label = glyphLabel("SNAP!", Theme.color.red, 60)
				label.Size = UDim2.fromOffset(170, 60)
				label.Rotation = math.random(-12, 12)
				particle(layer, label, UDim2.fromScale(0.5, 0.25), UDim2.fromScale(0.5, 0.12), 0.7, {
					TextTransparency = 1,
				})
			end
		end)
	elseif fx == "critter" then
		-- A rarity light beam from the sky and stars rising around the critter.
		local beam = Instance.new("Frame")
		beam.Size = UDim2.fromScale(0.42, 1.2)
		beam.Position = UDim2.fromScale(0.5, 0.45)
		beam.AnchorPoint = Vector2.new(0.5, 0.5)
		beam.BackgroundColor3 = color
		beam.BorderSizePixel = 0
		beam.ZIndex = 2
		local g = Instance.new("UIGradient")
		g.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0.25),
			NumberSequenceKeypoint.new(1, 1),
		})
		g.Parent = beam
		beam.Parent = layer
		every(0.05, function()
			beam.Size = UDim2.fromScale(0.42 + math.sin((os.clock() - t0) * 4) * 0.06, 1.2)
		end)
		every(0.1, function()
			local s = glyphLabel("✦", Theme.lighten(color, 0.4), math.random(14, 28))
			local x = rand(0.3, 0.7)
			particle(
				layer,
				s,
				UDim2.fromScale(x, 1),
				UDim2.fromScale(x, -0.05),
				rand(1, 1.6),
				{ TextTransparency = 1 }
			)
		end)
	elseif fx == "smoke" then
		-- The bomb puffs out smoke and vanishes into it, then pops back.
		every(0.09, function()
			local grey = math.random(150, 220)
			local puff = circle(Color3.fromRGB(grey, grey, grey + 10), math.random(40, 80), 0.2)
			particle(
				layer,
				puff,
				UDim2.fromScale(rand(0.4, 0.6), rand(0.5, 0.7)),
				UDim2.fromScale(rand(0, 1), rand(0.05, 0.6)),
				rand(1, 1.6),
				{ BackgroundTransparency = 1, Size = UDim2.fromOffset(160, 160) }
			)
		end)
		every(2.4, function()
			local s = pic:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
			s.Parent = pic
			tween(s, 0.25, { Scale = 0 })
			task.delay(0.9, function()
				tween(s, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
			end)
		end)
	elseif fx == "dust" then
		-- The tumbleweed rolls, bounces and kicks up dust.
		every(0.03, function()
			local t = os.clock() - t0
			pic.Rotation = (t * 220) % 360
			pic.Position = UDim2.new(0.5, math.sin(t * 1.4) * 60, 0.5, -math.abs(math.sin(t * 5)) * 30)
		end)
		every(0.12, function()
			local puff = circle(Color3.fromRGB(214, 170, 110), math.random(20, 40), 0.25)
			local x = 0.5 + math.sin((os.clock() - t0) * 1.4) * 0.15
			particle(
				layer,
				puff,
				UDim2.fromScale(x, 0.8),
				UDim2.fromScale(x + rand(-0.25, 0.25), rand(0.6, 0.85)),
				0.8,
				{
					BackgroundTransparency = 1,
					Size = UDim2.fromOffset(80, 80),
				}
			)
		end)
	elseif fx == "egg" then
		-- The egg wobbles like it's about to hatch.
		every(1.6, function()
			for _, angle in { 12, -12, 8, -8, 0 } do
				tween(pic, 0.1, { Rotation = angle })
				task.wait(0.1)
			end
			punch(1.1)
		end)
		every(0.2, function()
			local s = glyphLabel("✦", Theme.color.white, math.random(12, 24))
			local x = rand(0.2, 0.8)
			particle(
				layer,
				s,
				UDim2.fromScale(x, 0.8),
				UDim2.fromScale(x, 0.2),
				1.1,
				{ TextTransparency = 1 }
			)
		end)
	end

	return function()
		alive = false
	end
end

-- ---------------------------------------------------------------- cards

local function hoverScale(): any
	return action(function(instance: Instance)
		local button = instance :: GuiButton
		local scale = Instance.new("UIScale")
		scale.Parent = button
		local connections = {
			button.MouseEnter:Connect(function()
				tween(scale, 0.18, { Scale = 1.05 }, Enum.EasingStyle.Back)
			end),
			button.MouseLeave:Connect(function()
				tween(scale, 0.2, { Scale = 1 })
			end),
			button.MouseButton1Down:Connect(function()
				tween(scale, 0.07, { Scale = 0.95 })
			end),
			button.MouseButton1Up:Connect(function()
				tween(scale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
			end),
		}
		cleanup(function()
			for _, c in connections do
				c:Disconnect()
			end
		end)
	end)
end

local function priceTag(item: Item, height: number): Instance
	return create("Frame")({
		Name = "PriceTag",
		Size = UDim2.new(1, -16, 0, height),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 6,
		Components.corner(UDim.new(0, 10)),
		Components.stroke(2.5),
		Components.gradient(function()
			if item.owned() then
				return Theme.color.green
			elseif item.locked() then
				return Color3.fromRGB(120, 120, 130)
			end
			return if item.currency == "robux"
				then Theme.color.green
				elseif item.currency == "cash" then Theme.color.cash
				else Theme.color.nugget
		end),
		create("Frame")({
			Size = UDim2.fromOffset(height - 6, height - 6),
			Position = UDim2.new(0, 4, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundTransparency = 1,
			ZIndex = 7,
			Visible = function()
				return item.currency == "nuggets" and not item.owned()
			end,
			Components.icon("nugget", "◆", Theme.color.nugget),
		}),
		text({
			Size = UDim2.new(1, -12, 1, -6),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			TextColor3 = Theme.color.white,
			FontFace = Theme.font.title,
			ZIndex = 7,
			Text = function()
				if item.owned() then
					return "✔ OWNED"
				end
				local locked = item.locked()
				if locked then
					return `🔒 {locked}`
				end
				return if item.currency == "nuggets" then `   {item.price}` else priceText(item)
			end,
			Components.textStroke(2.5),
		}),
	})
end

local function itemCard(item: Item, order: number, onSelect: (Item) -> ()): Instance
	return create("TextButton")({
		Name = item.id,
		LayoutOrder = order,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		Activated = function()
			Sound.play("click")
			onSelect(item)
		end,
		hoverScale(),
		create("Frame")({
			Name = "Card",
			Components.popIn(order * 0.03),
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(1, 1, 1),
			ZIndex = 1,
			Components.corner(UDim.new(0, 16)),
			Components.stroke(3),
			Components.gradient(Theme.lighten(item.color, 0.75)),
			-- The stage: dark backdrop in the item's colour, a slow sunburst, the picture.
			create("Frame")({
				Name = "Stage",
				Size = UDim2.new(1, -12, 0.64, 0),
				Position = UDim2.fromOffset(6, 6),
				BackgroundColor3 = Color3.new(1, 1, 1),
				ClipsDescendants = true,
				ZIndex = 2,
				Components.corner(UDim.new(0, 12)),
				Components.gradient(Theme.darken(item.color, 0.15)),
				Components.stripes(UDim.new(0, 12), 0.08),
				create("Frame")({
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					ZIndex = 3,
					Components.sunburst(Theme.lighten(item.color, 0.5), 10, UDim2.fromScale(1.5, 1.5)),
				}),
				picture(item, UDim2.fromScale(0.78, 0.86), true),
				(if item.random
					then text({
						Size = UDim2.fromOffset(56, 20),
						Position = UDim2.new(1, -4, 0, 4),
						AnchorPoint = Vector2.new(1, 0),
						BackgroundTransparency = 0,
						BackgroundColor3 = Theme.color.skyDeep,
						TextColor3 = Theme.color.white,
						FontFace = Theme.font.title,
						Text = "ODDS",
						ZIndex = 8,
						Components.corner(UDim.new(0, 6)),
					})
					else nil) :: any,
			}),
			text({
				Size = UDim2.new(1, -12, 0.15, 0),
				Position = UDim2.new(0.5, 0, 0.66, 4),
				AnchorPoint = Vector2.new(0.5, 0),
				Text = item.name,
				TextColor3 = Theme.color.white,
				FontFace = Theme.font.title,
				ZIndex = 4,
				Components.textStroke(2.5),
			}),
			create("Frame")({
				Size = UDim2.new(1, 0, 0.17, 0),
				Position = UDim2.new(0, 8, 1, -6),
				AnchorPoint = Vector2.new(0, 1),
				BackgroundTransparency = 1,
				ZIndex = 5,
				priceTag(item, 30),
			}),
		}),
	})
end

local function grid(children: any): Instance
	return create("ScrollingFrame")({
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ScrollBarThickness = 8,
		VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		create("UIGridLayout")({
			CellSize = UDim2.new(0.25, -12, 0, 214),
			CellPadding = UDim2.fromOffset(12, 12),
			SortOrder = Enum.SortOrder.LayoutOrder,
			-- Cards keep their shape on small screens.
			create("UIAspectRatioConstraint")({ AspectRatio = 0.86 }),
		}),
		Components.padding(8),
		children,
	})
end

-- ---------------------------------------------------------------- the preview

local function showOdds()
	task.spawn(function()
		local result = Net.invoke("GetOdds", "reserved")
		if result then
			Store.odds({ kind = "reserved", data = result })
		end
	end)
end

local function preview(item: Item, onClose: () -> ()): Instance
	local tabLabel = "ITEM"
	for _, tab in TABS do
		if tab.id == item.tab then
			tabLabel = tab.label
		end
	end
	return create("Frame")({
		Name = "Preview",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 20,
		create("TextButton")({
			Size = UDim2.fromScale(3, 3),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.35,
			AutoButtonColor = false,
			Text = "",
			ZIndex = 20,
			Activated = onClose,
		}),
		create("Frame")({
			Name = "Window",
			Active = true,
			Size = UDim2.fromScale(0.7, 0.66),
			Position = UDim2.fromScale(0.5, 0.52),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.new(1, 1, 1),
			ZIndex = 21,
			create("UISizeConstraint")({ MaxSize = Vector2.new(780, 430), MinSize = Vector2.new(320, 220) }),
			Components.corner(UDim.new(0, 22)),
			Components.stroke(5),
			Components.gradient(Theme.color.cream),
			Components.stripes(UDim.new(0, 22), 0.05),
			Components.popIn(),
			-- Left: the stage with the item and its effect.
			create("Frame")({
				Name = "StageHolder",
				Size = UDim2.new(0.52, -14, 1, -28),
				Position = UDim2.fromOffset(14, 14),
				BackgroundTransparency = 1,
				ZIndex = 22,
				create("Frame")({
					Name = "Stage",
					Size = UDim2.fromScale(1, 1),
					BackgroundColor3 = Color3.new(1, 1, 1),
					ClipsDescendants = true,
					ZIndex = 22,
					Components.corner(UDim.new(0, 18)),
					Components.stroke(4),
					Components.gradient(Theme.darken(item.color, 0.2)),
					Components.stripes(UDim.new(0, 18), 0.07),
					create("Frame")({
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						ZIndex = 23,
						Components.sunburst(Theme.lighten(item.color, 0.55), 14, UDim2.fromScale(1.7, 1.7)),
					}),
					-- Ground shadow under the item.
					create("Frame")({
						Size = UDim2.fromScale(0.5, 0.08),
						Position = UDim2.fromScale(0.5, 0.86),
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundColor3 = Color3.new(0, 0, 0),
						BackgroundTransparency = 0.6,
						ZIndex = 23,
						Components.corner(UDim.new(1, 0)),
					}),
					(action :: any)(function(instance: Instance)
						local stage = instance :: Frame
						local layer = Instance.new("Frame")
						layer.Name = "Fx"
						layer.Size = UDim2.fromScale(1, 1)
						layer.BackgroundTransparency = 1
						layer.ZIndex = 24
						layer.Parent = stage
						local pic = Instance.new("Frame")
						pic.Name = "Hero"
						pic.Size = UDim2.fromScale(0.8, 0.8)
						pic.Position = UDim2.fromScale(0.5, 0.5)
						pic.AnchorPoint = Vector2.new(0.5, 0.5)
						pic.SizeConstraint = Enum.SizeConstraint.RelativeYY
						pic.BackgroundTransparency = 1
						pic.ZIndex = 26
						pic.Parent = stage
						local inner = picture(item, UDim2.fromScale(1, 1), item.fx ~= "dust") :: GuiObject
						inner.Parent = pic
						-- Entrance: drop in big and settle.
						local s = Instance.new("UIScale")
						s.Scale = 0
						s.Parent = pic
						tween(s, 0.5, { Scale = 1 }, Enum.EasingStyle.Back)
						local stop = runEffect(item.fx, item.color, layer, pic, stage)
						cleanup(stop)
					end),
				}),
			}),
			-- Right: what it is and the buy button.
			create("Frame")({
				Name = "Info",
				Size = UDim2.new(0.48, -28, 1, -28),
				Position = UDim2.new(0.52, 14, 0, 14),
				BackgroundTransparency = 1,
				ZIndex = 22,
				text({
					Size = UDim2.fromOffset(120, 26),
					BackgroundTransparency = 0,
					BackgroundColor3 = item.color,
					TextColor3 = Theme.color.white,
					FontFace = Theme.font.title,
					Text = tabLabel,
					ZIndex = 23,
					Components.corner(UDim.new(0, 8)),
					Components.stroke(2.5),
					Components.textStroke(2),
					Components.padding(3),
				}),
				text({
					Size = UDim2.new(1, 0, 0.22, 0),
					Position = UDim2.fromScale(0, 0.12),
					Text = item.name,
					TextColor3 = Theme.color.white,
					FontFace = Theme.font.title,
					TextXAlignment = Enum.TextXAlignment.Left,
					ZIndex = 23,
					Components.goldText(),
					Components.textStroke(3.5),
				}),
				text({
					Size = UDim2.new(1, 0, 0.3, 0),
					Position = UDim2.fromScale(0, 0.36),
					Text = item.description,
					TextScaled = false,
					TextSize = 20,
					TextWrapped = true,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Top,
					TextColor3 = Theme.darken(Theme.color.wood, 0.3),
					ZIndex = 23,
				}),
				create("Frame")({
					Size = UDim2.new(0.62, 0, 0, 40),
					Position = UDim2.fromScale(0, 0.68),
					BackgroundTransparency = 1,
					ZIndex = 23,
					create("UIListLayout")({ HorizontalAlignment = Enum.HorizontalAlignment.Left }),
					priceTag(item, 40),
				}),
				(if item.random
					then Components.button({
						text = "Odds",
						color = Theme.color.skyDeep,
						size = UDim2.new(0.34, 0, 0, 40),
						position = UDim2.fromScale(1, 0.68),
						anchor = Vector2.new(1, 0),
						textSize = 20,
						onClick = showOdds,
					})
					else nil) :: any,
				Components.button({
					text = function()
						if item.owned() then
							return "OWNED"
						elseif item.locked() then
							return "LOCKED"
						end
						return if item.currency == "robux" then "View Item" else "BUY"
					end,
					color = function()
						return if item.owned() or item.locked()
							then Color3.fromRGB(130, 130, 140)
							else Theme.color.green
					end,
					size = UDim2.new(1, 0, 0, 62),
					position = UDim2.fromScale(0.5, 1),
					anchor = Vector2.new(0.5, 1),
					textSize = 34,
					shine = true,
					onClick = function()
						if item.owned() or item.locked() then
							return
						end
						Sound.play("buy")
						item.buy()
					end,
				}),
			}),
			Components.button({
				name = "Close",
				text = "X",
				color = Theme.color.red,
				size = UDim2.fromOffset(50, 50),
				position = UDim2.new(1, 14, 0, -14),
				anchor = Vector2.new(1, 0),
				onClick = onClose,
			}),
		}),
	})
end

-- ---------------------------------------------------------------- the menu

function Shop.menu(onClose: () -> ()): Instance
	local tab = source("passes")
	local selected = source(nil :: Item?)
	local select = function(item: Item)
		selected(item)
	end

	local products = productItems()
	local gear = gearItems()
	local function itemsIn(id: string): { Item }
		local out = {}
		for _, item in products do
			if item.tab == id then
				table.insert(out, item)
			end
		end
		if id == "gear" then
			for _, item in gear do
				table.insert(out, item)
			end
		end
		return out
	end

	-- Ids in stock; cards are keyed by id so a restock swaps them.
	local stock = derive(function()
		local ids = { "HatcheryEgg" }
		local shop = state().shop
		for _, id in (shop and shop.items) or {} do
			if Cosmetics.byId[id] then
				table.insert(ids, id)
			end
		end
		return ids
	end)
	local function lookup(id: string): Item
		return if id == "HatcheryEgg" then hatchery else cosmeticItem(id) :: Item
	end

	local tabButtons = {}
	for i, t in TABS do
		table.insert(
			tabButtons,
			create("TextButton")({
				Name = t.id,
				LayoutOrder = i,
				Size = UDim2.new(1 / #TABS, -8, 1, 0),
				BackgroundTransparency = 1,
				AutoButtonColor = false,
				Text = "",
				Activated = function()
					Sound.play("click")
					tab(t.id)
				end,
				hoverScale(),
				create("Frame")({
					Size = UDim2.fromScale(1, 1),
					BackgroundColor3 = Color3.new(1, 1, 1),
					ZIndex = 2,
					Components.corner(UDim.new(0, 12)),
					Components.stroke(3),
					Components.gradient(function()
						return if tab() == t.id then t.color else Theme.color.wood
					end),
					Components.gloss(UDim.new(0, 12)),
					create("Frame")({
						Size = UDim2.fromScale(0.86, 0.86),
						SizeConstraint = Enum.SizeConstraint.RelativeYY,
						Position = UDim2.new(0, 4, 0.5, 0),
						AnchorPoint = Vector2.new(0, 0.5),
						BackgroundTransparency = 1,
						ZIndex = 4,
						Components.icon(t.icon, t.glyph, Theme.color.white),
					}),
					text({
						Size = UDim2.new(1, -46, 0.6, 0),
						Position = UDim2.new(1, -4, 0.5, 0),
						AnchorPoint = Vector2.new(1, 0.5),
						Text = t.label,
						TextColor3 = Theme.color.white,
						FontFace = Theme.font.title,
						ZIndex = 4,
						Components.textStroke(2.5),
					}),
				}),
				-- Underline marker on the active tab.
				create("Frame")({
					Size = UDim2.new(0.5, 0, 0, 6),
					Position = UDim2.new(0.5, 0, 1, 6),
					AnchorPoint = Vector2.new(0.5, 0),
					BackgroundColor3 = t.color,
					Visible = function()
						return tab() == t.id
					end,
					ZIndex = 3,
					Components.corner(UDim.new(1, 0)),
					Components.stroke(2),
				}),
			})
		)
	end

	local pages = {}
	for _, t in TABS do
		table.insert(
			pages,
			show(function()
				return tab() == t.id
			end, function()
				if t.id == "stock" then
					return create("Frame")({
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						text({
							Size = UDim2.new(1, 0, 0, 24),
							FontFace = Theme.font.heading,
							TextColor3 = Theme.darken(Theme.color.wood, 0.2),
							Text = function()
								local shop = state().shop
								local left = if shop
									then math.max(0, shop.restockAt - Workspace:GetServerTimeNow())
									else 0
								return `Paid in Gold Nuggets (earned, never sold) · new stock in {NumberFormat.clock(
									left
								)}`
							end,
						}),
						create("Frame")({
							Size = UDim2.new(1, 0, 1, -28),
							Position = UDim2.fromOffset(0, 28),
							BackgroundTransparency = 1,
							grid(values(stock, function(id, i)
								return itemCard(lookup(id), i(), select)
							end)),
						}),
					})
				end
				local cards = {}
				for i, item in itemsIn(t.id) do
					table.insert(cards, itemCard(item, i, select))
				end
				if t.id == "gear" then
					return create("Frame")({
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						text({
							Size = UDim2.new(1, 0, 0, 24),
							FontFace = Theme.font.heading,
							TextColor3 = Theme.darken(Theme.color.wood, 0.2),
							Text = "Bought with cash · yours forever · new gear unlocks every Frontier",
						}),
						create("Frame")({
							Size = UDim2.new(1, 0, 1, -28),
							Position = UDim2.fromOffset(0, 28),
							BackgroundTransparency = 1,
							grid(cards :: any),
						}),
					})
				end
				return grid(cards :: any)
			end)
		)
	end

	return create("Frame")({
		Name = "Shop",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Components.panel({
			title = "TRADING POST",
			mascot = "SheriffShrimpo",
			accent = Theme.color.orange,
			size = UDim2.fromScale(0.74, 0.8),
			onClose = onClose,
			children = {
				create("Frame")({
					Name = "Tabs",
					Size = UDim2.new(1, 0, 0, 46),
					BackgroundTransparency = 1,
					create("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						Padding = UDim.new(0, 8),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
					tabButtons :: any,
				}),
				create("Frame")({
					Name = "Pages",
					Size = UDim2.new(1, 0, 1, -60),
					Position = UDim2.fromOffset(0, 60),
					BackgroundTransparency = 1,
					pages :: any,
				}),
			},
		}),
		(show :: any)(function()
			return selected() ~= nil
		end, function()
			return preview(selected() :: Item, function()
				selected(nil)
			end)
		end),
	})
end

return Shop
