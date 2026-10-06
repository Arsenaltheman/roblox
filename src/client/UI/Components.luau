--!strict
-- Reusable UI pieces with the game's chunky style: thick outline, top-lit gradient, drop shadow,
-- bouncy press feedback and an optional shine sweep.

local TweenService = game:GetService("TweenService")

local Vide = require("@game/ReplicatedStorage/Packages/Vide")
local Theme = require("./Theme")

local create = Vide.create :: any
local action = Vide.action
local cleanup = Vide.cleanup

local Components = {}

type Child = any

function Components.corner(radius: UDim?): Instance
	return create("UICorner")({ CornerRadius = radius or Theme.corner })
end

function Components.stroke(thickness: number?, color: Color3?): Instance
	return create("UIStroke")({
		Thickness = thickness or Theme.stroke,
		Color = color or Theme.color.ink,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
	})
end

function Components.textStroke(thickness: number?): Instance
	return create("UIStroke")({
		Thickness = thickness or 2,
		Color = Theme.color.ink,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		LineJoinMode = Enum.LineJoinMode.Round,
	})
end

-- Top-lit vertical gradient from a base color.
function Components.gradient(base: Color3): Instance
	return create("UIGradient")({
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Theme.lighten(base, 0.28)),
			ColorSequenceKeypoint.new(0.55, base),
			ColorSequenceKeypoint.new(1, Theme.darken(base, 0.18)),
		}),
	})
end

function Components.padding(px: number): Instance
	local u = UDim.new(0, px)
	return create("UIPadding")({ PaddingTop = u, PaddingBottom = u, PaddingLeft = u, PaddingRight = u })
end

function Components.aspect(ratio: number): Instance
	return create("UIAspectRatioConstraint")({ AspectRatio = ratio })
end

-- A looping diagonal shine sweep (for important buttons).
function Components.shine(): Child
	return action(function(instance: Instance)
		local gradient = Instance.new("UIGradient")
		gradient.Rotation = 20
		gradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.45, 1),
			NumberSequenceKeypoint.new(0.5, 0.55),
			NumberSequenceKeypoint.new(0.55, 1),
			NumberSequenceKeypoint.new(1, 1),
		})
		local overlay = Instance.new("Frame")
		overlay.Name = "Shine"
		overlay.Size = UDim2.fromScale(1, 1)
		overlay.BackgroundColor3 = Color3.new(1, 1, 1)
		overlay.BackgroundTransparency = 0
		overlay.ZIndex = 5
		local corner = Instance.new("UICorner")
		corner.CornerRadius = Theme.corner
		corner.Parent = overlay
		gradient.Parent = overlay
		overlay.Parent = instance
		local running = true
		task.spawn(function()
			while running and overlay.Parent do
				gradient.Offset = Vector2.new(-1, 0)
				local tween = TweenService:Create(gradient, TweenInfo.new(0.9, Enum.EasingStyle.Quad), { Offset = Vector2.new(1, 0) })
				tween:Play()
				task.wait(2.6)
			end
		end)
		cleanup(function()
			running = false
		end)
	end)
end

-- Bouncy press: scales down on press, springs back with overshoot.
local function pressFeedback(): Child
	return action(function(instance: Instance)
		local scale = Instance.new("UIScale")
		scale.Parent = instance
		local button = instance :: GuiButton
		local down = button.MouseButton1Down:Connect(function()
			TweenService:Create(scale, TweenInfo.new(0.08, Enum.EasingStyle.Quad), { Scale = 0.9 }):Play()
		end)
		local up = button.MouseButton1Up:Connect(function()
			TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end)
		local leave = button.MouseLeave:Connect(function()
			TweenService:Create(scale, TweenInfo.new(0.2), { Scale = 1 }):Play()
		end)
		cleanup(function()
			down:Disconnect()
			up:Disconnect()
			leave:Disconnect()
		end)
	end)
end

export type ButtonProps = {
	text: string | () -> string,
	color: (Color3 | () -> Color3)?,
	size: UDim2?,
	position: UDim2?,
	anchor: Vector2?,
	textSize: number?,
	shine: boolean?,
	onClick: () -> (),
	visible: (boolean | () -> boolean)?,
	layoutOrder: number?,
	children: { Child }?,
	name: string?,
}

function Components.button(props: ButtonProps): Instance
	local color = props.color or Theme.color.green
	return create("TextButton")({
		Name = props.name or "Button",
		Size = props.size or UDim2.fromOffset(160, 56),
		Position = props.position,
		AnchorPoint = props.anchor,
		BackgroundColor3 = Color3.new(1, 1, 1),
		AutoButtonColor = false,
		Text = props.text,
		TextColor3 = Theme.color.white,
		FontFace = Theme.font.title,
		TextScaled = true,
		Visible = props.visible,
		LayoutOrder = props.layoutOrder,
		Activated = props.onClick,

		create("UITextSizeConstraint")({ MaxTextSize = props.textSize or 30, MinTextSize = 9 }),
		Components.corner(),
		Components.stroke(),
		Components.textStroke(2.5),
		Components.padding(6),
		action(function(instance: Instance)
			-- The gradient follows the (possibly reactive) color.
			local gradient = Instance.new("UIGradient")
			gradient.Rotation = 90
			gradient.Parent = instance
			Vide.effect(function()
				local base = if type(color) == "function" then color() else color
				gradient.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Theme.lighten(base, 0.3)),
					ColorSequenceKeypoint.new(0.55, base),
					ColorSequenceKeypoint.new(1, Theme.darken(base, 0.2)),
				})
			end)
		end),
		pressFeedback(),
		if props.shine then Components.shine() else nil,
		props.children,
	})
end

-- A rounded "pill" showing an icon glyph and a value (cash, nuggets...).
function Components.pill(props: {
	icon: string,
	iconColor: Color3,
	text: () -> string,
	sub: (() -> string)?,
	size: UDim2?,
	position: UDim2?,
	anchor: Vector2?,
	layoutOrder: number?,
}): Instance
	return create("Frame")({
		Name = "Pill",
		Size = props.size or UDim2.fromOffset(210, 50),
		Position = props.position,
		AnchorPoint = props.anchor,
		BackgroundColor3 = Theme.color.paper,
		LayoutOrder = props.layoutOrder,
		Components.corner(UDim.new(1, 0)),
		Components.stroke(3),
		Components.gradient(Theme.color.paper),
		create("TextLabel")({
			Name = "Icon",
			Size = UDim2.new(0, 46, 0, 46),
			Position = UDim2.new(0, -6, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundColor3 = props.iconColor,
			Text = props.icon,
			TextColor3 = Theme.color.white,
			FontFace = Theme.font.title,
			TextScaled = true,
			Components.corner(UDim.new(1, 0)),
			Components.stroke(3),
			Components.textStroke(2),
			Components.padding(7),
		}),
		create("TextLabel")({
			Name = "Value",
			Size = UDim2.new(1, -56, if props.sub then 0.62 else 1, 0),
			Position = UDim2.new(0, 48, 0, 0),
			BackgroundTransparency = 1,
			Text = props.text,
			TextColor3 = Theme.color.ink,
			FontFace = Theme.font.number,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			create("UITextSizeConstraint")({ MaxTextSize = 30, MinTextSize = 9 }),
		}),
		if props.sub
			then create("TextLabel")({
				Name = "Sub",
				Size = UDim2.new(1, -56, 0.38, -4),
				Position = UDim2.new(0, 48, 0.62, 0),
				BackgroundTransparency = 1,
				Text = props.sub,
				TextColor3 = Theme.darken(Theme.color.cash, 0.35),
				FontFace = Theme.font.number,
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
			})
			else nil,
	})
end

-- A wanted-poster style panel with a title and a close button.
function Components.panel(props: {
	title: string | () -> string,
	size: UDim2?,
	onClose: () -> (),
	children: { Child },
	accent: Color3?,
}): Instance
	local accent = props.accent or Theme.color.red
	return create("Frame")({
		Name = "Panel",
		Size = props.size or UDim2.fromScale(0.62, 0.72),
		Position = UDim2.fromScale(0.5, 0.52),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.color.paper,
		create("UISizeConstraint")({ MaxSize = Vector2.new(820, 600), MinSize = Vector2.new(300, 240) }),
		Components.corner(UDim.new(0, 18)),
		Components.stroke(4),
		Components.gradient(Theme.color.paper),
		create("TextLabel")({
			Name = "Title",
			Size = UDim2.new(0.7, 0, 0, 52),
			Position = UDim2.new(0.5, 0, 0, -26),
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundColor3 = accent,
			Text = props.title,
			TextColor3 = Theme.color.white,
			FontFace = Theme.font.title,
			TextScaled = true,
			ZIndex = 3,
			Components.corner(UDim.new(0, 12)),
			Components.stroke(4),
			Components.textStroke(3),
			Components.gradient(accent),
			Components.padding(8),
		}),
		Components.button({
			name = "Close",
			text = "X",
			color = Theme.color.red,
			size = UDim2.fromOffset(48, 48),
			position = UDim2.new(1, 14, 0, -14),
			anchor = Vector2.new(1, 0),
			onClick = props.onClose,
		}),
		create("Frame")({
			Name = "Body",
			Size = UDim2.new(1, -28, 1, -54),
			Position = UDim2.new(0, 14, 0, 40),
			BackgroundTransparency = 1,
			props.children,
		}),
	})
end

return Components
