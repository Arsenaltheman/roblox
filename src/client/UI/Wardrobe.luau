--!strict
-- Wardrobe: equip the cosmetics you own (titles, hats, lasso trails, WANTED posters, ranch themes).
-- Locked ones show how to get them. Everyone sees what you wear (Controllers/Looks).

local Players = game:GetService("Players")

local Vide = require("@game/ReplicatedStorage/Packages/Vide")
local Cosmetics = require("@game/ReplicatedStorage/Shared/Config/Cosmetics")
local Net = require("@game/ReplicatedStorage/Shared/Net/Net")
local Sound = require("../Controllers/Sound")
local Store = require("../Store")
local Components = require("./Components")
local Theme = require("./Theme")

local create = Vide.create :: any
local show = Vide.show :: any
local source = Vide.source

local localPlayer = Players.LocalPlayer

local Wardrobe = {}

local SLOTS = {
	{ id = "title", label = "TITLES", icon = "crown", glyph = "♛" },
	{ id = "hat", label = "HATS", icon = "sheriffstar", glyph = "▲" },
	{ id = "lassoTrail", label = "LASSOS", icon = "lasso", glyph = "◎" },
	{ id = "poster", label = "POSTERS", icon = "scroll", glyph = "▤" },
	{ id = "ranchTheme", label = "RANCH", icon = "barn", glyph = "⌂" },
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
	elseif string.sub(cosmetic.id, 1, 6) == "title_" then
		return "Earned on the Bounty Trail"
	elseif cosmetic.id == "hat_premium" then
		return "Roblox Premium members"
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

function Wardrobe.menu(onClose: () -> ()): Instance
	local tab = source("title")
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
