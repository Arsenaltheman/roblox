--!strict
-- How luck works. Luck multiplies the weight of luck-affected rarities (Rare and up) on cages.
-- Reserved-cage upgrades and mutation chance use a softer curve (luck ^ softExponent).

return {
	-- Active Luck meter (owner decision): grows for each minute a player is active in this server,
	-- resets when they leave. "Active" = moved or interacted within idleAfterSeconds.
	activePerMinute = 0.04,
	activeMax = 2.2,
	idleAfterSeconds = 90,

	horseshoe = 1.5,
	serverLuckOptions = { 2, 3, 5 },
	serverLuckSeconds = 15 * 60,

	softExponent = 0.5,
	-- Safety cap on total luck from all sources.
	maxLuck = 40,
}
