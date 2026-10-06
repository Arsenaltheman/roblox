--!strict
-- Live operations: admin income events, Sheriff Powers (Sheriff's Star pass), the in-game
-- leaderboard, emote stickers and bug reports.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local Workspace = game:GetService("Workspace")

local Mutations = require("@game/ReplicatedStorage/Shared/Config/Mutations")
local Products = require("@game/ReplicatedStorage/Shared/Config/Products")
local NumberFormat = require("@game/ReplicatedStorage/Shared/Sim/NumberFormat")
local Net = require("@game/ReplicatedStorage/Shared/Net/Net")
local Registry = require("../Registry")

local LiveOps = {}

local sheriffReadyAt: { [Player]: number } = {}

function LiveOps.incomeEventActive(): boolean
	return Registry.LiveConfig.enabled("event.incomeBoost") or Registry.Events.goldRush()
end

local function sheriffPower(player: Player, power: string, arg: string)
	if not Registry.LiveConfig.enabled("ff.sheriffPowers") then
		return
	end
	if not Registry.Monetization.owns(player, "SheriffStar") then
		Registry.Monetization.prompt(player, "SheriffStar")
		return
	end
	-- Sheriff Powers change random outcomes: never usable where paid random items are restricted.
	if Registry.Monetization.policy(player).randomRestricted then
		Registry.Ui.toast(player, "Sheriff Powers aren't available in your region.")
		return
	end
	local t = os.clock()
	local sd = Registry.Data.get(player)
	-- Saved so leaving and rejoining doesn't reset the recharge.
	local readyAt =
		math.max(sheriffReadyAt[player] or 0, (sd and sd.Stats.SheriffReadyAt or 0) - os.time() + t)
	if t < readyAt then
		local minutes = math.ceil((readyAt - t) / 60)
		Registry.Ui.toast(player, `Your Sheriff Powers recharge in {minutes} min.`)
		return
	end
	if power == "GoldenExpress" then
		Registry.Train.callGoldenExpress(player.DisplayName)
	elseif power == "Weather" then
		if not Mutations.byId[arg] then
			return
		end
		Registry.Weather.start_(arg, Products.sheriffPowers.weatherSeconds)
	elseif power == "Stampede" then
		Registry.Train.startStampede(player.DisplayName)
	else
		return
	end
	sheriffReadyAt[player] = t + Products.sheriffPowers.cooldownSeconds
	if sd then
		sd.Stats.SheriffReadyAt = os.time() + Products.sheriffPowers.cooldownSeconds
	end
	player:SetAttribute(
		"SheriffReadyAt",
		Workspace:GetServerTimeNow() + Products.sheriffPowers.cooldownSeconds
	)
end

local function sticker(player: Player, id: number)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		Registry.Ui.fxAll("sticker", id, root.Position + Vector3.new(0, 4, 0))
	end
end

local bugStore: DataStore? = nil

local function bugReport(player: Player, category: string, text: string)
	if not Registry.LiveConfig.enabled("ff.bugReports") then
		return
	end
	local filtered = ""
	if #text > 0 then
		local ok, result = pcall(function()
			return TextService:FilterStringAsync(text, player.UserId):GetNonChatStringForBroadcastAsync()
		end)
		filtered = if ok then result else ""
	end
	local d = Registry.Data.get(player)
	local entry = {
		t = os.time(),
		user = player.UserId,
		cat = category,
		text = filtered,
		place = game.PlaceVersion,
		frontier = if d then d.Frontier else -1,
		errors = Registry.Telemetry.errorSummary(),
	}
	task.spawn(function()
		local store = bugStore
		if not store then
			return
		end
		local key = "day_" .. math.floor(os.time() / 86400)
		pcall(function()
			store:UpdateAsync(key, function(list)
				list = list or {}
				if #list < 500 then
					table.insert(list, entry)
				end
				return list
			end)
		end)
	end)
	Registry.Ui.toast(player, "Thanks! Bug report sent to the sheriff.")
end

local function setupLeaderstats(player: Player)
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"
	local cash = Instance.new("StringValue")
	cash.Name = "Cash"
	cash.Value = "$0"
	cash.Parent = folder
	local frontier = Instance.new("IntValue")
	frontier.Name = "Frontier"
	frontier.Parent = folder
	folder.Parent = player
end

function LiveOps.init()
	local ok, store = pcall(function()
		return DataStoreService:GetDataStore("BugReports_v1")
	end)
	if ok then
		bugStore = store
	end
end

function LiveOps.start()
	Net.on("SheriffPower", sheriffPower)
	Net.on("Sticker", sticker)
	Net.on("BugReport", bugReport)
	for _, player in Players:GetPlayers() do
		setupLeaderstats(player)
	end
	Players.PlayerAdded:Connect(setupLeaderstats)
	Players.PlayerRemoving:Connect(function(player)
		sheriffReadyAt[player] = nil
	end)
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 1 then
			return
		end
		accumulator = 0
		Workspace:SetAttribute("IncomeEvent", LiveOps.incomeEventActive())
		for _, player in Players:GetPlayers() do
			local d = Registry.Data.get(player)
			local stats = player:FindFirstChild("leaderstats")
			if d and stats then
				(stats:FindFirstChild("Cash") :: StringValue).Value = NumberFormat.cash(d.Cash);
				(stats:FindFirstChild("Frontier") :: IntValue).Value = d.Frontier
			end
		end
	end)
end

return LiveOps
