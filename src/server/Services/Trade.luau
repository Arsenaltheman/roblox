--!strict
-- Same-server escrow trading. Invite -> both build offers (critters + Gold Nuggets) -> both READY ->
-- 5 s countdown -> the server re-validates everything and swaps atomically. Rules and the state
-- machine live in shared/Sim/Trade (unit-tested); this service owns sessions, remotes and saving.
-- Items only: there is no free text anywhere in a trade.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Economy = require("@game/ReplicatedStorage/Shared/Sim/Economy")
local Rules = require("@game/ReplicatedStorage/Shared/Sim/Trade")
local Net = require("@game/ReplicatedStorage/Shared/Net/Net")
local Registry = require("../Registry")

local TICK = 0.25

local Trade = {}

type Ref = { session: Rules.Session, a: Player, b: Player }

local sessions: { [Player]: Ref } = {}
local invites: Rules.Invites = {}

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function byId(userId: number): Player?
	return Players:GetPlayerByUserId(userId)
end

-- nil when this player may trade at all (Frontier, account age, PolicyService).
function Trade.blockReason(player: Player): string?
	local d = Registry.Data.get(player)
	if not d then
		return "Still loading..."
	end
	-- Studio test players have brand-new accounts and no policy info; live servers always check.
	local studio = RunService:IsStudio()
	return Rules.eligibility({
		frontier = d.Frontier,
		accountAge = if studio then math.huge else player.AccountAge,
		tradingAllowed = studio or Registry.Monetization.policy(player).tradingAllowed == true,
	})
end

-- Carrying, stealing or mid-heist.
local function busy(player: Player): boolean
	return Registry.Steal.isBusy(player) or Registry.Heist.isCarrying(player)
end

function Trade.inTrade(player: Player): boolean
	return sessions[player] ~= nil
end

local function other(ref: Ref, player: Player): Player
	return if player == ref.a then ref.b else ref.a
end

-- ---------------------------------------------------------------- client views

local function sideView(player: Player, offer: Rules.Offer): { [string]: any }
	local d = Registry.Data.get(player)
	local critters = {}
	for _, cid in offer.critters do
		local critter = d and d.Critters[cid]
		if critter then
			table.insert(critters, {
				cid = cid,
				s = critter.s,
				t = critter.tier,
				m = critter.m,
				inc = Economy.critterIncome({ tier = critter.tier, mutation = critter.m }),
			})
		end
	end
	return { critters = critters, nuggets = offer.nuggets }
end

local function push(ref: Ref)
	local s = ref.session
	for _, player in { ref.a, ref.b } do
		local partner = other(ref, player)
		Net.send(player, "TradeState", {
			partner = partner.UserId,
			partnerName = partner.DisplayName,
			version = s.version,
			countdownEnd = s.countdownEnd,
			mine = sideView(player, s.offers[player.UserId]),
			theirs = sideView(partner, s.offers[partner.UserId]),
			myReady = s.ready[player.UserId],
			theirReady = s.ready[partner.UserId],
			theirChangedAt = s.changedAt[partner.UserId],
		})
	end
end

local function close(ref: Ref, reason: string?)
	for _, player in { ref.a, ref.b } do
		if sessions[player] == ref then
			sessions[player] = nil
		end
		if player.Parent == Players then
			Net.send(player, "TradeState", nil)
			if reason then
				Registry.Ui.toast(player, reason)
			end
		end
	end
end

-- ---------------------------------------------------------------- validation

local function pensOf(player: Player): (number, number)
	local d = Registry.Data.get(player)
	if not d then
		return 0, 0
	end
	local pens = Economy.pens(d.Frontier, Registry.Monetization.passes(player))
	local placed = 0
	for _, critter in d.Critters do
		if critter.p > 0 and critter.p <= pens then
			placed += 1
		end
	end
	return pens, placed
end

-- Does `receiver` have free pens for everything coming in (after what they give away)?
local function hasRoom(ref: Ref, receiver: Player): boolean
	local d = Registry.Data.get(receiver)
	if not d then
		return false
	end
	local giver = other(ref, receiver)
	local outgoingPlaced = 0
	for _, cid in ref.session.offers[receiver.UserId].critters do
		local critter = d.Critters[cid]
		if critter and critter.p > 0 then
			outgoingPlaced += 1
		end
	end
	local pens, placed = pensOf(receiver)
	return Rules.hasRoom(pens, placed, outgoingPlaced, #ref.session.offers[giver.UserId].critters)
end

-- nil when the trade can still go ahead, otherwise why it must be cancelled.
local function validate(ref: Ref): string?
	for _, player in { ref.a, ref.b } do
		local d = Registry.Data.get(player)
		if player.Parent ~= Players or not d then
			return `{player.DisplayName} left. Trade cancelled.`
		end
		if Trade.blockReason(player) then
			return `{player.DisplayName} can't trade right now. Trade cancelled.`
		end
		if busy(player) then
			return `{player.DisplayName} started stealing or a heist. Trade cancelled.`
		end
		local offer = ref.session.offers[player.UserId]
		for _, cid in offer.critters do
			local critter = d.Critters[cid]
			if not critter then
				return "A critter left the trade. Trade cancelled."
			end
			if Rules.critterBlock(critter) then
				return "A critter in the trade can't be traded any more. Trade cancelled."
			end
		end
		if d.Nuggets < offer.nuggets then
			return `{player.DisplayName} no longer has those Gold Nuggets. Trade cancelled.`
		end
	end
	return nil
end

-- ---------------------------------------------------------------- execution

-- Runs without yielding: re-validate, take from both givers, then give to both receivers.
local function execute(ref: Ref)
	local why = validate(ref)
	if why then
		close(ref, why)
		return
	end
	for _, receiver in { ref.a, ref.b } do
		if not hasRoom(ref, receiver) then
			close(ref, `{receiver.DisplayName}'s ranch has no free pens. Trade cancelled.`)
			return
		end
	end
	local s = ref.session
	local moving: { [Player]: { any } } = { [ref.a] = {}, [ref.b] = {} }
	local paid: { [Player]: number } = { [ref.a] = 0, [ref.b] = 0 }
	for _, giver in { ref.a, ref.b } do
		local offer = s.offers[giver.UserId]
		for _, cid in offer.critters do
			local critter = Registry.Ranch.removeCritter(giver, cid)
			if critter then
				table.insert(moving[giver], critter)
			end
		end
		if offer.nuggets > 0 and Registry.Wallet.trySpendNuggets(giver, offer.nuggets, "TradeOut") then
			paid[giver] = offer.nuggets
		end
	end
	for _, giver in { ref.a, ref.b } do
		local receiver = other(ref, giver)
		for _, critter in moving[giver] do
			local new = {
				species = critter.s,
				tier = critter.tier,
				mutation = critter.m,
				src = "trade",
				originalOwner = critter.uid,
			}
			if not Registry.Ranch.addCritter(receiver, new) then
				-- Room was checked above, so this shouldn't happen; never lose a critter.
				warn("[Trade] receiver add failed; returning critter to giver", critter.s)
				Registry.Ranch.addCritter(giver, new)
			end
		end
		if paid[giver] > 0 then
			Registry.Wallet.addNuggets(receiver, paid[giver], "TradeIn")
		end
	end
	for _, player in { ref.a, ref.b } do
		Registry.Data.saveNow(player)
		Registry.Ranch.syncAll(player)
		Registry.Ui.pushState(player)
		Registry.Ui.fx(player, "tradeDone", 0)
		Registry.Progression.questEvent(player, "trade", 1)
		Registry.Telemetry.custom(player, "Trade", #moving[player])
	end
	close(ref, "Trade complete! Check your ranch.")
end

-- ---------------------------------------------------------------- handlers

local function invite(player: Player, userId: number)
	local target = byId(userId)
	if not target or target == player then
		return
	end
	local why = Trade.blockReason(player)
	if why then
		Registry.Ui.toast(player, why)
		return
	end
	if Trade.blockReason(target) then
		Registry.Ui.toast(player, `{target.DisplayName} can't trade yet.`)
		return
	end
	if sessions[player] or sessions[target] then
		Registry.Ui.toast(player, "One of you is already trading.")
		return
	end
	if busy(player) then
		Registry.Ui.toast(player, "You can't trade while stealing or on a heist.")
		return
	end
	local refusal = Rules.canInvite(invites, player.UserId, target.UserId, now())
	if refusal then
		Registry.Ui.toast(player, refusal)
		return
	end
	Rules.addInvite(invites, player.UserId, target.UserId, now())
	Net.send(target, "TradeInvited", player.UserId, Rules.INVITE_SECONDS)
	Registry.Ui.toast(player, `Trade invite sent to {target.DisplayName}.`)
end

local function respond(player: Player, fromUserId: number, accept: boolean)
	local from = byId(fromUserId)
	if not Rules.takeInvite(invites, player.UserId, fromUserId, now()) or not from then
		Net.send(player, "TradeInvited", fromUserId, 0)
		return
	end
	if not accept then
		Registry.Ui.toast(from, `{player.DisplayName} declined your trade.`)
		return
	end
	if sessions[player] or sessions[from] then
		Registry.Ui.toast(player, "One of you is already trading.")
		return
	end
	for _, p in { player, from } do
		local why = Trade.blockReason(p)
		if why or busy(p) then
			Registry.Ui.toast(player, `{p.DisplayName} can't trade right now.`)
			Registry.Ui.toast(from, `{p.DisplayName} can't trade right now.`)
			return
		end
	end
	local ref: Ref = { session = Rules.newSession(from.UserId, player.UserId), a = from, b = player }
	sessions[from] = ref
	sessions[player] = ref
	push(ref)
end

local function offerCritter(player: Player, cid: string, include: boolean)
	local ref = sessions[player]
	local d = Registry.Data.get(player)
	if not ref or not d then
		return
	end
	if include then
		local critter = d.Critters[cid]
		if not critter then
			return
		end
		local why = Rules.critterBlock(critter)
		if why then
			Registry.Ui.toast(player, why)
			return
		end
	end
	local refusal = Rules.setCritter(ref.session, player.UserId, cid, include, now())
	if refusal then
		Registry.Ui.toast(player, refusal)
	end
	push(ref)
end

local function offerNuggets(player: Player, amount: number)
	local ref = sessions[player]
	local d = Registry.Data.get(player)
	if not ref or not d then
		return
	end
	local refusal = Rules.setNuggets(ref.session, player.UserId, amount, d.Nuggets, now())
	if refusal then
		Registry.Ui.toast(player, refusal)
	end
	push(ref)
end

local function ready(player: Player, value: boolean)
	local ref = sessions[player]
	if not ref then
		return
	end
	if value then
		for _, receiver in { ref.a, ref.b } do
			if not hasRoom(ref, receiver) then
				Registry.Ui.toast(player, `{receiver.DisplayName}'s ranch doesn't have enough free pens.`)
				return
			end
		end
	end
	local refusal = Rules.setReady(ref.session, player.UserId, value, now())
	if refusal then
		Registry.Ui.toast(player, refusal)
	end
	push(ref)
end

local function cancel(player: Player)
	local ref = sessions[player]
	if ref then
		close(ref, `{player.DisplayName} cancelled the trade.`)
		return
	end
	-- Withdraw an outgoing invite.
	local target = Rules.outgoing(invites, player.UserId)
	if target then
		invites[target] = nil
		local targetPlayer = byId(target)
		if targetPlayer then
			Net.send(targetPlayer, "TradeInvited", player.UserId, 0)
		end
	end
end

local function leave(player: Player)
	local ref = sessions[player]
	if ref then
		close(ref, `{player.DisplayName} left. Trade cancelled.`)
	end
	invites[player.UserId] = nil
	local target = Rules.outgoing(invites, player.UserId)
	if target then
		invites[target] = nil
		local targetPlayer = byId(target)
		if targetPlayer then
			Net.send(targetPlayer, "TradeInvited", player.UserId, 0)
		end
	end
end

-- ---------------------------------------------------------------- lifecycle

local function tick()
	local t = now()
	for _, e in Rules.prune(invites, t) do
		local from = byId(e.invite.from)
		if from then
			Registry.Ui.toast(from, "Your trade invite expired.")
		end
	end
	-- Each session once (both players point at the same ref).
	local seen: { [Ref]: boolean } = {}
	for _, ref in sessions do
		if not seen[ref] then
			seen[ref] = true
			local why = validate(ref)
			if why then
				close(ref, why)
			elseif Rules.due(ref.session, t) then
				execute(ref)
			end
		end
	end
	-- Mirror eligibility so the trade menu can explain why trading is locked.
	for _, player in Players:GetPlayers() do
		local reason = Trade.blockReason(player) or ""
		if player:GetAttribute("TradeBlock") ~= reason then
			player:SetAttribute("TradeBlock", reason)
		end
	end
end

function Trade.init() end

function Trade.start()
	Net.on("TradeInvite", invite)
	Net.on("TradeRespond", respond)
	Net.on("TradeOffer", offerCritter)
	Net.on("TradeNuggets", offerNuggets)
	Net.on("TradeReady", ready)
	Net.on("TradeCancel", cancel)
	Players.PlayerRemoving:Connect(leave)

	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < TICK then
			return
		end
		accumulator = 0
		tick()
	end)
end

return Trade
