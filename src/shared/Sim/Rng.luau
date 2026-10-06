--!strict
-- Deterministic random numbers (xoshiro128**), identical in Roblox and Lune.
-- Every roll that matters (cages, eggs, loot) comes from a seeded Rng so a logged seed replays a bug exactly.
-- Only small multipliers are used, so all intermediate values stay exact in doubles.

local TWO_32 = 4294967296

export type Rng = {
	s0: number,
	s1: number,
	s2: number,
	s3: number,
	nextU32: (self: Rng) -> number,
	nextFloat: (self: Rng) -> number,
	int: (self: Rng, min: number, max: number) -> number,
	range: (self: Rng, min: number, max: number) -> number,
	chance: (self: Rng, p: number) -> boolean,
	weighted: (self: Rng, weights: { number }) -> number,
}

local Rng = {}
Rng.__index = Rng

local function u32(x: number): number
	return x % TWO_32
end

-- Mix any number (or string) into a 32-bit seed.
local function hashSeed(seed: number | string): number
	if type(seed) == "string" then
		-- djb2: multiplier 33 keeps every intermediate value exact.
		local h = 5381
		for i = 1, #seed do
			h = u32(h * 33 + string.byte(seed, i))
		end
		return h
	end
	local n = seed :: number
	-- Fold large numbers (user ids, unix times) into 32 bits.
	local lo = u32(math.floor(n))
	local hi = u32(math.floor(n / TWO_32))
	return bit32.bxor(lo, hi * 2654435761 % TWO_32)
end

function Rng.new(seed: number | string): Rng
	local x = hashSeed(seed)
	local s = table.create(4, 0) :: { number }
	for i = 1, 4 do
		x = u32(x * 69069 + 12345)
		s[i] = bit32.bxor(x, bit32.rshift(x, 16))
	end
	if s[1] == 0 and s[2] == 0 and s[3] == 0 and s[4] == 0 then
		s[1] = 1
	end
	local self = setmetatable({ s0 = s[1], s1 = s[2], s2 = s[3], s3 = s[4] }, Rng)
	return (self :: any) :: Rng
end

-- A child seed for sub-streams, e.g. derive(serverSeed, trainCycle).
-- `n` must stay below ~2^20 so the products below remain exact.
function Rng.derive(seed: number | string, n: number): number
	local base = hashSeed(seed)
	return u32(bit32.bxor(base, u32(n * 2246822519 % TWO_32)) + u32(n * 3266489917 % TWO_32))
end

function Rng.nextU32(self: Rng): number
	local result = u32(bit32.lrotate(u32(self.s1 * 5), 7) * 9)
	local t = bit32.lshift(self.s1, 9)
	self.s2 = bit32.bxor(self.s2, self.s0)
	self.s3 = bit32.bxor(self.s3, self.s1)
	self.s1 = bit32.bxor(self.s1, self.s2)
	self.s0 = bit32.bxor(self.s0, self.s3)
	self.s2 = bit32.bxor(self.s2, t)
	self.s3 = bit32.lrotate(self.s3, 11)
	return result
end

-- Uniform in [0, 1).
function Rng.nextFloat(self: Rng): number
	return self:nextU32() / TWO_32
end

-- Uniform integer in [min, max].
function Rng.int(self: Rng, min: number, max: number): number
	assert(max >= min, "Rng.int: max < min")
	return min + math.floor(self:nextFloat() * (max - min + 1))
end

-- Uniform float in [min, max).
function Rng.range(self: Rng, min: number, max: number): number
	return min + self:nextFloat() * (max - min)
end

function Rng.chance(self: Rng, p: number): boolean
	return self:nextFloat() < p
end

-- Index into `weights`, chosen proportionally. Zero weights are never picked.
function Rng.weighted(self: Rng, weights: { number }): number
	local total = 0
	for _, w in weights do
		assert(w >= 0, "Rng.weighted: negative weight")
		total += w
	end
	assert(total > 0, "Rng.weighted: all weights are zero")
	local roll = self:nextFloat() * total
	for i, w in weights do
		roll -= w
		if roll < 0 and w > 0 then
			return i
		end
	end
	-- Floating-point edge: return the last positive weight.
	for i = #weights, 1, -1 do
		if weights[i] > 0 then
			return i
		end
	end
	return #weights
end

return Rng
