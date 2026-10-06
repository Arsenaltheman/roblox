-- Headless unit tests. Run from the repo root: lune run tests/run
local frktest = require("@frktest/frktest")
local reporter = require("@frktest/reporters/console_reporter")
local process = require("@lune/process")

local specs = {
	"./unit/Config.spec",
	"./unit/Rng.spec",
	"./unit/NumberFormat.spec",
	"./unit/Economy.spec",
	"./unit/TrainClock.spec",
	"./unit/Luck.spec",
	"./unit/Odds.spec",
	"./unit/Manifest.spec",
	"./unit/Loot.spec",
	"./unit/Streak.spec",
	"./unit/RateLimit.spec",
	"./unit/Profile.spec",
	"./unit/StealRules.spec",
	"./unit/BanditClock.spec",
	"./unit/Schemas.spec",
	"./unit/Heist.spec",
}

for _, path in specs do
	(require :: any)(path)()
end

reporter.init()
local ok = frktest.run()
if not ok then
	process.exit(1)
end
