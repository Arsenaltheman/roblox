--!strict
-- Server -> client UI messages: toasts, server-wide announcements, reveals, effects and the
-- player's private state (throttled snapshots of their save data for HUD and menus).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Net = require("@game/ReplicatedStorage/Shared/Net/Net")
local Registry = require("../Registry")

local STATE_MIN_INTERVAL = 0.25

local Ui = {}

local dirty: { [Player]: boolean } = {}
local lastPush: { [Player]: number } = {}

function Ui.toast(player: Player, text: string)
	Net.send(player, "Toast", text)
end

-- kind lets the client pick colors/sounds (a rarity id, "golden", "luck", "frontier", "steal", ...).
function Ui.announce(text: string, kind: string?)
	Net.broadcast("Announce", text, kind or "info")
end

function Ui.reveal(player: Player, data: { [string]: any })
	Net.send(player, "Reveal", data)
end

-- Effects only the owner needs (cash pops, lock sound). World effects use Ui.fxAll.
function Ui.fx(player: Player, kind: string, value: number?)
	Net.send(player, "Fx", kind, value or 0)
end

function Ui.fxAll(kind: string, value: number?, position: Vector3?)
	Net.broadcast("Fx", kind, value or 0, position)
end

-- Mark state as changed; it is sent at most every STATE_MIN_INTERVAL seconds.
function Ui.pushState(player: Player)
	dirty[player] = true
end

local function snapshot(player: Player): { [string]: any }?
	local d = Registry.Data.get(player)
	if not d then
		return nil
	end
	local critters = {}
	for cid, critter in d.Critters do
		critters[cid] = {
			s = critter.s,
			t = critter.tier,
			m = critter.m,
			p = critter.p,
			br = critter.br,
			pr = critter.pr,
			it = critter.it,
		}
	end
	return {
		cash = d.Cash,
		nuggets = d.Nuggets,
		frontier = d.Frontier,
		critters = critters,
		eggs = d.Eggs,
		almanac = d.Almanac,
		quests = Registry.Progression.questView(player),
		trail = Registry.Trail.view(player),
		streak = d.Streak,
		gifts = Registry.Progression.giftView(player),
		owned = d.Owned,
		equipped = d.Equipped,
		boosts = d.Boosts,
		settings = d.Settings,
		tutorial = d.Tutorial,
		pity = d.StrongboxPity,
		lockpicks = d.Stats.Lockpicks or 0,
		heists = d.Stats.Heists or 0,
		boots = d.Stats.Boots or 0,
		starterPack = d.StarterPack,
		pending = Registry.Progression.pendingView(player),
		shop = Registry.Shop.stockView(player),
		mayPrompt = Registry.Monetization.mayPrompt(player),
	}
end

function Ui.init() end

function Ui.start()
	Registry.Wallet.changed:Connect(Ui.pushState)
	Registry.Data.loaded:Connect(function(player)
		Ui.pushState(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		dirty[player] = nil
		lastPush[player] = nil
	end)
	local heartbeatAccumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		heartbeatAccumulator += dt
		local forceAll = heartbeatAccumulator >= 2
		if forceAll then
			heartbeatAccumulator = 0
		end
		local now = os.clock()
		for _, player in Players:GetPlayers() do
			if (dirty[player] or forceAll) and now - (lastPush[player] or 0) >= STATE_MIN_INTERVAL then
				local snap = snapshot(player)
				if snap then
					dirty[player] = nil
					lastPush[player] = now
					Net.send(player, "State", snap)
				end
			end
		end
	end)
end

return Ui
