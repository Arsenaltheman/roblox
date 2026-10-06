--!strict
-- Server event banner (top right). Always shows the real countdown to the next event; during the
-- last two minutes it grows and names the event; while one runs it pulses with time left.

local Workspace = game:GetService("Workspace")

local Vide = require("@game/ReplicatedStorage/Packages/Vide")
local EventsConfig = require("@game/ReplicatedStorage/Shared/Config/Events")
local Palette = require("@game/ReplicatedStorage/Shared/Config/Palette")
local NumberFormat = require("@game/ReplicatedStorage/Shared/Sim/NumberFormat")
local Components = require("./Components")
local Theme = require("./Theme")

local create = Vide.create :: any
local source = Vide.source
local show = Vide.show :: any
local action = Vide.action :: any
local cleanup = Vide.cleanup

local EventBanner = {}

local ICON: { [string]: { string } } = {
	CrateRain = { "crate", "▣" },
	GoldRush = { "moneybag", "$" },
	JackpotRestock = { "chest", "♛" },
	BanditKing = { "crown", "♚" },
}

function EventBanner.build(): Instance
	local now = source(Workspace:GetServerTimeNow())
	local function attr(name: string): any
		now()
		return Workspace:GetAttribute(name)
	end
	local function activeId(): string
		local id = attr("EventId")
		return if type(id) == "string" then id else ""
	end
	local function shownId(): string
		local id = activeId()
		if id ~= "" then
			return id
		end
		local nextId = attr("EventNextId")
		return if type(nextId) == "string" then nextId else ""
	end
	local function secondsToNext(): number
		local at = attr("EventNextAt")
		return if type(at) == "number" then math.max(0, at - now()) else math.huge
	end
	local function hot(): boolean
		return activeId() ~= "" or secondsToNext() <= EventsConfig.WARNING
	end
	local function color(): Color3
		local e = EventsConfig.byId[shownId()]
		return if e and hot() then Palette.color(e.color) else Theme.color.woodDark
	end

	return create("Frame")({
		Name = "EventBanner",
		Size = function()
			return if hot() then UDim2.fromOffset(330, 92) else UDim2.fromOffset(230, 44)
		end,
		Position = UDim2.new(1, -16, 0, 280),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Visible = function()
			return secondsToNext() < math.huge or activeId() ~= ""
		end,
		Components.corner(UDim.new(0, 16)),
		Components.stroke(3.5),
		Components.gradient(color),
		Components.stripes(UDim.new(0, 16), 0.1),
		Components.gloss(UDim.new(0, 16)),
		show(hot, function()
			return create("Frame")({
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Components.sparkles(5),
				Components.idle(1.5, 0.9),
			})
		end),
		create("Frame")({
			Size = UDim2.fromScale(0.3, 0.86),
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
			Position = UDim2.new(0, 6, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundTransparency = 1,
			ZIndex = 4,
			Visible = hot,
			create("Frame")({
				Size = UDim2.fromScale(3, 1),
				BackgroundTransparency = 1,
				-- Re-create the icon when the event changes.
				show(function()
					return shownId() ~= ""
				end, function()
					local look = ICON[shownId()] or { "gift", "★" }
					return create("Frame")({
						Size = UDim2.fromScale(1 / 3, 1),
						BackgroundTransparency = 1,
						Components.icon(look[1], look[2], Theme.color.white),
						Components.idle(8, 1.2),
					})
				end),
			}),
		}),
		create("TextLabel")({
			Size = function()
				return if hot() then UDim2.new(1, -96, 0.48, 0) else UDim2.new(1, -16, 1, -10)
			end,
			Position = function()
				return if hot() then UDim2.new(0, 88, 0.08, 0) else UDim2.fromOffset(8, 5)
			end,
			BackgroundTransparency = 1,
			TextScaled = true,
			FontFace = Theme.font.title,
			TextColor3 = Theme.color.white,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 5,
			Text = function()
				local e = EventsConfig.byId[shownId()]
				if hot() and e then
					return e.name
				end
				return `NEXT EVENT {NumberFormat.clock(secondsToNext())}`
			end,
			Components.textStroke(2.5),
		}),
		create("TextLabel")({
			Size = UDim2.new(1, -96, 0.34, 0),
			Position = UDim2.new(0, 88, 0.58, 0),
			BackgroundTransparency = 1,
			TextScaled = true,
			FontFace = Theme.font.heading,
			TextColor3 = Theme.color.white,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 5,
			Visible = hot,
			Text = function()
				if activeId() ~= "" then
					local ends = attr("EventEndsAt")
					local left = if type(ends) == "number" then math.max(0, ends - now()) else 0
					return `LIVE NOW · {NumberFormat.clock(left)} left`
				end
				return `starts in {NumberFormat.clock(secondsToNext())}`
			end,
			Components.textStroke(2),
		}),
		action(function()
			local alive = true
			task.spawn(function()
				while alive do
					now(Workspace:GetServerTimeNow())
					task.wait(0.25)
				end
			end)
			cleanup(function()
				alive = false
			end)
		end),
	})
end

return EventBanner
