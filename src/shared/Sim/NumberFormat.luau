--!strict
-- Turns big numbers into short labels: 950, 1.23K, 45.6M, 789B, 1.2T, 3.4Qa ...

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

local NumberFormat = {}

local function trimZeros(s: string): string
	if string.find(s, "%.") then
		s = string.gsub(s, "0+$", "")
		s = string.gsub(s, "%.$", "")
	end
	return s
end

-- Three significant digits with a suffix. Values below 1000 are shown as whole numbers.
function NumberFormat.short(n: number): string
	if n ~= n then
		return "0"
	end
	if n == math.huge or n == -math.huge then
		return if n > 0 then "∞" else "-∞"
	end
	local sign = if n < 0 then "-" else ""
	local value = math.abs(n)
	if value < 1000 then
		return sign .. tostring(math.floor(value))
	end
	local group = math.floor(math.log10(value) / 3)
	if group >= #SUFFIXES then
		return sign .. string.format("%.2e", value)
	end
	local scaled = value / 10 ^ (group * 3)
	-- Truncate (never round up): a player must never see more cash than they have.
	local text
	if scaled >= 100 then
		text = tostring(math.floor(scaled))
	elseif scaled >= 10 then
		text = trimZeros(string.format("%.1f", math.floor(scaled * 10) / 10))
	else
		text = trimZeros(string.format("%.2f", math.floor(scaled * 100) / 100))
	end
	-- Rounding can still produce "1000K"; bump to the next suffix.
	if text == "1000" and group + 1 < #SUFFIXES then
		return sign .. "1" .. SUFFIXES[group + 2]
	end
	return sign .. text .. SUFFIXES[group + 1]
end

function NumberFormat.cash(n: number): string
	return "$" .. NumberFormat.short(n)
end

function NumberFormat.perSecond(n: number): string
	return "$" .. NumberFormat.short(n) .. "/s"
end

-- 75 -> "1:15", 3725 -> "1:02:05"
function NumberFormat.clock(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	local h = s // 3600
	local m = (s % 3600) // 60
	local sec = s % 60
	if h > 0 then
		return string.format("%d:%02d:%02d", h, m, sec)
	end
	return string.format("%d:%02d", m, sec)
end

-- Odds labels: 0.05 -> "1 in 20"
function NumberFormat.oneIn(probability: number): string
	if probability <= 0 then
		return "never"
	end
	if probability >= 1 then
		return "always"
	end
	return "1 in " .. NumberFormat.short(math.floor(1 / probability + 0.5))
end

return NumberFormat
