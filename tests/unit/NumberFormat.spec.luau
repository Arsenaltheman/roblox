local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local NumberFormat = require("../../src/shared/Sim/NumberFormat")

return function()
	test.suite("NumberFormat", function()
		test.case("small numbers are whole", function()
			check.equal(NumberFormat.short(0), "0")
			check.equal(NumberFormat.short(25), "25")
			check.equal(NumberFormat.short(999.9), "999")
		end)

		test.case("suffixes with three significant digits, truncated", function()
			check.equal(NumberFormat.short(1000), "1K")
			check.equal(NumberFormat.short(1234), "1.23K")
			check.equal(NumberFormat.short(1239), "1.23K")
			check.equal(NumberFormat.short(12345), "12.3K")
			check.equal(NumberFormat.short(614400), "614K")
			check.equal(NumberFormat.short(4.9e6), "4.9M")
			check.equal(NumberFormat.short(1.29e12), "1.29T")
			check.equal(NumberFormat.short(13.7e12), "13.7T")
			check.equal(NumberFormat.short(2.5e15), "2.5Qa")
		end)

		test.case("never shows more than the real value", function()
			check.equal(NumberFormat.short(999999), "999K")
		end)

		test.case("negative and odd inputs", function()
			check.equal(NumberFormat.short(-1500), "-1.5K")
			check.equal(NumberFormat.short(0 / 0), "0")
		end)

		test.case("cash and per-second labels", function()
			check.equal(NumberFormat.cash(25), "$25")
			check.equal(NumberFormat.perSecond(1600), "$1.6K/s")
		end)

		test.case("clock", function()
			check.equal(NumberFormat.clock(75), "1:15")
			check.equal(NumberFormat.clock(3725), "1:02:05")
			check.equal(NumberFormat.clock(-4), "0:00")
		end)

		test.case("one in N", function()
			check.equal(NumberFormat.oneIn(0.05), "1 in 20")
			check.equal(NumberFormat.oneIn(0.0005), "1 in 2K")
			check.equal(NumberFormat.oneIn(0), "never")
		end)
	end)
end
