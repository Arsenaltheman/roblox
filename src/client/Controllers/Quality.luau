--!strict
-- Picks a visual quality tier (1 = low, 2 = medium, 3 = high) from the device and live frame time,
-- and steps down automatically if frames get slow. Effects read Store.quality().

local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Store = require("../Store")

local Quality = {}

local function initialTier(): number
	local ok, level = pcall(function()
		return UserSettings():GetService("UserGameSettings").SavedQualityLevel
	end)
	local tier = 2
	if ok and level and level ~= Enum.SavedQualitySetting.Automatic then
		local n = tonumber(string.match(tostring(level), "%d+")) or 5
		tier = if n <= 3 then 1 elseif n <= 7 then 2 else 3
	else
		local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
		tier = if touch then 2 else 3
	end
	local okSize, size = pcall(function()
		return GuiService.ViewportDisplaySize
	end)
	if okSize and size == Enum.DisplaySize.Small then
		tier = math.min(tier, 2)
	end
	return tier
end

function Quality.reducedMotion(): boolean
	local ok, value = pcall(function()
		return GuiService.ReducedMotionEnabled
	end)
	local state = Store.state()
	return (ok and value == true) or (state ~= nil and state.settings and state.settings.ReducedFx == true)
end

function Quality.init()
	Store.quality(initialTier())
end

local FIXED = { low = 1, medium = 2, high = 3 }

local function chosen(): string
	local state = Store.state()
	return (state and state.settings and state.settings.Quality) or "auto"
end

function Quality.start()
	-- The player's saved choice wins; "auto" uses the device guess plus the governor below.
	local applied = "auto"
	local autoTier = Store.quality()
	local window, frames = 0, 0
	local started = os.clock()
	RunService.Heartbeat:Connect(function(dt)
		local choice = chosen()
		if choice ~= applied then
			applied = choice
			Store.quality(FIXED[choice] or autoTier)
		end
		if FIXED[choice] then
			return
		end
		-- Frame-time governor: if frames average under 25 FPS for 5 s, drop a tier. The first 10 s are
		-- ignored (loading hitches).
		if os.clock() - started < 10 then
			return
		end
		window += dt
		frames += 1
		if window >= 5 then
			local avg = window / frames
			if avg > 1 / 25 and Store.quality() > 1 then
				autoTier = Store.quality() - 1
				Store.quality(autoTier)
			end
			window, frames = 0, 0
		end
	end)
end

return Quality
