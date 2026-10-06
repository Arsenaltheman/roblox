--!strict
-- Sprint HUD: a SPRINT button for touch players (bottom right, left of the jump button and below
-- the big action button, clear of the hotbar) and a small stamina bar that fades out when full.
-- Hold it to sprint, or tap it to latch sprint on until you stop or run dry (Movement handles both).
-- Keyboard/gamepad players get just the bar, above the hotbar.

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Vide = require("@game/ReplicatedStorage/Packages/Vide")
local Stamina = require("@game/ReplicatedStorage/Shared/Sim/Stamina")
local Movement = require("../Controllers/Movement")
local Store = require("../Store")
local Components = require("./Components")
local Theme = require("./Theme")

local create = Vide.create :: any
local source = Vide.source
local spring = Vide.spring
local action = Vide.action :: any
local cleanup = Vide.cleanup

local SprintButton = {}

local SIZE = 92

local function isTouch(): boolean
	local last = UserInputService:GetLastInputType()
	return last == Enum.UserInputType.Touch
		or (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled)
end

local function barColor(value: number): Color3
	if value < Stamina.MIN_START then
		return Theme.color.red
	elseif value < 0.4 then
		return Theme.color.orange
	end
	return Theme.color.cash
end

-- The stamina bar; `width` px wide.
local function bar(width: number, position: UDim2): Instance
	-- Fully hidden when the bar is full and you're not sprinting.
	local shown = spring(function()
		return if Store.stamina() < 0.999 or Store.sprinting() then 1 else 0
	end, 0.35, 1)
	local fade = function()
		return 1 - math.clamp(shown(), 0, 1)
	end
	return create("Frame")({
		Name = "StaminaBar",
		Size = UDim2.fromOffset(width, 14),
		Position = position,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.color.ink,
		BackgroundTransparency = function()
			return 0.15 + 0.85 * fade()
		end,
		Components.corner(UDim.new(1, 0)),
		create("UIStroke")({
			Thickness = 2.5,
			Color = Theme.color.ink,
			Transparency = fade,
		}),
		create("Frame")({
			Name = "Fill",
			Size = function()
				return UDim2.new(math.clamp(Store.stamina(), 0, 1), -4, 1, -4)
			end,
			Position = UDim2.fromOffset(2, 2),
			BackgroundColor3 = function()
				return barColor(Store.stamina())
			end,
			BackgroundTransparency = fade,
			BorderSizePixel = 0,
			Components.corner(UDim.new(1, 0)),
		}),
	})
end

function SprintButton.build(): Instance
	local touch = source(isTouch())
	local conn = UserInputService.LastInputTypeChanged:Connect(function()
		touch(isTouch())
	end)

	local function button(): Instance
		local scale: UIScale? = nil
		local function squash(down: boolean)
			if scale then
				TweenService:Create(
					scale,
					TweenInfo.new(
						if down then 0.08 else 0.35,
						if down then Enum.EasingStyle.Quad else Enum.EasingStyle.Back,
						Enum.EasingDirection.Out
					),
					{ Scale = if down then 0.86 else 1 }
				):Play()
			end
		end
		return create("TextButton")({
			Name = "Sprint",
			Size = UDim2.fromOffset(SIZE, SIZE),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			Text = "",
			Visible = touch,
			create("Frame")({
				Name = "Face",
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Color3.new(1, 1, 1),
				ClipsDescendants = true,
				Components.corner(UDim.new(1, 0)),
				Components.stroke(3.5),
				Components.gradient(function()
					return if Store.sprinting() then Theme.color.orange else Theme.color.wood
				end),
				Components.gloss(UDim.new(1, 0)),
				create("TextLabel")({
					Size = UDim2.fromScale(0.62, 0.42),
					Position = UDim2.fromScale(0.5, 0.42),
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Text = ">>",
					TextScaled = true,
					TextColor3 = Theme.color.white,
					FontFace = Theme.font.title,
					ZIndex = 3,
					Components.textStroke(3),
				}),
				create("TextLabel")({
					Size = UDim2.fromScale(0.8, 0.2),
					Position = UDim2.fromScale(0.5, 0.74),
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Text = "SPRINT",
					TextScaled = true,
					TextColor3 = Theme.color.white,
					FontFace = Theme.font.title,
					ZIndex = 3,
					Components.textStroke(2),
				}),
			}),
			action(function(instance: Instance)
				local gui = instance :: TextButton
				local s = Instance.new("UIScale")
				s.Parent = gui
				scale = s
				-- Track the exact touch that pressed us: the finger may slide off the button before
				-- lifting, and the release must still count.
				local activeInput: InputObject? = nil
				local connections = {
					gui.InputBegan:Connect(function(input)
						local kind = input.UserInputType
						if
							activeInput == nil
							and (kind == Enum.UserInputType.Touch or kind == Enum.UserInputType.MouseButton1)
						then
							activeInput = input
							squash(true)
							Movement.press("touch")
						end
					end),
					UserInputService.InputEnded:Connect(function(input)
						if input == activeInput then
							activeInput = nil
							squash(false)
							Movement.release("touch")
						end
					end),
				}
				cleanup(function()
					for _, c in connections do
						c:Disconnect()
					end
				end)
			end),
			Components.popIn(0.1),
		})
	end

	return create("Frame")({
		Name = "SprintHud",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		-- Touch: button left of the jump button and under the action button; bar on top of it.
		create("Frame")({
			Name = "Touch",
			Size = UDim2.fromOffset(SIZE, SIZE),
			Position = UDim2.new(1, -300, 1, -84),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Visible = touch,
			button(),
			bar(SIZE, UDim2.new(0.5, 0, 0, -14)),
		}),
		-- Keyboard / gamepad: just the bar, centred above the hotbar.
		create("Frame")({
			Name = "Desktop",
			Size = UDim2.fromOffset(200, 14),
			Position = UDim2.new(0.5, 0, 1, -112),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Visible = function()
				return not touch()
			end,
			bar(200, UDim2.fromScale(0.5, 0.5)),
		}),
		action(function()
			cleanup(function()
				conn:Disconnect()
			end)
		end),
	})
end

return SprintButton
