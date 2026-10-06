--!strict
-- Wardrobe: equip the cosmetics you own (titles, hats, lasso trails, WANTED posters, ranch themes).
-- Locked ones show how to get them. Everyone sees what you wear (Controllers/Looks).

local Players = game:GetService("Players")

local Vide = require("@game/ReplicatedStorage/Packages/Vide")
local Cosmetics = require("@game/ReplicatedStorage/Shared/Config/Cosmetics")
local Rarities = require("@game/ReplicatedStorage/Shared/Config/Rarities")
local Species = require("@game/ReplicatedStorage/Shared/Config/Species")
local Economy = require("@game/ReplicatedStorage/Shared/Sim/Economy")
local Net = require("@game/ReplicatedStorage/Shared/Net/Net")
local Sound = require("../Controllers/Sound")
local Store = require("../Store")
local Components = require("./Components")
local Theme = require("./Theme")

local create = Vide.create :: any
local show = Vide.show :: any
local values = Vide.values :: any
local source = Vide.source

local localPlayer = Players.LocalPlayer

local Wardrobe = {}

-- "companion" is a critter you own, not a cosmetic; its page is built from the save's critters.
local SLOTS = {
	{ id = "companion", label = "COMPANION", icon = "paw", glyph = "♥" },
	{ id = "title", label = "TITLES", icon = "crown", glyph = "♛" },
	{ id = "hat", label = "HATS", icon = "sheriffstar", glyph = "▲" },
	{ id = "lassoTrail", label = "LASSOS", icon = "lasso", glyph = "◎" },
	{ id = "poster", label = "POSTERS", icon = "scroll", glyph = "▤" },
	{ id = "ranchTheme", label = "RANCH", icon = "barn", glyph = "⌂" },
	{ id = "cape", label = "CAPES", icon = "scroll", glyph = "▼" },
}

local function state(): any
	return Store.state() or {}
end

local function owned(id: string): boolean
	if (state().owned or {})[id] then
		return true
	end
	return id == "trail_gold" and localPlayer:GetAttribute("VIP") == true
end

local function equipped(slot: string): string
	return (state().equipped or {})[slot] or ""
end

local function howToGet(cosmetic: Cosmetics.Cosmetic): string
	if cosmetic.nuggets then
		return `{cosmetic.nuggets} Nuggets in the Trading Post`
	elseif cosmetic.id == "title_season" then
		return "Rail Pass premium tier 20"
	elseif cosmetic.id == "hat_season" then
		return "Rail Pass premium tier 40"
	elseif string.sub(cosmetic.id, 1, 5) == "cape_" then
		return "Master a Trail Skill (level 50)"
	elseif string.sub(cosmetic.id, 1, 6) == "title_" then
		return "Earned on the Bounty Trail"
	elseif cosmetic.id == "hat_premium" then
		return "Roblox Premium members"
	elseif cosmetic.id == "hat_club" then
		return "Sheriff's Club members"
	elseif cosmetic.id == "title_regular" then
		return "A 30-day login streak"
	elseif cosmetic.id == "trail_gold" then
		return "Sheriff's Badge (VIP)"
	end
	return "Strongboxes and special rewards"
end

local function itemCard(cosmetic: Cosmetics.Cosmetic, order: number): Instance
	local c = Color3.fromHex(cosmetic.color)
	return create("TextButton")({
		LayoutOrder = order,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		Activated = function()
			if not owned(cosmetic.id) then
				return
			end
			Sound.play("click")
			local slot = cosmetic.slot
			Net.request("Equip", slot, if equipped(slot) == cosmetic.id then "" else cosmetic.id)
		end,
		create("Frame")({
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(1, 1, 1),
			Components.corner(UDim.new(0, 14)),
			create("UIStroke")({
				Thickness = function()
					return if equipped(cosmetic.slot) == cosmetic.id then 5 else 3
				end,
				Color = function()
					return if equipped(cosmetic.slot) == cosmetic.id
						then Theme.color.green
						else Theme.color.ink
				end,
			}),
			Components.gradient(function()
				return if owned(cosmetic.id) then Theme.lighten(c, 0.35) else Color3.fromRGB(150, 145, 140)
			end),
			-- Colour swatch
			create("Frame")({
				Size = UDim2.fromScale(0.5, 0.42),
				SizeConstraint = Enum.SizeConstraint.RelativeYY,
				Position = UDim2.fromScale(0.5, 0.3),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = c,
				Components.corner(UDim.new(1, 0)),
				Components.stroke(3),
				Components.gloss(UDim.new(1, 0)),
			}),
			create("TextLabel")({
				Size = UDim2.new(1, -10, 0.24, 0),
				Position = UDim2.new(0.5, 0, 0.58, 0),
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,
				Text = cosmetic.name,
				TextScaled = true,
				TextColor3 = Theme.color.white,
				FontFace = Theme.font.title,
				Components.textStroke(2),
			}),
			create("TextLabel")({
				Size = UDim2.new(1, -10, 0.15, 0),
				Position = UDim2.new(0.5, 0, 0.83, 0),
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,
				Text = function()
					if equipped(cosmetic.slot) == cosmetic.id then
						return "✔ EQUIPPED (tap to remove)"
					elseif owned(cosmetic.id) then
						return "TAP TO EQUIP"
					end
					return "🔒 " .. howToGet(cosmetic)
				end,
				TextScaled = true,
				TextColor3 = Theme.color.white,
				FontFace = Theme.font.heading,
				Components.textStroke(1.5),
			}),
		}),
	})
end

-- ---------------------------------------------------------------- companions

local function critters(): { [string]: any }
	return state().critters or {}
end

-- Critter ids sorted by tier (best first), then by id so the order is stable.
local function companionIds(): { string }
	local all = critters()
	local list = {}
	for cid in all do
		table.insert(list, cid)
	end
	table.sort(list, function(a, b)
		if all[a].t ~= all[b].t then
			return all[a].t > all[b].t
		end
		return (tonumber(a) or 0) < (tonumber(b) or 0)
	end)
	return list
end

local function companionCard(cid: string, order: () -> number): Instance
	local first = critters()[cid] or {}
	local speciesId: string = first.s or "Cottontail"
	local tier: number = first.t or 1
	local mutation: string? = first.m
	local rarity = Rarities.forTier(math.clamp(tier, 1, Rarities.maxTier))
	local c = Color3.fromHex(rarity.color)
	local species = Species.byId[speciesId]
	local boost = Economy.companionBoost({ tier = tier, mutation = mutation })
	local function current(): any
		return critters()[cid]
	end
	local function following(): boolean
		return equipped("companion") == cid
	end
	local function inTransit(): boolean
		local info = current()
		return info ~= nil and info.it == true
	end
	return create("TextButton")({
		LayoutOrder = order,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		Activated = function()
			if inTransit() then
				return
			end
			Sound.play("click")
			Net.request("Equip", "companion", if following() then "" else cid)
		end,
		create("Frame")({
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(1, 1, 1),
			Components.corner(UDim.new(0, 14)),
			create("UIStroke")({
				Thickness = function()
					return if following() then 5 else 3
				end,
				Color = function()
					return if following() then Theme.color.green else Theme.color.ink
				end,
			}),
			Components.gradient(function()
				return if inTransit() then Color3.fromRGB(150, 145, 140) else Theme.lighten(c, 0.35)
			end),
			Components.mascot({
				species = speciesId,
				tier = tier,
				mutation = mutation,
				size = UDim2.fromScale(0.55, 0.55),
				position = UDim2.fromScale(0.5, 0.3),
			}),
			create("TextLabel")({
				Size = UDim2.new(1, -10, 0.17, 0),
				Position = UDim2.new(0.5, 0, 0.56, 0),
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,
				Text = `{if species then species.name else speciesId}{if first.br then " ★" else ""}`,
				TextScaled = true,
				TextColor3 = Theme.color.white,
				FontFace = Theme.font.title,
				Components.textStroke(2),
			}),
			create("TextLabel")({
				Size = UDim2.new(1, -10, 0.11, 0),
				Position = UDim2.new(0.5, 0, 0.72, 0),
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,
				Text = `T{tier} {rarity.name}{if mutation and mutation ~= "" then ` · {mutation}` else ""} · +{math.floor(
					boost * 100 + 0.5
				)}% cash while following you`,
				TextScaled = true,
				TextColor3 = Theme.color.white,
				FontFace = Theme.font.heading,
				Components.textStroke(1.5),
			}),
			create("TextLabel")({
				Size = UDim2.new(1, -10, 0.13, 0),
				Position = UDim2.new(0.5, 0, 0.84, 0),
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,
				Text = function()
					if inTransit() then
						return "A thief has it!"
					elseif following() then
						return "✔ FOLLOWING (tap to stop)"
					end
					return "EQUIP"
				end,
				TextScaled = true,
				TextColor3 = function()
					return if following() then Theme.color.green else Theme.color.white
				end,
				FontFace = Theme.font.title,
				Components.textStroke(2),
			}),
		}),
	})
end

local function companionPage(): Instance
	return create("ScrollingFrame")({
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ScrollBarThickness = 8,
		VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		create("UIGridLayout")({
			CellSize = UDim2.new(0.25, -10, 0, 160),
			CellPadding = UDim2.fromOffset(10, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
			create("UIAspectRatioConstraint")({ AspectRatio = 1.05 }),
		}),
		Components.padding(6),
		create("TextLabel")({
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Visible = function()
				return #companionIds() == 0
			end,
			Text = "Buy a critter from the train, then pick one here to follow you around.",
			TextScaled = true,
			TextColor3 = Theme.color.white,
			FontFace = Theme.font.heading,
			Components.textStroke(2),
			create("UITextSizeConstraint")({ MaxTextSize = 26 }),
		}),
		values(companionIds, companionCard),
	})
end

function Wardrobe.menu(onClose: () -> ()): Instance
	local tab = source("companion")
	local tabs = {}
	for i, slot in SLOTS do
		table.insert(
			tabs,
			Components.button({
				text = slot.label,
				color = function()
					return if tab() == slot.id then Theme.color.purple else Theme.color.wood
				end,
				size = UDim2.new(1 / #SLOTS, -8, 1, 0),
				layoutOrder = i,
				textSize = 22,
				onClick = function()
					Sound.play("click")
					tab(slot.id)
				end,
			})
		)
	end
	local pages = {}
	for _, slot in SLOTS do
		table.insert(
			pages,
			show(function()
				return tab() == slot.id
			end, function()
				if slot.id == "companion" then
					return companionPage()
				end
				local cards = {}
				local n = 0
				for _, cosmetic in Cosmetics.list do
					if cosmetic.slot == slot.id then
						n += 1
						table.insert(cards, itemCard(cosmetic, n))
					end
				end
				return create("ScrollingFrame")({
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					ScrollBarThickness = 8,
					VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
					AutomaticCanvasSize = Enum.AutomaticSize.Y,
					CanvasSize = UDim2.new(),
					create("UIGridLayout")({
						CellSize = UDim2.new(0.25, -10, 0, 160),
						CellPadding = UDim2.fromOffset(10, 10),
						SortOrder = Enum.SortOrder.LayoutOrder,
						create("UIAspectRatioConstraint")({ AspectRatio = 1.05 }),
					}),
					Components.padding(6),
					cards :: any,
				})
			end)
		)
	end
	return Components.panel({
		title = "WARDROBE",
		accent = Theme.color.purple,
		size = UDim2.fromScale(0.7, 0.78),
		onClose = onClose,
		children = {
			create("Frame")({
				Size = UDim2.new(1, 0, 0, 44),
				BackgroundTransparency = 1,
				create("UIListLayout")({
					FillDirection = Enum.FillDirection.Horizontal,
					Padding = UDim.new(0, 8),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				tabs :: any,
			}),
			create("Frame")({
				Size = UDim2.new(1, 0, 1, -56),
				Position = UDim2.fromOffset(0, 56),
				BackgroundTransparency = 1,
				pages :: any,
			}),
		},
	})
end

return Wardrobe
