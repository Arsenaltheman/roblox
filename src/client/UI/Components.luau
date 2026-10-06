--!strict
-- Reusable UI pieces with the game's chunky style. Buttons are "3D": a coloured face sitting on a
-- darker base that it sinks into when pressed, with a gloss highlight, white text with a thick ink
-- outline, a hover pop and an optional shine sweep. Panels pop open over a dimmed screen.

local TweenService = game:GetService("TweenService")

local AssetIds = require("@game/ReplicatedStorage/Shared/Config/AssetIds")
local Vide = require("@game/ReplicatedStorage/Packages/Vide")
local CritterRig = require("../Controllers/CritterRig")
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
			while alive do
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
			Components.stripes(radius, 0.07),
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
function Components.tile(
	props: {
		glyph: string,
		label: string,
		color: ColorProp,
		onClick: () -> (),
		image: string?, -- name of an icon in assets/ui (used once uploaded)
		layoutOrder: number?,
		visible: (() -> boolean)?,
		badge: (() -> number)?,
		size: number?,
	}
): Instance
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
			create("Frame")({
				Size = UDim2.fromScale(0.78, 0.6),
				Position = UDim2.fromScale(0.5, 0.37),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				ZIndex = 4,
				Components.icon(props.image or "", props.glyph),
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
	image: string?,
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
			create("Frame")({
				Size = UDim2.fromScale(0.8, 0.8),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				ZIndex = 4,
				Components.icon(props.image or "", props.icon),
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
function Components.panel(
	props: {
		title: string | () -> string,
		size: UDim2?,
		onClose: () -> (),
		children: { Child },
		accent: Color3?,
		mascot: string?, -- species id of a 3D critter peeking over the panel's top-left corner
	}
): Instance
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
			Active = true,
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
					Components.stripes(UDim.new(0, 22), 0.14),
				}),
				Components.stripes(UDim.new(0, 22), 0.05),
			}),
			-- Title ribbon: striped accent banner with big gold gradient lettering and sparkles.
			create("Frame")({
				Name = "Ribbon",
				Size = UDim2.new(0.66, 0, 0, 64),
				Position = UDim2.new(0.5, 0, 0, -32),
				AnchorPoint = Vector2.new(0.5, 0),
				Rotation = -2,
				BackgroundColor3 = Color3.new(1, 1, 1),
				ZIndex = 5,
				Components.corner(UDim.new(0, 16)),
				Components.stroke(4),
				Components.gradient(accent),
				Components.stripes(UDim.new(0, 16), 0.16),
				Components.gloss(UDim.new(0, 16)),
				Components.popIn(0.08),
				create("TextLabel")({
					Name = "Title",
					Size = UDim2.new(1, -24, 1, -12),
					Position = UDim2.fromScale(0.5, 0.5),
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Text = props.title,
					TextColor3 = Color3.new(1, 1, 1),
					FontFace = Theme.font.title,
					TextScaled = true,
					ZIndex = 7,
					Components.goldText(),
					Components.textStroke(4),
				}),
				Components.sparkles(4),
			}),
			if props.mascot
				then Components.mascot({
					species = props.mascot,
					size = UDim2.fromOffset(170, 170),
					position = UDim2.new(0, -40, 0, -50),
					rotation = -10,
				})
				else nil,
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

-- ---------------------------------------------------------------- character & flair

-- Gold-to-orange fill for big headline text (goes on a TextLabel; tints its text).
function Components.goldText(): Instance
	return create("UIGradient")({
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 251, 190)),
			ColorSequenceKeypoint.new(0.45, Color3.fromRGB(255, 214, 60)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 132, 30)),
		}),
	})
end

-- Diagonal candy stripes laid over a frame (a white overlay whose transparency alternates).
function Components.stripes(radius: UDim?, strength: number?): Instance
	local keys = {}
	local n = 9
	local a = 1 - (strength or 0.12)
	for i = 0, n do
		local t = i / n
		table.insert(keys, NumberSequenceKeypoint.new(t, if i % 2 == 0 then a else 1))
		if i < n then
			table.insert(
				keys,
				NumberSequenceKeypoint.new(math.min(1, t + 1 / n - 0.001), if i % 2 == 0 then a else 1)
			)
		end
	end
	return create("Frame")({
		Name = "Stripes",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0,
		ZIndex = 1,
		create("UICorner")({ CornerRadius = radius or Theme.corner }),
		create("UIGradient")({ Rotation = 35, Transparency = NumberSequence.new(keys) }),
	})
end

-- A slowly spinning sunburst of light rays (behind prizes, titles and the wheel).
function Components.sunburst(color: Color3?, rays: number?, size: UDim2?): Instance
	local list = {}
	local count = rays or 12
	for i = 1, count do
		table.insert(
			list,
			create("Frame")({
				Size = UDim2.fromScale(0.16, 1),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Rotation = i * (180 / count),
				BackgroundColor3 = color or Theme.color.gold,
				BorderSizePixel = 0,
				create("UIGradient")({
					Rotation = 90,
					Transparency = NumberSequence.new({
						NumberSequenceKeypoint.new(0, 1),
						NumberSequenceKeypoint.new(0.5, 0.35),
						NumberSequenceKeypoint.new(1, 1),
					}),
				}),
			})
		)
	end
	return create("Frame")({
		Name = "Sunburst",
		Size = size or UDim2.fromScale(1.6, 1.6),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		ZIndex = 0,
		list,
		action(function(instance: Instance)
			local gui = instance :: GuiObject
			local alive = true
			task.spawn(function()
				while alive do
					gui.Rotation = (gui.Rotation + 0.25) % 360
					task.wait()
				end
			end)
			cleanup(function()
				alive = false
			end)
		end),
	})
end

-- Twinkling sparkles scattered over an element.
function Components.sparkles(count: number?, color: Color3?): Instance
	local list = {}
	for i = 1, count or 6 do
		table.insert(
			list,
			create("TextLabel")({
				Size = UDim2.fromOffset(26, 26),
				Position = UDim2.fromScale(math.random(), math.random()),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Text = "✦",
				TextScaled = true,
				TextColor3 = color or Color3.fromRGB(255, 245, 190),
				FontFace = Theme.font.title,
				ZIndex = 9,
				action(function(instance: Instance)
					local label = instance :: TextLabel
					local scale = Instance.new("UIScale")
					scale.Scale = 0
					scale.Parent = label
					local alive = true
					task.spawn(function()
						task.wait(i * 0.37)
						while alive do
							label.Position = UDim2.fromScale(math.random(), math.random())
							tween(scale, 0.35, { Scale = 0.6 + math.random() * 0.8 }, Enum.EasingStyle.Back)
							task.wait(0.6 + math.random() * 0.6)
							tween(scale, 0.3, { Scale = 0 })
							task.wait(0.5 + math.random())
						end
					end)
					cleanup(function()
						alive = false
					end)
				end),
			})
		)
	end
	return create("Frame")({
		Name = "Sparkles",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 9,
		list,
	})
end

-- A live 3D critter in the UI (mascots peeking out of panels, prize cards). Gently bobs and turns.
function Components.mascot(props: {
	species: string,
	tier: number?,
	mutation: string?,
	size: UDim2,
	position: UDim2,
	anchor: Vector2?,
	rotation: number?,
}): Instance
	return create("ViewportFrame")({
		Name = "Mascot",
		Size = props.size,
		Position = props.position,
		AnchorPoint = props.anchor or Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Rotation = props.rotation or 0,
		Ambient = Color3.fromRGB(200, 190, 180),
		LightColor = Color3.fromRGB(255, 240, 220),
		LightDirection = Vector3.new(-1, -1.5, -1),
		ZIndex = 8,
		action(function(instance: Instance)
			local viewport = instance :: ViewportFrame
			local world = Instance.new("WorldModel")
			world.Parent = viewport
			local model = CritterRig.build(props.species, props.tier or 5, props.mutation, 2, 3)
			model.Parent = world
			local camera = Instance.new("Camera")
			camera.FieldOfView = 30
			camera.CFrame = CFrame.lookAt(Vector3.new(0, 1.2, -11), Vector3.new(0, 0.6, 0))
			camera.Parent = viewport
			viewport.CurrentCamera = camera
			local alive = true
			local seed = math.random() * 10
			task.spawn(function()
				while alive do
					local t = os.clock()
					model:PivotTo(
						CFrame.new(0, math.abs(math.sin(t * 3 + seed)) * 0.5, 0)
							* CFrame.Angles(0, math.sin(t * 0.9) * 0.6, math.sin(t * 2.2) * 0.06)
					)
					task.wait()
				end
			end)
			cleanup(function()
				alive = false
			end)
		end),
	})
end

-- An icon: the uploaded image when it exists (assets/ui/<name>.png → AssetIds.images), otherwise the
-- glyph fallback in chunky outlined text.
function Components.icon(name: string, glyph: string, color: Color3?): Instance
	local image = (AssetIds :: any).images and (AssetIds :: any).images[name]
	if image then
		return create("ImageLabel")({
			Name = "Icon",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = image,
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = 5,
		})
	end
	return create("TextLabel")({
		Name = "Icon",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = glyph,
		TextScaled = true,
		TextColor3 = color or Theme.color.white,
		FontFace = Theme.font.title,
		ZIndex = 5,
		Components.textStroke(3),
	})
end

return Components
