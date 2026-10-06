--!strict
-- Analytics (funnels, economy, progression, custom events) and error capture.
-- Every call is wrapped in pcall: analytics must never break gameplay.

local AnalyticsService = game:GetService("AnalyticsService")
local ScriptContext = game:GetService("ScriptContext")

local Net = require("@game/ReplicatedStorage/Shared/Net/Net")

local Telemetry = {}

-- Onboarding funnel steps (order matters; Roblox charts the drop-off between them).
Telemetry.ONBOARDING = {
	"Spawned",
	"FirstBuy",
	"FirstCollect",
	"FirstEgg",
	"FirstLasso",
	"FirstSteal",
	"FirstQuest",
	"Played15Min",
	"FirstFrontier",
}

local stepIndex: { [string]: number } = {}
for i, name in Telemetry.ONBOARDING do
	stepIndex[name] = i
end

local errorCounts: { [string]: number } = {}

local function safe(fn: () -> ())
	local ok, err = pcall(fn :: any)
	if not ok then
		warn("[Telemetry] " .. tostring(err))
	end
end

function Telemetry.onboarding(player: Player, step: string)
	local index = stepIndex[step]
	if not index then
		return
	end
	safe(function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, index, step)
	end)
end

-- reason: what caused the change (e.g. "BuyCage", "Collect", "Gift", "Robux:CashBag1h").
function Telemetry.economy(player: Player, currency: string, amount: number, balance: number, reason: string)
	if amount == 0 then
		return
	end
	local flow = if amount > 0
		then Enum.AnalyticsEconomyFlowType.Source
		else Enum.AnalyticsEconomyFlowType.Sink
	local transaction = if string.sub(reason, 1, 6) == "Robux:"
		then Enum.AnalyticsEconomyTransactionType.IAP.Name
		elseif amount > 0 then Enum.AnalyticsEconomyTransactionType.Gameplay.Name
		else Enum.AnalyticsEconomyTransactionType.Shop.Name
	safe(function()
		AnalyticsService:LogEconomyEvent(
			player,
			flow,
			currency,
			math.abs(amount),
			balance,
			transaction,
			reason
		)
	end)
end

function Telemetry.progression(player: Player, path: string, level: number)
	safe(function()
		AnalyticsService:LogProgressionCompleteEvent(player, path, level)
	end)
end

function Telemetry.custom(player: Player, name: string, value: number?)
	safe(function()
		AnalyticsService:LogCustomEvent(player, name, value or 1)
	end)
end

-- Short stable hash of an error so repeats are counted, not spammed.
local function hash(text: string): string
	local h = 5381
	for i = 1, math.min(#text, 200) do
		h = (h * 33 + string.byte(text, i)) % 4294967296
	end
	return string.format("%08x", h)
end

function Telemetry.error(source: string, message: string, trace: string?)
	local key = hash(source .. message .. (trace or ""))
	errorCounts[key] = (errorCounts[key] or 0) + 1
	-- Log the first few occurrences in full; afterwards only count.
	if errorCounts[key] <= 3 then
		warn(`[Error {key}] {source}: {message}\n{trace or ""}`)
	end
end

function Telemetry.errorSummary(): { [string]: number }
	return table.clone(errorCounts)
end

function Telemetry.init()
	ScriptContext.Error:Connect(function(message, trace)
		Telemetry.error("server", message, trace)
	end)
end

function Telemetry.start()
	Net.on("ClientLog", function(player, level: number, message: string)
		Telemetry.error(`client:{player.UserId}:L{level}`, message)
	end)
end

return Telemetry
