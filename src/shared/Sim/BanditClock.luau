--!strict
-- Bandit Camp "red light": the bandit naps, then peeks. Steal while he's napping; if he peeks during
-- your grab, you're caught. A head-turn "tell" plays just before every peek so it's fair.

local PERIOD = 7
local PEEK = 1.6
local TELL = 0.7

local BanditClock = {}

BanditClock.GRAB_SECONDS = 2.5
BanditClock.PEEK_SECONDS = PEEK
BanditClock.TELL_SECONDS = TELL

-- Peek start offset inside period `k` (deterministic jitter so it isn't a fixed rhythm).
local function offset(k: number): number
	local h = (k * 2654435761) % 4294967296
	return 3 + (h % 25) / 10 -- 3.0 .. 5.4 s
end

export type State = "napping" | "tell" | "peeking"

function BanditClock.state(t: number): State
	local k = math.floor(t / PERIOD)
	local inPeriod = t - k * PERIOD
	local start = offset(k)
	if inPeriod >= start and inPeriod < start + PEEK then
		return "peeking"
	end
	if inPeriod >= start - TELL and inPeriod < start then
		return "tell"
	end
	return "napping"
end

-- True if the bandit peeks at any moment in [t0, t1].
function BanditClock.peeksDuring(t0: number, t1: number): boolean
	local k0 = math.floor(t0 / PERIOD) - 1
	local k1 = math.floor(t1 / PERIOD) + 1
	for k = k0, k1 do
		local start = k * PERIOD + offset(k)
		local finish = start + PEEK
		if start < t1 and finish > t0 then
			return true
		end
	end
	return false
end

return BanditClock
