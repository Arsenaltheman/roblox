--!strict
-- Daily login streak with one forgiven missed day. Days are UTC calendar days.

local Progression = require("../Config/Progression")

export type State = {
	count: number,
	lastDay: number,
	graceUsed: boolean,
}

export type Result = {
	state: State,
	-- True when today's reward should be granted (first login of a new day).
	reward: boolean,
	-- 1..7 reward slot for today.
	slot: number,
	broke: boolean,
}

local Streak = {}

function Streak.dayOf(unixSeconds: number): number
	return math.floor(unixSeconds / 86400)
end

function Streak.new(): State
	return { count = 0, lastDay = -1, graceUsed = false }
end

local function slotFor(count: number): number
	local n = #Progression.streak.rewards
	return math.min(count, n)
end

Streak.slotFor = slotFor

function Streak.login(state: State, unixSeconds: number): Result
	local today = Streak.dayOf(unixSeconds)
	if today == state.lastDay then
		return { state = state, reward = false, slot = slotFor(state.count), broke = false }
	end
	local gap = today - state.lastDay
	local nextState: State
	local broke = false
	if state.lastDay < 0 then
		nextState = { count = 1, lastDay = today, graceUsed = false }
	elseif gap == 1 then
		nextState = { count = state.count + 1, lastDay = today, graceUsed = state.graceUsed }
	elseif gap == 1 + Progression.streak.graceDays and not state.graceUsed then
		nextState = { count = state.count + 1, lastDay = today, graceUsed = true }
	elseif gap < 0 then
		-- Clock went backwards (device or server skew): keep the streak, don't reward.
		return { state = state, reward = false, slot = slotFor(state.count), broke = false }
	else
		nextState = { count = 1, lastDay = today, graceUsed = false }
		broke = true
	end
	-- A full week earns the grace day back.
	if nextState.count % #Progression.streak.rewards == 0 then
		nextState.graceUsed = false
	end
	return { state = nextState, reward = true, slot = slotFor(nextState.count), broke = broke }
end

-- Seconds until the next UTC day starts (for the real countdown on the streak screen).
function Streak.secondsUntilNextDay(unixSeconds: number): number
	return 86400 - (unixSeconds % 86400)
end

return Streak
