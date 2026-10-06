--!strict
-- Live-tunable values and kill switches from Roblox Configs (ConfigService), with safe defaults.
-- If Configs can't load, every key falls back to src/shared/Config/Flags.luau, so the game always runs.

local ConfigService = game:GetService("ConfigService")

local Flags = require("@game/ReplicatedStorage/Shared/Config/Flags")
local Signal = require("@game/ReplicatedStorage/Shared/Util/Signal")

local LiveConfig = {}

local snapshot: ConfigSnapshot? = nil
LiveConfig.changed = Signal.new() :: Signal.Signal<string, any>

-- Returns the live value for `key` if it has the same type as the default, else the default.
function LiveConfig.get(key: string): any
	local default = Flags[key]
	if snapshot then
		local ok, value = pcall(function()
			return (snapshot :: ConfigSnapshot):GetValue(key)
		end)
		if ok and value ~= nil and (default == nil or typeof(value) == typeof(default)) then
			return value
		end
	end
	return default
end

function LiveConfig.enabled(flag: string): boolean
	return LiveConfig.get(flag) == true
end

function LiveConfig.init()
	local ok, result = pcall(function()
		return ConfigService:GetConfigAsync()
	end)
	if not ok then
		warn("[LiveConfig] Configs unavailable, using defaults: " .. tostring(result))
		return
	end
	local snap = result :: ConfigSnapshot
	snapshot = snap
	snap.UpdateAvailable:Connect(function()
		snap:Refresh()
	end)
	for key: string in Flags :: any do
		snap:GetValueChangedSignal(key):Connect(function()
			LiveConfig.changed:Fire(key, LiveConfig.get(key))
		end)
	end
end

function LiveConfig.start() end

return LiveConfig
