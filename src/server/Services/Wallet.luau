--!strict
-- The ONLY place currencies change. Every change carries a reason (analytics + audits).

local Economy = require("@game/ReplicatedStorage/Shared/Sim/Economy")
local Signal = require("@game/ReplicatedStorage/Shared/Util/Signal")
local Registry = require("../Registry")

local Wallet = {}

Wallet.changed = Signal.new() :: Signal.Signal<Player>

local function data(player: Player)
	return Registry.Data.get(player)
end

function Wallet.cash(player: Player): number
	local d = data(player)
	return if d then d.Cash else 0
end

function Wallet.nuggets(player: Player): number
	local d = data(player)
	return if d then d.Nuggets else 0
end

function Wallet.addCash(player: Player, amount: number, reason: string): boolean
	local d = data(player)
	if not d or amount ~= amount or amount <= 0 then
		return false
	end
	d.Cash = Economy.clampCash(d.Cash + amount)
	d.LifetimeCash += amount
	Registry.Telemetry.economy(player, "Cash", amount, d.Cash, reason)
	Wallet.changed:Fire(player)
	return true
end

function Wallet.trySpendCash(player: Player, amount: number, reason: string): boolean
	local d = data(player)
	if not d or amount ~= amount or amount < 0 or d.Cash < amount then
		return false
	end
	d.Cash = Economy.clampCash(d.Cash - amount)
	Registry.Telemetry.economy(player, "Cash", -amount, d.Cash, reason)
	Wallet.changed:Fire(player)
	return true
end

-- Gold Nuggets: earned only, never sold for Robux (keeps eggs out of "paid random items").
function Wallet.addNuggets(player: Player, amount: number, reason: string): boolean
	local d = data(player)
	if not d or amount ~= amount or amount <= 0 then
		return false
	end
	assert(string.sub(reason, 1, 6) ~= "Robux:", "Nuggets can never come from Robux")
	d.Nuggets += math.floor(amount)
	Registry.Telemetry.economy(player, "Nuggets", amount, d.Nuggets, reason)
	Wallet.changed:Fire(player)
	return true
end

function Wallet.trySpendNuggets(player: Player, amount: number, reason: string): boolean
	local d = data(player)
	if not d or amount ~= amount or amount < 0 or d.Nuggets < amount then
		return false
	end
	d.Nuggets -= amount
	Registry.Telemetry.economy(player, "Nuggets", -amount, d.Nuggets, reason)
	Wallet.changed:Fire(player)
	return true
end

function Wallet.init() end
function Wallet.start() end

return Wallet
