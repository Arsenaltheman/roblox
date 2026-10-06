--!strict
-- Same-server escrow trading rules: who may trade, what may be traded, invites and the
-- offer -> ready -> countdown state machine. Pure (no Roblox APIs); server/Services/Trade drives it.

local Trade = {}

Trade.MAX_CRITTERS = 6
Trade.MIN_FRONTIER = 1
Trade.MIN_ACCOUNT_AGE_DAYS = 7
Trade.INVITE_SECONDS = 20
Trade.COUNTDOWN_SECONDS = 5
Trade.MAX_NUGGETS = 1e9

-- ---------------------------------------------------------------- eligibility

export type Who = {
	frontier: number,
	-- days (Player.AccountAge)
	accountAge: number,
	-- PolicyService IsPaidItemTradingAllowed (a failed lookup counts as false)
	tradingAllowed: boolean,
}

-- nil when the player may trade, otherwise the reason shown to them.
function Trade.eligibility(who: Who): string?
	if not who.tradingAllowed then
		return "Trading isn't available for your account or region"
	end
	if who.accountAge < Trade.MIN_ACCOUNT_AGE_DAYS then
		return `Your Roblox account must be {Trade.MIN_ACCOUNT_AGE_DAYS}+ days old to trade`
	end
	if who.frontier < Trade.MIN_FRONTIER then
		return `Reach Frontier {Trade.MIN_FRONTIER} to unlock trading`
	end
	return nil
end

export type CritterLike = { br: boolean, pr: boolean, it: boolean }

-- nil when the critter can go into a trade.
function Trade.critterBlock(critter: CritterLike): string?
	if critter.br then
		return "Branded critters can't be traded"
	end
	if critter.pr then
		return "Critters found during a Robux luck boost can't be traded"
	end
	if critter.it then
		return "That critter is being stolen!"
	end
	return nil
end

-- Room for `incoming` critters after the receiver gives `outgoingPlaced` placed critters away?
function Trade.hasRoom(pens: number, placed: number, outgoingPlaced: number, incoming: number): boolean
	return placed - outgoingPlaced + incoming <= pens
end

-- ---------------------------------------------------------------- invites (keyed by userId)

export type Invite = { from: number, expires: number }
-- target userId -> the one pending invite they have
export type Invites = { [number]: Invite }

-- Drops expired invites and returns them as { target, invite } pairs.
function Trade.prune(invites: Invites, now: number): { { target: number, invite: Invite } }
	local expired = {}
	for target, invite in invites do
		if now >= invite.expires then
			table.insert(expired, { target = target, invite = invite })
		end
	end
	for _, e in expired do
		invites[e.target] = nil
	end
	return expired
end

function Trade.outgoing(invites: Invites, from: number): number?
	for target, invite in invites do
		if invite.from == from then
			return target
		end
	end
	return nil
end

-- One pending invite per player, either way.
function Trade.canInvite(invites: Invites, from: number, to: number, now: number): string?
	if from == to then
		return "You can't trade with yourself"
	end
	Trade.prune(invites, now)
	if invites[to] or Trade.outgoing(invites, to) then
		return "They already have a trade invite pending"
	end
	if invites[from] or Trade.outgoing(invites, from) then
		return "You already have a trade invite pending"
	end
	return nil
end

function Trade.addInvite(invites: Invites, from: number, to: number, now: number)
	invites[to] = { from = from, expires = now + Trade.INVITE_SECONDS }
end

-- Consumes the invite `to` got from `from`. False if there is none or it expired.
function Trade.takeInvite(invites: Invites, to: number, from: number, now: number): boolean
	local invite = invites[to]
	if not invite or invite.from ~= from then
		return false
	end
	invites[to] = nil
	return now < invite.expires
end

-- ---------------------------------------------------------------- session state machine

export type Offer = { critters: { string }, nuggets: number }

export type Session = {
	a: number,
	b: number,
	offers: { [number]: Offer },
	ready: { [number]: boolean },
	-- set while both are READY; the trade executes when it passes
	countdownEnd: number?,
	-- bumped on every offer change (clients flash "changed!")
	version: number,
	changedAt: { [number]: number },
}

function Trade.newSession(a: number, b: number): Session
	return {
		a = a,
		b = b,
		offers = { [a] = { critters = {}, nuggets = 0 }, [b] = { critters = {}, nuggets = 0 } },
		ready = { [a] = false, [b] = false },
		countdownEnd = nil,
		version = 0,
		changedAt = { [a] = -math.huge, [b] = -math.huge },
	}
end

function Trade.isMember(s: Session, user: number): boolean
	return user == s.a or user == s.b
end

function Trade.partner(s: Session, user: number): number
	return if user == s.a then s.b else s.a
end

-- Any change un-readies both sides and stops the countdown.
local function changed(s: Session, user: number, now: number)
	s.ready[s.a] = false
	s.ready[s.b] = false
	s.countdownEnd = nil
	s.version += 1
	s.changedAt[user] = now
end

function Trade.isEmpty(s: Session): boolean
	for _, offer in s.offers do
		if #offer.critters > 0 or offer.nuggets > 0 then
			return false
		end
	end
	return true
end

-- Add or remove one critter from `user`'s offer. Returns a reason when refused.
function Trade.setCritter(s: Session, user: number, cid: string, include: boolean, now: number): string?
	local offer = s.offers[user]
	if not offer then
		return "Not in this trade"
	end
	local at = table.find(offer.critters, cid)
	if include then
		if at then
			return nil
		end
		if #offer.critters >= Trade.MAX_CRITTERS then
			return `Up to {Trade.MAX_CRITTERS} critters per side`
		end
		table.insert(offer.critters, cid)
	else
		if not at then
			return nil
		end
		table.remove(offer.critters, at)
	end
	changed(s, user, now)
	return nil
end

function Trade.setNuggets(s: Session, user: number, amount: number, balance: number, now: number): string?
	local offer = s.offers[user]
	if not offer then
		return "Not in this trade"
	end
	if amount ~= amount or amount < 0 or amount > Trade.MAX_NUGGETS then
		return "Invalid amount"
	end
	amount = math.floor(amount)
	if amount > balance then
		return "Not enough Gold Nuggets"
	end
	if amount == offer.nuggets then
		return nil
	end
	offer.nuggets = amount
	changed(s, user, now)
	return nil
end

-- READY toggles; when both are READY the countdown starts, un-READY stops it.
function Trade.setReady(s: Session, user: number, ready: boolean, now: number): string?
	if not Trade.isMember(s, user) then
		return "Not in this trade"
	end
	if ready and Trade.isEmpty(s) then
		return "Add something to the trade first"
	end
	if s.ready[user] == ready then
		return nil
	end
	s.ready[user] = ready
	if s.ready[s.a] and s.ready[s.b] then
		s.countdownEnd = now + Trade.COUNTDOWN_SECONDS
	else
		s.countdownEnd = nil
	end
	return nil
end

-- True when the countdown has finished and the server should execute the trade.
function Trade.due(s: Session, now: number): boolean
	local t = s.countdownEnd
	return t ~= nil and now >= t and s.ready[s.a] == true and s.ready[s.b] == true
end

return Trade
