--!strict
-- Token bucket rate limiter, one bucket per (player, event). The clock is passed in so tests are exact.

export type Limit = {
	-- Tokens added per second.
	rate: number,
	-- Bucket size (max burst).
	burst: number,
}

export type Bucket = {
	tokens: number,
	updated: number,
}

local RateLimit = {}

-- Limits for every client -> server request. A unit test fails if a remote has no entry here.
RateLimit.limits = {
	BuyCage = { rate = 4, burst = 6 },
	Collect = { rate = 6, burst = 8 },
	Sell = { rate = 3, burst = 4 },
	Place = { rate = 3, burst = 4 },
	Lock = { rate = 1, burst = 2 },
	StealStart = { rate = 2, burst = 3 },
	StealCancel = { rate = 2, burst = 3 },
	Lasso = { rate = 1, burst = 2 },
	CrackStart = { rate = 2, burst = 3 },
	Hatch = { rate = 3, burst = 4 },
	Claim = { rate = 3, burst = 4 },
	Frontier = { rate = 0.2, burst = 1 },
	ShopBuy = { rate = 3, burst = 4 },
	Equip = { rate = 5, burst = 6 },
	Setting = { rate = 5, burst = 6 },
	Sticker = { rate = 1 / 3, burst = 2 },
	GetOdds = { rate = 1, burst = 3 },
	SheriffPower = { rate = 0.2, burst = 1 },
	Lockpick = { rate = 0.5, burst = 1 },
	ClientLog = { rate = 0.2, burst = 2 },
	BugReport = { rate = 1 / 60, burst = 1 },
	HeistGrab = { rate = 2, burst = 3 },
	BuyBoots = { rate = 1, burst = 2 },
	SpinWheel = { rate = 0.2, burst = 1 },
	BuyGear = { rate = 1, burst = 2 },
	UseGear = { rate = 2, burst = 3 },
	HitBoss = { rate = 3, burst = 4 },
	-- Press + release per sprint; generous so tapping sprint never gets a release dropped.
	Sprint = { rate = 6, burst = 10 },
	TradeInvite = { rate = 0.2, burst = 2 },
	TradeRespond = { rate = 1, burst = 2 },
	TradeOffer = { rate = 4, burst = 8 },
	TradeNuggets = { rate = 3, burst = 5 },
	TradeReady = { rate = 2, burst = 3 },
	TradeCancel = { rate = 1, burst = 2 },
} :: { [string]: Limit }

function RateLimit.newBucket(limit: Limit, now: number): Bucket
	return { tokens = limit.burst, updated = now }
end

-- Returns true and spends a token if the request is allowed.
function RateLimit.take(bucket: Bucket, limit: Limit, now: number): boolean
	local elapsed = math.max(0, now - bucket.updated)
	bucket.tokens = math.min(limit.burst, bucket.tokens + elapsed * limit.rate)
	bucket.updated = now
	if bucket.tokens >= 1 then
		bucket.tokens -= 1
		return true
	end
	return false
end

-- Convenience: per-key buckets for one player.
export type Limiter = {
	buckets: { [string]: Bucket },
	allow: (self: Limiter, event: string, now: number) -> boolean,
}

local LimiterMethods = {}
LimiterMethods.__index = LimiterMethods

function LimiterMethods.allow(self: Limiter, event: string, now: number): boolean
	local limit = RateLimit.limits[event]
	if limit == nil then
		-- Unknown events are always refused.
		return false
	end
	local bucket = self.buckets[event]
	if bucket == nil then
		bucket = RateLimit.newBucket(limit, now)
		self.buckets[event] = bucket
	end
	return RateLimit.take(bucket, limit, now)
end

function RateLimit.newLimiter(): Limiter
	return (setmetatable({ buckets = {} }, LimiterMethods) :: any) :: Limiter
end

return RateLimit
