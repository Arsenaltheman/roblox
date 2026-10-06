--!strict
-- The Starter Pack offer: shown once per session at a calm moment (tutorial done, no menu open,
-- nothing lost in the last two minutes), never again once it's claimed. One card, one picture,
-- a plain "View Item" button: Roblox shows the real price. Honest copy, no timers.

local Players = game:GetService("Players")

local Vide = require("@game/ReplicatedStorage/Packages/Vide")
local Products = require("@game/ReplicatedStorage/Shared/Config/Products")
local Net = require("@game/ReplicatedStorage/Shared/Net/Net")
local Sound = require("../Controllers/Sound")
local Store = require("../Store")
local Components = require("./Components")
local Theme = require("./Theme")

local create = Vide.create :: any

local localPlayer = Players.LocalPlayer

local Offer = {}

local shownThisSession = false

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

-- Opens the offer when the moment is right. Called from a slow client loop.
function Offer.maybeShow()
	if shownThisSession then
		return
	end
	local s = Store.state()
	if not s or (s.tutorial or 0) < 3 or s.starterPack or Store.menu() ~= "" or s.mayPrompt == false then
		return
	end
	local p = s.pending
	if p and ((p.offline or 0) > 0 or p.streakSlot ~= nil) then
		return -- the welcome panel goes first
	end
	if localPlayer:GetAttribute("HeistCarry") == true then
		return
	end
	shownThisSession = true
	Store.menu("offer")
end

function Offer.panel(onClose: () -> ()): Instance
	local product = Products.byKey.StarterPack
	return Components.panel({
		title = "STARTER PACK",
		accent = Theme.color.pink,
		mascot = "DeputyDuck",
		size = UDim2.fromScale(0.52, 0.6),
		onClose = onClose,
		children = {
			create("Frame")({
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				text({
					Size = UDim2.new(1, 0, 0, 40),
					FontFace = Theme.font.title,
					TextColor3 = Theme.color.white,
					Text = "DEPUTY DUCK + 30 MIN 2x CASH + STARTER STETSON",
					Components.goldText(),
					Components.textStroke(3),
				}),
				text({
					Size = UDim2.new(1, 0, 0, 70),
					Position = UDim2.fromOffset(0, 48),
					FontFace = Theme.font.heading,
					TextWrapped = true,
					TextScaled = false,
					TextSize = 22,
					TextColor3 = Theme.darken(Theme.color.wood, 0.3),
					Text = "Deputy Duck is BRANDED: nobody can steal him, and he stays with you through every Frontier. "
						.. (product and product.description or ""),
				}),
				text({
					Size = UDim2.new(1, 0, 0, 24),
					Position = UDim2.new(0, 0, 1, -94),
					FontFace = Theme.font.body,
					TextColor3 = Theme.darken(Theme.color.wood, 0.2),
					Text = "One-time pack. Nothing random. Also in the Shop any time.",
				}),
				Components.button({
					text = "View Item",
					color = Theme.color.green,
					size = UDim2.new(0.6, 0, 0, 60),
					position = UDim2.new(0.5, 0, 1, -4),
					anchor = Vector2.new(0.5, 1),
					textSize = 30,
					shine = true,
					onClick = function()
						Sound.play("buy")
						Net.request("ShopBuy", "StarterPack", 1)
						onClose()
					end,
				}),
			}),
		},
	})
end

return Offer
