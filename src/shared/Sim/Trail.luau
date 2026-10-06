--!strict
-- Bounty Trail progress maths (Config/Trail). Pure: the server feeds it events and facts.

local TrailConfig = require("../Config/Trail")

local Trail = {}

export type Facts = {
	frontier: number,
	boots: number,
	income: number,
	almanac: number,
	sets: number,
	gearOwned: number,
	bestTier: number,
	mutated: number,
}

export type ObjectiveView = { text: string, have: number, goal: number, done: boolean }

function Trail.quest(chapter: number, quest: number): TrailConfig.Quest?
	local c = TrailConfig.chapters[chapter]
	return c and c.quests[quest]
end

-- How far along one objective is. Counted kinds read `progress[i]`; checked kinds read the facts.
function Trail.have(objective: TrailConfig.Objective, count: number, facts: Facts): number
	if TrailConfig.checked[objective.kind] then
		return (facts :: any)[objective.kind] or 0
	end
	return count
end

function Trail.view(
	quest: TrailConfig.Quest,
	progress: { [string]: number },
	facts: Facts
): ({ ObjectiveView }, boolean)
	local out = {}
	local all = true
	for i, objective in quest.objectives do
		local have = Trail.have(objective, progress[tostring(i)] or 0, facts)
		local done = have >= objective.goal
		all = all and done
		table.insert(out, {
			text = objective.text,
			have = math.min(have, objective.goal),
			goal = objective.goal,
			done = done,
		})
	end
	return out, all
end

-- Adds an event to every counted objective of that kind. Returns true if anything changed.
function Trail.event(
	quest: TrailConfig.Quest,
	progress: { [string]: number },
	kind: string,
	amount: number
): boolean
	local changed = false
	for i, objective in quest.objectives do
		if objective.kind == kind and TrailConfig.counted[kind] then
			-- String keys: data stores don't keep sparse number keys reliably.
			local key = tostring(i)
			local before = progress[key] or 0
			if before < objective.goal then
				progress[key] = math.min(objective.goal, before + amount)
				changed = true
			end
		end
	end
	return changed
end

-- The quest after this one, or nil when the Trail is finished.
function Trail.after(chapter: number, quest: number): (number?, number?)
	local c = TrailConfig.chapters[chapter]
	if not c then
		return nil, nil
	end
	if quest < #c.quests then
		return chapter, quest + 1
	end
	if TrailConfig.chapters[chapter + 1] then
		return chapter + 1, 1
	end
	return nil, nil
end

function Trail.isFinale(chapter: number, quest: number): boolean
	local c = TrailConfig.chapters[chapter]
	return c ~= nil and quest == #c.quests
end

-- Weekly bounties: the week number (weeks start Monday 00:00 UTC) and that week's picks.
function Trail.week(unix: number): number
	-- 1970-01-01 was a Thursday; shift so weeks roll over on Monday.
	return math.floor((unix + 3 * 86400) / (7 * 86400))
end

function Trail.weekly(week: number): { number }
	local pool = TrailConfig.weeklyPool
	local picked: { number } = {}
	-- Deterministic shuffle from the week number (LCG), same for every server.
	local seed = (week * 1103515245 + 12345) % 2147483648
	local indices = {}
	for i = 1, #pool do
		indices[i] = i
	end
	for i = #indices, 2, -1 do
		seed = (seed * 1103515245 + 12345) % 2147483648
		local j = (seed % i) + 1
		indices[i], indices[j] = indices[j], indices[i]
	end
	for i = 1, math.min(TrailConfig.WEEKLY_COUNT, #indices) do
		table.insert(picked, indices[i])
	end
	return picked
end

return Trail
