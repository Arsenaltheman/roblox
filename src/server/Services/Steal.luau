--!strict
-- Stealing, carrying, delivery, the lasso, lockpicks, the Bandit Camp and the tutorial bandit.
-- Owner decisions: theft is harsh (no payback, no bounties, no robbery caps). Protections kept:
-- newbie shield, Safe Pens, Branded critters. The lasso is the counter: the owner lassoing a thief
-- sends the critter home; anyone else lassoing a thief grabs it for themselves.
--
-- No-dupe rule: while carried, a critter stays in the OWNER's save (flagged in transit). Delivery moves
-- it between both saves in one step and both save immediately.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Layout = require("@game/ReplicatedStorage/Shared/Config/Layout")
local Rarities = require("@game/ReplicatedStorage/Shared/Config/Rarities")
local Species = require("@game/ReplicatedStorage/Shared/Config/Species")
local BanditClock = require("@game/ReplicatedStorage/Shared/Sim/BanditClock")
local Economy = require("@game/ReplicatedStorage/Shared/Sim/Economy")
local StealRules = require("@game/ReplicatedStorage/Shared/Sim/StealRules")
local Net = require("@game/ReplicatedStorage/Shared/Net/Net")
local Registry = require("../Registry")

local GRAB_SECONDS = 1.5
local GRAB_REACH = 10
local CARRY_TIMEOUT = 60
local LASSO_RANGE = 40
local LASSO_COOLDOWN = 2
local STUN_SECONDS = 1.5
local BASE_SPEED = 16
local CARRY_SPEED = 0.75
local BANDIT_COOLDOWN = 10 * 60
local TUTORIAL_BANDIT_ID = 1

local Steal = {}

type Carry = {
	owner: Player,
	ownerId: number,
	cid: string,
	started: number,
}

local carrying: { [Player]: Carry } = {}
local grabbing: { [Player]: number } = {}
local stunnedUntil: { [Player]: number } = {}
local lassoReadyAt: { [Player]: number } = {}
local banditReadyAt: { [Player]: number } = {}

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function root(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function humanoid(player: Player): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

function Steal.isCarrying(player: Player): boolean
	return carrying[player] ~= nil
end

-- Walk speed from passes and carry state.
local function applySpeed(player: Player)
	local h = humanoid(player)
	if not h then
		return
	end
	local speed = BASE_SPEED
	local spurs = Registry.Monetization.owns(player, "SpeedSpurs")
	if spurs then
		speed *= 1.2
	end
	if carrying[player] then
		speed = BASE_SPEED * CARRY_SPEED * (if spurs then 1.15 else 1)
	end
	if now() < (stunnedUntil[player] or 0) then
		speed = 0
	end
	h.WalkSpeed = speed
end

local function setCarryAttributes(player: Player, carry: Carry?)
	if carry then
		local d = Registry.Data.get(carry.owner)
		local critter = d and d.Critters[carry.cid]
		player:SetAttribute("Carrying", if critter then critter.s else "")
		player:SetAttribute("CarryingTier", if critter then critter.tier else 0)
		player:SetAttribute("CarryingMutation", if critter then critter.m or "" else "")
		player:SetAttribute("CarryingFrom", carry.ownerId)
		player:SetAttribute("Wanted", true)
	else
		player:SetAttribute("Carrying", "")
		player:SetAttribute("CarryingTier", 0)
		player:SetAttribute("CarryingMutation", "")
		player:SetAttribute("CarryingFrom", 0)
		player:SetAttribute("Wanted", false)
	end
	applySpeed(player)
end

local function ownerCritter(carry: Carry)
	local d = Registry.Data.get(carry.owner)
	return d and d.Critters[carry.cid]
end

-- Critter goes back to its owner's pen.
local function returnCarry(thief: Player, reason: string)
	local carry = carrying[thief]
	if not carry then
		return
	end
	carrying[thief] = nil
	local critter = ownerCritter(carry)
	if critter then
		critter.it = false
		Registry.Ranch.syncCritter(carry.owner, carry.cid)
		Registry.Ui.pushState(carry.owner)
		if carry.owner.Parent == Players then
			Registry.Ui.toast(carry.owner, `Your {Species.byId[critter.s].name} is back home!`)
		end
	end
	setCarryAttributes(thief, nil)
	Registry.Ui.fxAll("stealFailed", thief.UserId)
	if reason == "timeout" then
		Registry.Ui.toast(thief, "Too slow! The critter ran home.")
	end
end

local function deliver(thief: Player)
	local carry = carrying[thief]
	if not carry then
		return
	end
	local critter = ownerCritter(carry)
	if not critter then
		carrying[thief] = nil
		setCarryAttributes(thief, nil)
		return
	end
	if not Registry.Ranch.canAccept(thief, critter.tier, critter.m) then
		Registry.Ui.toast(thief, "Your pens are full of better critters — it ran home.")
		returnCarry(thief, "full")
		return
	end
	-- One step: remove from owner, add to thief, save both.
	carrying[thief] = nil
	local taken = Registry.Ranch.removeCritter(carry.owner, carry.cid)
	if not taken then
		setCarryAttributes(thief, nil)
		return
	end
	local cid = Registry.Ranch.addCritter(thief, {
		species = taken.s,
		tier = taken.tier,
		mutation = taken.m,
		src = "steal",
		paidRandom = taken.pr,
		originalOwner = taken.uid,
	})
	setCarryAttributes(thief, nil)
	Registry.Data.saveNow(thief)
	Registry.Data.saveNow(carry.owner)
	if not cid then
		warn("[Steal] delivery add failed after canAccept; critter lost", carry.cid)
		return
	end
	local td, od = Registry.Data.get(thief), Registry.Data.get(carry.owner)
	if td then
		td.Stats.Steals = (td.Stats.Steals or 0) + 1
	end
	if od then
		od.Stats.Robbed = (od.Stats.Robbed or 0) + 1
	end
	Registry.Monetization.noteLoss(carry.owner)
	local name = Species.byId[taken.s].name
	Registry.Ui.toast(carry.owner, `{thief.DisplayName} stole your {name}!`)
	Registry.Ui.fx(carry.owner, "robbed", taken.tier)
	Registry.Ui.reveal(thief, { kind = "stolen", species = taken.s, tier = taken.tier, mutation = taken.m })
	Registry.Progression.questEvent(thief, "steal", 1)
	Registry.Progression.onboard(thief, "FirstSteal")
	if Rarities.indexOf(Rarities.forTier(taken.tier).id) >= 5 then
		Registry.Ui.announce(`{thief.DisplayName} stole a {Rarities.forTier(taken.tier).name} {name} from {carry.owner.DisplayName}!`, "steal")
	end
end

local function insideOwnRanch(player: Player): boolean
	local index = Registry.Ranch.indexOf(player)
	local r = root(player)
	if not index or not r then
		return false
	end
	local center = Layout.ranches[index].center
	local half = Layout.ranchSize / 2
	return math.abs(r.Position.X - center.x) <= half and math.abs(r.Position.Z - center.z) <= half
end

local function padPosition(index: number, pen: number): Vector3?
	local m = Registry.World.ranchModel(index)
	local pens = m and m:FindFirstChild("Pens")
	local pad = pens and pens:FindFirstChild("Pen" .. pen) :: BasePart?
	return pad and pad.Position
end

local function banditPadPosition(n: number): Vector3?
	local town = Workspace:FindFirstChild("Town")
	local camp = town and town:FindFirstChild("BanditCamp")
	local loot = camp and camp:FindFirstChild("Loot")
	local pad = loot and loot:FindFirstChild("LootPen" .. n) :: BasePart?
	return pad and pad.Position
end

local function near(player: Player, position: Vector3?, reach: number): boolean
	local r = root(player)
	return r ~= nil and position ~= nil and (r.Position - position).Magnitude <= reach
end

local function stealBandit(player: Player, lootPen: string)
	local n = tonumber(lootPen)
	if not n or n < 1 or n > 3 then
		return
	end
	if now() < (banditReadyAt[player] or 0) then
		local wait = math.ceil(((banditReadyAt[player] or 0) - now()) / 60)
		Registry.Ui.toast(player, `The bandits are on alert. Try again in {wait} min.`)
		return
	end
	local position = banditPadPosition(n)
	if not near(player, position, GRAB_REACH) then
		return
	end
	local started = now()
	grabbing[player] = started
	Registry.Ui.fx(player, "grabStart", BanditClock.GRAB_SECONDS)
	task.delay(BanditClock.GRAB_SECONDS, function()
		if grabbing[player] ~= started or player.Parent ~= Players then
			return
		end
		grabbing[player] = nil
		if not near(player, position, GRAB_REACH + 2) then
			Registry.Ui.toast(player, "You let go!")
			return
		end
		if BanditClock.peeksDuring(started, started + BanditClock.GRAB_SECONDS) then
			stunnedUntil[player] = now() + STUN_SECONDS
			applySpeed(player)
			task.delay(STUN_SECONDS, function()
				applySpeed(player)
			end)
			Registry.Ui.fx(player, "caught", 0)
			Registry.Ui.toast(player, "CAUGHT! Wait for him to nap...")
			return
		end
		banditReadyAt[player] = now() + BANDIT_COOLDOWN
		local band = Registry.Ranch.band(player)
		local tier = math.clamp(band + 1, 1, math.min(Economy.carryLimit(0, {}) + 10, Rarities.maxTier))
		local species = Species.byTier[tier]
		local cid = Registry.Ranch.addCritter(player, { species = species.id, tier = tier, src = "bandit" })
		if cid then
			Registry.Ui.reveal(player, { kind = "stolen", species = species.id, tier = tier })
		else
			Registry.Wallet.addCash(player, Economy.sellValue({ tier = tier }), "BanditLoot")
		end
		Registry.Progression.questEvent(player, "bandit", 1)
		Registry.Progression.onboard(player, "FirstSteal")
	end)
end

local function stealStart(player: Player, ranchIndex: number, cid: string)
	if not Registry.LiveConfig.enabled("ff.stealing") then
		return
	end
	if carrying[player] or grabbing[player] then
		return
	end
	if ranchIndex == 9 then
		stealBandit(player, cid)
		return
	end
	local target = Registry.Ranch.targetInfo(ranchIndex, cid)
	if not target or target.owner == player then
		return
	end
	local d = Registry.Data.get(player)
	if not d then
		return
	end
	local reason = StealRules.canSteal({
		frontier = d.Frontier,
		passes = Registry.Monetization.passes(player),
		carrying = false,
		stunnedUntil = stunnedUntil[player] or 0,
		isOwner = false,
	}, target.info, now())
	if reason then
		Registry.Ui.toast(player, reason)
		return
	end
	local position = padPosition(ranchIndex, target.critter.p)
	if not near(player, position, GRAB_REACH) then
		return
	end
	local started = now()
	grabbing[player] = started
	Registry.Ui.fx(player, "grabStart", GRAB_SECONDS)
	Registry.Ui.fx(target.owner, "alarm", ranchIndex)
	task.delay(GRAB_SECONDS, function()
		if grabbing[player] ~= started or player.Parent ~= Players then
			return
		end
		grabbing[player] = nil
		-- Re-check everything after the hold: lock, transit, distance.
		local again = Registry.Ranch.targetInfo(ranchIndex, cid)
		if not again or again.owner ~= target.owner then
			return
		end
		local d2 = Registry.Data.get(player)
		if not d2 then
			return
		end
		local reason2 = StealRules.canSteal({
			frontier = d2.Frontier,
			passes = Registry.Monetization.passes(player),
			carrying = carrying[player] ~= nil,
			stunnedUntil = stunnedUntil[player] or 0,
			isOwner = false,
		}, again.info, now())
		if reason2 or not near(player, padPosition(ranchIndex, again.critter.p), GRAB_REACH + 2) then
			return
		end
		again.critter.it = true
		Registry.Ranch.syncCritter(again.owner, cid)
		local carry = { owner = again.owner, ownerId = again.owner.UserId, cid = cid, started = now() }
		carrying[player] = carry
		setCarryAttributes(player, carry)
		Registry.Ui.toast(again.owner, `{player.DisplayName} is stealing your {Species.byId[again.critter.s].name}! Lasso them!`)
		Registry.Ui.fxAll("wanted", player.UserId)
	end)
end

local function stealCancel(player: Player)
	grabbing[player] = nil
end

-- The tutorial bandit: an NPC that "steals" a copy of a new player's critter so they learn the lasso.
local tutorialBandits: { [Player]: Model } = {}

local function spawnTutorialBandit(player: Player)
	if tutorialBandits[player] then
		return
	end
	local index = Registry.Ranch.indexOf(player)
	if not index then
		return
	end
	local ok, npc = pcall(function()
		return Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
	end)
	if not ok or not npc then
		return
	end
	local model = npc :: Model
	model.Name = "Bandit Bart"
	local center = Layout.ranches[index].center
	local start = Vector3.new(center.x, 4, center.z)
	model:PivotTo(CFrame.new(start))
	model:SetAttribute("TutorialFor", player.UserId)
	model:SetAttribute("Wanted", true)
	local h = model:FindFirstChildOfClass("Humanoid")
	local folder = Workspace:FindFirstChild("NPCs") or Instance.new("Folder")
	folder.Name = "NPCs"
	folder.Parent = Workspace
	model.Parent = folder
	tutorialBandits[player] = model
	Registry.Ui.toast(player, "BANDIT BART is stealing your critter! Tap LASSO!")
	Registry.Ui.fx(player, "tutorialBandit", 0)
	if h then
		h.WalkSpeed = 9
		local camp = Layout.landmarks.banditCamp
		h:MoveTo(Vector3.new(camp.x, 3, camp.z))
	end
	task.delay(30, function()
		if tutorialBandits[player] == model then
			tutorialBandits[player] = nil
			model:Destroy()
			-- Missed it: no harm done, the critter was never really taken.
			Registry.Progression.advanceTutorial(player, 3)
		end
	end)
end

local function lassoTutorialBandit(player: Player)
	local model = tutorialBandits[player]
	if not model then
		return
	end
	local npcRoot = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not npcRoot or not near(player, npcRoot.Position, LASSO_RANGE * 1.5) then
		return
	end
	tutorialBandits[player] = nil
	Registry.Ui.fxAll("lasso", player.UserId, npcRoot.Position)
	model:Destroy()
	Registry.Wallet.addCash(player, 150, "TutorialBounty")
	Registry.Ui.toast(player, "Gotcha! Your critter's safe. +$150")
	Registry.Progression.advanceTutorial(player, 3)
	Registry.Progression.onboard(player, "FirstLasso")
end

local function lasso(player: Player, targetUserId: number)
	if not Registry.LiveConfig.enabled("ff.lasso") then
		return
	end
	if targetUserId == TUTORIAL_BANDIT_ID then
		lassoTutorialBandit(player)
		return
	end
	local t = now()
	if t < (lassoReadyAt[player] or 0) or t < (stunnedUntil[player] or 0) then
		return
	end
	local golden = Registry.Monetization.owns(player, "GoldenLasso")
	lassoReadyAt[player] = t + (if golden then LASSO_COOLDOWN / 2 else LASSO_COOLDOWN)
	local target = Players:GetPlayerByUserId(targetUserId)
	if not target or target == player then
		return
	end
	local carry = carrying[target]
	if not carry then
		return
	end
	local targetRoot = root(target)
	if not targetRoot or not near(player, targetRoot.Position, LASSO_RANGE * (if golden then 1.5 else 1)) then
		return
	end
	local critter = ownerCritter(carry)
	if not critter then
		return
	end
	local d = Registry.Data.get(player)
	if not d then
		return
	end
	Registry.Ui.fxAll("lasso", player.UserId, targetRoot.Position)
	stunnedUntil[target] = t + STUN_SECONDS
	task.delay(STUN_SECONDS, function()
		applySpeed(target)
	end)
	local outcome = StealRules.lassoOutcome(
		player.UserId,
		carry.ownerId,
		critter.tier,
		d.Frontier,
		Registry.Monetization.passes(player),
		carrying[player] ~= nil
	)
	d.Stats.Lassos = (d.Stats.Lassos or 0) + 1
	Registry.Progression.questEvent(player, "lasso", 1)
	Registry.Progression.onboard(player, "FirstLasso")
	if outcome == "intercept" then
		carrying[target] = nil
		setCarryAttributes(target, nil)
		carry.started = now()
		carrying[player] = carry
		setCarryAttributes(player, carry)
		Registry.Ui.toast(target, `{player.DisplayName} lassoed you and grabbed the critter!`)
		Registry.Ui.toast(player, "You grabbed it! Get it to your ranch!")
		Registry.Ui.fxAll("wanted", player.UserId)
	else
		returnCarry(target, "lassoed")
		Registry.Ui.toast(target, `{player.DisplayName} lassoed you!`)
	end
	applySpeed(target)
end

local function lockpick(player: Player, ranchIndex: number)
	local d = Registry.Data.get(player)
	if not d or (d.Stats.Lockpicks or 0) < 1 then
		Registry.Ui.toast(player, "You don't have any lockpicks.")
		return
	end
	local m = Registry.World.ranchModel(ranchIndex)
	local gate = m and m:FindFirstChild("Gate") :: BasePart?
	if not gate or not near(player, gate.Position, 20) then
		return
	end
	if not Registry.Ranch.isLocked(ranchIndex) then
		Registry.Ui.toast(player, "That ranch isn't locked.")
		return
	end
	d.Stats.Lockpicks -= 1
	local seconds = require("@game/ReplicatedStorage/Shared/Config/Products").lockpickSeconds
	Registry.Ranch.applyLockpick(ranchIndex, seconds)
	Registry.Ui.fxAll("lockpick", ranchIndex)
	local owner = Registry.Ranch.ownerOf(ranchIndex)
	if owner then
		Registry.Ui.toast(owner, `{player.DisplayName} picked your lock! {seconds} seconds!`)
	end
	Registry.Ui.pushState(player)
end

function Steal.init() end

function Steal.start()
	Net.on("StealStart", stealStart)
	Net.on("StealCancel", stealCancel)
	Net.on("Lasso", lasso)
	Net.on("Lockpick", lockpick)

	local function onCharacter(player: Player)
		player.CharacterAdded:Connect(function()
			-- Dying while carrying drops the critter home.
			returnCarry(player, "died")
			task.wait()
			applySpeed(player)
		end)
	end
	for _, player in Players:GetPlayers() do
		onCharacter(player)
	end
	Players.PlayerAdded:Connect(onCharacter)
	Registry.Monetization.passChanged:Connect(function(player)
		applySpeed(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		-- Thief leaves: critter returns. Owner leaves: anyone carrying their critter drops it.
		returnCarry(player, "left")
		for thief, carry in carrying do
			if carry.owner == player then
				carrying[thief] = nil
				setCarryAttributes(thief, nil)
				Registry.Ui.toast(thief, "The owner left — the critter ran home.")
			end
		end
		local bandit = tutorialBandits[player]
		if bandit then
			bandit:Destroy()
			tutorialBandits[player] = nil
		end
		grabbing[player] = nil
		stunnedUntil[player] = nil
		lassoReadyAt[player] = nil
		banditReadyAt[player] = nil
	end)

	-- 10 Hz: deliveries and timeouts.
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.1 then
			return
		end
		accumulator = 0
		local t = now()
		for thief, carry in carrying do
			if t - carry.started > CARRY_TIMEOUT then
				returnCarry(thief, "timeout")
			elseif insideOwnRanch(thief) then
				deliver(thief)
			end
		end
	end)

	-- Tutorial bandit appears ~4 minutes into a brand-new player's first session.
	Registry.Ranch.critterAdded:Connect(function(player)
		if Registry.Progression.tutorialStep(player) == 2 then
			task.delay(20, function()
				if player.Parent == Players and Registry.Progression.tutorialStep(player) == 2 then
					spawnTutorialBandit(player)
				end
			end)
		end
	end)
end

return Steal
