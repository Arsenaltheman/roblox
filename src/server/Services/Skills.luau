--!strict
-- Trail Skills: six masteries fed by quest events (Progression.questEvent forwards every event).
-- Level-ups toast, every 10th level unlocks a perk other services read through Skills.perks, and
-- level 50 grants an untradable cape.

local SkillsConfig = require("@game/ReplicatedStorage/Shared/Config/Skills")
local SkillsSim = require("@game/ReplicatedStorage/Shared/Sim/Skills")
local Registry = require("../Registry")

local Skills = {}

function Skills.level(player: Player, skillId: string): number
	local d = Registry.Data.get(player)
	if not d then
		return 1
	end
	local level = SkillsSim.levelFor(d.Skills[skillId] or 0)
	return level
end

-- Number of perks earned (0..5).
function Skills.perks(player: Player, skillId: string): number
	return SkillsSim.perks(Skills.level(player, skillId))
end

-- Perk value at the player's level (e.g. 3 for +3% income).
function Skills.perkValue(player: Player, skillId: string): number
	return SkillsSim.perkValue(skillId, Skills.level(player, skillId))
end

function Skills.event(player: Player, kind: string, amount: number)
	local d = Registry.Data.get(player)
	if not d then
		return
	end
	local ups = SkillsSim.add(d.Skills, kind, amount)
	for _, up in ups do
		local skill = SkillsConfig.byId[up.skill]
		if not skill then
			continue
		end
		local perkNow = SkillsSim.perks(up.to) > SkillsSim.perks(up.from)
		if up.to >= SkillsConfig.MAX_LEVEL then
			d.Owned["cape_" .. string.lower(skill.id)] = true
			Registry.Ui.toast(player, `{skill.name} MASTERED! You earned the {skill.name}'s Cape.`)
			Registry.Ui.announce(`{player.DisplayName} mastered {skill.name} and earned the cape!`, "golden")
			Registry.Ui.fx(player, "skillPerk", 0)
		elseif perkNow then
			local perkText = string.gsub(skill.perk, "{n}", tostring(SkillsSim.perkValue(skill.id, up.to)))
			Registry.Ui.toast(player, `{skill.name} level {up.to}: new perk! {perkText}`)
			Registry.Ui.fx(player, "skillPerk", 0)
		else
			Registry.Ui.fx(player, "skillUp", up.to)
		end
		Registry.Telemetry.custom(player, "Skill:" .. skill.id, up.to)
	end
	if #ups > 0 then
		Registry.Ranch.syncAll(player)
		Registry.Ui.pushState(player)
	end
end

function Skills.init() end
function Skills.start() end

return Skills
