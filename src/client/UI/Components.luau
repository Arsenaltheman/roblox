--!strict
-- Reusable UI pieces with the game's chunky style. Buttons are "3D": a coloured face sitting on a
-- darker base that it sinks into when pressed, with a gloss highlight, white text with a thick ink
-- outline, a hover pop and an optional shine sweep. Panels pop open over a dimmed screen.

local TweenService = game:GetService("TweenService")

local Vide = require("@game/ReplicatedStorage/Packages/Vide")
local Theme = require("./Theme")

local create = Vide.create :: any
local action = Vide.action
local cleanup = Vide.cleanup

local Components = {}

type Child = any
type ColorProp = Color3 | () -> Color3

local function read(color: ColorProp): Color3
	return if type(color) == "function" then color() else color
end

local function tween(
	instance: Instance,
	time: number,
	goal: { [string]: any },
	style: Enum.EasingStyle?,
	dir: Enum.EasingDirection?
)
	TweenService:Create(
		instance,
		TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out),
		goal
	):Play()
end

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

-- Top-lit vertical gradient from a base colour. Only put this on frames without their own text:
-- a UIGradient tints an object's text too.
function Components.gradient(base: ColorProp): Instance
	return create("UIGradient")({
		Rotation = 90,
		Color = function()
			local c = read(base)
			return ColorSequence.new({
				ColorSequenceKeypoint.new(0, Theme.lighten(c, 0.32)),
				ColorSequenceKeypoint.new(0.5, c),
				ColorSequenceKeypoint.new(1, Theme.darken(c, 0.16)),
			})
		end,
	})
end

function Components.padding(px: number): Instance
	local u = UDim.new(0, px)
	return create("UIPadding")({ PaddingTop = u, PaddingBottom = u, PaddingLeft = u, PaddingRight = u })
end

function Components.aspect(ratio: number): Instance
	return create("UIAspectRatioConstraint")({ AspectRatio = ratio })
end

-- Glossy highlight across the top half of a face.
function Components.gloss(radius: UDim?): Instance
	return create("Frame")({
		Name = "Gloss",
		Size = UDim2.new(1, -8, 0.46, 0),
		Position = UDim2.new(0.5, 0, 0, 4),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.72,
		ZIndex = 2,
		Components.corner(radius),
		create("UIGradient")({
			Rotation = 90,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.1),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}),
	})
end

-- A looping diagonal shine sweep (for important buttons).
function Components.shine(radius: UDim?): Child
	return action(function(instance: Instance)
		local overlay = Instance.new("Frame")
		overlay.Name = "Shine"
		overlay.Size = UDim2.fromScale(1, 1)
		overlay.BackgroundColor3 = Color3.new(1, 1, 1)
		overlay.ZIndex = 3
		local corner = Instance.new("UICorner")
		corner.CornerRadius = radius or Theme.corner
		corner.Parent = overlay
		local gradient = Instance.new("UIGradient")
		gradient.Rotation = 20
		gradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.42, 1),
			NumberSequenceKeypoint.new(0.5, 0.45),
			NumberSequenceKeypoint.new(0.58, 1),
			NumberSequenceKeypoint.new(1, 1),
		})
		gradient.Parent = overlay
		overlay.Parent = instance
		local running = true
		task.spawn(function()
			while running and overlay.Parent do
				gradient.Offset = Vector2.new(-1, 0)
				tween(gradient, 0.8, { Offset = Vector2.new(1, 0) })
				task.wait(2.4)
			end
		end)
		cleanup(function()
			running = false
		end)
	end)
end

-- Pops in from small with an overshoot when created.
function Components.popIn(delay: number?): Child
	return action(function(instance: Instance)
		local scale = Instance.new("UIScale")
		scale.Scale = 0.2
		scale.Parent = instance
		task.delay(delay or 0, function()
			tween(scale, 0.42, { Scale = 1 }, Enum.EasingStyle.Back)
		end)
	end)
end

-- Gentle idle bob/wiggle so important buttons feel alive.
function Components.idle(amplitude: number?, period: number?): Child
	return action(function(instance: Instance)
		local rotation = amplitude or 4
		local alive = true
		task.spawn(function()
			local gui = instance :: GuiObject
			while alive and gui.Parent do
				tween(
					gui,
					(period or 1.6) / 2,
					{ Rotation = rotation },
					Enum.EasingStyle.Sine,
					Enum.EasingDirection.InOut
				)
				task.wait((period or 1.6) / 2)
				tween(
					gui,
					(period or 1.6) / 2,
					{ Rotation = -rotation },
					Enum.EasingStyle.Sine,
					Enum.EasingDirection.InOut
				)
				task.wait((period or 1.6) / 2)
			end
		end)
		cleanup(function()
			alive = false
		end)
	end)
end

-- Builds the 3D face + base inside a button-ish GuiObject and wires hover/press animation.
-- `depth` is how far (px) the face sits above its base.
local function faceAndBase(color: ColorProp, radius: UDim, depth: number, shine: boolean?): Child
	return {
		create("Frame")({
			Name = "Base",
			Size = UDim2.new(1, 0, 1, 0),
			Position = UDim2.fromOffset(0, depth),
			BackgroundColor3 = function()
				return Theme.darken(read(color), 0.45)
			end,
			ZIndex = 0,
			create("UICorner")({ CornerRadius = radius }),
			Components.stroke(3),
		}),
		create("Frame")({
			Name = "Face",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(1, 1, 1),
			ZIndex = 1,
			create("UICorner")({ CornerRadius = radius }),
			Components.stroke(3),
			Components.gradient(color),
			Components.gloss(radius),
			if shine then Components.shine(radius) else nil,
		}),
	}
end

-- Hover pop + press sink for a GuiButton that has Face/Base children from faceAndBase.
local function pressFeedback(depth: number): Child
	return action(function(instance: Instance)
		local button = instance :: GuiButton
		local scale = Instance.new("UIScale")
		scale.Parent = button
		local function face(): GuiObject?
			return button:FindFirstChild("Face") :: GuiObject?
		end
		local function content(): GuiObject?
			return button:FindFirstChild("Content") :: GuiObject?
		end
		local function sink(down: boolean)
			local offset = if down then UDim2.fromOffset(0, depth - 1) else UDim2.fromOffset(0, 0)
			local f, c = face(), content()
			if f then
				tween(f, 0.07, { Position = offset })
			end
			if c then
				tween(c, 0.07, { Position = offset })
			end
		end
		local connections = {
			button.MouseEnter:Connect(function()
				tween(scale, 0.18, { Scale = 1.06 }, Enum.EasingStyle.Back)
			end),
			button.MouseLeave:Connect(function()
				tween(scale, 0.2, { Scale = 1 })
				sink(false)
			end),
			button.MouseButton1Down:Connect(function()
				sink(true)
				tween(scale, 0.07, { Scale = 0.94 })
			end),
			button.MouseButton1Up:Connect(function()
				sink(false)
				tween(scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
			end),
		}
		cleanup(function()
			for _, c in connections do
				c:Disconnect()
			end
		end)
	end)
end

export type ButtonProps = {
	text: string | () -> string,
	color: ColorProp?,
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
	icon: string?,
	pulse: boolean?,
}

function Components.button(props: ButtonProps): Instance
	local color: ColorProp = props.color or Theme.color.green
	local radius = UDim.new(0, 14)
	local depth = 5
	return create("TextButton")({
		Name = props.name or "Button",
		Size = props.size or UDim2.fromOffset(160, 56),
		Position = props.position,
		AnchorPoint = props.anchor,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		Visible = props.visible,
		LayoutOrder = props.layoutOrder,
		Activated = props.onClick,

		faceAndBase(color, radius, depth, props.shine),
		create("Frame")({
			Name = "Content",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ZIndex = 4,
			create("TextLabel")({
				Name = "Label",
				Size = UDim2.new(1, -14, 1, -10),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Text = if props.icon
					then function()
						local t = if type(props.text) == "function" then props.text() else props.text
						return `{props.icon} {t}`
					end
					else props.text,
				TextColor3 = Theme.color.white,
				FontFace = Theme.font.title,
				TextScaled = true,
				ZIndex = 4,
				create("UITextSizeConstraint")({ MaxTextSize = props.textSize or 30, MinTextSize = 9 }),
				Components.textStroke(3),
			}),
		}),
		pressFeedback(depth),
		if props.pulse then Components.idle(2.5, 1.2) else nil,
		props.children,
	})
end

-- Square icon tile button (side menu): big glyph, label under it, optional red count badge.
function Components.tile(props: {
	glyph: string,
	label: string,
	color: ColorProp,
	onClick: () -> (),
	layoutOrder: number?,
	visible: (() -> boolean)?,
	badge: (() -> number)?,
	size: number?,
}): Instance
	local radius = UDim.new(0, 18)
	local depth = 5
	local px = props.size or 78
	return create("TextButton")({
		Name = props.label,
		Size = UDim2.fromOffset(px, px),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		LayoutOrder = props.layoutOrder,
		Visible = props.visible,
		Activated = props.onClick,
		faceAndBase(props.color, radius, depth),
		create("Frame")({
			Name = "Content",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ZIndex = 4,
			create("TextLabel")({
				Size = UDim2.fromScale(0.8, 0.56),
				Position = UDim2.fromScale(0.5, 0.38),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Text = props.glyph,
				TextColor3 = Theme.color.white,
				FontFace = Theme.font.title,
				TextScaled = true,
				ZIndex = 4,
				Components.textStroke(3),
				Components.idle(6, 2.2),
			}),
			create("TextLabel")({
				Size = UDim2.fromScale(0.96, 0.26),
				Position = UDim2.fromScale(0.5, 0.82),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Text = props.label,
				TextColor3 = Theme.color.white,
				FontFace = Theme.font.title,
				TextScaled = true,
				ZIndex = 4,
				Components.textStroke(2),
			}),
		}),
		pressFeedback(depth),
		if props.badge
			then Vide.show(function()
				return (props.badge :: () -> number)() > 0
			end, function()
				return create("TextLabel")({
					Size = UDim2.fromOffset(30, 30),
					Position = UDim2.new(1, 8, 0, -8),
					AnchorPoint = Vector2.new(1, 0),
					BackgroundColor3 = Theme.color.red,
					TextColor3 = Theme.color.white,
					FontFace = Theme.font.number,
					TextScaled = true,
					ZIndex = 6,
					Text = function()
						return tostring((props.badge :: () -> number)())
					end,
					Components.corner(UDim.new(1, 0)),
					Components.stroke(2.5),
					Components.padding(4),
					Components.popIn(),
					Components.idle(10, 0.8),
				})
			end)
			else nil,
	})
end

-- A rounded "pill" showing an icon and a value (cash, nuggets...). The value punches when it changes.
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
		BackgroundTransparency = 1,
		LayoutOrder = props.layoutOrder,
		-- Dark base for depth, then the bright face.
		create("Frame")({
			Name = "Base",
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromOffset(0, 4),
			BackgroundColor3 = Theme.darken(Theme.color.ink, 0.1),
			BackgroundTransparency = 0.35,
			Components.corner(UDim.new(1, 0)),
		}),
		create("Frame")({
			Name = "Face",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(1, 1, 1),
			Components.corner(UDim.new(1, 0)),
			Components.stroke(3),
			Components.gradient(Theme.color.ink:Lerp(Color3.fromRGB(70, 50, 120), 0.6)),
		}),
		create("Frame")({
			Name = "Icon",
			Size = UDim2.new(0, 54, 0, 54),
			Position = UDim2.new(0, -10, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundColor3 = Color3.new(1, 1, 1),
			ZIndex = 3,
			Components.corner(UDim.new(1, 0)),
			Components.stroke(3),
			Components.gradient(props.iconColor),
			Components.gloss(UDim.new(1, 0)),
			create("TextLabel")({
				Size = UDim2.fromScale(0.7, 0.7),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Text = props.icon,
				TextColor3 = Theme.color.white,
				FontFace = Theme.font.title,
				TextScaled = true,
				ZIndex = 4,
				Components.textStroke(2.5),
			}),
		}),
		create("TextLabel")({
			Name = "Value",
			Size = UDim2.new(1, -62, if props.sub then 0.64 else 0.9, 0),
			Position = UDim2.new(0, 52, if props.sub then 0.02 else 0.05, 0),
			BackgroundTransparency = 1,
			Text = props.text,
			TextColor3 = Theme.color.white,
			FontFace = Theme.font.title,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 3,
			create("UITextSizeConstraint")({ MaxTextSize = 32, MinTextSize = 9 }),
			Components.textStroke(2.5),
			-- Punch when the number changes (coins coming in feel good).
			action(function(instance: Instance)
				local label = instance :: TextLabel
				local scale = Instance.new("UIScale")
				scale.Parent = label
				local last = label.Text
				local connection = label:GetPropertyChangedSignal("Text"):Connect(function()
					if label.Text ~= last then
						last = label.Text
						scale.Scale = 1.14
						tween(scale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
					end
				end)
				cleanup(function()
					connection:Disconnect()
				end)
			end),
		}),
		if props.sub
			then create("TextLabel")({
				Name = "Sub",
				Size = UDim2.new(1, -62, 0.34, -4),
				Position = UDim2.new(0, 54, 0.62, 0),
				BackgroundTransparency = 1,
				Text = props.sub,
				TextColor3 = Theme.color.cash,
				FontFace = Theme.font.number,
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 3,
				Components.textStroke(1.5),
			})
			else nil,
	})
end

-- A full-screen overlay: dimmed background (tap to close) and a bright panel that pops open.
function Components.panel(props: {
	title: string | () -> string,
	size: UDim2?,
	onClose: () -> (),
	children: { Child },
	accent: Color3?,
}): Instance
	local accent = props.accent or Theme.color.red
	return create("Frame")({
		Name = "Overlay",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		create("TextButton")({
			Name = "Dim",
			Size = UDim2.fromScale(3, 3),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			Text = "",
			Activated = props.onClose,
			action(function(instance: Instance)
				tween(instance, 0.2, { BackgroundTransparency = 0.45 })
			end),
		}),
		create("Frame")({
			Name = "Panel",
			Size = props.size or UDim2.fromScale(0.62, 0.72),
			Position = UDim2.fromScale(0.5, 0.53),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			create("UISizeConstraint")({ MaxSize = Vector2.new(840, 610), MinSize = Vector2.new(300, 240) }),
			Components.popIn(),
			-- Drop shadow
			create("Frame")({
				Name = "Shadow",
				Size = UDim2.fromScale(1, 1),
				Position = UDim2.fromOffset(0, 10),
				BackgroundColor3 = Color3.new(0, 0, 0),
				BackgroundTransparency = 0.55,
				ZIndex = 0,
				Components.corner(UDim.new(0, 22)),
			}),
			create("Frame")({
				Name = "Paper",
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Color3.new(1, 1, 1),
				ZIndex = 1,
				Components.corner(UDim.new(0, 22)),
				Components.stroke(5),
				Components.gradient(Theme.color.cream),
				-- Coloured header band behind the title.
				create("Frame")({
					Name = "Header",
					Size = UDim2.new(1, 0, 0, 58),
					BackgroundColor3 = Color3.new(1, 1, 1),
					ZIndex = 1,
					Components.corner(UDim.new(0, 22)),
					Components.gradient(Theme.darken(accent, 0.15)),
				}),
			}),
			create("TextLabel")({
				Name = "Title",
				Size = UDim2.new(0.66, 0, 0, 60),
				Position = UDim2.new(0.5, 0, 0, -30),
				AnchorPoint = Vector2.new(0.5, 0),
				Rotation = -2,
				BackgroundColor3 = accent,
				Text = props.title,
				TextColor3 = Theme.color.white,
				FontFace = Theme.font.title,
				TextScaled = true,
				ZIndex = 5,
				Components.corner(UDim.new(0, 14)),
				Components.stroke(4),
				Components.textStroke(3.5),
				Components.padding(9),
				Components.popIn(0.08),
			}),
			Components.button({
				name = "Close",
				text = "X",
				color = Theme.color.red,
				size = UDim2.fromOffset(52, 52),
				position = UDim2.new(1, 16, 0, -16),
				anchor = Vector2.new(1, 0),
				onClick = props.onClose,
			}),
			create("Frame")({
				Name = "Body",
				Size = UDim2.new(1, -32, 1, -84),
				Position = UDim2.new(0, 16, 0, 70),
				BackgroundTransparency = 1,
				ZIndex = 2,
				props.children,
			}),
		}),
	})
end

return Components
