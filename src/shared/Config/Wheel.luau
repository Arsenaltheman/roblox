--!strict
-- The Prize Wheel: free spins only (one a day, plus spins earned by playing). Spins are never sold
-- for Robux, so this is not a paid random item, and every spin wins something (no fake near
-- misses). Odds are still shown in game. Pure data + math, unit-tested in Lune.

export type Segment = {
	id: string,
	label: string,
	glyph: string,
	color: string, -- palette name or hex
	weight: number,
	kind: "cash" | "nuggets" | "critter" | "spins",
	-- cash: seconds of your current income · nuggets: count · critter: tiers above your best
	-- (capped) · spins: extra spins
	amount: number,
}

local segments: { Segment } = {
	{
		id = "cash5",
		label = "5 MIN CASH",
		glyph = "$",
		color = "#5FCB4E",
		weight = 26,
		kind = "cash",
		amount = 300,
	},
	{
		id = "nug15",
		label = "15 NUGGETS",
		glyph = "◆",
		color = "#FFC83D",
		weight = 20,
		kind = "nuggets",
		amount = 15,
	},
	{
		id = "cash20",
		label = "20 MIN CASH",
		glyph = "$$",
		color = "#3FB7B0",
		weight = 18,
		kind = "cash",
		amount = 1200,
	},
	{
		id = "spin",
		label = "+1 SPIN",
		glyph = "↻",
		color = "#3C96FF",
		weight = 10,
		kind = "spins",
		amount = 1,
	},
	{
		id = "nug50",
		label = "50 NUGGETS",
		glyph = "◆◆",
		color = "#FF8C28",
		weight = 10,
		kind = "nuggets",
		amount = 50,
	},
	{
		id = "cash60",
		label = "1 HOUR CASH",
		glyph = "$$$",
		color = "#965AFF",
		weight = 9,
		kind = "cash",
		amount = 3600,
	},
	{
		id = "critter",
		label = "RARE CRITTER",
		glyph = "★",
		color = "#FF5FAA",
		weight = 5,
		kind = "critter",
		amount = 1,
	},
	{
		id = "jackpot",
		label = "JACKPOT!",
		glyph = "♛",
		color = "#E2463A",
		weight = 2,
		kind = "critter",
		amount = 3,
	},
}

local Wheel = {}

Wheel.segments = segments
Wheel.DAILY_SPINS = 1
Wheel.HEISTS_PER_SPIN = 3 -- every 3rd delivered heist earns a spin
Wheel.PLAY_SECONDS_PER_SPIN = 5 * 60 -- and every 5 minutes played
Wheel.MAX_STORED = 10
-- Jackpot rules (per UTC day): at most one, and at least one. If you haven't hit it by your
-- JACKPOT_GUARANTEE_SPIN-th spin of the day, that spin is the jackpot. Shown in the wheel UI.
Wheel.JACKPOT_ID = "jackpot"
Wheel.JACKPOT_GUARANTEE_SPIN = 8

function Wheel.totalWeight(): number
	local total = 0
	for _, s in segments do
		total += s.weight
	end
	return total
end

-- Segment index for a uniform random number r in [0, 1).
function Wheel.pick(r: number): number
	local target = r * Wheel.totalWeight()
	local acc = 0
	for i, s in segments do
		acc += s.weight
		if target < acc then
			return i
		end
	end
	return #segments
end

-- Shown odds (percent) per segment, in order; they sum to 100.
function Wheel.odds(): { number }
	local total = Wheel.totalWeight()
	local out = {}
	for i, s in segments do
		out[i] = s.weight / total * 100
	end
	return out
end

local function jackpotIndex(): number
	for i, s in segments do
		if s.id == Wheel.JACKPOT_ID then
			return i
		end
	end
	error("no jackpot segment")
end

-- Odds (percent) for the player's next spin today, given whether they already hit the jackpot
-- today and how many spins they've already done today. Sums to 100.
function Wheel.oddsFor(jackpotToday: boolean, spinsToday: number): { number }
	local jp = jackpotIndex()
	local out = {}
	if not jackpotToday and spinsToday + 1 >= Wheel.JACKPOT_GUARANTEE_SPIN then
		for i in segments do
			out[i] = if i == jp then 100 else 0
		end
		return out
	end
	local total = 0
	for i, s in segments do
		if not (jackpotToday and i == jp) then
			total += s.weight
		end
	end
	for i, s in segments do
		out[i] = if jackpotToday and i == jp then 0 else s.weight / total * 100
	end
	return out
end

-- Segment for the next spin under the daily jackpot rules. r is uniform [0, 1).
function Wheel.pickFor(r: number, jackpotToday: boolean, spinsToday: number): number
	local odds = Wheel.oddsFor(jackpotToday, spinsToday)
	local target = r * 100
	local acc = 0
	local last = 1
	for i, p in odds do
		if p > 0 then
			acc += p
			last = i
			if target < acc then
				return i
			end
		end
	end
	return last
end

-- UTC day number for the daily free spin.
function Wheel.day(unixSeconds: number): number
	return math.floor(unixSeconds / 86400)
end

return Wheel
