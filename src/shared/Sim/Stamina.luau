--!strict
-- Sprint stamina. The server runs this to decide the real walk speed; the client runs the same math to
-- predict the stamina bar without waiting on the network. Pure (time is passed in): unit-tested.
--
-- `value` is 0..1. Sprinting drains it (faster while carrying); once you stop, it waits a short
-- delay and then refills. Running dry ends the sprint, and you must let go and press again.

local Stamina = {}

Stamina.MULTIPLIER = 1.3 -- sprint speed on top of boots / passes / carry
Stamina.DRAIN_SECONDS = 5 -- full bar of sprinting (not carrying)
Stamina.REFILL_SECONDS = 4 -- empty -> full
Stamina.REFILL_DELAY = 0.8 -- pause after a sprint before the bar refills
Stamina.CARRY_DRAIN = 1.5 -- carrying a critter or crate drains this much faster
-- Starting a sprint needs a little in the tank, so a dry bar can't flicker sprint on and off.
Stamina.MIN_START = 0.15

export type State = {
	value: number,
	active: boolean,
	-- Time the last sprint ended (refill starts REFILL_DELAY after it).
	restedAt: number,
	-- Time `value` was last brought up to date.
	updated: number,
}

function Stamina.new(now: number): State
	return { value = 1, active = false, restedAt = -math.huge, updated = now }
end

-- Bring the bar up to `now`. `draining` = sprinting AND actually moving (standing still while holding
-- sprint costs nothing). Returns true if the bar just ran dry (the sprint ended).
function Stamina.advance(s: State, now: number, draining: boolean, carrying: boolean): boolean
	local dt = math.max(0, now - s.updated)
	s.updated = now
	if s.active then
		if draining then
			local rate = (if carrying then Stamina.CARRY_DRAIN else 1) / Stamina.DRAIN_SECONDS
			if s.value - dt * rate <= 0 then
				-- Rest from the moment it actually ran dry, not from this (possibly late) update.
				s.restedAt = now - dt + s.value / rate
				s.value = 0
				s.active = false
				return true
			end
			s.value -= dt * rate
		end
		return false
	end
	-- Only the part of dt after the refill delay counts.
	local refillFrom = s.restedAt + Stamina.REFILL_DELAY
	local refillTime = math.min(dt, math.max(0, now - refillFrom))
	if refillTime > 0 then
		s.value = math.min(1, s.value + refillTime / Stamina.REFILL_SECONDS)
	end
	return false
end

-- Try to start or stop sprinting (call advance first). Returns the new active flag.
function Stamina.set(s: State, now: number, on: boolean): boolean
	if on and not s.active then
		if s.value >= Stamina.MIN_START then
			s.active = true
		end
	elseif not on and s.active then
		s.active = false
		s.restedAt = now
	end
	return s.active
end

return Stamina
