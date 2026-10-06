--!strict
-- The Bandit King: a server co-op boss that shows up in Ghost Town as a server event. Everyone
-- lassoes him together; he leaps around and stomps (dodge the red ring). Beat him before time runs
-- out and every helper gets loot; the top lassoer also gets a rare critter. Pure data (unit-tested).

local Boss = {}

Boss.ZONE = 4 -- Ghost Town
Boss.HIT_RANGE = 45 -- studs from the King to lasso him
Boss.HIT_COOLDOWN = 0.8 -- seconds between a player's lassos
Boss.LEAP_EVERY = 4.5 -- seconds between leaps
Boss.WARN_SECONDS = 1.2 -- red ring shows this long before he lands
Boss.STOMP_RADIUS = 14
Boss.STOMP_STUN = 1.5
Boss.MIN_HITS = 3 -- hits needed to earn loot
Boss.REWARD_INCOME_SECONDS = 300 -- cash reward = this many seconds of your own income
Boss.REWARD_MIN_CASH = 2500
Boss.REWARD_NUGGETS = 30
Boss.TOP_CRITTER_BONUS = 3 -- top lassoer's critter: best tier + this

-- Health scales with how many players are in the server.
function Boss.health(players: number): number
	return math.clamp(40 + 30 * players, 60, 420)
end

-- Cash reward for someone with this income per second.
function Boss.cashReward(incomePerSecond: number): number
	return math.max(Boss.REWARD_MIN_CASH, math.floor(incomePerSecond * Boss.REWARD_INCOME_SECONDS))
end

-- Who earned loot, and who lassoed most (ties go to whoever reached the count first, i.e. the
-- earlier entry in `order`).
function Boss.results(hits: { [any]: number }, order: { any }): ({ any }, any?)
	local winners = {}
	local top, topHits = nil, 0
	for _, who in order do
		local n = hits[who] or 0
		if n >= Boss.MIN_HITS then
			table.insert(winners, who)
		end
		if n > topHits then
			top, topHits = who, n
		end
	end
	if topHits < Boss.MIN_HITS then
		top = nil
	end
	return winners, top
end

return Boss
