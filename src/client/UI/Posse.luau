--!strict
-- Posse UI: a strip on the HUD with your posse mates and the shared bounty, an invite popup, and
-- the Posse panel (MORE → Posse) to invite players in the server or leave.

local Players = game:GetService("Players")

local Vide = require("@game/ReplicatedStorage/Packages/Vide")
local Net = require("@game/ReplicatedStorage/Shared/Net/Net")
local Sound = require("../Controllers/Sound")
local Components = require("./Components")
local Theme = require("./Theme")

local create = Vide.create :: any
local show = Vide.show :: any
local values = Vide.values :: any
local source = Vide.source
local action = Vide.action :: any
local cleanup = Vide.cleanup

local localPlayer = Players.LocalPlayer

local Posse = {}

local MAX = 4
local BOUNTY_GOAL = 10

-- Ticks so lists of players and attributes re-evaluate.
local tick = source(0)
task.spawn(function()
	while true do
		tick(tick() + 1)
		task.wait(1)
	end
end)

local invite = source(nil :: { from: number, expires: number }?)

local function myPosse(): number
	tick()
	return (localPlayer:GetAttribute("Posse") :: number?) or 0
end

local function mates(): { Player }
	local id = myPosse()
	local out = {}
	if id == 0 then
		return out
	end
	for _, other in Players:GetPlayers() do
		if other ~= localPlayer and other:GetAttribute("Posse") == id then
			table.insert(out, other)
		end
	end
	return out
end

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

local function distanceTo(other: Player): string
	local a = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local b = other.Character and other.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not a or not b then
		return ""
	end
	return `{math.floor((a.Position - b.Position).Magnitude)} studs`
end

-- ---------------------------------------------------------------- HUD strip

function Posse.hud(visible: () -> boolean): Instance
	return create("Frame")({
		Name = "PosseHud",
		Size = UDim2.fromOffset(240, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		-- Below the hint/announcement band and above the Trail tracker.
		Position = UDim2.new(0, 112, 0, 160),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		Visible = function()
			return visible() and myPosse() ~= 0
		end,
		Components.corner(UDim.new(0, 12)),
		create("UIStroke")({ Thickness = 2.5, Color = Theme.color.sky }),
		create("UIListLayout")({ Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }),
		Components.padding(8),
		text({
			Size = UDim2.new(1, 0, 0, 20),
			LayoutOrder = 1,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Theme.color.sky,
			FontFace = Theme.font.title,
			Text = function()
				local n = #mates() + 1
				local heists = (localPlayer:GetAttribute("PosseHeists") :: number?) or 0
				return `YOUR POSSE ({n}/{MAX}) · BOUNTY {heists % BOUNTY_GOAL}/{BOUNTY_GOAL}`
			end,
			Components.textStroke(1.5),
		}),
		values(mates, function(other: Player, i)
			return text({
				Size = UDim2.new(1, 0, 0, 18),
				LayoutOrder = 1 + i,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = Theme.color.white,
				FontFace = Theme.font.heading,
				Text = function()
					tick()
					return `• {other.DisplayName}  {distanceTo(other)}`
				end,
				Components.textStroke(1),
			})
		end),
	})
end

-- ---------------------------------------------------------------- invite popup

function Posse.invitePopup(): Instance
	-- Everything reads invite() live, so a newer invite replaces the old one in place.
	local function current(): { from: number, expires: number }
		return invite() or { from = 0, expires = 0 }
	end
	local function fromName(): string
		local from = Players:GetPlayerByUserId(current().from)
		return if from then from.DisplayName else "Someone"
	end
	return show(function()
		local inv = invite()
		tick()
		return inv ~= nil and os.clock() < inv.expires
	end, function()
		return create("Frame")({
			Name = "PosseInvite",
			Size = UDim2.fromOffset(420, 120),
			Position = UDim2.new(0.5, 0, 0, 300),
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundColor3 = Color3.new(1, 1, 1),
			ZIndex = 30,
			Components.corner(UDim.new(0, 18)),
			Components.stroke(4),
			Components.gradient(Theme.color.cream),
			Components.popIn(),
			text({
				Size = UDim2.new(1, -20, 0, 44),
				Position = UDim2.fromOffset(10, 10),
				FontFace = Theme.font.title,
				TextColor3 = Theme.color.white,
				Text = function()
					return `{fromName()} wants you in their POSSE!`
				end,
				ZIndex = 31,
				Components.goldText(),
				Components.textStroke(3),
			}),
			Components.button({
				text = "RIDE TOGETHER",
				color = Theme.color.green,
				size = UDim2.fromOffset(200, 48),
				position = UDim2.new(0, 14, 1, -12),
				anchor = Vector2.new(0, 1),
				textSize = 22,
				onClick = function()
					Sound.play("buy")
					Net.request("PosseRespond", current().from, true)
					invite(nil)
				end,
			}),
			Components.button({
				text = "NO THANKS",
				color = Theme.color.wood,
				size = UDim2.fromOffset(160, 48),
				position = UDim2.new(1, -14, 1, -12),
				anchor = Vector2.new(1, 1),
				textSize = 22,
				onClick = function()
					Net.request("PosseRespond", current().from, false)
					invite(nil)
				end,
			}),
			text({
				Size = UDim2.new(1, 0, 0, 18),
				Position = UDim2.fromOffset(0, 56),
				FontFace = Theme.font.heading,
				ZIndex = 31,
				Text = function()
					tick()
					return `Posse mates can't rob each other and boost each other's cash · {math.max(
						0,
						math.ceil(current().expires - os.clock())
					)}s`
				end,
			}),
		})
	end)
end

-- ---------------------------------------------------------------- panel

function Posse.panel(onClose: () -> ()): Instance
	local others = function(): { Player }
		tick()
		local out = {}
		for _, other in Players:GetPlayers() do
			if other ~= localPlayer then
				table.insert(out, other)
			end
		end
		return out
	end
	return Components.panel({
		title = "POSSE",
		accent = Theme.color.sky,
		size = UDim2.fromScale(0.6, 0.72),
		onClose = onClose,
		children = {
			text({
				Size = UDim2.new(1, 0, 0, 44),
				FontFace = Theme.font.heading,
				TextWrapped = true,
				TextScaled = false,
				TextSize = 20,
				TextColor3 = Theme.darken(Theme.color.wood, 0.3),
				Text = `Ride with up to {MAX} friends: no robbing each other, +10% cash per posse mate in the server, and every {BOUNTY_GOAL} crates you run home together pays everyone a spin and Nuggets. Friends can join your server from your Roblox profile.`,
			}),
			show(function()
				return myPosse() ~= 0
			end, function()
				return Components.button({
					text = "LEAVE POSSE",
					color = Theme.color.red,
					size = UDim2.fromOffset(200, 44),
					position = UDim2.new(1, 0, 0, 50),
					anchor = Vector2.new(1, 0),
					textSize = 20,
					onClick = function()
						Net.request("PosseLeave")
					end,
				})
			end),
			create("ScrollingFrame")({
				Size = UDim2.new(1, 0, 1, -104),
				Position = UDim2.fromOffset(0, 104),
				BackgroundTransparency = 1,
				ScrollBarThickness = 8,
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				CanvasSize = UDim2.new(),
				create("UIListLayout")({ Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
				show(function()
					return #others() == 0
				end, function()
					return text({
						Size = UDim2.new(1, 0, 0, 40),
						FontFace = Theme.font.heading,
						Text = "Nobody else is here yet. Invite a friend to your server from your Roblox friends list!",
					})
				end),
				values(others, function(other: Player, i)
					local inPosse = function()
						return myPosse() ~= 0 and other:GetAttribute("Posse") == myPosse()
					end
					return create("Frame")({
						Size = UDim2.new(1, -10, 0, 60),
						LayoutOrder = i,
						BackgroundColor3 = Color3.new(1, 1, 1),
						Components.corner(UDim.new(0, 14)),
						Components.stroke(3),
						Components.gradient(function()
							return if inPosse()
								then Theme.lighten(Theme.color.sky, 0.6)
								else Theme.color.cream
						end),
						text({
							Size = UDim2.new(0.55, 0, 0.5, 0),
							Position = UDim2.new(0, 14, 0.1, 0),
							TextXAlignment = Enum.TextXAlignment.Left,
							FontFace = Theme.font.title,
							TextColor3 = Theme.color.white,
							Text = other.DisplayName,
							Components.textStroke(2.5),
						}),
						text({
							Size = UDim2.new(0.55, 0, 0.3, 0),
							Position = UDim2.new(0, 14, 0.62, 0),
							TextXAlignment = Enum.TextXAlignment.Left,
							Text = function()
								if inPosse() then
									return "In your posse"
								end
								return if (other:GetAttribute("Posse") :: number?) ~= 0
									then "Riding with another posse"
									else "Free rider"
							end,
						}),
						Components.button({
							text = function()
								return if inPosse() then "MATE" else "INVITE"
							end,
							color = function()
								return if inPosse() then Color3.fromRGB(130, 130, 140) else Theme.color.green
							end,
							size = UDim2.fromOffset(140, 44),
							position = UDim2.new(1, -12, 0.5, 0),
							anchor = Vector2.new(1, 0.5),
							textSize = 20,
							onClick = function()
								if not inPosse() then
									Sound.play("click")
									Net.request("PosseInvite", other.UserId)
								end
							end,
						}),
					})
				end),
			}),
		},
	})
end

-- Listens for invites (mounted once).
function Posse.listen(): Instance
	return create("Folder")({
		Name = "PosseListener",
		action(function()
			local connection = Net.listen("PosseInvited", function(fromId: number, seconds: number)
				if seconds <= 0 then
					invite(nil)
					return
				end
				Sound.play("giftReady")
				invite({ from = fromId, expires = os.clock() + seconds })
			end)
			cleanup(function()
				if typeof(connection) == "RBXScriptConnection" then
					(connection :: RBXScriptConnection):Disconnect()
				end
			end)
		end),
	})
end

return Posse
