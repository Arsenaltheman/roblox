--!strict
-- Leaderboards: Richest Ranchers (west end of the platform), Top Heisters (east end) and Most
-- Wanted by steals (Bandit Camp). Each shows THIS SERVER live and ALL-TIME (OrderedDataStore, refreshed every
-- couple of minutes; skipped quietly if data stores aren't available, e.g. Studio without API
-- access). The all-time #1 rancher stands as a gold statue next to the Richest board.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local NumberFormat = require("@game/ReplicatedStorage/Shared/Sim/NumberFormat")
local Registry = require("../Registry")

local Leaderboards = {}

type Board = {
	id: string,
	title: string,
	color: Color3,
	value: (Player) -> number,
	format: (number) -> string,
	position: Vector3,
	facing: Vector3,
	store: OrderedDataStore?,
	allTime: { { name: string, value: number, userId: number } },
	server: TextLabel?,
	global: TextLabel?,
}

local function stat(name: string): (Player) -> number
	return function(player: Player): number
		local d = Registry.Data.get(player)
		return if d then (d.Stats[name] or 0) else 0
	end
end

local boards: { Board } = {
	{
		id = "Income",
		title = "RICHEST RANCHERS",
		color = Color3.fromRGB(255, 200, 61),
		value = function(player: Player): number
			return Registry.Ranch.income(player)
		end,
		format = function(n: number): string
			return NumberFormat.perSecond(n)
		end,
		position = Vector3.new(-62, 7, 12),
		facing = Vector3.new(1, 0, 0),
		allTime = {},
	},
	{
		id = "Heists",
		title = "TOP HEISTERS",
		color = Color3.fromRGB(63, 183, 176),
		value = stat("Heists"),
		format = function(n: number): string
			return `{NumberFormat.short(n)} crates`
		end,
		position = Vector3.new(62, 7, 12),
		facing = Vector3.new(-1, 0, 0),
		allTime = {},
	},
	{
		id = "Steals",
		title = "MOST WANTED",
		color = Color3.fromRGB(226, 70, 58),
		value = stat("Steals"),
		format = function(n: number): string
			return `{NumberFormat.short(n)} steals`
		end,
		-- At the Bandit Camp, where outlaws hang out.
		position = Vector3.new(-134, 7, 60),
		facing = Vector3.new(1, 0, 0),
		allTime = {},
	},
}

local names: { [number]: string } = {}
local function nameOf(userId: number): string
	local cached = names[userId]
	if cached then
		return cached
	end
	local ok, result = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	local name = if ok and result then result else "Rancher"
	names[userId] = name
	return name
end

local function textLabel(
	parent: Instance,
	size: UDim2,
	pos: UDim2,
	text: string,
	color: Color3,
	font: Enum.Font
): TextLabel
	local l = Instance.new("TextLabel")
	l.Size = size
	l.Position = pos
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextColor3 = color
	l.FontFace = Font.fromEnum(font)
	l.TextScaled = true
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Top
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(43, 29, 20)
	stroke.Parent = l
	l.Parent = parent
	return l
end

local function buildBoard(board: Board, parent: Instance)
	local model = Instance.new("Model")
	model.Name = "Leaderboard_" .. board.id
	local cf = CFrame.lookAt(board.position, board.position + board.facing)
	local panel = Instance.new("Part")
	panel.Name = "Panel"
	panel.Anchored = true
	panel.Size = Vector3.new(16, 11, 0.8)
	panel.CFrame = cf
	panel.Color = Color3.fromRGB(91, 58, 38)
	panel.Material = Enum.Material.WoodPlanks
	panel.Parent = model
	for _, side in { -1, 1 } do
		local post = Instance.new("Part")
		post.Anchored = true
		post.Size = Vector3.new(1, 13, 1)
		post.CFrame = cf * CFrame.new(side * 8.4, -0.5, 0)
		post.Color = Color3.fromRGB(91, 58, 38)
		post.Material = Enum.Material.Wood
		post.Parent = model
	end
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Front
	light.Color = board.color
	light.Brightness = 1.5
	light.Range = 18
	light.Parent = panel

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(640, 440)
	gui.LightInfluence = 0.2
	gui.Parent = panel
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(243, 226, 192)
	bg.Parent = gui
	local header = Instance.new("Frame")
	header.Size = UDim2.new(1, 0, 0, 74)
	header.BackgroundColor3 = board.color
	header.BorderSizePixel = 0
	header.Parent = bg
	local title = textLabel(
		header,
		UDim2.new(1, -20, 1, -12),
		UDim2.fromOffset(10, 6),
		board.title,
		Color3.new(1, 1, 1),
		Enum.Font.LuckiestGuy
	)
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.TextYAlignment = Enum.TextYAlignment.Center
	local ink = Color3.fromRGB(43, 29, 20)
	textLabel(
		bg,
		UDim2.new(0.5, -20, 0, 34),
		UDim2.fromOffset(14, 84),
		"THIS SERVER",
		board.color,
		Enum.Font.LuckiestGuy
	)
	textLabel(
		bg,
		UDim2.new(0.5, -20, 0, 34),
		UDim2.new(0.5, 6, 0, 84),
		"ALL-TIME",
		board.color,
		Enum.Font.LuckiestGuy
	)
	board.server = textLabel(
		bg,
		UDim2.new(0.5, -20, 1, -136),
		UDim2.fromOffset(14, 124),
		"...",
		ink,
		Enum.Font.FredokaOne
	)
	board.global = textLabel(
		bg,
		UDim2.new(0.5, -20, 1, -136),
		UDim2.new(0.5, 6, 0, 124),
		"...",
		ink,
		Enum.Font.FredokaOne
	)
	for _, l in { board.server, board.global } do
		local s = (l :: TextLabel):FindFirstChildOfClass("UIStroke")
		if s then
			s:Destroy()
		end
		local limit = Instance.new("UITextSizeConstraint")
		limit.MaxTextSize = 30
		limit.Parent = l
	end
	model.Parent = parent
end

local MEDALS = { "🥇", "🥈", "🥉" }

local function lines(entries: { any }, format: (number) -> string): string
	if #entries == 0 then
		return "Nobody yet. Be first!"
	end
	local out = {}
	for i, e in entries do
		if i > 8 then
			break
		end
		table.insert(out, `{MEDALS[i] or (tostring(i) .. ".")} {e.name}  {format(e.value)}`)
	end
	return table.concat(out, "\n")
end

local function refreshServer()
	for _, board in boards do
		local entries = {}
		for _, player in Players:GetPlayers() do
			if Registry.Data.get(player) then
				table.insert(entries, { name = player.DisplayName, value = board.value(player) })
			end
		end
		table.sort(entries, function(a, b)
			return a.value > b.value
		end)
		if board.server then
			(board.server :: TextLabel).Text = lines(entries, board.format)
		end
	end
end

local statue: Model? = nil
local statueUser = 0

local function updateStatue(userId: number)
	if userId == statueUser or userId <= 0 then
		return
	end
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromUserIdAsync(userId)
	end)
	if not ok or not model then
		return
	end
	statueUser = userId
	if statue then
		statue:Destroy()
	end
	local m = model :: Model
	m.Name = "ChampionStatue"
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.Material = Enum.Material.Foil
			d.Color = Color3.fromRGB(255, 200, 61)
		elseif d:IsA("Decal") then
			d.Color3 = Color3.fromRGB(255, 200, 61)
		end
	end
	local humanoid = m:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	m:PivotTo(CFrame.lookAt(Vector3.new(-62, 3, 22), Vector3.new(0, 3, 22)))
	local town = Workspace:FindFirstChild("Town")
	m.Parent = town or Workspace
	statue = m
end

local function refreshGlobal()
	-- Save everyone's current values, then read the top lists.
	for _, board in boards do
		local store = board.store
		if store then
			for _, player in Players:GetPlayers() do
				if Registry.Data.get(player) then
					local value = math.floor(math.min(board.value(player), 9e15))
					pcall(function()
						store:SetAsync(tostring(player.UserId), value)
					end)
				end
			end
			local ok, pages = pcall(function()
				return store:GetSortedAsync(false, 8)
			end)
			if ok and pages then
				local entries = {}
				for _, item in (pages :: DataStorePages):GetCurrentPage() do
					local userId = tonumber(item.key) or 0
					table.insert(entries, { name = nameOf(userId), value = item.value, userId = userId })
				end
				board.allTime = entries
				if board.global then
					(board.global :: TextLabel).Text = lines(entries, board.format)
				end
				if board.id == "Income" and entries[1] then
					updateStatue(entries[1].userId)
				end
			end
		elseif board.global then
			(board.global :: TextLabel).Text = "Turns on once the game is published."
		end
	end
end

function Leaderboards.init()
	for _, board in boards do
		local ok, store = pcall(function()
			return DataStoreService:GetOrderedDataStore("Lb_" .. board.id .. "_v1")
		end)
		if ok then
			board.store = store
		end
	end
end

function Leaderboards.start()
	local town = Workspace:FindFirstChild("Town") or Workspace
	for _, board in boards do
		buildBoard(board, town)
	end
	task.spawn(function()
		while true do
			pcall(refreshServer)
			task.wait(5)
		end
	end)
	task.spawn(function()
		task.wait(20)
		while true do
			pcall(refreshGlobal)
			task.wait(120)
		end
	end)
end

return Leaderboards
