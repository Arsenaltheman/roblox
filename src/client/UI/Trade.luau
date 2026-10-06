--!strict
-- Trading UI: the player picker (TRADE tile), the invite popup and the escrow trade window.
-- Everything shown comes from the server (Store.trade / Store.tradeInvite); the client only sends
-- item choices. No free text anywhere.

local Players = game:GetService("Players")

local Vide = require("@game/ReplicatedStorage/Packages/Vide")
local Mutations = require("@game/ReplicatedStorage/Shared/Config/Mutations")
local Rarities = require("@game/ReplicatedStorage/Shared/Config/Rarities")
local Species = require("@game/ReplicatedStorage/Shared/Config/Species")
local Economy = require("@game/ReplicatedStorage/Shared/Sim/Economy")
local NumberFormat = require("@game/ReplicatedStorage/Shared/Sim/NumberFormat")
local Rules = require("@game/ReplicatedStorage/Shared/Sim/Trade")
local Net = require("@game/ReplicatedStorage/Shared/Net/Net")
local Sound = require("../Controllers/Sound")
local Store = require("../Store")
local Components = require("./Components")
local Theme = require("./Theme")

local create = Vide.create :: any
local show = Vide.show :: any
local values = Vide.values :: any
local source = Vide.source
local cleanup = Vide.cleanup

local localPlayer = Players.LocalPlayer

local Trade = {}

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

-- A clock that ticks while the calling component is alive.
local function ticker(period: number, read: () -> number): () -> number
	local clock = source(read())
	local alive = true
	task.spawn(function()
		while alive do
			task.wait(period)
			clock(read())
		end
	end)
	cleanup(function()
		alive = false
	end)
	return clock
end

local function trade(): any
	return Store.trade()
end

local function speciesName(id: string): string
	local species = Species.byId[id]
	return if species then species.name else id
end

-- ---------------------------------------------------------------- critter card

-- Rarity-coloured card: live 3D critter, name, tier + rarity, income/s, mutation.
-- `info` reads the latest data for this critter (nil when it has left the list).
local function critterCard(
	species: string,
	info: () -> any,
	props: {
		size: UDim2,
		order: (() -> number)?,
		onClick: (() -> ())?,
		dim: (() -> boolean)?,
	}
): Instance
	local function field(key: string, fallback: any): any
		local i = info()
		return if i and i[key] ~= nil then i[key] else fallback
	end
	return create("TextButton")({
		Size = props.size,
		LayoutOrder = props.order,
		AutoButtonColor = false,
		Text = "",
		BackgroundColor3 = function()
			return Theme.rarityForTier(field("t", 1))
		end,
		Activated = function()
			if props.onClick then
				Sound.play("click")
				props.onClick()
			end
		end,
		Components.corner(UDim.new(0, 12)),
		Components.stroke(2.5),
		Components.mascot({
			species = species,
			tier = field("t", 5),
			size = UDim2.fromScale(0.62, 0.62),
			position = UDim2.fromScale(0.5, 0.33),
		}),
		-- Mutation ribbon (top).
		show(function()
			return field("m", nil) ~= nil
		end, function()
			return text({
				Size = UDim2.new(1, -8, 0.16, 0),
				Position = UDim2.fromOffset(4, 3),
				ZIndex = 9,
				FontFace = Theme.font.title,
				TextColor3 = function()
					return Theme.mutationColor(field("m", nil)) or Theme.color.white
				end,
				Text = function()
					local m = Mutations.byId[field("m", "")]
					return if m then string.upper(m.name) else ""
				end,
				Components.textStroke(2),
			})
		end),
		text({
			Size = UDim2.new(1, -8, 0.17, 0),
			Position = UDim2.new(0, 4, 0.62, 0),
			ZIndex = 9,
			FontFace = Theme.font.heading,
			TextColor3 = Theme.color.white,
			Text = speciesName(species),
			Components.textStroke(2),
		}),
		text({
			Size = UDim2.new(1, -8, 0.17, 0),
			Position = UDim2.new(0, 4, 0.8, 0),
			ZIndex = 9,
			FontFace = Theme.font.number,
			TextColor3 = Theme.color.white,
			Text = function()
				local tier = field("t", 1)
				local inc = field("inc", 0)
				return `T{tier} {Rarities.forTier(tier).name} · {NumberFormat.perSecond(inc)}`
			end,
			Components.textStroke(1.5),
		}),
		create("Frame")({
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(0, 0, 0),
			ZIndex = 10,
			BackgroundTransparency = function()
				return if props.dim and props.dim() then 0.5 else 1
			end,
			Components.corner(UDim.new(0, 12)),
		}),
	})
end

-- ---------------------------------------------------------------- player picker

function Trade.picker(onClose: () -> ()): Instance
	local function readPlayers(): number
		return #Players:GetPlayers() * 1000 + math.floor(os.clock())
	end
	local clock = ticker(1, readPlayers)
	local myBlock = function(): string
		clock()
		return (localPlayer:GetAttribute("TradeBlock") :: string?) or ""
	end
	local others = function(): { [number]: Player }
		clock()
		local list = {}
		for _, p in Players:GetPlayers() do
			if p ~= localPlayer then
				table.insert(list, p)
			end
		end
		table.sort(list, function(a, b)
			return a.DisplayName < b.DisplayName
		end)
		return list
	end
	return Components.panel({
		title = "TRADE",
		accent = Theme.color.teal,
		onClose = onClose,
		children = {
			text({
				Size = UDim2.new(1, 0, 0, 52),
				FontFace = Theme.font.heading,
				TextWrapped = true,
				TextColor3 = function()
					return if myBlock() ~= "" then Theme.color.red else Theme.color.ink
				end,
				Text = function()
					local why = myBlock()
					return if why ~= ""
						then `🔒 {why}`
						else "Pick a player. Both sides see every critter before the trade happens, and Branded or Robux-luck critters can't be traded."
				end,
			}),
			create("ScrollingFrame")({
				Size = UDim2.new(1, 0, 1, -60),
				Position = UDim2.fromOffset(0, 60),
				BackgroundTransparency = 1,
				ScrollBarThickness = 8,
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				CanvasSize = UDim2.new(),
				create("UIListLayout")({ Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
				Components.padding(4),
				show(function()
					return #others() == 0
				end, function()
					return text({
						Size = UDim2.new(1, 0, 0, 40),
						FontFace = Theme.font.heading,
						Text = "Nobody else is here yet. Invite a friend!",
					})
				end),
				values(others, function(p: Player, i: () -> number)
					local blocked = function(): string
						clock()
						return (p:GetAttribute("TradeBlock") :: string?) or ""
					end
					return create("Frame")({
						Size = UDim2.new(1, -10, 0, 70),
						LayoutOrder = i,
						BackgroundColor3 = Color3.new(1, 1, 1),
						Components.corner(UDim.new(0, 14)),
						Components.stroke(3),
						Components.gradient(Theme.lighten(Theme.color.teal, 0.75)),
						text({
							Size = UDim2.new(0.6, 0, 0.5, 0),
							Position = UDim2.new(0, 16, 0.08, 0),
							FontFace = Theme.font.title,
							TextColor3 = Theme.color.white,
							TextXAlignment = Enum.TextXAlignment.Left,
							Text = p.DisplayName,
							Components.textStroke(2.5),
						}),
						text({
							Size = UDim2.new(0.6, 0, 0.32, 0),
							Position = UDim2.new(0, 16, 0.6, 0),
							TextXAlignment = Enum.TextXAlignment.Left,
							TextColor3 = Theme.darken(Theme.color.wood, 0.25),
							Text = function()
								return if blocked() ~= "" then "Can't trade yet" else "Ready to trade"
							end,
						}),
						Components.button({
							text = "INVITE",
							color = function()
								return if blocked() ~= "" or myBlock() ~= ""
									then Theme.color.woodDark
									else Theme.color.green
							end,
							size = UDim2.new(0.28, 0, 0, 50),
							position = UDim2.new(1, -12, 0.5, -3),
							anchor = Vector2.new(1, 0.5),
							textSize = 24,
							onClick = function()
								Sound.play("click")
								Net.request("TradeInvite", p.UserId)
							end,
						}),
					})
				end),
			}),
		},
	})
end

-- ---------------------------------------------------------------- invite popup

function Trade.invitePopup(): Instance
	local clock = ticker(0.25, os.clock)
	local function inviter(): Player?
		local inv = Store.tradeInvite()
		return if inv then Players:GetPlayerByUserId(inv.from) else nil
	end
	local function answer(accept: boolean)
		local inv = Store.tradeInvite()
		if inv then
			Sound.play("click")
			Net.request("TradeRespond", inv.from, accept)
			Store.tradeInvite(nil)
		end
	end
	-- Expire locally too (the server also refuses late answers).
	Vide.effect(function()
		local inv = Store.tradeInvite()
		if inv and clock() >= inv.expires then
			Vide.untrack(function()
				Store.tradeInvite(nil)
			end)
		end
	end)
	return create("Frame")({
		Name = "TradeInvite",
		Size = UDim2.fromOffset(420, 150),
		Position = UDim2.new(0.5, 0, 0, 90),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 20,
		Components.corner(UDim.new(0, 18)),
		Components.stroke(4),
		Components.gradient(Theme.color.cream),
		Components.popIn(),
		text({
			Size = UDim2.new(1, -24, 0, 40),
			Position = UDim2.fromOffset(12, 10),
			FontFace = Theme.font.title,
			TextColor3 = Theme.color.white,
			Text = function()
				local p = inviter()
				return `{if p then p.DisplayName else "Someone"} wants to trade!`
			end,
			Components.textStroke(2.5),
		}),
		text({
			Size = UDim2.new(1, -24, 0, 22),
			Position = UDim2.fromOffset(12, 52),
			FontFace = Theme.font.number,
			Text = function()
				local inv = Store.tradeInvite()
				local left = if inv then math.max(0, math.ceil(inv.expires - clock())) else 0
				return `Expires in {left}s`
			end,
		}),
		Components.button({
			text = "DECLINE",
			color = Theme.color.red,
			size = UDim2.new(0.44, 0, 0, 52),
			position = UDim2.new(0.04, 0, 1, -64),
			textSize = 24,
			onClick = function()
				answer(false)
			end,
		}),
		Components.button({
			text = "ACCEPT",
			color = Theme.color.green,
			size = UDim2.new(0.44, 0, 0, 52),
			position = UDim2.new(0.52, 0, 1, -64),
			textSize = 24,
			pulse = true,
			onClick = function()
				answer(true)
			end,
		}),
	})
end

-- ---------------------------------------------------------------- trade window

local function cidsOf(side: string): () -> { string }
	return function()
		local t = trade()
		local list = {}
		if t and t[side] then
			for _, c in t[side].critters do
				table.insert(list, c.cid)
			end
		end
		return list
	end
end

local function infoOf(side: string, cid: string): () -> any
	return function()
		local t = trade()
		if t and t[side] then
			for _, c in t[side].critters do
				if c.cid == cid then
					return c
				end
			end
		end
		return nil
	end
end

-- One side of the trade: 6 card slots and the nugget amount.
local function offerColumn(side: string, position: UDim2): Instance
	local mine = side == "mine"
	local cids = cidsOf(side)
	local speciesByCid: { [string]: string } = {}
	return create("Frame")({
		Size = UDim2.new(0.5, -6, 0, 286),
		Position = position,
		BackgroundColor3 = function()
			local t = trade()
			local isReady = t and (if mine then t.myReady else t.theirReady)
			return if isReady
				then Theme.lighten(Theme.color.green, 0.55)
				else Theme.lighten(Theme.color.wood, 0.7)
		end,
		Components.corner(UDim.new(0, 14)),
		Components.stroke(3),
		text({
			Size = UDim2.new(1, -16, 0, 30),
			Position = UDim2.fromOffset(8, 4),
			FontFace = Theme.font.title,
			TextColor3 = Theme.color.white,
			Text = function()
				local t = trade()
				if not t then
					return ""
				end
				local who = if mine then "YOU GIVE" else `{string.upper(t.partnerName)} GIVES`
				local isReady = if mine then t.myReady else t.theirReady
				return if isReady then `{who} ✔ READY` else who
			end,
			Components.textStroke(2.5),
		}),
		-- "Changed!" flash on the partner's side so last-second swaps can't slip by.
		if not mine
			then show(function()
				local t = trade()
				local clock = Store.serverClock()
				return t ~= nil and clock - (t.theirChangedAt or -math.huge) < 3
			end, function()
				return text({
					Size = UDim2.fromOffset(150, 26),
					Position = UDim2.new(1, -8, 0, 6),
					AnchorPoint = Vector2.new(1, 0),
					BackgroundTransparency = 0,
					BackgroundColor3 = Theme.color.red,
					TextColor3 = Theme.color.white,
					FontFace = Theme.font.title,
					Text = "OFFER CHANGED!",
					ZIndex = 12,
					Components.corner(UDim.new(0, 8)),
					Components.idle(4, 0.4),
				})
			end)
			else nil,
		create("Frame")({
			Size = UDim2.new(1, -12, 0, 212),
			Position = UDim2.fromOffset(6, 38),
			BackgroundTransparency = 1,
			create("UIGridLayout")({
				CellSize = UDim2.new(1 / 3, -6, 0.5, -4),
				CellPadding = UDim2.fromOffset(6, 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			values(cids, function(cid: string, i: () -> number)
				local info = infoOf(side, cid)
				local first = info()
				speciesByCid[cid] = speciesByCid[cid] or (first and first.s) or "Cottontail"
				return critterCard(speciesByCid[cid], info, {
					size = UDim2.fromScale(1, 1),
					order = i,
					onClick = if mine
						then function()
							Net.request("TradeOffer", cid, false)
						end
						else nil,
				})
			end),
		}),
		text({
			Size = UDim2.new(1, -16, 0, 26),
			Position = UDim2.new(0, 8, 1, -32),
			FontFace = Theme.font.number,
			TextColor3 = Theme.color.nugget,
			Text = function()
				local t = trade()
				local n = if t then t[side].nuggets else 0
				return `+ {NumberFormat.short(n)} Gold Nuggets`
			end,
			Components.textStroke(2),
		}),
	})
end

-- Own ranch: tap a critter to add it to (or take it out of) the offer.
local function ranchStrip(): Instance
	local speciesByCid: { [string]: string } = {}
	local function critters(): any
		return (Store.state() or {}).critters or {}
	end
	local function offered(cid: string): boolean
		local t = trade()
		if t then
			for _, c in t.mine.critters do
				if c.cid == cid then
					return true
				end
			end
		end
		return false
	end
	local cids = function(): { string }
		local list = {}
		for cid in critters() do
			table.insert(list, cid)
		end
		local all = critters()
		table.sort(list, function(a, b)
			local ca, cb = all[a], all[b]
			if ca.t ~= cb.t then
				return ca.t > cb.t
			end
			return (tonumber(a) or 0) < (tonumber(b) or 0)
		end)
		return list
	end
	return create("Frame")({
		Size = UDim2.new(1, 0, 0, 150),
		Position = UDim2.fromOffset(0, 292),
		BackgroundTransparency = 1,
		text({
			Size = UDim2.new(1, 0, 0, 22),
			FontFace = Theme.font.heading,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = `YOUR RANCH: tap to add or remove (up to {Rules.MAX_CRITTERS}). Darkened ones can't be traded.`,
		}),
		create("ScrollingFrame")({
			Size = UDim2.new(1, 0, 1, -24),
			Position = UDim2.fromOffset(0, 24),
			BackgroundTransparency = 1,
			ScrollBarThickness = 6,
			ScrollingDirection = Enum.ScrollingDirection.X,
			AutomaticCanvasSize = Enum.AutomaticSize.X,
			CanvasSize = UDim2.new(),
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			values(cids, function(cid: string, i: () -> number)
				local first = critters()[cid]
				speciesByCid[cid] = speciesByCid[cid] or (first and first.s) or "Cottontail"
				local info = function(): any
					local c = critters()[cid]
					if not c then
						return nil
					end
					return {
						s = c.s,
						t = c.t,
						m = c.m,
						inc = Economy.critterIncome({ tier = c.t, mutation = c.m }),
						blocked = Rules.critterBlock({
							br = c.br == true,
							pr = c.pr == true,
							it = c.it == true,
						}),
					}
				end
				return create("Frame")({
					Size = UDim2.fromOffset(112, 112),
					LayoutOrder = i,
					BackgroundTransparency = 1,
					critterCard(speciesByCid[cid], info, {
						size = UDim2.fromScale(1, 1),
						onClick = function()
							local c = info()
							if c and c.blocked then
								Store.toast(c.blocked)
								return
							end
							Net.request("TradeOffer", cid, not offered(cid))
						end,
						dim = function()
							local c = info()
							return c ~= nil and c.blocked ~= nil
						end,
					}),
					show(function()
						return offered(cid)
					end, function()
						return text({
							Size = UDim2.fromOffset(34, 34),
							Position = UDim2.new(1, 4, 0, -4),
							AnchorPoint = Vector2.new(1, 0),
							BackgroundTransparency = 0,
							BackgroundColor3 = Theme.color.green,
							TextColor3 = Theme.color.white,
							FontFace = Theme.font.title,
							Text = "✔",
							ZIndex = 12,
							Components.corner(UDim.new(1, 0)),
							Components.stroke(2),
						})
					end),
				})
			end),
		}),
	})
end

local function nuggetButtons(): Instance
	local function set(amount: number)
		local have = (Store.state() or {}).nuggets or 0
		Net.request("TradeNuggets", math.clamp(math.floor(amount), 0, math.min(have, Rules.MAX_NUGGETS)))
	end
	local function current(): number
		local t = trade()
		return if t then t.mine.nuggets else 0
	end
	local row = {}
	for i, step in { 10, 100, 1000 } do
		table.insert(
			row,
			Components.button({
				text = `+{NumberFormat.short(step)}`,
				color = Theme.color.nugget,
				size = UDim2.fromOffset(78, 44),
				layoutOrder = i,
				textSize = 20,
				onClick = function()
					set(current() + step)
				end,
			})
		)
	end
	table.insert(
		row,
		Components.button({
			text = "ALL",
			color = Theme.color.orange,
			size = UDim2.fromOffset(70, 44),
			layoutOrder = 4,
			textSize = 20,
			onClick = function()
				set((Store.state() or {}).nuggets or 0)
			end,
		})
	)
	table.insert(
		row,
		Components.button({
			text = "0",
			color = Theme.color.woodDark,
			size = UDim2.fromOffset(50, 44),
			layoutOrder = 5,
			textSize = 20,
			onClick = function()
				set(0)
			end,
		})
	)
	return create("Frame")({
		Size = UDim2.new(0.5, 0, 0, 50),
		Position = UDim2.new(0, 0, 1, -50),
		BackgroundTransparency = 1,
		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
		row :: any,
	})
end

function Trade.window(): Instance
	local function cancel()
		Sound.play("click")
		Net.request("TradeCancel")
	end
	local function status(): string
		local t = trade()
		if not t then
			return ""
		end
		local clock = Store.serverClock()
		if t.countdownEnd then
			local left = math.max(0, math.ceil(t.countdownEnd - clock))
			return `CHECK BOTH SIDES! Trading in {left}...`
		end
		if t.myReady and not t.theirReady then
			return `Waiting for {t.partnerName}...`
		end
		if t.theirReady and not t.myReady then
			return `{t.partnerName} is READY. Check their offer, then press READY.`
		end
		return "Any change un-readies both sides."
	end
	return Components.panel({
		title = "TRADE",
		accent = Theme.color.teal,
		size = UDim2.fromScale(0.9, 0.9),
		onClose = cancel,
		children = {
			offerColumn("mine", UDim2.fromOffset(0, 0)),
			offerColumn("theirs", UDim2.new(0.5, 6, 0, 0)),
			ranchStrip(),
			nuggetButtons(),
			text({
				Size = UDim2.new(0.5, -170, 0, 44),
				Position = UDim2.new(0.5, 0, 1, -47),
				FontFace = Theme.font.heading,
				TextWrapped = true,
				TextColor3 = function()
					local t = trade()
					return if t and t.countdownEnd then Theme.color.red else Theme.color.ink
				end,
				Text = status,
			}),
			Components.button({
				text = "CANCEL",
				color = Theme.color.red,
				size = UDim2.fromOffset(78, 48),
				position = UDim2.new(1, -84, 1, -2),
				anchor = Vector2.new(1, 1),
				textSize = 20,
				onClick = cancel,
			}),
			Components.button({
				text = function()
					local t = trade()
					return if t and t.myReady then "UNREADY" else "READY"
				end,
				color = function()
					local t = trade()
					return if t and t.myReady then Theme.color.orange else Theme.color.green
				end,
				size = UDim2.fromOffset(80, 48),
				position = UDim2.new(1, 0, 1, -2),
				anchor = Vector2.new(1, 1),
				textSize = 20,
				shine = true,
				onClick = function()
					local t = trade()
					Sound.play("click")
					Net.request("TradeReady", not (t and t.myReady))
				end,
			}),
		},
	})
end

return Trade
