--!strict
-- Who may steal what, and what a lasso does. Pure decisions; services apply them.
-- Owner decisions (2026-10-06): theft is harsh. Kept protections: newbie shield, Safe Pens, Branded critters.
-- Cut: payback, bounties, value band, robbery caps.

local Economy = require("./Economy")

local StealRules = {}

export type Target = {
	-- Ranch owner state
	ownerShieldUntil: number,
	lockedUntil: number,
	-- Lockpick opened the gate until this time
	pickedUntil: number,
	critterTier: number,
	critterBranded: boolean,
	critterInSafePen: boolean,
	critterInTransit: boolean,
}

export type Thief = {
	frontier: number,
	passes: Economy.Passes,
	carrying: boolean,
	stunnedUntil: number,
	isOwner: boolean,
}

-- Returns nil when allowed, or a short player-facing reason.
function StealRules.canSteal(thief: Thief, target: Target, now: number): string?
	if thief.isOwner then
		return "That's your own ranch"
	end
	if thief.carrying then
		return "Your hands are full"
	end
	if now < thief.stunnedUntil then
		return "You're tied up"
	end
	if now < target.ownerShieldUntil then
		return "New rancher protection"
	end
	if now < target.lockedUntil and now >= target.pickedUntil then
		return "Ranch is locked"
	end
	if target.critterBranded then
		return "Branded critters can't be stolen"
	end
	if target.critterInSafePen then
		return "This pen is a Safe Pen"
	end
	if target.critterInTransit then
		return "Someone already grabbed it"
	end
	if target.critterTier > Economy.carryLimit(thief.frontier, thief.passes) then
		return "Too heavy — reach a higher Frontier"
	end
	return nil
end

export type LassoOutcome = "return" | "intercept" | "none"

-- What happens when `lassoerId` lassoes a player carrying a critter owned by `ownerId`.
-- Owner lassoes -> critter goes home. Anyone else -> they grab it and become the carrier,
-- but only if they're allowed to carry that tier and aren't already carrying.
function StealRules.lassoOutcome(
	lassoerId: number,
	ownerId: number,
	critterTier: number,
	lassoerFrontier: number,
	lassoerPasses: Economy.Passes,
	lassoerCarrying: boolean
): LassoOutcome
	if lassoerId == ownerId then
		return "return"
	end
	if lassoerCarrying then
		return "return"
	end
	if critterTier > Economy.carryLimit(lassoerFrontier, lassoerPasses) then
		return "return"
	end
	return "intercept"
end

return StealRules
