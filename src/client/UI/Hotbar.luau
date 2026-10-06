--!strict
-- Gear hotbar (bottom centre): one chunky button per gear item you own, with its key (1/2/3), a
-- cooldown sweep and seconds left. Tap it or press the key to use it.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Vide = require("@game/ReplicatedStorage/Packages/Vide")
local GearConfig = require("@game/ReplicatedStorage/Shared/Config/Gear")
local Net = require("@game/ReplicatedStorage/Shared/Net/Net")
local Sound = require("../Controllers/Sound")
local Components = require("./Components")
local Theme = require("./Theme")

local create = Vide.create :: any
local source = Vide.source
local action = Vide.action :: any
local cleanup = Vide.cleanup

local localPlayer = Players.LocalPlayer

local Hotbar = {}

local KEY_LABEL: { [string]: string } = { One = "1", Two = "2", Three = "3" }
local COLOR: { [string]: Color3 } = {
	SmokeBomb = Color3.fromRGB(120, 130, 150),
	TumbleweedBomb = Theme.color.orange,
	BearTrap = Theme.color.red,
}

local function use(key: string)
	local readyAt = (localPlayer:GetAttribute("GearReady_" .. key) :: number?) or 0
	if Workspace:GetServerTimeNow() < readyAt then
		Sound.play("click")
		return
	end
	Net.request("UseGear", key)
end

function Hotbar.build(): Instance
	local now = source(Workspace:GetServerTimeNow())
	local tick = source(0)
	local conn = localPlayer.AttributeChanged:Connect(function()
		tick(tick() + 1)
	end)

	local buttons = {}
	for i, gear in GearConfig.list do
		local owned = function()
			tick()
			return localPlayer:GetAttribute("Gear_" .. gear.key) == true
		end
		local left = function()
			tick()
			local readyAt = (localPlayer:GetAttribute("GearReady_" .. gear.key) :: number?) or 0
			return math.max(0, readyAt - now())
		end
		table.insert(
			buttons,
			create("TextButton")({
				Name = gear.key,
				LayoutOrder = i,
				Size = UDim2.fromOffset(74, 74),
				BackgroundTransparency = 1,
				AutoButtonColor = false,
				Text = "",
				Visible = owned,
				Activated = function()
					use(gear.key)
				end,
				create("Frame")({
					Size = UDim2.fromScale(1, 1),
					BackgroundColor3 = Color3.new(1, 1, 1),
					ClipsDescendants = true,
					Components.corner(UDim.new(0, 16)),
					Components.stroke(3.5),
					Components.gradient(COLOR[gear.key] or Theme.color.orange),
					Components.gloss(UDim.new(0, 16)),
					create("Frame")({
						Size = UDim2.fromScale(0.8, 0.8),
						Position = UDim2.fromScale(0.5, 0.48),
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						ZIndex = 3,
						Components.icon(gear.icon, gear.glyph, Theme.color.white),
					}),
					-- Cooldown: a dark shade that drains from the top.
					create("Frame")({
						Name = "Cooldown",
						AnchorPoint = Vector2.new(0, 1),
						Position = UDim2.fromScale(0, 1),
						Size = function()
							return UDim2.fromScale(1, math.clamp(left() / gear.cooldown, 0, 1))
						end,
						BackgroundColor3 = Color3.new(0, 0, 0),
						BackgroundTransparency = 0.45,
						BorderSizePixel = 0,
						ZIndex = 4,
					}),
					create("TextLabel")({
						Size = UDim2.fromScale(0.7, 0.5),
						Position = UDim2.fromScale(0.5, 0.5),
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						Text = function()
							local l = left()
							return if l > 0 then tostring(math.ceil(l)) else ""
						end,
						TextScaled = true,
						TextColor3 = Theme.color.white,
						FontFace = Theme.font.title,
						ZIndex = 5,
						Components.textStroke(3),
					}),
				}),
				-- Key hint.
				create("TextLabel")({
					Size = UDim2.fromOffset(26, 26),
					Position = UDim2.new(0, -6, 0, -6),
					BackgroundColor3 = Theme.color.ink,
					Text = KEY_LABEL[gear.keybind] or "",
					TextScaled = true,
					TextColor3 = Theme.color.white,
					FontFace = Theme.font.title,
					ZIndex = 6,
					Components.corner(UDim.new(1, 0)),
					Components.stroke(2),
					Components.padding(3),
				}),
				Components.popIn(i * 0.05),
			})
		)
	end

	return create("Frame")({
		Name = "Hotbar",
		Size = UDim2.fromOffset(260, 80),
		Position = UDim2.new(0.5, 0, 1, -18),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			Padding = UDim.new(0, 12),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		buttons :: any,
		action(function()
			local alive = true
			task.spawn(function()
				while alive do
					now(Workspace:GetServerTimeNow())
					task.wait(0.1)
				end
			end)
			for _, gear in GearConfig.list do
				ContextActionService:BindAction("Gear_" .. gear.key, function(_, inputState)
					if inputState == Enum.UserInputState.Begin then
						use(gear.key)
					end
					return Enum.ContextActionResult.Pass
				end, false, (Enum.KeyCode :: any)[gear.keybind])
			end
			cleanup(function()
				alive = false
				conn:Disconnect()
				for _, gear in GearConfig.list do
					ContextActionService:UnbindAction("Gear_" .. gear.key)
				end
			end)
		end),
	})
end

return Hotbar
