--!strict
-- Economy simulator. Plays thousands of simulated players through the SAME config and Sim modules the
-- game uses, then checks the pacing gates from docs/PLAN.md.
--
--   lune run tools/econ-sim/main                 -- default: 200 seeds per persona, 10 hours
--   lune run tools/econ-sim/main -- --seeds 50   -- quicker
--   lune run tools/econ-sim/main -- --gates      -- exit 1 if any gate fails (used by CI)

local fs = require("@lune/fs")
local process = require("@lune/process")

local Economy = require("../../src/shared/Sim/Economy")
local Loot = require("../../src/shared/Sim/Loot")
local Luck = require("../../src/shared/Sim/Luck")
local Manifest = require("../../src/shared/Sim/Manifest")
local Rng = require("../../src/shared/Sim/Rng")
local TrainClock = require("../../src/shared/Sim/TrainClock")
local EconomyConfig = require("../../src/shared/Config/Economy")
local LuckConfig = require("../../src/shared/Config/Luck")
local Progression = require("../../src/shared/Config/Progression")
local Rarities = require("../../src/shared/Config/Rarities")

type Critter = { tier: number, mutation: string?, branded: boolean, exclusive: string? }

type Persona = {
	name: string,
	collectEvery: number,
	-- Chance to act on any given train (attention).
	attention: number,
	-- Chance to try a wild cage the player can afford and wants.
	wildInterest: number,
	steals: boolean,
	passes: Economy.Passes & { AutoCollect: boolean?, LuckyHorseshoe: boolean? },
	serverLuck: number,
	exclusives: { string },
	-- nil = one continuous session; otherwise minutes per day across `days`.
	sessionMinutes: number?,
	days: number?,
}

local PERSONAS: { Persona } = {
	{
		name = "Tapper",
		collectEvery = 120,
		attention = 0.8,
		wildInterest = 0.5,
		steals = false,
		passes = {},
		serverLuck = 1,
		exclusives = {},
	},
	{
		name = "Optimizer",
		collectEvery = 45,
		attention = 1,
		wildInterest = 1,
		steals = false,
		passes = {},
		serverLuck = 1,
		exclusives = {},
	},
	{
		name = "Thief",
		collectEvery = 90,
		attention = 0.85,
		wildInterest = 0.7,
		steals = true,
		passes = {},
		serverLuck = 1,
		exclusives = {},
	},
	{
		name = "Whale",
		collectEvery = 45,
		attention = 1,
		wildInterest = 1,
		steals = true,
		passes = {
			DoubleCash = true,
			VIP = true,
			AutoCollect = true,
			LuckyHorseshoe = true,
			BigRanch = true,
			HeavySaddlebag = true,
			IronLock = true,
		},
		serverLuck = 3,
		exclusives = { "DeputyDuck", "GoldenLocomotive", "DiamondDesperado" },
	},
	{
		name = "Returner",
		collectEvery = 120,
		attention = 0.8,
		wildInterest = 0.5,
		steals = false,
		passes = {},
		serverLuck = 1,
		exclusives = {},
		sessionMinutes = 45,
		days = 14,
	},
}

-- Model knobs that describe OTHER players (not game config).
local MODEL = {
	otherPlayers = 7,
	-- Chance another player buys a wild cage before our player gets to it.
	wildTakenByOthers = 0.5,
	stealAttemptEvery = 4 * 60,
	stealSuccess = 0.45,
	-- How often someone tries to rob our player, and how often that succeeds (lock, defence, lasso).
	robbedEvery = 12 * 60,
	robbedSuccess = 0.5,
	questEvery = 20 * 60,
}

local CHECKPOINTS_MIN = { 15, 30, 60, 120, 180, 240, 300, 360, 420, 480, 540, 600 }

-- ---------------------------------------------------------------------------

local function argNumber(name: string, default: number): number
	for i, a in process.args do
		if a == name and process.args[i + 1] then
			return tonumber(process.args[i + 1]) or default
		end
	end
	return default
end

local function hasFlag(name: string): boolean
	return table.find(process.args, name) ~= nil
end

local SEEDS = argNumber("--seeds", 200)
local HOURS = argNumber("--hours", 10)
local CHECK_GATES = hasFlag("--gates")

local function quantile(values: { number }, q: number): number
	if #values == 0 then
		return math.huge
	end
	local sorted = table.clone(values)
	table.sort(sorted)
	local pos = math.clamp(math.floor(q * (#sorted - 1) + 0.5) + 1, 1, #sorted)
	return sorted[pos]
end

local function critterIncome(c: Critter, band: number): number
	if c.exclusive then
		return Economy.income(Economy.exclusiveTier(c.exclusive, band))
	end
	return Economy.critterIncome({ tier = c.tier, mutation = c.mutation })
end

type Result = {
	frontierAt: { [number]: number },
	incomeAt: { [number]: number },
	tierAt: { [number]: number },
	frontierAtCheckpoint: { [number]: number },
	rewardTimes: { number },
	nuggetsIn: number,
	nuggetsOut: number,
	broken: string?,
	finalFrontier: number,
	maxCash: number,
}

local function simulate(persona: Persona, seed: number): Result
	local rng = Rng.new(Rng.derive(seed, 1))
	local serverSeed = Rng.derive(seed, 2)

	local frontier = 0
	local cash = EconomyConfig.startingCash
	local uncollected = 0
	local nuggets = 0
	local critters: { Critter } = {}
	local eggs: { number } = {}
	local pity = 0
	local result: Result = {
		frontierAt = {},
		incomeAt = {},
		tierAt = {},
		frontierAtCheckpoint = {},
		rewardTimes = {},
		nuggetsIn = 0,
		nuggetsOut = 0,
		finalFrontier = 0,
		maxCash = 0,
	}

	local passes = persona.passes
	for _, key in persona.exclusives do
		table.insert(critters, { tier = 1, branded = true, exclusive = key })
	end

	local function income(band: number): number
		local base = 0
		for _, c in critters do
			base += critterIncome(c, band)
		end
		return base * Economy.multiplier({ frontier = frontier, passes = passes })
	end

	local function bestTier(): number
		local best = 0
		for _, c in critters do
			if not c.exclusive and c.tier > best then
				best = c.tier
			end
		end
		return best
	end

	local function reward(t: number)
		if t <= 15 * 60 then
			table.insert(result.rewardTimes, t)
		end
	end

	-- Add a critter; replace the weakest (non-branded) if pens are full and it's better.
	local function place(c: Critter, band: number): boolean
		local pens = Economy.pens(frontier, passes)
		if #critters < pens then
			table.insert(critters, c)
			return true
		end
		local weakest, weakestIncome = nil, math.huge
		for i, existing in critters do
			if not existing.branded then
				local inc = critterIncome(existing, band)
				if inc < weakestIncome then
					weakest, weakestIncome = i, inc
				end
			end
		end
		if weakest and critterIncome(c, band) > weakestIncome then
			local old = critters[weakest]
			cash += Economy.sellValue({ tier = old.tier, mutation = old.mutation })
			critters[weakest] = c
			return true
		end
		return false
	end

	local function wants(c: Critter, band: number): boolean
		if #critters < Economy.pens(frontier, passes) then
			return true
		end
		local inc = critterIncome(c, band)
		for _, existing in critters do
			if not existing.branded and critterIncome(existing, band) < inc then
				return true
			end
		end
		return false
	end

	local cycleLength = TrainClock.cycleLength()
	local totalSeconds = HOURS * 3600
	local sessionSeconds = if persona.sessionMinutes then persona.sessionMinutes * 60 else totalSeconds
	local days = persona.days or 1
	if persona.sessionMinutes then
		totalSeconds = sessionSeconds * days
	end

	local play = 0 -- seconds of play so far
	local giftIndex = 1
	local nextEgg = Progression.eggs.layEverySeconds
	local nextWeather = 4 * 60 -- servers schedule the first weather early
	local weatherUntil = -1
	local weatherMutation: string? = nil
	local nextQuest = MODEL.questEvery
	local nextStealAttempt = Progression.newbieShieldSeconds
	local nextRobbery = Progression.newbieShieldSeconds + MODEL.robbedEvery
	local lastCollect = 0
	local checkpointIndex = 1
	local cycle = 0
	local sessionStart = 0

	while play < totalSeconds do
		-- Session boundaries (Returner): offline earnings between days.
		if persona.sessionMinutes and play - sessionStart >= sessionSeconds then
			local band = Economy.bandTier(cash, income(1))
			local away = 24 * 3600 - sessionSeconds
			cash += Economy.offlineEarnings(income(band), away, frontier)
			sessionStart = play
			giftIndex = 1
		end
		local inSession = play - sessionStart
		local activeMinutes = inSession / 60

		local band = Economy.bandTier(cash, income(Economy.bandTier(cash, 0)))
		local inc = income(band)

		-- 1. Income for one train cycle.
		local earned = inc * cycleLength
		if passes.AutoCollect then
			cash += earned
		else
			uncollected = math.min(uncollected + earned, inc * EconomyConfig.uncollectedCapSeconds)
			if play - lastCollect >= persona.collectEvery then
				cash += uncollected
				uncollected = 0
				lastCollect = play
				reward(play)
			end
		end

		-- 2. Playtime gifts (per session).
		local gift = Progression.gifts[giftIndex]
		if gift and inSession >= gift.minute * 60 then
			if gift.kind == "cash" then
				cash += math.max(gift.floor or 0, inc * gift.amount)
			elseif gift.kind == "nuggets" then
				nuggets += gift.amount
				result.nuggetsIn += gift.amount
			else
				for _ = 1, gift.amount do
					table.insert(eggs, band)
				end
			end
			giftIndex += 1
			reward(play)
		end

		-- 3. Weather.
		if play >= nextWeather then
			weatherMutation = Loot.weather(rng)
			weatherUntil = play + Progression.weather.durationSeconds
			nextWeather = play + Progression.weather.everySeconds
			for _, c in critters do
				if not c.exclusive and rng:chance(Progression.weather.ranchRollChance) then
					if Loot.betterMutation(c.mutation, weatherMutation :: string) then
						c.mutation = weatherMutation
						reward(play)
					end
				end
			end
		end
		local activeWeather = if play < weatherUntil then weatherMutation else nil

		-- 4. Eggs laid by ranch critters, hatched straight away.
		if play >= nextEgg then
			nextEgg = play + Progression.eggs.layEverySeconds
			if #critters > 0 and #eggs < Progression.eggs.maxWaiting then
				local parent = critters[rng:int(1, #critters)]
				local parentTier = if parent.exclusive then band else parent.tier
				table.insert(eggs, parentTier)
			end
		end
		local cap = Economy.carryLimit(frontier, passes) + 3
		while #eggs > 0 do
			local parentTier = table.remove(eggs, 1) :: number
			local tier = Loot.hatch(rng, parentTier, cap)
			if place({ tier = tier, branded = false }, band) then
				reward(play)
			end
		end

		-- 5. The train.
		if rng:chance(persona.attention) then
			local personal = Luck.personal({
				activeMinutes = activeMinutes,
				horseshoe = passes.LuckyHorseshoe,
				serverLuck = persona.serverLuck,
			})
			local slots =
				{ { userId = 1, bandTier = band, personalLuck = personal, activeMinutes = activeMinutes } }
			for i = 1, MODEL.otherPlayers do
				table.insert(slots, { userId = i + 1, bandTier = band, personalLuck = 1, activeMinutes = 0 })
			end
			local manifest = Manifest.roll(serverSeed, cycle, slots, {
				sharedLuck = persona.serverLuck,
				weatherMutation = activeWeather,
			})
			-- Reserved cage first, then wild cages best-first.
			local options = {}
			for _, cage in manifest.cages do
				if cage.owner == 1 then
					table.insert(options, cage)
				elseif
					cage.owner == 0
					and not rng:chance(MODEL.wildTakenByOthers)
					and rng:chance(persona.wildInterest)
				then
					if Luck.canBuyRarity(cage.rarity, activeMinutes) then
						table.insert(options, cage)
					end
				end
			end
			table.sort(options, function(a, b)
				return Economy.critterIncome(a) > Economy.critterIncome(b)
			end)
			for _, cage in options do
				local c = { tier = cage.tier, mutation = cage.mutation, branded = false }
				if cash >= cage.price and wants(c, band) then
					cash -= cage.price
					place(c, band)
					reward(play)
				end
			end
			-- Strongbox.
			if manifest.strongbox then
				local loot = Loot.strongbox(rng, pity)
				if loot.kind == "egg" then
					pity = 0
					table.insert(eggs, band + (if loot.pity then 1 else 0))
				else
					pity += 1
					if loot.kind == "cash" then
						cash += inc * loot.amount
					elseif loot.kind == "nuggets" then
						nuggets += loot.amount
						result.nuggetsIn += loot.amount
					end
				end
				reward(play)
			end
		end

		-- 6. Quests and the Hatchery.
		if play >= nextQuest then
			nextQuest = play + MODEL.questEvery
			cash += inc * Progression.quests.cashSeconds
			nuggets += Progression.quests.nuggets
			result.nuggetsIn += Progression.quests.nuggets
			reward(play)
		end
		while nuggets >= Progression.eggs.hatcheryCost do
			nuggets -= Progression.eggs.hatcheryCost
			result.nuggetsOut += Progression.eggs.hatcheryCost
			table.insert(eggs, band)
		end

		-- 7. Stealing (harsh theft: no value band, no robbery cap).
		if persona.steals and play >= nextStealAttempt then
			nextStealAttempt = play + MODEL.stealAttemptEvery
			if rng:chance(MODEL.stealSuccess) then
				local tier = math.min(band + 1, Economy.carryLimit(frontier, passes))
				if place({ tier = tier, branded = false }, band) then
					reward(play)
				end
			end
		end
		if play >= nextRobbery then
			nextRobbery = play + MODEL.robbedEvery
			if rng:chance(MODEL.robbedSuccess) then
				-- Thieves take a random stealable critter outside Safe Pens (the best N are protected).
				local safe = Economy.safePens(frontier)
				local stealable = {}
				local sorted = table.clone(critters)
				table.sort(sorted, function(a, b)
					return critterIncome(a, band) > critterIncome(b, band)
				end)
				for i, c in sorted do
					if i > safe and not c.branded then
						table.insert(stealable, c)
					end
				end
				if #stealable > 0 then
					local victim = stealable[rng:int(1, #stealable)]
					local idx = table.find(critters, victim)
					if idx then
						table.remove(critters, idx)
					end
				end
			end
		end

		-- 8. Frontier.
		if Economy.canFrontier(frontier, cash, bestTier()) then
			frontier += 1
			result.frontierAt[frontier] = play
			cash = Economy.frontierPurse(frontier)
			uncollected = 0
			local kept = {}
			for _, c in critters do
				if c.branded then
					table.insert(kept, c)
				end
			end
			critters = kept
			reward(play)
		end

		cash = Economy.clampCash(cash)
		if cash ~= cash or inc ~= inc or inc == math.huge then
			result.broken = `NaN/inf at t={play}`
		end
		result.maxCash = math.max(result.maxCash, cash)

		play += cycleLength
		cycle += 1

		while CHECKPOINTS_MIN[checkpointIndex] and play >= CHECKPOINTS_MIN[checkpointIndex] * 60 do
			local m = CHECKPOINTS_MIN[checkpointIndex]
			result.incomeAt[m] = inc
			result.tierAt[m] = bestTier()
			result.frontierAtCheckpoint[m] = frontier
			checkpointIndex += 1
		end
	end
	result.finalFrontier = frontier
	return result
end

-- ---------------------------------------------------------------------------

local NumberFormat = require("../../src/shared/Sim/NumberFormat")

local function minutes(seconds: number): string
	if seconds == math.huge then
		return "—"
	end
	local m = seconds / 60
	if m >= 120 then
		return string.format("%.1f h", m / 60)
	end
	return string.format("%.0f min", m)
end

local lines: { string } = {}
local function out(s: string)
	table.insert(lines, s)
	print(s)
end

local summary: { [string]: any } = {}

out(`# Economy simulator results`)
out("")
out(`{SEEDS} simulated players per persona, {HOURS} hours of play (Returner: 45 min/day for 14 days).`)
out("")

for _, persona in PERSONAS do
	local frontierTimes: { [number]: { number } } = {}
	local incomes: { [number]: { number } } = {}
	local tiers: { [number]: { number } } = {}
	local frontiersAt: { [number]: { number } } = {}
	local gaps: { number } = {}
	local nuggetsIn, nuggetsOut = 0, 0
	local broken = 0
	local finals: { number } = {}
	local maxCash = 0

	for s = 1, SEEDS do
		local r = simulate(persona, s * 7919 + #persona.name)
		for n, t in r.frontierAt do
			frontierTimes[n] = frontierTimes[n] or {}
			table.insert(frontierTimes[n], t)
		end
		for m, v in r.incomeAt do
			incomes[m] = incomes[m] or {}
			table.insert(incomes[m], v)
			tiers[m] = tiers[m] or {}
			table.insert(tiers[m], r.tierAt[m])
			frontiersAt[m] = frontiersAt[m] or {}
			table.insert(frontiersAt[m], r.frontierAtCheckpoint[m])
		end
		table.sort(r.rewardTimes)
		local last = 0
		for _, t in r.rewardTimes do
			table.insert(gaps, t - last)
			last = t
		end
		nuggetsIn += r.nuggetsIn
		nuggetsOut += r.nuggetsOut
		if r.broken then
			broken += 1
		end
		table.insert(finals, r.finalFrontier)
		maxCash = math.max(maxCash, r.maxCash)
	end

	-- Frontier times use only seeds that reached it; report how many did.
	local function frontierStats(n: number)
		local times = frontierTimes[n] or {}
		return {
			count = #times,
			p10 = quantile(times, 0.1),
			p50 = if #times >= SEEDS / 2 then quantile(times, 0.5) else math.huge,
			p90 = quantile(times, 0.9),
		}
	end

	out(`## {persona.name}`)
	out("")
	out("| Frontier | reached by | p10 | median | p90 |")
	out("|---|---|---|---|---|")
	for n = 1, 14 do
		local st = frontierStats(n)
		if st.count > 0 then
			out(
				`| F{n} | {math.floor(st.count / SEEDS * 100)}% | {minutes(st.p10)} | {minutes(st.p50)} | {minutes(
					st.p90
				)} |`
			)
		end
	end
	out("")
	if persona.sessionMinutes == nil then
		out("| Played | Frontier (median) | Best tier (median) | Income/s (median) |")
		out("|---|---|---|---|")
		for _, m in CHECKPOINTS_MIN do
			if incomes[m] then
				out(
					`| {minutes(m * 60)} | F{quantile(frontiersAt[m], 0.5)} | t{quantile(tiers[m], 0.5)} | {NumberFormat.perSecond(
						quantile(incomes[m], 0.5)
					)} |`
				)
			end
		end
		out("")
	else
		out(`Median Frontier after 14 days: F{quantile(finals, 0.5)}`)
		out("")
	end
	local gapP90 = quantile(gaps, 0.9)
	out(`Reward gap in the first 15 min: p90 {string.format("%.0f", gapP90)} s`)
	out(
		`Gold Nuggets: earned {nuggetsIn}, spent {nuggetsOut} (spent/earned {string.format(
			"%.2f",
			if nuggetsIn > 0 then nuggetsOut / nuggetsIn else 0
		)})`
	)
	out(`Broken runs (NaN/inf): {broken}; highest cash seen: {NumberFormat.cash(maxCash)}`)
	out("")

	summary[persona.name] = {
		f1 = frontierStats(1).p50,
		f3 = frontierStats(3).p50,
		gapP90 = gapP90,
		nuggetRatio = if nuggetsIn > 0 then nuggetsOut / nuggetsIn else 1,
		broken = broken,
		maxCash = maxCash,
	}
end

-- Gates (docs/PLAN.md §8.1, updated by the decision log).
type Gate = { name: string, ok: boolean, detail: string }
local gates: { Gate } = {}
local function gate(name: string, ok: boolean, detail: string)
	table.insert(gates, { name = name, ok = ok, detail = detail })
end

local tapper = summary.Tapper
local optimizer = summary.Optimizer
local whale = summary.Whale
gate(
	"Free player (Tapper) reaches F1 in 25–40 min",
	tapper.f1 >= 25 * 60 and tapper.f1 <= 40 * 60,
	minutes(tapper.f1)
)
gate(
	"Free player (Tapper) reaches F3 in 1.5–2.5 h",
	tapper.f3 >= 90 * 60 and tapper.f3 <= 150 * 60,
	minutes(tapper.f3)
)
gate("Optimizer is not absurdly fast (F1 ≥ 18 min)", optimizer.f1 >= 18 * 60, minutes(optimizer.f1))
gate(
	"Reward every < 60 s in the first 15 min (p90)",
	tapper.gapP90 < 60,
	`{string.format("%.0f", tapper.gapP90)} s`
)
gate(
	"Pay-to-win: whale reaches F3 at least 2.5x faster than a free player",
	whale.f3 * 2.5 <= tapper.f3,
	`whale {minutes(whale.f3)} vs free {minutes(tapper.f3)}`
)
gate(
	"Sanity: whale is not more than 10x faster (content would run out)",
	whale.f3 * 10 >= tapper.f3,
	`{string.format("%.1f", tapper.f3 / whale.f3)}x`
)
local nuggetOk = true
local brokenTotal = 0
for _, s in summary do
	nuggetOk = nuggetOk and s.nuggetRatio >= 0.85
	brokenTotal += s.broken
end
gate("Gold Nuggets don't pile up (spent ≥ 85% of earned)", nuggetOk, "")
gate("No NaN/inf and cash below the exact-maths ceiling", brokenTotal == 0, `{brokenTotal} broken runs`)

out("## Gates")
out("")
local failed = 0
for _, g in gates do
	out(`- {if g.ok then "PASS" else "FAIL"}: {g.name} ({g.detail})`)
	if not g.ok then
		failed += 1
	end
end
out("")

fs.writeDir("tools/econ-sim/out")
fs.writeFile("tools/econ-sim/out/summary.md", table.concat(lines, "\n") .. "\n")

if CHECK_GATES and failed > 0 then
	print(`{failed} gate(s) failed`)
	process.exit(1)
end
-- Keep unused-import linting quiet for knobs used only in some personas.
local _ = { LuckConfig, Rarities }
