--!strict
-- The whole UI: HUD, menus, odds panel and overlays. Designed at 1280x720 and scaled with UIScale.
-- HUD starts minimal; buttons pop in as the tutorial unlocks systems.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Vide = require("@game/ReplicatedStorage/Packages/Vide")
local LuckConfig = require("@game/ReplicatedStorage/Shared/Config/Luck")
local Mutations = require("@game/ReplicatedStorage/Shared/Config/Mutations")
local Rarities = require("@game/ReplicatedStorage/Shared/Config/Rarities")
local Species = require("@game/ReplicatedStorage/Shared/Config/Species")
local HeistConfig = require("@game/ReplicatedStorage/Shared/Config/Heist")
local WheelConfig = require("@game/ReplicatedStorage/Shared/Config/Wheel")
local Palette = require("@game/ReplicatedStorage/Shared/Config/Palette")
local Economy = require("@game/ReplicatedStorage/Shared/Sim/Economy")
local Luck = require("@game/ReplicatedStorage/Shared/Sim/Luck")
local TrainClock = require("@game/ReplicatedStorage/Shared/Sim/TrainClock")
local Almanac = require("@game/ReplicatedStorage/Shared/Sim/Almanac")
local NumberFormat = require("@game/ReplicatedStorage/Shared/Sim/NumberFormat")
local Net = require("@game/ReplicatedStorage/Shared/Net/Net")
local Context = require("../Controllers/Context")
local Sound = require("../Controllers/Sound")
local Store = require("../Store")
local Components = require("./Components")
local Shop = require("./Shop")
local TradeUI = require("./Trade")
local Hotbar = require("./Hotbar")
local SprintButton = require("./SprintButton")
local EventBanner = require("./EventBanner")
local Quests = require("./Quests")
local Wardrobe = require("./Wardrobe")
local Theme = require("./Theme")

local create = Vide.create :: any
local show = Vide.show
local indexes = Vide.indexes
local values = Vide.values :: any
local derive = Vide.derive
local source = Vide.source
local spring = Vide.spring

local localPlayer = Players.LocalPlayer

local App = {}

local function state(): any
	return Store.state() or {}
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

local function open(menu: string)
	Sound.play("click")
	Store.menu(if Store.menu() == menu then "" else menu)
end

-- ---------------------------------------------------------------- HUD pieces

local function cashPills(): Instance
	return create("Frame")({
		Name = "Wallet",
		Size = UDim2.fromOffset(460, 56),
		Position = UDim2.new(0.5, 0, 0, 8),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 12),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Components.pill({
			icon = "$",
			image = "coin",
			iconColor = Theme.color.cash,
			size = UDim2.fromOffset(250, 56),
			layoutOrder = 1,
			text = function()
				return NumberFormat.cash(state().cash or 0)
			end,
			sub = function()
				return "+" .. NumberFormat.perSecond(Store.income())
			end,
		}),
		Components.pill({
			icon = "◆",
			image = "nugget",
			iconColor = Theme.color.nugget,
			size = UDim2.fromOffset(150, 56),
			layoutOrder = 2,
			text = function()
				return NumberFormat.short(state().nuggets or 0)
			end,
		}),
	})
end

-- Goal pill: progress toward the next Frontier.
local function goalPill(): Instance
	local progress = derive(function()
		local s = state()
		local n = (s.frontier or 0) + 1
		local cost = Economy.frontierCost(n)
		return math.clamp((s.cash or 0) / cost, 0, 1)
	end)
	local smooth = spring(progress, 0.6, 0.9)
	return create("TextButton")({
		Name = "Goal",
		Size = UDim2.fromOffset(380, 34),
		Position = UDim2.new(0.5, 0, 0, 70),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Theme.color.woodDark,
		Text = "",
		AutoButtonColor = false,
		Activated = function()
			open("frontier")
		end,
		Components.corner(UDim.new(1, 0)),
		Components.stroke(3),
		create("Frame")({
			Name = "Fill",
			Size = function()
				return UDim2.fromScale(smooth(), 1)
			end,
			BackgroundColor3 = Theme.color.gold,
			Components.corner(UDim.new(1, 0)),
			Components.gradient(Theme.color.gold),
		}),
		text({
			Size = UDim2.new(1, -16, 1, -6),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			TextColor3 = Theme.color.white,
			FontFace = Theme.font.heading,
			ZIndex = 3,
			Text = function()
				local s = state()
				local n = (s.frontier or 0) + 1
				local tier = Economy.frontierTargetTier(n)
				return `FRONTIER {n}: {NumberFormat.cash(Economy.frontierCost(n))} + a {Rarities.forTier(tier).name} critter`
			end,
			Components.textStroke(2),
		}),
	})
end

local function menuButton(
	order: number,
	glyph: string,
	label: string,
	menu: string,
	visible: () -> boolean,
	badge: (() -> number)?,
	color: Color3?,
	image: string?
): Instance
	return Components.tile({
		glyph = glyph,
		image = image,
		label = label,
		color = color or Theme.color.blue,
		layoutOrder = order,
		visible = visible,
		badge = badge,
		onClick = function()
			open(menu)
		end,
	})
end

local function readyQuests(): number
	local count = 0
	for _, q in state().quests or {} do
		if q.progress >= q.goal and not q.claimed then
			count += 1
		end
	end
	return count
end

local function readyEggs(): number
	local count = 0
	local now = Workspace:GetServerTimeNow()
	for _, egg in state().eggs or {} do
		if egg.hatchAt <= now then
			count += 1
		end
	end
	return count
end

-- Speed Boots level (server mirrors it to a player attribute).
local bootsAttr = source((localPlayer:GetAttribute("Boots") :: number?) or 0)
localPlayer:GetAttributeChangedSignal("Boots"):Connect(function()
	bootsAttr((localPlayer:GetAttribute("Boots") :: number?) or 0)
end)
local function bootsLevel(): number
	return bootsAttr()
end

local spinsAttr = source((localPlayer:GetAttribute("Spins") :: number?) or 0)
localPlayer:GetAttributeChangedSignal("Spins"):Connect(function()
	spinsAttr((localPlayer:GetAttribute("Spins") :: number?) or 0)
end)

local function sideMenu(): Instance
	local step = function()
		return state().tutorial or 0
	end
	return create("Frame")({
		Name = "SideMenu",
		Size = UDim2.fromOffset(90, 500),
		Position = UDim2.new(0, 12, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		create("UIListLayout")({
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
		menuButton(1, "★", "SHOP", "shop", function()
			return step() >= 1
		end, nil, Theme.color.yellow, "shop"),
		menuButton(2, "◉", "EGGS", "eggs", function()
			return step() >= 2 or #(state().eggs or {}) > 0
		end, readyEggs, Theme.color.pink, "egg"),
		menuButton(3, "!", "QUESTS", "quests", function()
			return step() >= 2
		end, readyQuests, Theme.color.orange, "scroll"),
		menuButton(4, "▤", "ALMANAC", "almanac", function()
			return step() >= 3
		end, nil, Theme.color.purple, "book"),
		menuButton(-1, "✪", "SPIN", "wheel", function()
			return true
		end, function()
			return spinsAttr()
		end, Theme.color.pink, "wheel"),
		menuButton(0, "»", "BOOTS", "boots", function()
			return true
		end, function()
			local level = bootsLevel()
			local cost = HeistConfig.bootsCost(level)
			return if cost and (state().cash or 0) >= cost then 1 else 0
		end, Theme.color.blue, "boots"),
		menuButton(5, "⚙", "MORE", "settings", function()
			return true
		end, nil, Theme.color.teal, "settings"),
	})
end

-- Next playtime gift timer (top right).
local function giftButton(): Instance
	local nextGift = derive(function()
		for _, g in state().gifts or {} do
			if not g.claimed then
				return g
			end
		end
		return nil
	end)
	local clock = source(0)
	task.spawn(function()
		while true do
			clock(os.clock())
			task.wait(1)
		end
	end)
	return create("TextButton")({
		Name = "Gift",
		Size = UDim2.fromOffset(96, 96),
		Position = UDim2.new(1, -16, 0, 70),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		AutoButtonColor = false,
		Text = "",
		Visible = function()
			return nextGift() ~= nil
		end,
		Activated = function()
			local g = nextGift()
			if g and g.ready then
				Net.request("Claim", "gift", g.index)
			else
				Store.toast("Keep playing to unlock the next gift!")
			end
		end,
		Components.corner(UDim.new(0, 20)),
		Components.stroke(3),
		Components.gradient(Theme.color.red),
		text({
			Size = UDim2.fromScale(0.7, 0.5),
			Position = UDim2.fromScale(0.5, 0.36),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Text = "🎁",
		}),
		text({
			Size = UDim2.fromScale(0.9, 0.3),
			Position = UDim2.fromScale(0.5, 0.8),
			AnchorPoint = Vector2.new(0.5, 0.5),
			TextColor3 = Theme.color.white,
			FontFace = Theme.font.number,
			Text = function()
				clock()
				local g = nextGift()
				if not g then
					return ""
				end
				return if g.ready then "CLAIM!" else NumberFormat.clock(g.secondsLeft)
			end,
			Components.textStroke(2),
		}),
	})
end

local function statusBadges(): Instance
	-- Boost end times are server unix time; compare against server time, not the device clock.
	local clock = source(Workspace:GetServerTimeNow())
	task.spawn(function()
		while true do
			clock(Workspace:GetServerTimeNow())
			task.wait(1)
		end
	end)
	local function badge(order: number, label: () -> string, color: Color3, visible: () -> boolean): Instance
		return create("TextLabel")({
			Size = UDim2.fromOffset(200, 34),
			LayoutOrder = order,
			BackgroundColor3 = color,
			Text = label,
			TextColor3 = Theme.color.white,
			FontFace = Theme.font.heading,
			TextScaled = true,
			Visible = visible,
			Components.corner(UDim.new(1, 0)),
			Components.stroke(3),
			Components.textStroke(2),
			Components.padding(5),
		})
	end
	return create("Frame")({
		Name = "Badges",
		Size = UDim2.fromOffset(200, 250),
		Position = UDim2.new(1, -124, 0, 70),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundTransparency = 1,
		create("UIListLayout")({
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
		}),
		badge(
			1,
			function()
				return `LUCK x{string.format("%.2f", Luck.active(Store.activeMinutes()))}`
			end,
			Theme.color.green,
			function()
				return true
			end
		),
		badge(
			2,
			function()
				local w = Store.weather()
				local m = Mutations.byId[w]
				return if m then `{string.upper(m.name)} WEATHER` else ""
			end,
			Theme.color.skyDeep,
			function()
				return Store.weather() ~= ""
			end
		),
		badge(
			3,
			function()
				return `SERVER LUCK x{Store.serverLuck()}`
			end,
			Theme.color.brass,
			function()
				return Store.serverLuck() > 1
			end
		),
		badge(
			5,
			function()
				local left = ((state().boosts or {}).DoubleCash or 0) - clock()
				return `2x CASH {NumberFormat.clock(math.max(0, left))}`
			end,
			Theme.color.green,
			function()
				return ((state().boosts or {}).DoubleCash or 0) > clock()
			end
		),
		badge(
			6,
			function()
				local left = ((state().boosts or {}).Luck or 0) - clock()
				return `LUCK POTION {NumberFormat.clock(math.max(0, left))}`
			end,
			Theme.color.purple,
			function()
				return ((state().boosts or {}).Luck or 0) > clock()
			end
		),
		badge(
			4,
			function()
				return "GOLDEN EXPRESS NEXT!"
			end,
			Theme.color.gold,
			function()
				return Store.goldenCycle() == Store.trainCycle() + 1
			end
		),
	})
end

-- The big contextual button (bottom-right, above the mobile jump button).
local function actionButton(): Instance
	local visible = derive(function()
		return Store.action().kind ~= ""
	end)
	local scale = spring(function()
		return if visible() then 1 else 0
	end, 0.3, 0.55)
	local colorFor = function(): Color3
		local kind = Store.action().kind
		if kind == "steal" or kind == "lasso" then
			return Theme.color.red
		elseif kind == "crack" or kind == "grab" then
			return Theme.color.brass
		elseif kind == "protected" then
			return Theme.color.wood
		end
		return Theme.color.green
	end
	return create("Frame")({
		Name = "Action",
		Size = UDim2.fromOffset(170, 170),
		Position = UDim2.new(1, -150, 1, -190),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		create("UIScale")({
			Scale = function()
				return math.max(scale(), 0.001)
			end,
		}),
		Components.button({
			name = "Main",
			text = function()
				return Store.action().label
			end,
			color = colorFor,
			size = UDim2.fromScale(1, 0.72),
			position = UDim2.fromScale(0.5, 0.36),
			anchor = Vector2.new(0.5, 0.5),
			textSize = 40,
			shine = true,
			pulse = true,
			onClick = function()
				Context.execute()
			end,
		}),
		text({
			Size = UDim2.fromScale(1.4, 0.2),
			Position = UDim2.fromScale(0.5, 0.86),
			AnchorPoint = Vector2.new(0.5, 0.5),
			TextColor3 = Theme.color.white,
			FontFace = Theme.font.heading,
			Text = function()
				return Store.action().sub
			end,
			Components.textStroke(2),
		}),
		-- Hold progress (steal / crack / grab)
		show(function()
			return Store.grab() ~= nil
		end, function()
			local fill = source(0)
			task.spawn(function()
				while Store.grab() do
					local g = Store.grab()
					if g then
						fill(math.clamp((os.clock() - g.started) / g.duration, 0, 1))
					end
					task.wait()
				end
			end)
			return create("Frame")({
				Size = UDim2.new(1, 0, 0, 12),
				Position = UDim2.new(0, 0, 0, -18),
				BackgroundColor3 = Theme.color.ink,
				Components.corner(UDim.new(1, 0)),
				create("Frame")({
					Size = function()
						return UDim2.fromScale(fill(), 1)
					end,
					BackgroundColor3 = Theme.color.gold,
					Components.corner(UDim.new(1, 0)),
				}),
			})
		end),
	})
end

local function toasts(): Instance
	return create("Frame")({
		Name = "Toasts",
		Size = UDim2.fromOffset(560, 160),
		Position = UDim2.new(0.5, 0, 1, -120),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		create("UIListLayout")({
			Padding = UDim.new(0, 6),
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		-- Keyed by value so each toast keeps its own row as older ones expire.
		values(Store.toasts, function(toast, i)
			return text({
				LayoutOrder = i,
				Size = UDim2.fromOffset(540, 40),
				BackgroundTransparency = 0.05,
				BackgroundColor3 = Theme.color.paper,
				FontFace = Theme.font.heading,
				Text = function()
					return toast.text
				end,
				Components.corner(UDim.new(0, 12)),
				Components.stroke(3),
				Components.padding(6),
				Components.popIn(),
			})
		end),
	})
end

local function announcements(): Instance
	return create("Frame")({
		Name = "Announcements",
		Size = UDim2.fromOffset(760, 110),
		Position = UDim2.new(0.5, 0, 0, 112),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		create("UIListLayout")({
			Padding = UDim.new(0, 6),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		values(Store.announcements, function(item, i)
			local kind = item.kind
			local color = if Rarities.byId[kind]
				then Theme.rarityColor(kind)
				elseif kind == "golden" or kind == "luck" then Theme.color.gold
				elseif kind == "steal" then Theme.color.red
				elseif kind == "event" then Theme.color.orange
				else Theme.color.skyDeep
			local scale = source(1.6)
			local s = spring(scale, 0.35, 0.5)
			task.defer(function()
				scale(1)
			end)
			return text({
				LayoutOrder = i,
				Size = UDim2.fromOffset(740, 46),
				BackgroundTransparency = 0,
				BackgroundColor3 = color,
				TextColor3 = Theme.color.white,
				FontFace = Theme.font.title,
				Text = function()
					return item.text
				end,
				create("UIScale")({ Scale = s }),
				Components.corner(UDim.new(0, 14)),
				Components.stroke(4),
				Components.textStroke(2.5),
				Components.padding(7),
			})
		end),
	})
end

-- ---------------------------------------------------------------- Menus

local function card(props: {
	title: () -> string,
	sub: () -> string,
	color: Color3,
	button: string | () -> string,
	onClick: () -> (),
	order: number?,
	extra: any,
	glyph: string?,
}): Instance
	return create("Frame")({
		Size = UDim2.new(1, -10, 0, 90),
		BackgroundColor3 = Color3.new(1, 1, 1),
		LayoutOrder = props.order,
		Components.corner(UDim.new(0, 16)),
		Components.stroke(3),
		Components.gradient(Theme.lighten(props.color, 0.82)),
		Components.popIn((props.order or 0) * 0.03),
		-- Icon tile in the item's colour.
		create("Frame")({
			Size = UDim2.fromOffset(66, 66),
			Position = UDim2.new(0, 12, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundColor3 = Color3.new(1, 1, 1),
			Components.corner(UDim.new(0, 14)),
			Components.stroke(3),
			Components.gradient(props.color),
			Components.gloss(UDim.new(0, 14)),
			text({
				Size = UDim2.fromScale(0.7, 0.7),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Text = props.glyph or "★",
				TextColor3 = Theme.color.white,
				FontFace = Theme.font.title,
				ZIndex = 3,
				Components.textStroke(2.5),
			}),
		}),
		text({
			Size = UDim2.new(0.5, 0, 0.44, 0),
			Position = UDim2.new(0, 92, 0.1, 0),
			Text = props.title,
			FontFace = Theme.font.title,
			TextColor3 = Theme.color.white,
			TextXAlignment = Enum.TextXAlignment.Left,
			Components.textStroke(2.5),
		}),
		text({
			Size = UDim2.new(0.5, 0, 0.3, 0),
			Position = UDim2.new(0, 92, 0.58, 0),
			Text = props.sub,
			TextColor3 = Theme.darken(Theme.color.wood, 0.25),
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		Components.button({
			text = props.button,
			color = Theme.color.green,
			size = UDim2.new(0.25, 0, 0, 54),
			position = UDim2.new(1, -14, 0.5, -3),
			anchor = Vector2.new(1, 0.5),
			textSize = 26,
			onClick = props.onClick,
		}),
		props.extra,
	})
end

local function list(children: { any }): Instance
	return create("ScrollingFrame")({
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ScrollBarThickness = 8,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		create("UIListLayout")({ Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
		Components.padding(4),
		children,
	})
end

local function showOdds(kind: string)
	task.spawn(function()
		local result = Net.invoke("GetOdds", kind)
		if result then
			Store.odds({ kind = kind, data = result })
		end
	end)
end

local function shopMenu(): Instance
	return Shop.menu(function()
		Store.menu("")
	end)
end

local function eggsMenu(): Instance
	local clock = source(Workspace:GetServerTimeNow())
	local alive = true
	task.spawn(function()
		while alive do
			clock(Workspace:GetServerTimeNow())
			task.wait(1)
		end
	end)
	Vide.cleanup(function()
		alive = false
	end)
	return Components.panel({
		title = "EGGS",
		accent = Theme.color.sky,
		onClose = function()
			Store.menu("")
		end,
		children = {
			list({
				Components.button({
					text = "Egg odds",
					color = Theme.color.skyDeep,
					size = UDim2.fromOffset(160, 40),
					layoutOrder = 0,
					onClick = function()
						showOdds("egg")
					end,
				}),
				indexes(function()
					return state().eggs or {}
				end, function(egg, i)
					return card({
						order = i,
						title = function()
							return `{Rarities.forTier(egg().tier).name} Egg`
						end,
						sub = function()
							local left = egg().hatchAt - clock()
							return if left <= 0
								then "Ready to hatch!"
								else `Hatches in {NumberFormat.clock(left)}`
						end,
						color = Theme.rarityForTier(egg().tier),
						button = function()
							return if egg().hatchAt <= clock() then "HATCH!" else "..."
						end,
						onClick = function()
							if egg().hatchAt <= Workspace:GetServerTimeNow() then
								Net.request("Hatch", i)
							end
						end,
					})
				end),
			}),
		},
	})
end

local function questsMenu(): Instance
	return Quests.menu(function()
		Store.menu("")
	end)
end

local function almanacMenu(): Instance
	local cells = {}
	for _, species in Species.list do
		table.insert(
			cells,
			create("Frame")({
				Size = UDim2.fromOffset(110, 110),
				LayoutOrder = species.tier,
				BackgroundColor3 = function()
					local seen = (state().almanac or {})[species.id]
					return if seen then Theme.rarityForTier(species.tier) else Theme.color.woodDark
				end,
				Components.corner(UDim.new(0, 12)),
				Components.stroke(3),
				text({
					Size = UDim2.new(1, -8, 0.5, 0),
					Position = UDim2.fromOffset(4, 6),
					TextColor3 = Theme.color.white,
					FontFace = Theme.font.heading,
					Text = function()
						return if (state().almanac or {})[species.id] then species.name else "???"
					end,
					Components.textStroke(2),
				}),
				text({
					Size = UDim2.new(1, -8, 0.3, 0),
					Position = UDim2.new(0, 4, 0.62, 0),
					TextColor3 = Theme.color.white,
					FontFace = Theme.font.number,
					Text = function()
						local mask = (state().almanac or {})[species.id] or 0
						local count = 0
						for bit = 1, #Mutations.list + 1 do
							if bit32.btest(mask, bit32.lshift(1, bit - 1)) then
								count += 1
							end
						end
						return `{Theme.glyphFor(Rarities.forTier(species.tier).id)} {count}/{#Mutations.list + 1}`
					end,
					Components.textStroke(1.5),
				}),
			})
		)
	end
	return Components.panel({
		title = function()
			local found = 0
			for _ in state().almanac or {} do
				found += 1
			end
			return `ALMANAC {found}/{#Species.list}`
		end,
		accent = Theme.color.skyDeep,
		onClose = function()
			Store.menu("")
		end,
		children = {
			-- Rarity sets: find every species of a rarity for +5% income forever.
			create("Frame")({
				Size = UDim2.new(1, 0, 0, 56),
				BackgroundTransparency = 1,
				create("UIListLayout")({
					FillDirection = Enum.FillDirection.Horizontal,
					Padding = UDim.new(0, 6),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				indexes(function()
					return Almanac.sets(state().almanac or {})
				end, function(set, i)
					return create("Frame")({
						Size = UDim2.new(1 / #Rarities.list, -6, 1, 0),
						LayoutOrder = i,
						BackgroundColor3 = function()
							return if set().done
								then Theme.rarityColor(set().rarity)
								else Theme.color.woodDark
						end,
						Components.corner(UDim.new(0, 10)),
						Components.stroke(2.5),
						text({
							Size = UDim2.new(1, -6, 0.5, 0),
							Position = UDim2.fromOffset(3, 3),
							TextColor3 = Theme.color.white,
							FontFace = Theme.font.title,
							Text = function()
								return string.upper(Rarities.byId[set().rarity].name)
							end,
							Components.textStroke(1.5),
						}),
						text({
							Size = UDim2.new(1, -6, 0.42, 0),
							Position = UDim2.new(0, 3, 0.52, 0),
							TextColor3 = Theme.color.white,
							FontFace = Theme.font.number,
							Text = function()
								return if set().done then "✔ +5% $" else `{set().have}/{set().total}`
							end,
							Components.textStroke(1.5),
						}),
					})
				end),
			}),
			create("ScrollingFrame")({
				Size = UDim2.new(1, 0, 1, -64),
				Position = UDim2.fromOffset(0, 64),
				BackgroundTransparency = 1,
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				CanvasSize = UDim2.new(),
				ScrollBarThickness = 8,
				create("UIGridLayout")({
					CellSize = UDim2.fromOffset(110, 110),
					CellPadding = UDim2.fromOffset(10, 10),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				Components.padding(6),
				cells,
			}),
		},
	})
end

local function frontierMenu(): Instance
	return Components.panel({
		title = function()
			return `FRONTIER {(state().frontier or 0) + 1}`
		end,
		accent = Theme.color.gold,
		size = UDim2.fromScale(0.5, 0.6),
		onClose = function()
			Store.menu("")
		end,
		children = {
			list({
				text({
					Size = UDim2.new(1, 0, 0, 110),
					LayoutOrder = 1,
					FontFace = Theme.font.heading,
					TextWrapped = true,
					Text = function()
						local s = state()
						local n = (s.frontier or 0) + 1
						local tier = Economy.frontierTargetTier(n)
						return `Needs {NumberFormat.cash(Economy.frontierCost(n))} and a critter of tier {tier}+ ({Species.byTier[tier].name} or better).\nResets cash and critters (Branded critters stay).\nRewards: income x{n + 1}, +1 pen, longer lock, carry rarer critters.`
					end,
				}),
				Components.button({
					text = "RIDE INTO THE SUNSET",
					color = Theme.color.gold,
					size = UDim2.new(1, -8, 0, 64),
					layoutOrder = 2,
					shine = true,
					onClick = function()
						Net.request("Frontier")
						Store.menu("")
					end,
				}),
			}),
		},
	})
end

local function settingsMenu(): Instance
	local function toggle(order: number, key: string, label: string): Instance
		return card({
			order = order,
			title = function()
				return label
			end,
			sub = function()
				local s = state().settings or {}
				return if s[key] then "On" else "Off"
			end,
			color = Theme.color.sky,
			button = "Toggle",
			onClick = function()
				local s = state().settings or {}
				Net.request("Setting", key, not s[key])
			end,
		})
	end
	local function volume(order: number, key: string, label: string): Instance
		return card({
			order = order,
			title = function()
				return label
			end,
			sub = function()
				local s = state().settings or {}
				return `{math.floor((s[key] or 0) * 100 + 0.5)}%`
			end,
			color = Theme.color.sky,
			button = "Change",
			onClick = function()
				local s = state().settings or {}
				local v = (s[key] or 0) + 0.25
				if v > 1.01 then
					v = 0
				end
				Net.request("Setting", key, v)
			end,
		})
	end
	return Components.panel({
		title = "SETTINGS",
		accent = Theme.color.wood,
		onClose = function()
			Store.menu("")
		end,
		children = {
			list({
				card({
					order = 0,
					title = function()
						return "Trade with players"
					end,
					sub = function()
						return "Safe escrow trades: critters and Gold Nuggets"
					end,
					color = Theme.color.teal,
					button = "TRADE",
					glyph = "⇄",
					onClick = function()
						Sound.play("click")
						Store.menu("trade")
					end,
				}),
				card({
					order = 0,
					title = function()
						return "Wardrobe"
					end,
					sub = function()
						return "Titles, hats, lasso trails, posters, ranch themes"
					end,
					color = Theme.color.purple,
					button = "OPEN",
					glyph = "♛",
					onClick = function()
						Sound.play("click")
						Store.menu("wardrobe")
					end,
				}),
				card({
					order = 1,
					title = function()
						return "Graphics quality"
					end,
					sub = function()
						local q = (state().settings or {}).Quality or "auto"
						return if q == "auto" then "Auto (adjusts to your device)" else string.upper(q)
					end,
					color = Theme.color.sky,
					button = "Change",
					onClick = function()
						local order = { "auto", "low", "medium", "high" }
						local q = (state().settings or {}).Quality or "auto"
						local i = table.find(order, q) or 1
						Net.request("Setting", "Quality", order[i % #order + 1])
					end,
				}),
				volume(1, "Music", "Music volume"),
				volume(2, "Sfx", "Sound effects"),
				volume(3, "Voice", "Critter voices"),
				toggle(4, "ReducedFx", "Reduced effects (no flashes or shakes)"),
				toggle(5, "QuickReveal", "Quick reveals"),
				card({
					order = 6,
					title = function()
						return "Report a bug"
					end,
					sub = function()
						return "Sends your game state to the developers"
					end,
					color = Theme.color.red,
					button = "Report",
					onClick = function()
						Net.request("BugReport", "other", "")
					end,
				}),
				card({
					order = 7,
					title = function()
						return "Sheriff Powers (Sheriff's Star)"
					end,
					sub = function()
						return "Golden Express · Weather · Stampede"
					end,
					color = Theme.color.gold,
					button = "Golden Express",
					onClick = function()
						Net.request("SheriffPower", "GoldenExpress", "")
					end,
				}),
			}),
		},
	})
end

local function oddsPanel(): Instance
	return Components.panel({
		title = "ODDS",
		accent = Theme.color.skyDeep,
		size = UDim2.fromScale(0.5, 0.7),
		onClose = function()
			Store.odds(nil)
		end,
		children = {
			list({
				indexes(function()
					local o = Store.odds()
					return if o then o.data.rows else {}
				end, function(row, i)
					return text({
						Size = UDim2.new(1, -8, 0, 30),
						LayoutOrder = i,
						FontFace = Theme.font.heading,
						TextXAlignment = Enum.TextXAlignment.Left,
						Text = function()
							return `{row().label}: {string.format("%.4f", row().percent)}%`
						end,
					})
				end),
				text({
					Size = UDim2.new(1, -8, 0, 26),
					LayoutOrder = 999,
					TextXAlignment = Enum.TextXAlignment.Left,
					Text = function()
						local o = Store.odds()
						return if o then o.data.note or "" else ""
					end,
				}),
			}),
		},
	})
end

-- Welcome back: offline earnings + streak reward.
local function welcome(): Instance
	return Components.panel({
		title = "WELCOME BACK!",
		accent = Theme.color.gold,
		size = UDim2.fromScale(0.5, 0.55),
		onClose = function()
			local p = state().pending or {}
			if p.offline and p.offline > 0 then
				Net.request("Claim", "offline", 0)
			end
			if p.streakSlot then
				Net.request("Claim", "streak", 0)
			end
		end,
		children = {
			list({
				text({
					Size = UDim2.new(1, 0, 0, 60),
					LayoutOrder = 1,
					FontFace = Theme.font.title,
					Text = function()
						local p = state().pending or {}
						return if p.offline and p.offline > 0
							then `Your ranch earned {NumberFormat.cash(p.offline)} while you were away!`
							else ""
					end,
				}),
				text({
					Size = UDim2.new(1, 0, 0, 40),
					LayoutOrder = 2,
					FontFace = Theme.font.heading,
					Text = function()
						local p = state().pending or {}
						local s = state().streak
						return if p.streakSlot
							then `Day {s and s.count or 1} login streak reward ready!`
							else ""
					end,
				}),
				Components.button({
					text = "COLLECT",
					color = Theme.color.green,
					size = UDim2.new(1, -8, 0, 64),
					layoutOrder = 3,
					shine = true,
					onClick = function()
						local p = state().pending or {}
						if p.offline and p.offline > 0 then
							Net.request("Claim", "offline", 0)
						end
						if p.streakSlot then
							Net.request("Claim", "streak", 0)
						end
					end,
				}),
			}),
		},
	})
end

-- First-session hint ("Buy a critter!", "Collect at your ranch"...).
-- The next thing a new player should try: the tutorial, then the first heist, boots and gear.
-- Ticks twice a second so hints that depend on the train re-evaluate.
local hintClock = source(0)
task.spawn(function()
	while true do
		hintClock(os.clock())
		task.wait(0.5)
	end
end)

local function nextHint(): string
	hintClock()
	local s = state()
	local step = s.tutorial or 0
	local epoch = Workspace:GetAttribute("TrainEpoch") :: number?
	local train = if epoch then TrainClock.at(epoch, Workspace:GetServerTimeNow()) else nil
	local trainHere = train ~= nil and train.doorsOpen
	if step == 0 then
		return if trainHere
			then "Follow the red arrow and tap BUY on your RESERVED cage!"
			else "The Critter Express is coming! Wait on the platform."
	elseif step == 1 and not s.collected then
		return "Your critter earns cash! Step on the gold COLLECT plate at your ranch."
	elseif step == 1 then
		return if trainHere
			then "A GOLDEN TICKET cage is waiting for you! Grab it!"
			else "Next train brings you a GOLDEN TICKET critter. Head to the platform!"
	elseif step < 3 then
		return "Watch out! Bandit Bart is coming for your critters. LASSO him!"
	end
	if localPlayer:GetAttribute("HeistCarry") == true then
		return ""
	end
	local heists = s.heists or 0
	if heists == 0 then
		return "HEIST TIME! Follow the teal arc to Cactus Flats and GRAB a crate!"
	end
	local bootsCost = HeistConfig.bootsCost(s.boots or 0)
	if heists < 4 and (s.boots or 0) == 0 and bootsCost and (s.cash or 0) >= bootsCost then
		return "Buy SPEED BOOTS to outrun the guards!"
	end
	local anyGear = false
	for key in s.owned or {} do
		if string.sub(key, 1, 5) == "gear:" then
			anyGear = true
		end
	end
	if not anyGear and (s.cash or 0) >= 2500 and heists < 10 then
		return "New: buy a SMOKE BOMB in the Shop's GEAR tab!"
	end
	return ""
end

local function hint(): Instance
	return text({
		Name = "Hint",
		Size = UDim2.fromOffset(520, 44),
		Position = UDim2.new(0.5, 0, 0, 112),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 0,
		BackgroundColor3 = Theme.color.red,
		TextColor3 = Theme.color.white,
		FontFace = Theme.font.title,
		Visible = function()
			return nextHint() ~= "" and #Store.announcements() == 0
		end,
		Text = nextHint,
		Components.corner(UDim.new(0, 14)),
		Components.stroke(4),
		Components.textStroke(2.5),
		Components.padding(7),
	})
end

-- Speed Boots: the heist progression. Shows your speed, the next upgrade, and which zones'
-- guards you can outrun while carrying a crate.
local function bootsMenu(): Instance
	local rows = {}
	for i, zone in HeistConfig.zones do
		table.insert(
			rows,
			create("Frame")({
				Size = UDim2.new(1, -10, 0, 54),
				LayoutOrder = 10 + i,
				BackgroundColor3 = Color3.new(1, 1, 1),
				Components.corner(UDim.new(0, 12)),
				Components.stroke(3),
				Components.gradient(function()
					local fast = HeistConfig.walkSpeed(bootsLevel(), false, true) > zone.chaseSpeed
					return if fast
						then Theme.lighten(Theme.color.green, 0.55)
						else Theme.lighten(Theme.color.red, 0.6)
				end),
				text({
					Size = UDim2.new(0.55, 0, 0.8, 0),
					Position = UDim2.new(0, 14, 0.1, 0),
					Text = string.upper(zone.name),
					FontFace = Theme.font.title,
					TextColor3 = Theme.color.white,
					TextXAlignment = Enum.TextXAlignment.Left,
					Components.textStroke(2.5),
				}),
				text({
					Size = UDim2.new(0.42, 0, 0.7, 0),
					Position = UDim2.new(1, -12, 0.15, 0),
					AnchorPoint = Vector2.new(1, 0),
					FontFace = Theme.font.heading,
					TextXAlignment = Enum.TextXAlignment.Right,
					Text = function()
						local fast = HeistConfig.walkSpeed(bootsLevel(), false, true) > zone.chaseSpeed
						return if fast then "YOU CAN OUTRUN THEM" else `NEED BOOTS {zone.suggestedBoots}`
					end,
				}),
			})
		)
	end
	return Components.panel({
		title = "SPEED BOOTS",
		accent = Theme.color.blue,
		mascot = "Thunderhoof",
		onClose = function()
			Store.menu("")
		end,
		children = {
			list({
				create("Frame")({
					Size = UDim2.new(1, -10, 0, 120),
					LayoutOrder = 1,
					BackgroundTransparency = 1,
					text({
						Size = UDim2.new(0.6, 0, 0.42, 0),
						Position = UDim2.new(0, 8, 0, 4),
						FontFace = Theme.font.title,
						TextColor3 = Theme.color.white,
						TextXAlignment = Enum.TextXAlignment.Left,
						Text = function()
							return `LEVEL {bootsLevel()} / {HeistConfig.MAX_BOOTS}`
						end,
						Components.textStroke(3),
					}),
					text({
						Size = UDim2.new(0.6, 0, 0.3, 0),
						Position = UDim2.new(0, 8, 0.5, 0),
						FontFace = Theme.font.heading,
						TextXAlignment = Enum.TextXAlignment.Left,
						Text = function()
							local level = bootsLevel()
							local now = HeistConfig.walkSpeed(level, false, false)
							local nextLevel = math.min(level + 1, HeistConfig.MAX_BOOTS)
							return `Speed {now} → {HeistConfig.walkSpeed(nextLevel, false, false)}`
						end,
					}),
					Components.button({
						text = function()
							local cost = HeistConfig.bootsCost(bootsLevel())
							return if cost then `UPGRADE {NumberFormat.cash(cost)}` else "MAXED!"
						end,
						color = function()
							local cost = HeistConfig.bootsCost(bootsLevel())
							return if cost and (state().cash or 0) >= cost
								then Theme.color.green
								else Theme.color.wood
						end,
						size = UDim2.new(0.38, 0, 0, 70),
						position = UDim2.new(1, -8, 0.5, 0),
						anchor = Vector2.new(1, 0.5),
						textSize = 30,
						shine = true,
						onClick = function()
							Net.request("BuyBoots")
						end,
					}),
				}),
				rows,
			}),
		},
	})
end

-- ---------------------------------------------------------------- Prize Wheel
-- A ring of prize bubbles; a light chases around, slows down and lands on the server's result.
local wheelLit = source(0)
local wheelBusy = source(false)
local wheelPrize = source("")

local function playWheel(index: number, prizeText: string)
	wheelBusy(true)
	wheelPrize("")
	local count = #WheelConfig.segments
	local current = math.max(wheelLit(), 1)
	local steps = count * 3 + ((index - current) % count)
	task.spawn(function()
		for step = 1, steps do
			current = current % count + 1
			wheelLit(current)
			Sound.play("click", 0.15)
			-- Ease out: quick at first, then slower and slower ticks.
			local p = step / steps
			task.wait(0.035 + 0.38 * p ^ 3)
		end
		local segment = WheelConfig.segments[index]
		local big = segment.kind == "critter"
		Sound.play(if big then "revealLegendary" else "revealRare")
		wheelPrize(`YOU WON {prizeText}`)
		for _ = 1, 3 do
			wheelLit(0)
			task.wait(0.12)
			wheelLit(index)
			task.wait(0.18)
		end
		wheelBusy(false)
	end)
end

Net.listen("WheelResult", function(index: number, prizeText: string)
	Store.menu("wheel")
	playWheel(index, prizeText)
end)

local WHEEL_ICONS: { [string]: string } = {
	cash5 = "coin",
	nug15 = "nugget",
	cash20 = "moneybag",
	spin = "wheel",
	nug50 = "nugget",
	cash60 = "moneybag",
	critter = "crate",
	jackpot = "crown",
}

local function wheelMenu(): Instance
	local bubbles = {}
	local count = #WheelConfig.segments
	-- Live odds for the player's next spin under the daily jackpot rules.
	local jackpotToday = source(localPlayer:GetAttribute("JackpotToday") == true)
	local spinsToday = source((localPlayer:GetAttribute("SpinsToday") :: number?) or 0)
	local jackpotConn = localPlayer:GetAttributeChangedSignal("JackpotToday"):Connect(function()
		jackpotToday(localPlayer:GetAttribute("JackpotToday") == true)
	end)
	local spinsTodayConn = localPlayer:GetAttributeChangedSignal("SpinsToday"):Connect(function()
		spinsToday((localPlayer:GetAttribute("SpinsToday") :: number?) or 0)
	end)
	Vide.cleanup(function()
		jackpotConn:Disconnect()
		spinsTodayConn:Disconnect()
	end)
	local odds = derive(function()
		return WheelConfig.oddsFor(jackpotToday(), spinsToday())
	end)
	for i, segment in WheelConfig.segments do
		local angle = (i - 1) / count * math.pi * 2 - math.pi / 2
		local color = Palette.color(segment.color)
		table.insert(
			bubbles,
			create("Frame")({
				Name = "Bubble" .. i,
				Size = UDim2.fromScale(0.21, 0.21),
				Position = UDim2.fromScale(0.5 + math.cos(angle) * 0.37, 0.5 + math.sin(angle) * 0.37),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.new(1, 1, 1),
				ZIndex = 3,
				Components.corner(UDim.new(1, 0)),
				create("UIStroke")({
					Thickness = function()
						return if wheelLit() == i then 7 else 3
					end,
					Color = function()
						return if wheelLit() == i then Color3.new(1, 1, 1) else Theme.color.ink
					end,
				}),
				Components.gradient(function()
					return if wheelLit() == i then Theme.lighten(color, 0.35) else color
				end),
				Components.gloss(UDim.new(1, 0)),
				create("UIScale")({
					Scale = spring(function()
						return if wheelLit() == i then 1.28 else 1
					end, 0.12, 0.5),
				}),
				create("Frame")({
					Size = UDim2.fromScale(0.62, 0.55),
					Position = UDim2.fromScale(0.5, 0.36),
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					ZIndex = 4,
					Components.icon(WHEEL_ICONS[segment.id] or "", segment.glyph),
				}),
				text({
					Size = UDim2.fromScale(1.3, 0.26),
					Position = UDim2.fromScale(0.5, 0.78),
					AnchorPoint = Vector2.new(0.5, 0.5),
					Text = segment.label,
					FontFace = Theme.font.title,
					TextColor3 = Theme.color.white,
					ZIndex = 4,
					Components.textStroke(2),
				}),
				text({
					Size = UDim2.fromScale(1, 0.2),
					Position = UDim2.fromScale(0.5, 1.12),
					AnchorPoint = Vector2.new(0.5, 0.5),
					Text = function()
						return string.format("%.1f%%", odds()[i])
					end,
					FontFace = Theme.font.number,
					TextColor3 = Theme.color.white,
					ZIndex = 4,
					Components.textStroke(1.5),
				}),
			})
		)
	end
	return Components.panel({
		title = "PRIZE WHEEL",
		accent = Theme.color.pink,
		mascot = "CloudCowboy",
		size = UDim2.fromScale(0.5, 0.86),
		onClose = function()
			if not wheelBusy() then
				Store.menu("")
			end
		end,
		children = {
			Components.sunburst(Theme.color.gold, 14, UDim2.fromScale(1.15, 1.15)),
			create("Frame")({
				Name = "Ring",
				Size = UDim2.fromScale(1, 1),
				SizeConstraint = Enum.SizeConstraint.RelativeYY,
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.new(1, 1, 1),
				Components.corner(UDim.new(1, 0)),
				Components.stroke(5),
				Components.gradient(Theme.color.ink:Lerp(Theme.color.purple, 0.55)),
				-- Slowly rotating sunburst glow behind the bubbles.
				create("Frame")({
					Size = UDim2.fromScale(0.62, 0.62),
					Position = UDim2.fromScale(0.5, 0.5),
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundColor3 = Theme.color.gold,
					BackgroundTransparency = 0.55,
					Components.corner(UDim.new(1, 0)),
					Components.idle(25, 6),
				}),
				bubbles :: any,
				Components.button({
					name = "Spin",
					text = function()
						return if wheelBusy() then "..." else `SPIN! ({spinsAttr()})`
					end,
					color = function()
						return if spinsAttr() > 0 and not wheelBusy()
							then Theme.color.green
							else Theme.color.wood
					end,
					size = UDim2.fromScale(0.36, 0.17),
					position = UDim2.fromScale(0.5, 0.5),
					anchor = Vector2.new(0.5, 0.5),
					textSize = 34,
					shine = true,
					pulse = true,
					onClick = function()
						if not wheelBusy() then
							Net.request("SpinWheel")
						end
					end,
				}),
			}),
			show(function()
				return wheelPrize() ~= ""
			end, function()
				return text({
					Size = UDim2.new(0.9, 0, 0, 56),
					Position = UDim2.new(0.5, 0, 1, 10),
					AnchorPoint = Vector2.new(0.5, 1),
					BackgroundTransparency = 0,
					BackgroundColor3 = Theme.color.gold,
					TextColor3 = Theme.color.white,
					FontFace = Theme.font.title,
					ZIndex = 8,
					Text = wheelPrize,
					Components.corner(UDim.new(0, 14)),
					Components.stroke(4),
					Components.textStroke(3),
					Components.padding(8),
					Components.popIn(),
				})
			end),
			text({
				Size = UDim2.new(1, 0, 0, 22),
				Position = UDim2.new(0.5, 0, 0, -6),
				AnchorPoint = Vector2.new(0.5, 1),
				FontFace = Theme.font.heading,
				TextColor3 = Theme.color.ink,
				Text = function()
					if jackpotToday() then
						return "Jackpot already won today (1 a day). Free spins: +1 every 5 min, +1 every 3 heists."
					end
					local left = math.max(1, WheelConfig.JACKPOT_GUARANTEE_SPIN - spinsToday())
					return `JACKPOT guaranteed within {left} more spin{if left == 1 then "" else "s"} today! Free spins every 5 min.`
				end,
			}),
		},
	})
end

-- Big pulsing banner while you carry a heist crate.
local function runBanner(): any
	local carrying = source(localPlayer:GetAttribute("HeistCarry") == true)
	localPlayer:GetAttributeChangedSignal("HeistCarry"):Connect(function()
		carrying(localPlayer:GetAttribute("HeistCarry") == true)
	end)
	return show(carrying, function()
		return text({
			Name = "RunBanner",
			Size = UDim2.fromOffset(560, 64),
			Position = UDim2.new(0.5, 0, 0, 222),
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 0,
			BackgroundColor3 = Theme.color.red,
			TextColor3 = Theme.color.white,
			FontFace = Theme.font.title,
			Text = "RUN IT HOME! FOLLOW THE GOLD ARC!",
			Components.corner(UDim.new(0, 16)),
			Components.stroke(4),
			Components.textStroke(3),
			Components.padding(8),
			Components.popIn(),
			Components.idle(2, 0.5),
		})
	end)
end

function App.mount()
	local playerGui = localPlayer:WaitForChild("PlayerGui")
	local scale = source(1)
	-- Scale the 1280x720 design to the screen (phones get a smaller UI).
	local function rescale()
		local camera = Workspace.CurrentCamera
		if camera then
			local size = camera.ViewportSize
			scale(math.clamp(math.min(size.X / 1280, size.Y / 720), 0.55, 1.25))
		end
	end
	rescale()
	if Workspace.CurrentCamera then
		Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	end
	Vide.mount(function()
		return App.build(scale)
	end, playerGui)
end

function App.build(scale: () -> number): Instance
	return create("ScreenGui")({
		Name = "CritterExpressUI",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		-- A UIScale also scales the frame's own size, so the frame is sized 1/scale to still cover the
		-- whole screen; everything inside is laid out in 1280x720 design pixels.
		create("Frame")({
			Name = "Root",
			Size = function()
				return UDim2.fromScale(1 / scale(), 1 / scale())
			end,
			BackgroundTransparency = 1,
			create("UIScale")({ Scale = scale }),
			cashPills(),
			goalPill(),
			hint(),
			announcements(),
			sideMenu(),
			giftButton(),
			statusBadges(),
			actionButton(),
			toasts(),
			runBanner(),
			Hotbar.build(),
			SprintButton.build(),
			EventBanner.build(),
			Quests.tracker(function()
				return (state().tutorial or 0) >= 3 and Store.menu() == ""
			end),
		}),
		create("Frame")({
			Name = "Menus",
			Size = function()
				return UDim2.fromScale(1 / scale(), 1 / scale())
			end,
			create("UIScale")({ Scale = scale }),
			BackgroundTransparency = 1,
			ZIndex = 10,
			show(function()
				return Store.menu() == "shop"
			end, shopMenu),
			show(function()
				return Store.menu() == "eggs"
			end, eggsMenu),
			show(function()
				return Store.menu() == "wardrobe"
			end, function()
				return Wardrobe.menu(function()
					Store.menu("")
				end)
			end),
			show(function()
				return Store.menu() == "quests"
			end, questsMenu),
			show(function()
				return Store.menu() == "almanac"
			end, almanacMenu),
			show(function()
				return Store.menu() == "frontier"
			end, frontierMenu),
			show(function()
				return Store.menu() == "settings"
			end, settingsMenu),
			show(function()
				return Store.menu() == "boots"
			end, bootsMenu),
			show(function()
				return Store.menu() == "wheel"
			end, wheelMenu),
			show(function()
				return Store.menu() == "trade"
			end, function()
				return TradeUI.picker(function()
					Store.menu("")
				end)
			end),
			show(function()
				return Store.trade() ~= nil
			end, TradeUI.window),
			show(function()
				return Store.tradeInvite() ~= nil and Store.trade() == nil
			end, TradeUI.invitePopup),
			show(function()
				local p = state().pending
				return p ~= nil and ((p.offline or 0) > 0 or p.streakSlot ~= nil)
			end, welcome),
			show(function()
				return Store.odds() ~= nil
			end, oddsPanel),
		}),
	})
end

-- Kept for screens that will show luck math (tooltips).
App.luckConfig = LuckConfig

return App
