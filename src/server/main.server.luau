--!strict
-- Server entry point (the only server Script). Boots every service in a fixed order:
-- all init() first (no yielding cross-service calls), then all start().

local Net = require("@game/ReplicatedStorage/Shared/Net/Net")
local Registry = require("./Registry")

local ORDER = {
	"World",
	"LiveConfig",
	"Telemetry",
	"Guard",
	"Data",
	"Session",
	"Wallet",
	"Monetization",
	"Ui",
	"Ranch",
	"Train",
	"Weather",
	"Eggs",
	"Progression",
	"Steal",
	"Heist",
	"Wheel",
	"Gear",
	"Trade",
	"Shop",
	"LiveOps",
	"Boss",
	"Events",
	"Leaderboards",
	"Trail",
	"Season",
	"Posse",
	"Afk",
}

local services = script.Parent:WaitForChild("Services")
for _, name in ORDER do
	Registry[name] = (require :: any)(services:WaitForChild(name))
end

Net.initServer()

-- Failures are logged and recorded (the cloud smoke test reads BootFailures) but don't stop the boot.
local failures: { string } = {}
for _, name in ORDER do
	local ok, err = pcall(Registry[name].init)
	if not ok then
		warn(`[Boot] {name}.init failed: {err}`)
		table.insert(failures, name .. ".init")
	end
end
for _, name in ORDER do
	local ok, err = pcall(Registry[name].start)
	if not ok then
		warn(`[Boot] {name}.start failed: {err}`)
		table.insert(failures, name .. ".start")
	end
end

local Workspace = game:GetService("Workspace")
Workspace:SetAttribute("BootFailures", table.concat(failures, ","))
Workspace:SetAttribute("ServerReady", true)
print("[Boot] Critter Express server ready")
