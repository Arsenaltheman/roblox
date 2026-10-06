--!strict
-- Pure Trail Skills maths (runs in Lune). State is xp per skill id.

local Config = require("../Config/Skills")

local Skills = {}

export type State = { [string]: number }
export type LevelUp = { skill: string, from: number, to: number }

-- XP needed to go from `level` to `level + 1`.
function Skills.cost(level: number): number
	return math.floor(Config.costBase * Config.costGrowth ^ (level - 1))
end

-- Level for a total xp, plus xp into the current level and xp needed for the next one.
-- At MAX_LEVEL `into == need` so bars read full.
function Skills.levelFor(xp: number): (number, number, number)
	local level = 1
	local rest = math.max(0, xp)
	while level < Config.MAX_LEVEL do
		local need = Skills.cost(level)
		if rest < need then
			return level, rest, need
		end
		rest -= need
		level += 1
	end
	local last = Skills.cost(Config.MAX_LEVEL - 1)
	return Config.MAX_LEVEL, last, last
end

function Skills.perks(level: number): number
	return math.floor(level / Config.PERK_EVERY)
end

-- Perk value (e.g. +6 for "+6% income") for a skill at a level.
function Skills.perkValue(skillId: string, level: number): number
	local skill = Config.byId[skillId]
	if not skill then
		return 0
	end
	return Skills.perks(level) * skill.perkPer
end

-- XP each skill earns for a quest event.
function Skills.xpFor(kind: string, amount: number): { [string]: number }
	local out = {}
	for _, skill in Config.list do
		local per = skill.kinds[kind]
		if per then
			out[skill.id] = per * math.max(0, amount)
		end
	end
	return out
end

-- Applies an event to the state. Returns the level-ups it caused.
function Skills.add(state: State, kind: string, amount: number): { LevelUp }
	local ups = {}
	for id, xp in Skills.xpFor(kind, amount) do
		local before = Skills.levelFor(state[id] or 0)
		state[id] = (state[id] or 0) + xp
		local after = Skills.levelFor(state[id])
		if after > before then
			table.insert(ups, { skill = id, from = before, to = after })
		end
	end
	return ups
end

-- Total xp to reach a level from 1 (for tests and tooling).
function Skills.totalFor(level: number): number
	local total = 0
	for l = 1, math.min(level, Config.MAX_LEVEL) - 1 do
		total += Skills.cost(l)
	end
	return total
end

return Skills
