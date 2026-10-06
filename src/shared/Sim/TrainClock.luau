--!strict
-- Where the train is at any moment, as a pure function of (epoch, now).
-- The server never simulates the train: clients render from this and the server uses it to validate requests.

local Train = require("../Config/Train")

export type Phase = "arriving" | "dwelling" | "departing"

export type State = {
	cycle: number,
	phase: Phase,
	-- Seconds since this phase started, and the phase length.
	inPhase: number,
	phaseLength: number,
	-- 0..1 progress through the phase (for animation).
	progress: number,
	-- Seconds since the cycle started.
	inCycle: number,
	doorsOpen: boolean,
	hasStrongbox: boolean,
}

local TrainClock = {}

function TrainClock.cycleLength(): number
	return Train.arriveSeconds + Train.dwellSeconds + Train.departSeconds
end

function TrainClock.hasStrongbox(cycle: number): boolean
	return cycle % Train.strongboxEvery == Train.strongboxEvery - 1
end

function TrainClock.at(epoch: number, now: number): State
	local length = TrainClock.cycleLength()
	local elapsed = math.max(0, now - epoch)
	local cycle = math.floor(elapsed / length)
	local inCycle = elapsed - cycle * length

	local phase: Phase
	local inPhase: number
	local phaseLength: number
	if inCycle < Train.arriveSeconds then
		phase, inPhase, phaseLength = "arriving", inCycle, Train.arriveSeconds
	elseif inCycle < Train.arriveSeconds + Train.dwellSeconds then
		phase, inPhase, phaseLength = "dwelling", inCycle - Train.arriveSeconds, Train.dwellSeconds
	else
		phase = "departing"
		inPhase = inCycle - Train.arriveSeconds - Train.dwellSeconds
		phaseLength = Train.departSeconds
	end

	return {
		cycle = cycle,
		phase = phase,
		inPhase = inPhase,
		phaseLength = phaseLength,
		progress = inPhase / phaseLength,
		inCycle = inCycle,
		doorsOpen = phase == "dwelling" and inPhase >= Train.doorsOpenDelay,
		hasStrongbox = TrainClock.hasStrongbox(cycle),
	}
end

-- Server time at which a cycle's doors open (for countdowns).
function TrainClock.doorsOpenTime(epoch: number, cycle: number): number
	return epoch + cycle * TrainClock.cycleLength() + Train.arriveSeconds + Train.doorsOpenDelay
end

-- Server time at which a cycle departs (for "Departing in 5..." countdowns).
function TrainClock.departTime(epoch: number, cycle: number): number
	return epoch + cycle * TrainClock.cycleLength() + Train.arriveSeconds + Train.dwellSeconds
end

-- Can a cage on `cycle` be bought at `now`? Allows a small grace for network latency.
function TrainClock.canBuy(epoch: number, cycle: number, now: number, graceSeconds: number?): boolean
	local grace = graceSeconds or 0
	local opens = TrainClock.doorsOpenTime(epoch, cycle)
	local closes = TrainClock.departTime(epoch, cycle)
	return now >= opens and now <= closes + grace
end

return TrainClock
