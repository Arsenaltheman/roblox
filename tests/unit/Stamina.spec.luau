local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local Stamina = require("../../src/shared/Sim/Stamina")
local Schemas = require("../../src/shared/Net/Schemas")

local function near(a: number, b: number): boolean
	return math.abs(a - b) < 1e-6
end

return function()
	test.suite("Stamina", function()
		test.case("a full bar lasts DRAIN_SECONDS of running", function()
			local s = Stamina.new(0)
			check.is_true(Stamina.set(s, 0, true))
			check.is_false(Stamina.advance(s, Stamina.DRAIN_SECONDS - 0.1, true, false))
			check.is_true(s.active)
			check.is_true(Stamina.advance(s, Stamina.DRAIN_SECONDS + 0.01, true, false))
			check.is_false(s.active)
			check.equal(s.value, 0)
		end)

		test.case("carrying drains CARRY_DRAIN times faster", function()
			local s = Stamina.new(0)
			Stamina.set(s, 0, true)
			Stamina.advance(s, 1, true, true)
			check.is_true(near(s.value, 1 - Stamina.CARRY_DRAIN / Stamina.DRAIN_SECONDS))
		end)

		test.case("standing still while sprinting costs nothing", function()
			local s = Stamina.new(0)
			Stamina.set(s, 0, true)
			Stamina.advance(s, 3, false, false)
			check.equal(s.value, 1)
		end)

		test.case("refill waits for the delay, then fills in REFILL_SECONDS", function()
			local s = Stamina.new(0)
			Stamina.set(s, 0, true)
			Stamina.advance(s, 10, true, false) -- runs dry at t=5
			check.equal(s.value, 0)
			Stamina.advance(s, 10 + Stamina.REFILL_DELAY * 0.5, false, false)
			-- dry at t=5 means the delay already passed by t=10; refill from 5.8
			check.is_true(s.value > 0)
			local t = Stamina.new(0)
			Stamina.set(t, 0, true)
			Stamina.advance(t, 1, true, false)
			Stamina.set(t, 1, false)
			Stamina.advance(t, 1 + Stamina.REFILL_DELAY, false, false)
			check.is_true(near(t.value, 0.8))
			Stamina.advance(t, 1 + Stamina.REFILL_DELAY + Stamina.REFILL_SECONDS, false, false)
			check.equal(t.value, 1)
		end)

		test.case("an empty bar can't restart a sprint until it has MIN_START", function()
			local s = Stamina.new(0)
			Stamina.set(s, 0, true)
			Stamina.advance(s, 5, true, false)
			check.is_false(Stamina.set(s, 5, true))
			Stamina.advance(s, 5 + Stamina.REFILL_DELAY + Stamina.REFILL_SECONDS * 0.2, false, false)
			check.is_true(Stamina.set(s, 7, true))
		end)

		test.case("Sprint remote takes exactly one boolean", function()
			check.is_true(Schemas.validate("Sprint", { true }, 1))
			check.is_true(Schemas.validate("Sprint", { false }, 1))
			check.is_false(Schemas.validate("Sprint", { 1 }, 1))
			check.is_false(Schemas.validate("Sprint", {}, 0))
		end)
	end)
end
