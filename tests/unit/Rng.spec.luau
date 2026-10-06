local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local Rng = require("../../src/shared/Sim/Rng")

return function()
	test.suite("Rng", function()
		test.case("same seed gives the same sequence", function()
			local a, b = Rng.new(12345), Rng.new(12345)
			for _ = 1, 100 do
				check.equal(a:nextU32(), b:nextU32())
			end
		end)

		test.case("different seeds give different sequences", function()
			local a, b = Rng.new(1), Rng.new(2)
			local same = 0
			for _ = 1, 50 do
				if a:nextU32() == b:nextU32() then
					same += 1
				end
			end
			check.is_true(same < 3)
		end)

		test.case("string seeds work and are stable", function()
			local a, b = Rng.new("server-abc"), Rng.new("server-abc")
			check.equal(a:nextU32(), b:nextU32())
		end)

		test.case("outputs are 32-bit integers and floats are in [0,1)", function()
			local rng = Rng.new(99)
			for _ = 1, 2000 do
				local u = rng:nextU32()
				check.is_true(u >= 0 and u < 4294967296 and u == math.floor(u))
				local f = rng:nextFloat()
				check.is_true(f >= 0 and f < 1)
			end
		end)

		test.case("int covers the full inclusive range", function()
			local rng = Rng.new(7)
			local seen = {}
			for _ = 1, 600 do
				local v = rng:int(1, 6)
				check.is_true(v >= 1 and v <= 6)
				seen[v] = true
			end
			for v = 1, 6 do
				check.is_true(seen[v] == true)
			end
		end)

		test.case("weighted follows the weights (statistically)", function()
			local rng = Rng.new(2024)
			local counts = { 0, 0, 0 }
			local n = 60000
			for _ = 1, n do
				local i = rng:weighted({ 1, 2, 7 })
				counts[i] += 1
			end
			check.is_true(math.abs(counts[1] / n - 0.1) < 0.01)
			check.is_true(math.abs(counts[2] / n - 0.2) < 0.01)
			check.is_true(math.abs(counts[3] / n - 0.7) < 0.01)
		end)

		test.case("weighted never picks a zero weight", function()
			local rng = Rng.new(5)
			for _ = 1, 5000 do
				check.is_true(rng:weighted({ 0, 1, 0, 3 }) ~= 1)
			end
		end)

		test.case("mean of nextFloat is about 0.5", function()
			local rng = Rng.new(31337)
			local sum = 0
			local n = 50000
			for _ = 1, n do
				sum += rng:nextFloat()
			end
			check.is_true(math.abs(sum / n - 0.5) < 0.01)
		end)

		test.case("derive gives distinct child seeds", function()
			local seen = {}
			for n = 0, 500 do
				local s = Rng.derive(424242, n)
				check.falsy(seen[s])
				seen[s] = true
			end
		end)
	end)
end
