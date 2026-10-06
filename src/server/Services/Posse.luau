--!strict
-- Posses: a party of up to 4 in the same server. Posse mates can't steal from or lasso each other,
-- each mate in the server boosts everyone's income like a friend (+10%, shared cap +30%), and the
-- posse shares a session bounty: run crates home together for spins and Nuggets for all.
-- Membership is published as the player attribute "Posse" (the leader's userId, 0 = none).

local Players = game:GetService("Players")

local Net = require("@game/ReplicatedStorage/Shared/Net/Net")
local Registry = require("../Registry")

local Posse = {}

Posse.MAX = 4
Posse.INVITE_SECONDS = 20
Posse.BOUNTY_GOAL = 10 -- heist crates run home by the posse (per session)
Posse.BOUNTY_SPINS = 1
Posse.BOUNTY_NUGGETS = 20

type Group = { leader: Player, members: { Player }, heists: number }

local groups: { [Player]: Group } = {} -- by leader
local memberOf: { [Player]: Group } = {}
local invites: { [Player]: { from: Player, expires: number } } = {} -- by invitee

local function publish(group: Group)
	for _, member in group.members do
		member:SetAttribute("Posse", group.leader.UserId)
		member:SetAttribute("PosseHeists", group.heists)
		Registry.Ui.pushState(member)
	end
end

local function remove(player: Player, reason: string)
	local group = memberOf[player]
	if not group then
		return
	end
	memberOf[player] = nil
	player:SetAttribute("Posse", 0)
	player:SetAttribute("PosseHeists", nil)
	local i = table.find(group.members, player)
	if i then
		table.remove(group.members, i)
	end
	for _, member in group.members do
		Registry.Ui.toast(member, `{player.DisplayName} left the posse{reason}.`)
	end
	if #group.members <= 1 then
		-- A posse of one is no posse.
		for _, member in group.members do
			memberOf[member] = nil
			member:SetAttribute("Posse", 0)
			member:SetAttribute("PosseHeists", nil)
			Registry.Ui.toast(member, "Your posse disbanded.")
			Registry.Ui.pushState(member)
		end
		groups[group.leader] = nil
	else
		if group.leader == player then
			group.leader = group.members[1]
			groups[player] = nil
			groups[group.leader] = group
		end
		publish(group)
	end
	if player.Parent == Players then
		Registry.Ui.pushState(player)
	end
end

function Posse.sameGroup(a: Player, b: Player): boolean
	local g = memberOf[a]
	return g ~= nil and g == memberOf[b]
end

-- Posse mates present in the server (not counting yourself).
function Posse.mateCount(player: Player): number
	local g = memberOf[player]
	return if g then #g.members - 1 else 0
end

function Posse.members(player: Player): { Player }
	local g = memberOf[player]
	return if g then g.members else {}
end

local function invite(player: Player, targetId: number)
	local target = Players:GetPlayerByUserId(targetId)
	if not target or target == player then
		return
	end
	local g = memberOf[player]
	if g and g.leader ~= player then
		Registry.Ui.toast(player, "Only the posse leader can invite.")
		return
	end
	if g and #g.members >= Posse.MAX then
		Registry.Ui.toast(player, `A posse holds {Posse.MAX} riders at most.`)
		return
	end
	if memberOf[target] then
		Registry.Ui.toast(player, `{target.DisplayName} is already riding with a posse.`)
		return
	end
	local pending = invites[target]
	if pending and os.clock() < pending.expires then
		Registry.Ui.toast(player, `{target.DisplayName} already has an invite open.`)
		return
	end
	invites[target] = { from = player, expires = os.clock() + Posse.INVITE_SECONDS }
	Net.send(target, "PosseInvited", player.UserId, Posse.INVITE_SECONDS)
	Registry.Ui.toast(player, `Posse invite sent to {target.DisplayName}.`)
end

local function respond(player: Player, fromId: number, accept: boolean)
	local pending = invites[player]
	if not pending or pending.from.UserId ~= fromId then
		return
	end
	invites[player] = nil
	local from = pending.from
	if os.clock() > pending.expires or from.Parent ~= Players then
		Registry.Ui.toast(player, "That invite expired.")
		return
	end
	if not accept then
		Registry.Ui.toast(from, `{player.DisplayName} declined.`)
		return
	end
	if memberOf[player] then
		return
	end
	local g = memberOf[from]
	if g and g.leader ~= from then
		-- The inviter joined someone else's posse meanwhile; their leader never agreed to this.
		Registry.Ui.toast(player, "That invite expired.")
		return
	end
	if not g then
		g = { leader = from, members = { from }, heists = 0 }
		groups[from] = g
		memberOf[from] = g
	end
	if #g.members >= Posse.MAX then
		Registry.Ui.toast(player, "That posse is full.")
		return
	end
	table.insert(g.members, player)
	memberOf[player] = g
	publish(g)
	for _, member in g.members do
		Registry.Ui.toast(member, `{player.DisplayName} joined the posse! ({#g.members}/{Posse.MAX})`)
		Registry.Ui.fx(member, "posseJoin", 0)
	end
	if #g.members == 2 then
		Registry.Ui.announce(`{from.DisplayName} and {player.DisplayName} formed a posse!`, "info")
	end
end

local function leave(player: Player)
	remove(player, "")
end

-- Called by Heist after every delivery: posse bounty progress.
function Posse.onHeist(player: Player)
	local g = memberOf[player]
	if not g or #g.members < 2 then
		return
	end
	g.heists += 1
	if g.heists % Posse.BOUNTY_GOAL == 0 then
		for _, member in g.members do
			Registry.Wheel.addSpins(member, Posse.BOUNTY_SPINS, "Posse bounty")
			Registry.Wallet.addNuggets(member, Posse.BOUNTY_NUGGETS, "PosseBounty")
			Registry.Ui.toast(
				member,
				`POSSE BOUNTY! {Posse.BOUNTY_GOAL} crates together: +{Posse.BOUNTY_NUGGETS} Nuggets and a spin for everyone!`
			)
			Registry.Ui.fx(member, "posseBounty", 0)
		end
	end
	publish(g)
end

function Posse.init() end

function Posse.start()
	Net.on("PosseInvite", invite)
	Net.on("PosseRespond", respond)
	Net.on("PosseLeave", leave)
	Players.PlayerAdded:Connect(function(player)
		player:SetAttribute("Posse", 0)
	end)
	for _, player in Players:GetPlayers() do
		player:SetAttribute("Posse", 0)
	end
	Players.PlayerRemoving:Connect(function(player)
		invites[player] = nil
		remove(player, " (left the game)")
	end)
end

return Posse
