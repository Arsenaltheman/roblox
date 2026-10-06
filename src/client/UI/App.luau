--!strict
-- The whole UI: HUD, menus, odds panel and overlays. Designed at 1280x720 and scaled with UIScale.
-- HUD starts minimal; buttons pop in as the tutorial unlocks systems.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Vide = require("@game/ReplicatedStorage/Packages/Vide")
local Cosmetics = require("@game/ReplicatedStorage/Shared/Config/Cosmetics")
local LuckConfig = require("@game/ReplicatedStorage/Shared/Config/Luck")
local Mutations = require("@game/ReplicatedStorage/Shared/Config/Mutations")
local Products = require("@game/ReplicatedStorage/Shared/Config/Products")
local Progression = require("@game/ReplicatedStorage/Shared/Config/Progression")
local Rarities = require("@game/ReplicatedStorage/Shared/Config/Rarities")
local Species = require("@game/ReplicatedStorage/Shared/Config/Species")
local HeistConfig = require("@game/ReplicatedStorage/Shared/Config/Heist")
local Economy = require("@game/ReplicatedStorage/Shared/Sim/Economy")
local Luck = require("@game/ReplicatedStorage/Shared/Sim/Luck")
local NumberFormat = require("@game/ReplicatedStorage/Shared/Sim/NumberFormat")
local Net = require("@game/ReplicatedStorage/Shared/Net/Net")
local Context = require("../Controllers/Context")
local Sound = require("../Controllers/Sound")
local Store = require("../Store")
local Components = require("./Components")
local Theme = require("./Theme")

local create = Vide.create :: any
local show = Vide.show
local indexes = Vide.indexes
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
	color: Color3?
): Instance
	return Components.tile({
		glyph = glyph,
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
	local now = os.time()
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
		end, nil, Theme.color.yellow),
		menuButton(2, "◉", "EGGS", "eggs", function()
			return step() >= 2 or #(state().eggs or {}) > 0
		end, readyEggs, Theme.color.pink),
		menuButton(3, "!", "QUESTS", "quests", function()
			return step() >= 2
		end, readyQuests, Theme.color.orange),
		menuButton(4, "▤", "ALMANAC", "almanac", function()
			return step() >= 3
		end, nil, Theme.color.purple),
		menuButton(0, "»", "BOOTS", "boots", function()
			return true
		end, function()
			local level = bootsLevel()
			local cost = HeistConfig.bootsCost(level)
			return if cost and (state().cash or 0) >= cost then 1 else 0
		end, Theme.color.blue),
		menuButton(5, "⚙", "MORE", "settings", function()
			return true
		end, nil, Theme.color.teal),
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
		Size = UDim2.fromOffset(200, 200),
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
		}),
		indexes(Store.toasts, function(toast)
			return text({
				Size = UDim2.fromOffset(540, 40),
				BackgroundTransparency = 0.05,
				BackgroundColor3 = Theme.color.paper,
				FontFace = Theme.font.heading,
				Text = function()
					return toast().text
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
		}),
		indexes(Store.announcements, function(item)
			local kind = item().kind
			local color = if Rarities.byId[kind]
				then Theme.rarityColor(kind)
				elseif kind == "golden" or kind == "luck" then Theme.color.gold
				elseif kind == "steal" then Theme.color.red
				else Theme.color.skyDeep
			local scale = source(1.6)
			local s = spring(scale, 0.35, 0.5)
			task.defer(function()
				scale(1)
			end)
			return text({
				Size = UDim2.fromOffset(740, 46),
				BackgroundTransparency = 0,
				BackgroundColor3 = color,
				TextColor3 = Theme.color.white,
				FontFace = Theme.font.title,
				Text = function()
					return item().text
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

-- Icon glyph and colour for each shop item (no image assets needed).
local SHOP_LOOK: { [string]: { any } } = {
	VIP = { "★", Theme.color.yellow },
	DoubleCash = { "2x", Theme.color.green },
	AutoCollect = { "$", Theme.color.teal },
	LuckyHorseshoe = { "♣", Theme.color.gold },
	GoldenLasso = { "◎", Theme.color.orange },
	SpeedSpurs = { "»", Theme.color.blue },
	IronLock = { "■", Theme.color.purple },
	HeavySaddlebag = { "▲", Theme.color.pink },
	BigRanch = { "+2", Theme.color.green },
	SheriffStar = { "✦", Theme.color.red },
	ServerLuck2 = { "x2", Theme.color.gold },
	ServerLuck3 = { "x3", Theme.color.gold },
	ServerLuck5 = { "x5", Theme.color.gold },
	Lockpick = { "!", Theme.color.purple },
	CashBag10m = { "$", Theme.color.green },
	CashBag1h = { "$$", Theme.color.green },
	CashBag6h = { "$$$", Theme.color.green },
	CashBag24h = { "$$$$", Theme.color.green },
	StarterPack = { "◆", Theme.color.pink },
	GoldenLocomotive = { "♛", Theme.color.yellow },
	DiamondDesperado = { "♛", Theme.color.teal },
}

local function shopMenu(): Instance
	local tab = source("robux")
	local restricted = localPlayer:GetAttribute("RandomRestricted") == true
	local robux = {}
	for i, product in Products.list do
		if product.kind ~= "privateServer" and not (product.random and restricted) then
			local owned = function()
				return product.kind == "pass" and localPlayer:GetAttribute("Pass_" .. product.key) == true
			end
			table.insert(
				robux,
				card({
					order = i,
					title = function()
						return product.name
					end,
					sub = function()
						return product.description
					end,
					color = SHOP_LOOK[product.key] and SHOP_LOOK[product.key][2]
						or (if product.random then Theme.color.gold else Theme.color.blue),
					glyph = SHOP_LOOK[product.key] and SHOP_LOOK[product.key][1] or "★",
					button = function()
						return if owned() then "OWNED" else "View Item"
					end,
					onClick = function()
						if not owned() then
							Net.request("ShopBuy", product.key, 1)
						end
					end,
					extra = if product.random
						then Components.button({
							text = "Odds",
							color = Theme.color.skyDeep,
							size = UDim2.fromOffset(80, 36),
							position = UDim2.new(0.62, 0, 0.5, 0),
							anchor = Vector2.new(0, 0.5),
							textSize = 18,
							onClick = function()
								showOdds("reserved")
							end,
						})
						else nil,
				})
			)
		end
	end
	local post = derive(function()
		local items = {}
		local shop = state().shop
		for _, id in (shop and shop.items) or {} do
			table.insert(items, id)
		end
		return items
	end)
	return Components.panel({
		title = "TRADING POST",
		onClose = function()
			Store.menu("")
		end,
		children = {
			create("Frame")({
				Size = UDim2.new(1, 0, 0, 48),
				BackgroundTransparency = 1,
				create("UIListLayout")({
					FillDirection = Enum.FillDirection.Horizontal,
					Padding = UDim.new(0, 10),
				}),
				Components.button({
					text = "ROBUX",
					color = function()
						return if tab() == "robux" then Theme.color.green else Theme.color.wood
					end,
					size = UDim2.fromOffset(150, 44),
					onClick = function()
						tab("robux")
					end,
				}),
				Components.button({
					text = "NUGGETS",
					color = function()
						return if tab() == "nuggets" then Theme.color.green else Theme.color.wood
					end,
					size = UDim2.fromOffset(150, 44),
					onClick = function()
						tab("nuggets")
					end,
				}),
			}),
			create("Frame")({
				Size = UDim2.new(1, 0, 1, -56),
				Position = UDim2.fromOffset(0, 56),
				BackgroundTransparency = 1,
				show(function()
					return tab() == "robux"
				end, function()
					return list(robux)
				end),
				show(function()
					return tab() == "nuggets"
				end, function()
					return list({
						card({
							order = 0,
							title = function()
								return "Hatchery Egg"
							end,
							sub = function()
								return `{Progression.eggs.hatcheryCost} Gold Nuggets · odds shown in Eggs`
							end,
							color = Theme.color.nugget,
							button = "BUY",
							onClick = function()
								Net.request("ShopBuy", "HatcheryEgg", 1)
							end,
						}),
						text({
							Size = UDim2.new(1, 0, 0, 26),
							LayoutOrder = 1,
							FontFace = Theme.font.heading,
							Text = function()
								local shop = state().shop
								local left = if shop
									then math.max(0, shop.restockAt - Workspace:GetServerTimeNow())
									else 0
								return `New stock in {NumberFormat.clock(left)}`
							end,
						}),
						indexes(post, function(id, i)
							local cosmetic = Cosmetics.byId[id()]
							return card({
								order = 1 + i,
								title = function()
									return cosmetic.name
								end,
								sub = function()
									return `{cosmetic.nuggets} Gold Nuggets`
								end,
								color = Theme.color.nugget,
								button = function()
									return if (state().owned or {})[id()] then "OWNED" else "BUY"
								end,
								onClick = function()
									Net.request("ShopBuy", id(), 1)
								end,
							})
						end),
					})
				end),
			}),
		},
	})
end

local function eggsMenu(): Instance
	local clock = source(os.time())
	task.spawn(function()
		while true do
			clock(os.time())
			task.wait(1)
		end
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
							if egg().hatchAt <= os.time() then
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
	return Components.panel({
		title = "WANTED BOARD",
		onClose = function()
			Store.menu("")
		end,
		children = {
			list({
				text({
					Size = UDim2.new(1, 0, 0, 30),
					LayoutOrder = 0,
					FontFace = Theme.font.heading,
					Text = function()
						local s = state().streak
						return `Login streak: day {s and s.count or 0} · new quests at 00:00 UTC`
					end,
				}),
				indexes(function()
					return state().quests or {}
				end, function(q, i)
					return card({
						order = i,
						title = function()
							return q().text
						end,
						sub = function()
							return `{q().progress}/{q().goal} · reward: cash + {Progression.quests.nuggets} nuggets`
						end,
						color = Theme.color.red,
						button = function()
							return if q().claimed
								then "DONE"
								elseif q().progress >= q().goal then "CLAIM"
								else "..."
						end,
						onClick = function()
							Net.request("Claim", "quest", q().index)
						end,
					})
				end),
			}),
		},
	})
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
			create("ScrollingFrame")({
				Size = UDim2.fromScale(1, 1),
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
			return (state().tutorial or 0) < 3 and #Store.announcements() == 0
		end,
		Text = function()
			local step = state().tutorial or 0
			if step == 0 then
				return "Tap BUY on your RESERVED cage!"
			elseif step == 1 then
				return "Grab the GOLDEN TICKET cage on the next train!"
			end
			return "Lasso Bandit Bart when he shows up!"
		end,
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
			Position = UDim2.new(0.5, 0, 0, 150),
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
		create("Frame")({
			Name = "Root",
			Size = UDim2.fromScale(1, 1),
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
		}),
		create("Frame")({
			Name = "Menus",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ZIndex = 10,
			show(function()
				return Store.menu() == "shop"
			end, shopMenu),
			show(function()
				return Store.menu() == "eggs"
			end, eggsMenu),
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
