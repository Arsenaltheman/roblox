--!strict
-- Default values for live config. Production values come from Roblox Configs (LiveConfig service);
-- anything missing or invalid falls back to these.

return {
	-- Kill switches
	["ff.stealing"] = true,
	["ff.lasso"] = true,
	["ff.goldenExpress"] = true,
	["ff.eggs"] = true,
	["ff.weather"] = true,
	["ff.offline"] = true,
	["ff.luckProducts"] = true,
	["ff.sheriffPowers"] = true,
	["ff.bugReports"] = true,
	["ff.trading"] = false,

	-- Dials
	["econ.incomeScale"] = 1,
	["vfx.maxTier"] = 4,

	-- Live events: flip on during Saturday admin events (2x income for everyone while true).
	["event.incomeBoost"] = false,
}
