--!strict
-- Quests: the Bounty Trail (the long campaign), the Daily Wanted Board and Weekly Bounties, in one
-- tabbed menu, plus a small tracker on the HUD that always shows what to do next.

local Workspace = game:GetService("Workspace")

local Vide = require("@game/ReplicatedStorage/Packages/Vide")
local Progression = require("@game/ReplicatedStorage/Shared/Config/Progression")
local SeasonConfig = require("@game/ReplicatedStorage/Shared/Config/Season")
local TrailConfig = require("@game/ReplicatedStorage/Shared/Config/Trail")
local SkillsConfig = require("@game/ReplicatedStorage/Shared/Config/Skills")
local SkillsSim = require("@game/ReplicatedStorage/Shared/Sim/Skills")
local Products = require("@game/ReplicatedStorage/Shared/Config/Products")
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

local function season(): any
	return state().season or {}
end

-- A server-time source ticking once a second (for real countdowns).
local function clock(): () -> number
	local now = source(Workspace:GetServerTimeNow())
	action(function()
		local alive = true
		task.spawn(function()
			while alive do
				now(Workspace:GetServerTimeNow())
				task.wait(1)
			end
		end)
		cleanup(function()
			alive = false
		end)
	end)
	return now
end

local function countdown(seconds: number): string
	local left = math.max(0, seconds)
	local days = math.floor(left / 86400)
	return if days > 0 then `{days}d {NumberFormat.clock(left % 86400)}` else NumberFormat.clock(left)
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

-- ---------------------------------------------------------------- rail pass

local GLYPH = {
	cash = "$",
	nuggets = "◆",
	spins = "☸",
	luck = "♣",
	doubleCash = "2x",
	title = "✎",
	hat = "▲",
}

-- One reward cell of a tier card. Locked (tier not reached / no pass), claimable or claimed.
local function rewardCell(get: () -> any, premium: boolean, order: number): Instance
	local function reward(): any
		return (if premium then get().premium else get().free) or nil
	end
	local function claimed(): boolean
		return if premium then get().premiumClaimed == true else get().freeClaimed == true
	end
	local function reached(): boolean
		return (season().tier or 0) >= (get().tier or 1)
	end
	local function claimable(): boolean
		return reward() ~= nil and reached() and not claimed() and (not premium or season().premium == true)
	end
	return create("TextButton")({
		Size = UDim2.new(1, 0, 0.5, -3),
		LayoutOrder = order,
		AutoButtonColor = false,
		Text = "",
		Visible = function()
			return reward() ~= nil
		end,
		BackgroundColor3 = function()
			if claimed() then
				return Theme.lighten(Theme.color.green, 0.55)
			elseif claimable() then
				return Theme.color.green
			elseif premium and season().premium ~= true then
				return Theme.lighten(Theme.color.purple, 0.5)
			end
			return if reached() then Theme.color.white else Theme.lighten(Theme.color.wood, 0.55)
		end,
		Activated = function()
			if claimable() then
				Sound.play("buy")
				Net.request("SeasonClaim", get().tier, premium)
			end
		end,
		Components.corner(UDim.new(0, 10)),
		Components.stroke(2.5),
		text({
			Size = UDim2.new(1, -8, 0.45, 0),
			Position = UDim2.new(0, 4, 0, 2),
			FontFace = Theme.font.title,
			TextColor3 = function()
				return if claimable() then Theme.color.white else Theme.color.ink
			end,
			Text = function()
				local r = reward()
				if not r then
					return ""
				end
				if claimed() then
					return "✔"
				elseif premium and season().premium ~= true then
					return "🔒"
				end
				return GLYPH[r.kind] or "★"
			end,
		}),
		text({
			Size = UDim2.new(1, -8, 0.4, 0),
			Position = UDim2.new(0, 4, 0.5, 0),
			FontFace = Theme.font.heading,
			TextColor3 = function()
				return if claimable() then Theme.color.white else Theme.color.ink
			end,
			Text = function()
				local r = reward()
				if not r then
					return ""
				end
				return if claimable() then "CLAIM" else r.text
			end,
		}),
	})
end

local function tierCard(get: () -> any, order: number): Instance
	return create("Frame")({
		Size = UDim2.new(0, 112, 1, 0),
		LayoutOrder = order,
		BackgroundColor3 = Color3.new(1, 1, 1),
		Components.corner(UDim.new(0, 12)),
		create("UIStroke")({
			Thickness = function()
				return if (season().tier or 0) == get().tier then 4 else 2.5
			end,
			Color = function()
				return if (season().tier or 0) == get().tier then Theme.color.yellow else Theme.color.shadow
			end,
		}),
		Components.gradient(function()
			return if (season().tier or 0) >= get().tier
				then Theme.color.cream
				else Theme.lighten(Theme.color.wood, 0.4)
		end),
		Components.padding(6),
		create("UIListLayout")({ Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
		text({
			Size = UDim2.new(1, 0, 0, 22),
			LayoutOrder = 1,
			FontFace = Theme.font.title,
			TextColor3 = function()
				return if (season().tier or 0) >= get().tier then Theme.color.orange else Theme.color.wood
			end,
			Text = function()
				return `TIER {get().tier}`
			end,
		}),
		create("Frame")({
			Size = UDim2.new(1, 0, 1, -26),
			LayoutOrder = 2,
			BackgroundTransparency = 1,
			create("UIListLayout")({ Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
			rewardCell(get, false, 1),
			rewardCell(get, true, 2),
		}),
	})
end

local function railPage(): Instance
	local now = clock()
	return create("ScrollingFrame")({
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ScrollBarThickness = 8,
		VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		create("UIListLayout")({ Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
		Components.padding(4),
		-- Season banner: number, real countdown, tier and XP bar.
		create("Frame")({
			Size = UDim2.new(1, -8, 0, 104),
			LayoutOrder = 1,
			BackgroundColor3 = Color3.new(1, 1, 1),
			ClipsDescendants = true,
			Components.corner(UDim.new(0, 16)),
			Components.stroke(3.5),
			Components.gradient(function()
				local hex = season().color
				return if hex then Color3.fromHex(hex) else Theme.color.sky
			end),
			Components.stripes(UDim.new(0, 16), 0.1),
			Components.sparkles(5, Theme.color.yellow),
			text({
				Size = UDim2.new(0.6, 0, 0.3, 0),
				Position = UDim2.fromOffset(16, 8),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = Theme.color.white,
				FontFace = Theme.font.title,
				ZIndex = 3,
				Text = function()
					return `RAIL PASS · SEASON {season().season or 1}`
				end,
				Components.goldText(),
				Components.textStroke(3),
			}),
			text({
				Size = UDim2.new(0.38, -16, 0.26, 0),
				Position = UDim2.new(1, -16, 0, 10),
				AnchorPoint = Vector2.new(1, 0),
				TextXAlignment = Enum.TextXAlignment.Right,
				TextColor3 = Theme.color.white,
				FontFace = Theme.font.heading,
				ZIndex = 3,
				Text = function()
					return `Season ends in {countdown((season().endsAt or 0) - now())}`
				end,
				Components.textStroke(2),
			}),
			text({
				Size = UDim2.new(0.6, 0, 0.26, 0),
				Position = UDim2.new(0, 16, 0.36, 0),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = Theme.color.white,
				FontFace = Theme.font.heading,
				ZIndex = 3,
				Text = function()
					local sn = season()
					local tier = sn.tier or 0
					if tier >= SeasonConfig.PREMIUM_TIERS then
						return `TIER {tier} · track complete!`
					end
					return `TIER {tier} · {NumberFormat.short(sn.into or 0)} / {NumberFormat.short(
						sn.next or 0
					)} XP to tier {tier + 1}`
				end,
				Components.textStroke(2),
			}),
			text({
				Size = UDim2.new(0.38, -16, 0.22, 0),
				Position = UDim2.new(1, -16, 0.38, 0),
				AnchorPoint = Vector2.new(1, 0),
				TextXAlignment = Enum.TextXAlignment.Right,
				TextColor3 = Theme.color.white,
				FontFace = Theme.font.body,
				ZIndex = 3,
				Text = function()
					return `today's XP {season().xpToday or 0}/{SeasonConfig.XP_DAY_CAP}`
				end,
				Components.textStroke(1.5),
			}),
			-- XP bar
			create("Frame")({
				Size = UDim2.new(1, -32, 0, 18),
				Position = UDim2.new(0, 16, 1, -14),
				AnchorPoint = Vector2.new(0, 1),
				BackgroundColor3 = Theme.color.woodDark,
				ZIndex = 3,
				Components.corner(UDim.new(1, 0)),
				create("Frame")({
					Size = function()
						local sn = season()
						local size = sn.next or 0
						return UDim2.fromScale(
							if size > 0 then math.clamp((sn.into or 0) / size, 0, 1) else 1,
							1
						)
					end,
					BackgroundColor3 = Color3.new(1, 1, 1),
					ZIndex = 3,
					Components.corner(UDim.new(1, 0)),
					Components.gradient(Theme.color.gold),
				}),
			}),
		}),
		-- Buy / claim-all row.
		create("Frame")({
			Size = UDim2.new(1, -8, 0, 52),
			LayoutOrder = 2,
			BackgroundTransparency = 1,
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			Components.button({
				text = function()
					local price = Products.byKey.RailPass and Products.byKey.RailPass.price or 399
					return `GET THE RAIL PASS  {price} R$ · retroactive`
				end,
				color = Theme.color.purple,
				size = UDim2.new(0.5, -4, 1, 0),
				layoutOrder = 1,
				shine = true,
				textSize = 22,
				visible = function()
					return season().premium ~= true
				end,
				onClick = function()
					Sound.play("click")
					Net.request("ShopBuy", "RailPass", 1)
				end,
			}),
			text({
				Size = UDim2.new(0.5, -4, 1, 0),
				LayoutOrder = 1,
				FontFace = Theme.font.heading,
				Visible = function()
					return season().premium == true
				end,
				Text = function()
					return `✔ Rail Pass active for season {season().season or 1} · +2 contracts`
				end,
			}),
			Components.button({
				text = function()
					return `CLAIM FREE ({season().freeClaimable or 0})`
				end,
				color = function()
					return if (season().freeClaimable or 0) > 0
						then Theme.color.green
						else Color3.fromRGB(130, 130, 140)
				end,
				size = UDim2.new(0.25, -4, 1, 0),
				layoutOrder = 2,
				textSize = 20,
				onClick = function()
					if (season().freeClaimable or 0) > 0 then
						Sound.play("buy")
						Net.request("SeasonClaim", 0, false)
					end
				end,
			}),
			Components.button({
				text = function()
					return `CLAIM PASS ({season().premiumClaimable or 0})`
				end,
				color = function()
					return if (season().premiumClaimable or 0) > 0
						then Theme.color.green
						else Color3.fromRGB(130, 130, 140)
				end,
				size = UDim2.new(0.25, -4, 1, 0),
				layoutOrder = 3,
				textSize = 20,
				onClick = function()
					if (season().premiumClaimable or 0) > 0 then
						Sound.play("buy")
						Net.request("SeasonClaim", 0, true)
					end
				end,
			}),
		}),
		text({
			Size = UDim2.new(1, -8, 0, 20),
			LayoutOrder = 3,
			TextXAlignment = Enum.TextXAlignment.Left,
			FontFace = Theme.font.heading,
			TextColor3 = Theme.darken(Theme.color.wood, 0.2),
			Text = `Top row: free track ({SeasonConfig.FREE_TIERS} tiers). Bottom row: Rail Pass track ({SeasonConfig.PREMIUM_TIERS} tiers). Perks and looks only, never heist power.`,
		}),
		-- The track: 40 tier cards, scrolled sideways.
		create("ScrollingFrame")({
			Size = UDim2.new(1, -8, 0, 190),
			LayoutOrder = 4,
			BackgroundTransparency = 1,
			ScrollBarThickness = 8,
			ScrollingDirection = Enum.ScrollingDirection.X,
			AutomaticCanvasSize = Enum.AutomaticSize.X,
			CanvasSize = UDim2.new(),
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			Components.padding(4),
			indexes(function()
				return season().tiers or {}
			end, function(t, i)
				return tierCard(t, i)
			end),
		}),
		-- Weekly contracts.
		text({
			Size = UDim2.new(1, -8, 0, 26),
			LayoutOrder = 5,
			TextXAlignment = Enum.TextXAlignment.Left,
			FontFace = Theme.font.title,
			TextColor3 = Theme.color.orange,
			Text = function()
				return `CONTRACTS · each +{SeasonConfig.CONTRACT_XP} XP & Nuggets · new in {countdown(
					(season().weekEndsAt or 0) - now()
				)}`
			end,
			Components.textStroke(2),
		}),
		indexes(function()
			return season().contracts or {}
		end, function(w, i)
			return create("Frame")({
				Size = UDim2.new(1, -8, 0, 72),
				LayoutOrder = 10 + i,
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
							else `+{w().nuggets} ◆ +{SeasonConfig.CONTRACT_XP} XP`
					end,
					color = function()
						return if w().have >= w().goal and not w().claimed
							then Theme.color.green
							else Color3.fromRGB(130, 130, 140)
					end,
					size = UDim2.new(0.34, 0, 0, 22),
					position = UDim2.new(1, 0, 1, 0),
					anchor = Vector2.new(1, 1),
					textSize = 18,
					onClick = function()
						Net.request("ContractClaim", w().slot)
					end,
				}),
			})
		end),
		show(function()
			return season().premium ~= true
		end, function()
			return text({
				Size = UDim2.new(1, -8, 0, 22),
				LayoutOrder = 30,
				TextXAlignment = Enum.TextXAlignment.Left,
				FontFace = Theme.font.body,
				TextColor3 = Theme.darken(Theme.color.wood, 0.2),
				Text = "Rail Pass holders get 2 more contracts a week.",
			})
		end),
	})
end

-- ---------------------------------------------------------------- skills (masteries)

local function skillsPage(): Instance
	local rows = {}
	for i, skill in SkillsConfig.list do
		local c = Color3.fromHex(skill.color)
		local function xp(): number
			return (state().skills or {})[skill.id] or 0
		end
		table.insert(
			rows,
			create("Frame")({
				Size = UDim2.new(1, -8, 0, 86),
				LayoutOrder = i,
				BackgroundColor3 = Color3.new(1, 1, 1),
				Components.corner(UDim.new(0, 14)),
				Components.stroke(3),
				Components.gradient(Theme.lighten(c, 0.72)),
				text({
					Size = UDim2.new(0.5, 0, 0, 28),
					Position = UDim2.fromOffset(14, 6),
					TextXAlignment = Enum.TextXAlignment.Left,
					FontFace = Theme.font.title,
					TextColor3 = c,
					Text = function()
						local level = SkillsSim.levelFor(xp())
						return `{string.upper(skill.name)} · LV {level}`
					end,
					Components.textStroke(2),
				}),
				text({
					Size = UDim2.new(0.5, -14, 0, 22),
					Position = UDim2.new(0.5, 0, 0, 9),
					TextXAlignment = Enum.TextXAlignment.Right,
					FontFace = Theme.font.heading,
					TextColor3 = Theme.darken(Theme.color.wood, 0.3),
					Text = function()
						local level = SkillsSim.levelFor(xp())
						local perks = SkillsSim.perks(level)
						if level >= SkillsConfig.MAX_LEVEL then
							return "MASTERED · cape earned"
						end
						local nextPerk = (perks + 1) * SkillsConfig.PERK_EVERY
						return `Next perk at LV {nextPerk}`
					end,
				}),
				text({
					Size = UDim2.new(1, -28, 0, 18),
					Position = UDim2.fromOffset(14, 34),
					TextXAlignment = Enum.TextXAlignment.Left,
					TextScaled = false,
					TextSize = 15,
					FontFace = Theme.font.body,
					TextColor3 = Theme.darken(Theme.color.wood, 0.2),
					Text = function()
						local level = SkillsSim.levelFor(xp())
						local now = SkillsSim.perkValue(skill.id, level)
						local perk = string.gsub(skill.perk, "{n}", tostring(now))
						return `{skill.blurb}  ·  Now: {perk}`
					end,
				}),
				-- XP bar
				create("Frame")({
					Size = UDim2.new(1, -28, 0, 18),
					Position = UDim2.fromOffset(14, 58),
					BackgroundColor3 = Theme.darken(Theme.color.cream, 0.15),
					Components.corner(UDim.new(1, 0)),
					Components.stroke(2),
					create("Frame")({
						Size = function()
							local _, into, need = SkillsSim.levelFor(xp())
							return UDim2.fromScale(if need > 0 then math.clamp(into / need, 0, 1) else 1, 1)
						end,
						BackgroundColor3 = c,
						Components.corner(UDim.new(1, 0)),
						Components.gloss(UDim.new(1, 0)),
					}),
					text({
						Size = UDim2.fromScale(1, 1),
						ZIndex = 3,
						FontFace = Theme.font.heading,
						TextColor3 = Theme.color.white,
						Text = function()
							local _, into, need = SkillsSim.levelFor(xp())
							return `{NumberFormat.short(into)} / {NumberFormat.short(need)} XP`
						end,
						Components.textStroke(1.5),
					}),
				}),
			})
		)
	end
	return create("ScrollingFrame")({
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ScrollBarThickness = 8,
		VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		create("UIListLayout")({ Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
		Components.padding(4),
		text({
			Size = UDim2.new(1, -8, 0, 36),
			LayoutOrder = 0,
			TextScaled = false,
			TextSize = 16,
			TextWrapped = true,
			FontFace = Theme.font.body,
			TextColor3 = Theme.darken(Theme.color.wood, 0.2),
			Text = "Everything you do levels a skill. Every 10 levels unlocks a perk; level 50 earns a cape nobody can buy.",
		}),
		rows :: any,
	})
end

function Quests.menu(onClose: () -> ()): Instance
	local tab = source("rail")
	local function tabButton(id: string, label: string, color: Color3, order: number): Instance
		return Components.button({
			text = label,
			color = function()
				return if tab() == id then color else Theme.color.wood
			end,
			size = UDim2.new(1 / 5, -8, 1, 0),
			layoutOrder = order,
			textSize = 22,
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
				tabButton("rail", "RAIL PASS", Theme.color.sky, 1),
				tabButton("trail", "BOUNTY TRAIL", Theme.color.orange, 2),
				tabButton("daily", "DAILY", Theme.color.red, 3),
				tabButton("weekly", "WEEKLY", Theme.color.purple, 4),
				tabButton("skills", "SKILLS", Theme.color.green, 5),
			}),
			create("Frame")({
				Size = UDim2.new(1, 0, 1, -56),
				Position = UDim2.fromOffset(0, 56),
				BackgroundTransparency = 1,
				show(function()
					return tab() == "rail"
				end, railPage),
				show(function()
					return tab() == "trail"
				end, trailPage),
				show(function()
					return tab() == "daily"
				end, dailyPage),
				show(function()
					return tab() == "weekly"
				end, weeklyPage),
				show(function()
					return tab() == "skills"
				end, skillsPage),
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
		-- Rail Pass line: tier and XP into the next one.
		text({
			Size = UDim2.new(1, 0, 0, 18),
			LayoutOrder = 50,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Theme.color.sky,
			FontFace = Theme.font.heading,
			Visible = function()
				return season().tier ~= nil
			end,
			Text = function()
				local sn = season()
				local tier = sn.tier or 0
				if tier >= SeasonConfig.PREMIUM_TIERS then
					return `Rail Pass tier {tier} · complete`
				end
				return `Rail Pass tier {tier} · {NumberFormat.short(sn.into or 0)}/{NumberFormat.short(
					sn.next or 0
				)} XP`
			end,
			Components.textStroke(1),
		}),
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
