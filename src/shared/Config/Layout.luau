--!strict
-- Town layout shared by server (builds/validates) and client (renders the train, effects).
-- Plain numbers only (x, y, z tables) so it also loads under Lune.
--
-- Top view (+x right, +z down):
--
--   ====== front straight (track, z = 0) — the train stops here ======
--   [Saloon]   [========= STATION PLATFORM =========]   [Trading Post]
--        ranch1   ranch2   ranch3   ranch4        (row A, gates face the street)
--   ------------------- main street (z = 72) -------------------
--        ranch5   ranch6   ranch7   ranch8        (row B)
--   [Bandit Camp]                                  [Hatchery/Stables]
--   ====== back straight (track, z = 150) — train loops behind the ranches ======

export type V3 = { x: number, y: number, z: number }

local function v(x: number, y: number, z: number): V3
	return { x = x, y = y, z = z }
end

local TRACK = {
	-- Stadium-shaped loop: two straights joined by semicircles.
	halfStraight = 115,
	frontZ = 0,
	backZ = 150,
	y = 1.5,
}
TRACK.radius = (TRACK.backZ - TRACK.frontZ) / 2
TRACK.centerZ = (TRACK.backZ + TRACK.frontZ) / 2
TRACK.length = 4 * TRACK.halfStraight + 2 * math.pi * TRACK.radius

local RANCH_SIZE = 44

local ranches: { { index: number, center: V3, facing: number } } = {}
local xs = { -75, -25, 25, 75 }
for i, x in xs do
	-- Row A gates face +z (toward the street), row B gates face -z.
	table.insert(ranches, { index = i, center = v(x, 0, 46), facing = 1 })
end
for i, x in xs do
	table.insert(ranches, { index = i + 4, center = v(x, 0, 104), facing = -1 })
end

-- Where the train is along the loop. s = 0 is the station stop (front straight, x = 0), increasing
-- toward +x (east), around the east curve, back along the back straight to the west, and home.
local function trackPoint(s: number): (V3, V3)
	local L = TRACK.length
	s = s % L
	local h, r = TRACK.halfStraight, TRACK.radius
	local seg1 = h -- station -> east end of front straight
	local seg2 = seg1 + math.pi * r -- east curve
	local seg3 = seg2 + 2 * h -- back straight, east -> west
	local seg4 = seg3 + math.pi * r -- west curve
	if s < seg1 then
		return v(s, TRACK.y, TRACK.frontZ), v(1, 0, 0)
	elseif s < seg2 then
		local a = (s - seg1) / r -- 0..pi
		local cx, cz = h, TRACK.centerZ
		return v(cx + r * math.sin(a), TRACK.y, cz - r * math.cos(a)), v(math.cos(a), 0, math.sin(a))
	elseif s < seg3 then
		return v(h - (s - seg2), TRACK.y, TRACK.backZ), v(-1, 0, 0)
	elseif s < seg4 then
		local a = (s - seg3) / r
		local cx, cz = -h, TRACK.centerZ
		return v(cx - r * math.sin(a), TRACK.y, cz + r * math.cos(a)), v(-math.cos(a), 0, -math.sin(a))
	end
	return v(-h + (s - seg4), TRACK.y, TRACK.frontZ), v(1, 0, 0)
end

-- Pen pad positions inside a ranch, relative to its center (6 columns x 3 rows = 18 pens).
local function penOffset(index: number): V3
	local col = (index - 1) % 6
	local row = (index - 1) // 6
	return v(-16.5 + col * 6.6, 0, -9 + row * 7)
end

return {
	track = TRACK,
	trackPoint = trackPoint,
	ranchSize = RANCH_SIZE,
	ranches = ranches,
	penOffset = penOffset,
	maxPens = 18,
	platform = { center = v(0, 1, 11), size = v(110, 2, 14) },
	spawn = v(0, 4, 12),
	-- Distance (studs) of the approach run the train covers while "arriving".
	arriveDistance = 90,
	-- Where along the loop the locomotive stops (x = 45 on the front straight, so the six cars line up
	-- with the platform from x = 30 to x = -45).
	stationStop = 45,
	-- Cars trail behind the locomotive at this spacing along the track.
	carSpacing = 15,
	-- World position of cage `cageId` (1-based, two per car) while the train is stopped.
	cagePosition = function(cageId: number): V3
		local car = (cageId - 1) // 2 + 1
		local side = (cageId - 1) % 2 -- 0 = rear half of the car, 1 = front half
		local x = 45 - car * 15 + (if side == 0 then -3.5 else 3.5)
		return { x = x, y = 4, z = 2.5 }
	end,
	landmarks = {
		saloon = v(-80, 0, 18),
		tradingPost = v(80, 0, 18),
		banditCamp = v(-150, 0, 75),
		hatchery = v(150, 0, 60),
		stables = v(150, 0, 92),
	},
	-- Max distance (studs) at which a player can buy from a cage or crack a strongbox.
	reach = 16,
}
