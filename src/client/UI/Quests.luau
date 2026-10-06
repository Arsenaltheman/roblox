--!strict
-- Quests: the Bounty Trail (the long campaign), the Daily Wanted Board and Weekly Bounties, in one
-- tabbed menu, plus a small tracker on the HUD that always shows what to do next.

local Workspace = game:GetService("Workspace")

local Vide = require("@game/ReplicatedStorage/Packages/Vide")
local Progression = require("@game/ReplicatedStorage/Shared/Config/Progression")
local TrailConfig = require("@game/ReplicatedStorage/Shared/Config/Trail")
local NumberFormat = require("@game/ReplicatedStorage/Shared/Sim/NumberFormat")
local Net = require("@game/ReplicatedStorage/Shared/Net/Net")
local Sound = require("../Controllers/Sound")
local Store = require("../Store")
local Components = require("./Components")
local Theme = require("./Theme")

local create = Vide.create :: any
local show = Vide.show :: any
local indexes = Vide.indexes :: any
local source = Vide.source
local action = Vide.action :: any
local cleanup = Vide.cleanup

local Quests = {}

local function state(): any
	return Store.state() or {}
end

local function trail(): any
	return state().trail or {}
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

-- A progress row: label, bar, "have/goal", tick when done.
local function objectiveRow(get: () -> any, order: number, height: number): Instance
	return create("Frame")({
		Size = UDim2.new(1, 0, 0, height),
		LayoutOrder = order,
		BackgroundColor3 = function()
			return if get().done then Theme.lighten(Theme.color.green, 0.55) else Theme.color.white
		end,
		Components.corner(UDim.new(0, 10)),
		Components.stroke(2.5),
		text({
			Size = UDim2.new(0.62, -40, 0.62, 0),
			Position = UDim2.new(0, 40, 0.1, 0),
			Text = function()
				return get().text
			end,
			FontFace = Theme.font.heading,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		text({
			Size = UDim2.fromOffset(28, 28),
			Position = UDim2.new(0, 8, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			Text = function()
				return if get().done then "✔" else "○"
			end,
			TextColor3 = function()
				return if get().done then Theme.color.green else Theme.color.wood
			end,
			FontFace = Theme.font.title,
		}),
		-- Bar
		create("Frame")({
			Size = UDim2.new(0.36, -10, 0, 16),
			Position = UDim2.new(1, -8, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5),
			BackgroundColor3 = Theme.color.woodDark,
			Components.corner(UDim.new(1, 0)),
			create("Frame")({
				Size = function()
					local o = get()
					return UDim2.fromScale(math.clamp(o.have / math.max(1, o.goal), 0, 1), 1)
				end,
				BackgroundColor3 = Color3.new(1, 1, 1),
				Components.corner(UDim.new(1, 0)),
				Components.gradient(function()
					return if get().done then Theme.color.green else Theme.color.gold
				end),
			}),
			text({
				Size = UDim2.new(1, 0, 0, 18),
				Position = UDim2.new(0, 0, 0, -20),
				TextXAlignment = Enum.TextXAlignment.Right,
				FontFace = Theme.font.number,
				Text = function()
					local o = get()
					return `{NumberFormat.short(o.have)} / {NumberFormat.short(o.goal)}`
				end,
			}),
		}),
	})
end

-- ---------------------------------------------------------------- tabs

local function trailPage(): Instance
	return create("ScrollingFrame")({
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ScrollBarThickness = 8,
		VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		create("UIListLayout")({ Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
		Components.padding(4),
		-- Chapter banner.
		create("Frame")({
			Size = UDim2.new(1, -8, 0, 92),
			LayoutOrder = 1,
			BackgroundColor3 = Color3.new(1, 1, 1),
			ClipsDescendants = true,
			Components.corner(UDim.new(0, 16)),
			Components.stroke(3.5),
			Components.gradient(Theme.color.orange),
			Components.stripes(UDim.new(0, 16), 0.1),
			create("Frame")({
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Components.sunburst(Theme.color.yellow, 10, UDim2.fromScale(2.4, 2.4)),
			}),
			text({
				Size = UDim2.new(0.7, 0, 0.32, 0),
				Position = UDim2.fromOffset(16, 8),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = Theme.color.white,
				FontFace = Theme.font.heading,
				ZIndex = 3,
				Text = function()
					local t = trail()
					if t.finished then
						return "THE BOUNTY TRAIL · COMPLETE"
					end
					return `THE BOUNTY TRAIL · CHAPTER {t.chapter or 1} OF {t.chapters or #TrailConfig.chapters}`
				end,
				Components.textStroke(2),
			}),
			text({
				Size = UDim2.new(0.7, 0, 0.4, 0),
				Position = UDim2.new(0, 16, 0.36, 0),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = Theme.color.white,
				FontFace = Theme.font.title,
				ZIndex = 3,
				Text = function()
					local t = trail()
					return if t.finished then "KING OF THE WEST" else string.upper(t.chapterName or "")
				end,
				Components.goldText(),
				Components.textStroke(3),
			}),
			text({
				Size = UDim2.new(0.7, 0, 0.2, 0),
				Position = UDim2.new(0, 16, 0.76, 0),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = Theme.color.white,
				FontFace = Theme.font.body,
				ZIndex = 3,
				Text = function()
					return trail().blurb or ""
				end,
				Components.textStroke(1.5),
			}),
			-- Quest dots 1..5
			create("Frame")({
				Size = UDim2.new(0.28, 0, 0, 26),
				Position = UDim2.new(1, -14, 0.5, 0),
				AnchorPoint = Vector2.new(1, 0.5),
				BackgroundTransparency = 1,
				ZIndex = 3,
				create("UIListLayout")({
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Right,
					Padding = UDim.new(0, 6),
				}),
				(function()
					local dots = {}
					for i = 1, 5 do
						table.insert(
							dots,
							create("Frame")({
								Size = UDim2.fromOffset(24, 24),
								LayoutOrder = i,
								BackgroundColor3 = function()
									local t = trail()
									local q = t.quest or 1
									return if t.finished or i < q
										then Theme.color.green
										elseif i == q then Theme.color.yellow
										else Theme.color.woodDark
								end,
								Components.corner(UDim.new(1, 0)),
								Components.stroke(2.5),
							})
						)
					end
					return dots
				end)() :: any,
			}),
		}),
		-- Current quest.
		show(function()
			return not trail().finished
		end, function()
			return create("Frame")({
				Size = UDim2.new(1, -8, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = 2,
				BackgroundColor3 = Color3.new(1, 1, 1),
				Components.corner(UDim.new(0, 16)),
				Components.stroke(3),
				Components.gradient(Theme.color.cream),
				create("UIListLayout")({ Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
				Components.padding(12),
				text({
					Size = UDim2.new(1, 0, 0, 38),
					LayoutOrder = 1,
					TextXAlignment = Enum.TextXAlignment.Left,
					FontFace = Theme.font.title,
					TextColor3 = Theme.color.white,
					Text = function()
						local t = trail()
						return `{if t.finale then "★ FINALE: " else `QUEST {t.quest or 1}: `}{string.upper(
							t.questName or ""
						)}`
					end,
					Components.textStroke(3),
				}),
				indexes(function()
					return trail().objectives or {}
				end, function(o, i)
					return objectiveRow(o, 1 + i, 52)
				end),
				text({
					Size = UDim2.new(1, 0, 0, 24),
					LayoutOrder = 20,
					TextXAlignment = Enum.TextXAlignment.Left,
					FontFace = Theme.font.heading,
					TextColor3 = Theme.darken(Theme.color.wood, 0.2),
					Text = function()
						local t = trail()
						local c = t.chapter or 1
						local reward =
							`Reward: {NumberFormat.clock(TrailConfig.questCashSeconds(c))} of income + {TrailConfig.questNuggets(
								c
							)} Nuggets`
						if t.finale then
							reward ..= ` + chapter title, {TrailConfig.finaleSpins} spins, 2x Cash`
						elseif t.quest == 3 then
							reward ..= " + a free spin"
						end
						return reward
					end,
				}),
				Components.button({
					text = function()
						return if trail().done then "CLAIM REWARD!" else "IN PROGRESS..."
					end,
					color = function()
						return if trail().done then Theme.color.green else Color3.fromRGB(130, 130, 140)
					end,
					size = UDim2.new(1, 0, 0, 58),
					layoutOrder = 30,
					shine = true,
					pulse = false,
					onClick = function()
						if trail().done then
							Sound.play("buy")
							Net.request("Claim", "trail", 0)
						end
					end,
				}),
			})
		end),
		show(function()
			return trail().finished == true
		end, function()
			return text({
				Size = UDim2.new(1, -8, 0, 60),
				LayoutOrder = 2,
				FontFace = Theme.font.heading,
				Text = "You rode the whole Bounty Trail. Weekly Bounties keep the rewards coming!",
			})
		end),
		-- Chapter list.
		(function()
			local rows = {}
			for n, chapter in TrailConfig.chapters do
				table.insert(
					rows,
					create("Frame")({
						Size = UDim2.new(1, -8, 0, 40),
						LayoutOrder = 10 + n,
						BackgroundColor3 = function()
							local c = trail().chapter or 1
							return if n < c
								then Theme.lighten(Theme.color.green, 0.5)
								elseif n == c then Theme.lighten(Theme.color.yellow, 0.5)
								else Theme.lighten(Theme.color.wood, 0.55)
						end,
						Components.corner(UDim.new(0, 10)),
						Components.stroke(2),
						text({
							Size = UDim2.new(1, -20, 0.7, 0),
							Position = UDim2.new(0, 10, 0.15, 0),
							TextXAlignment = Enum.TextXAlignment.Left,
							FontFace = Theme.font.heading,
							Text = function()
								local c = trail().chapter or 1
								local mark = if n < c then "✔" elseif n == c then "▶" else "🔒"
								return `{mark}  Chapter {n}: {chapter.name}  ·  ends at Frontier {n}`
							end,
						}),
					})
				)
			end
			return rows
		end)() :: any,
	})
end

local function dailyPage(): Instance
	return create("ScrollingFrame")({
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ScrollBarThickness = 8,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		create("UIListLayout")({ Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
		Components.padding(4),
		text({
			Size = UDim2.new(1, 0, 0, 26),
			LayoutOrder = 0,
			FontFace = Theme.font.heading,
			Text = function()
				local s = state().streak
				return `Login streak: day {s and s.count or 0} · finish all 3 for 15 min of 2x Cash · new at 00:00 UTC`
			end,
		}),
		indexes(function()
			return state().quests or {}
		end, function(q, i)
			return create("Frame")({
				Size = UDim2.new(1, -8, 0, 72),
				LayoutOrder = i,
				BackgroundTransparency = 1,
				objectiveRow(function()
					local v: any = q()
					return { text = v.text, have = v.progress, goal = v.goal, done = v.progress >= v.goal }
				end, 0, 46),
				Components.button({
					text = function()
						return if q().claimed
							then "DONE"
							elseif q().progress >= q().goal then "CLAIM"
							else `+{Progression.quests.nuggets} ◆`
					end,
					color = function()
						return if q().progress >= q().goal and not q().claimed
							then Theme.color.green
							else Color3.fromRGB(130, 130, 140)
					end,
					size = UDim2.new(0.3, 0, 0, 22),
					position = UDim2.new(1, 0, 1, 0),
					anchor = Vector2.new(1, 1),
					textSize = 18,
					onClick = function()
						Net.request("Claim", "quest", q().index)
					end,
				}),
			})
		end),
	})
end

local function weeklyPage(): Instance
	return create("ScrollingFrame")({
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ScrollBarThickness = 8,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		create("UIListLayout")({ Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
		Components.padding(4),
		text({
			Size = UDim2.new(1, 0, 0, 26),
			LayoutOrder = 0,
			FontFace = Theme.font.heading,
			Text = function()
				local ends = trail().weekEndsAt or 0
				local left = math.max(0, ends - Workspace:GetServerTimeNow())
				local days = math.floor(left / 86400)
				return `Each: +{TrailConfig.weeklyNuggets} Nuggets & {TrailConfig.weeklySpins} spins · all {TrailConfig.WEEKLY_COUNT}: +{TrailConfig.weeklyAllNuggets} & a Luck Potion · new in {days}d {NumberFormat.clock(
					left % 86400
				)}`
			end,
		}),
		indexes(function()
			return trail().weekly or {}
		end, function(w, i)
			return create("Frame")({
				Size = UDim2.new(1, -8, 0, 72),
				LayoutOrder = i,
				BackgroundTransparency = 1,
				objectiveRow(function()
					local v: any = w()
					return { text = v.text, have = v.have, goal = v.goal, done = v.have >= v.goal }
				end, 0, 46),
				Components.button({
					text = function()
						return if w().claimed
							then "DONE"
							elseif w().have >= w().goal then "CLAIM"
							else "WEEKLY"
					end,
					color = function()
						return if w().have >= w().goal and not w().claimed
							then Theme.color.green
							else Color3.fromRGB(130, 130, 140)
					end,
					size = UDim2.new(0.3, 0, 0, 22),
					position = UDim2.new(1, 0, 1, 0),
					anchor = Vector2.new(1, 1),
					textSize = 18,
					onClick = function()
						Net.request("Claim", "weekly", w().slot)
					end,
				}),
			})
		end),
	})
end

function Quests.menu(onClose: () -> ()): Instance
	local tab = source("trail")
	local function tabButton(id: string, label: string, color: Color3, order: number): Instance
		return Components.button({
			text = label,
			color = function()
				return if tab() == id then color else Theme.color.wood
			end,
			size = UDim2.new(1 / 3, -8, 1, 0),
			layoutOrder = order,
			textSize = 24,
			onClick = function()
				Sound.play("click")
				tab(id)
			end,
		})
	end
	return Components.panel({
		title = "QUESTS",
		accent = Theme.color.orange,
		mascot = "SheriffShrimpo",
		size = UDim2.fromScale(0.7, 0.8),
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
				tabButton("trail", "BOUNTY TRAIL", Theme.color.orange, 1),
				tabButton("daily", "DAILY", Theme.color.red, 2),
				tabButton("weekly", "WEEKLY", Theme.color.purple, 3),
			}),
			create("Frame")({
				Size = UDim2.new(1, 0, 1, -56),
				Position = UDim2.fromOffset(0, 56),
				BackgroundTransparency = 1,
				show(function()
					return tab() == "trail"
				end, trailPage),
				show(function()
					return tab() == "daily"
				end, dailyPage),
				show(function()
					return tab() == "weekly"
				end, weeklyPage),
			}),
		},
	})
end

-- HUD tracker: the current Trail quest and its objectives. Tap to open Quests.
function Quests.tracker(visible: () -> boolean): Instance
	local pulse = source(0)
	return create("TextButton")({
		Name = "TrailTracker",
		Size = UDim2.fromOffset(240, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.new(0, 112, 0, 230),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		AutoButtonColor = false,
		Text = "",
		Visible = function()
			local t = trail()
			return visible() and t.chapter ~= nil and not t.finished
		end,
		Activated = function()
			Sound.play("click")
			Store.menu("quests")
		end,
		Components.corner(UDim.new(0, 12)),
		create("UIStroke")({
			Thickness = 2.5,
			Color = function()
				return if trail().done then Theme.color.green else Theme.color.gold
			end,
			Transparency = function()
				return pulse()
			end,
		}),
		create("UIListLayout")({ Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }),
		Components.padding(8),
		text({
			Size = UDim2.new(1, 0, 0, 20),
			LayoutOrder = 1,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Theme.color.gold,
			FontFace = Theme.font.title,
			Text = function()
				local t = trail()
				if t.done then
					return "★ QUEST DONE: TAP TO CLAIM!"
				end
				return `TRAIL {t.chapter or 1}-{t.quest or 1}: {string.upper(t.questName or "")}`
			end,
			Components.textStroke(1.5),
		}),
		indexes(function()
			return trail().objectives or {}
		end, function(o, i)
			return text({
				Size = UDim2.new(1, 0, 0, 18),
				LayoutOrder = 1 + i,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = function()
					return if o().done then Theme.color.green else Theme.color.white
				end,
				FontFace = Theme.font.heading,
				Text = function()
					local v = o()
					local mark = if v.done then "✔" else "•"
					return `{mark} {v.text} ({NumberFormat.short(v.have)}/{NumberFormat.short(v.goal)})`
				end,
				Components.textStroke(1),
			})
		end),
		action(function()
			local alive = true
			task.spawn(function()
				while alive do
					pulse(if trail().done then (math.sin(os.clock() * 6) + 1) / 2 * 0.6 else 0)
					task.wait(0.05)
				end
			end)
			cleanup(function()
				alive = false
			end)
		end),
	})
end

return Quests
