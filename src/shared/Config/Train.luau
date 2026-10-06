--!strict
-- The Critter Express timetable and cage rules.

return {
	-- One cycle: arrive -> stand at the platform -> depart and loop behind the ranches.
	arriveSeconds = 6,
	dwellSeconds = 20,
	departSeconds = 19,
	-- Doors open this long after the train stops (the same moment for everyone).
	doorsOpenDelay = 1,

	cars = 6,
	cagesPerCar = 2,
	minWildCages = 4,
	-- Every Nth train pulls a strongbox car.
	strongboxEvery = 3,

	-- Reserved cage: tier = player's band tier + delta.
	reservedDeltas = { -1, 0, 1, 2, 3 },
	reservedDeltaWeights = { 30, 40, 22, 7, 1 },
	-- A reserved delta at or above this glows as a "Golden Ticket" before the doors open.
	goldenTicketDelta = 2,
	-- The band is the best tier the player could afford with max(cash, this many seconds of income).
	bandIncomeSeconds = 45,

	-- Chance a cage carries a random mutation (before luck).
	mutationChance = 0.04,
	mutationChanceCap = 0.25,

	-- Golden Express: a special train with luck applied to every cage.
	goldenExpress = {
		minServerAgeSeconds = 15 * 60,
		everyCyclesMin = 40,
		everyCyclesMax = 60,
		announceSeconds = 60,
		luck = 4,
	},
}
