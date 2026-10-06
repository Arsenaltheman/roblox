--!strict
-- The Critter Express: rolls each train's cages, validates purchases, runs strongbox cracking,
-- server luck and the Golden Express. The train itself is never simulated here: clients render it
-- from (epoch, server time) via Sim/TrainClock.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Layout = require("@game/ReplicatedStorage/Shared/Config/Layout")
local LuckConfig = require("@game/ReplicatedStorage/Shared/Config/Luck")
local Products = require("@game/ReplicatedStorage/Shared/Config/Products")
local Rarities = require("@game/ReplicatedStorage/Shared/Config/Rarities")
local Species = require("@game/ReplicatedStorage/Shared/Config/Species")
local TrainConfig = require("@game/ReplicatedStorage/Shared/Config/Train")
local Economy = require("@game/ReplicatedStorage/Shared/Sim/Economy")
local Loot = require("@game/ReplicatedStorage/Shared/Sim/Loot")
local Luck = require("@game/ReplicatedStorage/Shared/Sim/Luck")
local Manifest = require("@game/ReplicatedStorage/Shared/Sim/Manifest")
local Odds = require("@game/ReplicatedStorage/Shared/Sim/Odds")
local Rng = require("@game/ReplicatedStorage/Shared/Sim/Rng")
local TrainClock = require("@game/ReplicatedStorage/Shared/Sim/TrainClock")
local Net = require("@game/ReplicatedStorage/Shared/Net/Net")
local Registry = require("../Registry")

local BUY_GRACE = 0.75
local CRACK_SECONDS = 1.5

local Train = {}

local epoch = 0
local serverSeed = 0
local currentCycle = -1
local manifests: { [number]: Manifest.Manifest } = {}
local sold: { [number]: { [number]: number } } = {}
local cracked: { [number]: { [Player]: boolean } } = {}
local cracking: { [Player]: { cycle: number, started: number } } = {}
local serverLuck = 1
local serverLuckUntil = 0
local goldenCycle = -1
local stampedeUntil = 0
local loot = Rng.new(os.time())

local function now(): number
	return Workspace:GetServerTimeNow()
end

function Train.epoch(): number
	return epoch
end

function Train.serverLuck(): number
	return if now() < serverLuckUntil then serverLuck else 1
end

local function eventLuck(): number
	return if now() < stampedeUntil then Products.sheriffPowers.stampedeLuck else 1
end

function Train.addServerLuck(multiplier: number)
	local t = now()
	if t >= serverLuckUntil then
		serverLuck = multiplier
		serverLuckUntil = t + LuckConfig.serverLuckSeconds
	else
		serverLuck = math.max(serverLuck, multiplier)
		serverLuckUntil += LuckConfig.serverLuckSeconds
	end
	Workspace:SetAttribute("ServerLuck", serverLuck)
	Workspace:SetAttribute("ServerLuckUntil", serverLuckUntil)
	-- Owner decision kept from the plan: purchases are announced without the buyer's name.
	Registry.Ui.announce(`SERVER LUCK x{serverLuck} is active for everyone!`, "luck")
end

-- Sheriff Power / schedule: the next train becomes the Golden Express.
function Train.callGoldenExpress(byName: string?)
	local state = TrainClock.at(epoch, now())
	-- The next train may already be rolled (late in this cycle); then target the one after.
	local rollAheadAt = TrainConfig.arriveSeconds + TrainConfig.dwellSeconds + 8
	goldenCycle = state.cycle + (if state.inCycle >= rollAheadAt - 0.5 then 2 else 1)
	Workspace:SetAttribute("GoldenCycle", goldenCycle)
	Registry.Ui.announce(
		if byName then `Sheriff {byName} called the GOLDEN EXPRESS! Next train!` else "The GOLDEN EXPRESS is coming! Next train!",
		"golden"
	)
end

function Train.startStampede(byName: string)
	stampedeUntil = now() + Products.sheriffPowers.stampedeSeconds
	Workspace:SetAttribute("StampedeUntil", stampedeUntil)
	Registry.Ui.announce(`Sheriff {byName} started a STAMPEDE! Lucky cages for 5 minutes!`, "stampede")
end

-- Luck for one player's reserved cage. Paid luck counts only where paid random items are allowed.
function Train.personalLuck(player: Player): (number, boolean)
	local restricted = Registry.Monetization.policy(player).randomRestricted
	local horseshoe = not restricted and Registry.Monetization.owns(player, "LuckyHorseshoe")
	local luck = Luck.personal({
		activeMinutes = Registry.Session.activeMinutes(player),
		horseshoe = horseshoe,
		serverLuck = Train.serverLuck(),
		eventLuck = eventLuck(),
	})
	local paid = horseshoe or Train.serverLuck() > 1
	return luck, paid
end

local function cageWorld(cageId: number): Vector3
	local p = Layout.cagePosition(cageId)
	return Vector3.new(p.x, p.y, p.z)
end

local function compactCages(manifest: Manifest.Manifest): { any }
	local compact = {}
	for _, cage in manifest.cages do
		table.insert(compact, {
			id = cage.id,
			s = cage.speciesId,
			t = cage.tier,
			m = cage.mutation,
			o = cage.owner,
			p = cage.price,
			g = cage.goldenTicket,
		})
	end
	return compact
end

local function sendManifest(player: Player, cycle: number)
	local manifest = manifests[cycle]
	if manifest then
		Net.send(player, "TrainManifest", cycle, compactCages(manifest), manifest.golden, manifest.strongbox)
	end
end

local function rollTrain(cycle: number)
	local slots: { Manifest.PlayerSlot } = {}
	local tutorial: { [number]: number } = {}
	for _, player in Players:GetPlayers() do
		if Registry.Ranch.indexOf(player) then
			local luck = Train.personalLuck(player)
			table.insert(slots, {
				userId = player.UserId,
				bandTier = Registry.Ranch.band(player),
				personalLuck = luck,
				activeMinutes = Registry.Session.activeMinutes(player),
			})
			local step = Registry.Progression.tutorialStep(player)
			if step <= 1 then
				tutorial[player.UserId] = step
			end
		end
	end
	local golden = cycle == goldenCycle
		and Registry.LiveConfig.enabled("ff.goldenExpress")
	local manifest = Manifest.roll(serverSeed, cycle, slots, {
		sharedLuck = Train.serverLuck() * eventLuck(),
		weatherMutation = Registry.Weather.current(),
		golden = golden,
	})
	-- Tutorial: the very first reserved cage is always Cactus Carl ($25); the second is a Gold Golden Ticket.
	for _, cage in manifest.cages do
		local step = tutorial[cage.owner]
		if step == 0 then
			local species = Species.byTier[1]
			cage.tier, cage.speciesId, cage.rarity = 1, species.id, Rarities.forTier(1).id
			cage.price, cage.mutation, cage.goldenTicket = Economy.price(1), nil, false
		elseif step == 1 then
			cage.mutation = "Gold"
			cage.goldenTicket = true
		end
	end
	manifests[cycle] = manifest
	sold[cycle] = {}
	cracked[cycle] = {}
	manifests[cycle - 3] = nil
	sold[cycle - 3] = nil
	cracked[cycle - 3] = nil

	Net.broadcast("TrainManifest", cycle, compactCages(manifest), manifest.golden, manifest.strongbox)
end

local function nearPosition(player: Player, position: Vector3, reach: number): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root ~= nil and (root.Position - position).Magnitude <= reach
end

local function buyCage(player: Player, cycle: number, cageId: number)
	local manifest = manifests[cycle]
	if not manifest or cycle ~= currentCycle then
		return
	end
	if not TrainClock.canBuy(epoch, cycle, now(), BUY_GRACE) then
		return
	end
	local cage = manifest.cages[cageId]
	if not cage or (sold[cycle] and sold[cycle][cageId]) then
		Registry.Ui.toast(player, "Too slow, partner! That one's gone.")
		return
	end
	if cage.owner ~= 0 and cage.owner ~= player.UserId then
		Registry.Ui.toast(player, "That cage is reserved for someone else.")
		return
	end
	if not Luck.canBuyRarity(cage.rarity, Registry.Session.activeMinutes(player)) then
		local need = Rarities.byId[cage.rarity].minActiveMinutes
		Registry.Ui.toast(player, `{cage.rarity} cages unlock after {need} active minutes in this server.`)
		return
	end
	if not nearPosition(player, cageWorld(cageId), Layout.reach + 4) then
		return
	end
	if not Registry.Ranch.canAccept(player, cage.tier, cage.mutation) then
		Registry.Ui.toast(player, "Your pens are full of better critters!")
		return
	end
	if not Registry.Wallet.trySpendCash(player, cage.price, "BuyCage") then
		Registry.Ui.toast(player, "Not enough cash yet!")
		return
	end
	local _, paidLuck = Train.personalLuck(player)
	local paidRandom = if cage.owner == 0 then Train.serverLuck() > 1 else paidLuck
	local cid = Registry.Ranch.addCritter(player, {
		species = cage.speciesId,
		tier = cage.tier,
		mutation = cage.mutation,
		src = "cage",
		paidRandom = paidRandom,
	})
	if not cid then
		-- Shouldn't happen after canAccept; refund to be safe.
		Registry.Wallet.addCash(player, cage.price, "Refund")
		return
	end
	sold[cycle][cageId] = player.UserId
	Net.broadcast("CageSold", cycle, cageId, player.UserId)
	local stepBefore = Registry.Progression.tutorialStep(player)
	Registry.Progression.onboard(player, "FirstBuy")
	if stepBefore == 1 and cage.owner == player.UserId and cage.goldenTicket then
		Registry.Progression.advanceTutorial(player, 2)
	end
	if manifest.golden then
		Registry.Progression.questEvent(player, "goldenbuy", 1)
	end
	Registry.Progression.questEvent(player, "buy", 1)
	local d = Registry.Data.get(player)
	if d then
		d.Stats.Buys = (d.Stats.Buys or 0) + 1
	end
	local rarityIndex = Rarities.indexOf(cage.rarity)
	if rarityIndex >= 6 then
		Registry.Ui.announce(`{player.DisplayName} lassoed a {string.upper(cage.rarity)} {Species.byId[cage.speciesId].name}!`, cage.rarity)
	end
end

local function finishCrack(player: Player, cycle: number)
	local manifest = manifests[cycle]
	if not manifest or not manifest.strongbox or cracked[cycle][player] then
		return
	end
	local state = TrainClock.at(epoch, now())
	if state.cycle ~= cycle or state.phase ~= "dwelling" then
		return
	end
	if not nearPosition(player, cageWorld(11), Layout.reach + 8) then
		return
	end
	cracked[cycle][player] = true
	local d = Registry.Data.get(player)
	if not d then
		return
	end
	local result = Loot.strongbox(loot, d.StrongboxPity)
	local income = Registry.Ranch.income(player)
	local reveal: { [string]: any } = { kind = "strongbox", loot = result.kind, pity = result.pity }
	if result.kind == "egg" then
		d.StrongboxPity = 0
		local band = Registry.Ranch.band(player)
		Registry.Eggs.give(player, band + (if result.pity then 1 else 0), "strongbox")
	else
		d.StrongboxPity += 1
		if result.kind == "cash" then
			local amount = math.max(50, income * result.amount)
			Registry.Wallet.addCash(player, amount, "Strongbox")
			reveal.amount = amount
		elseif result.kind == "nuggets" then
			Registry.Wallet.addNuggets(player, result.amount, "Strongbox")
			reveal.amount = result.amount
		else
			reveal.cosmetic = Registry.Shop.grantRandomCosmetic(player, loot)
		end
	end
	d.Stats.Cracks = (d.Stats.Cracks or 0) + 1
	reveal.pityCount = d.StrongboxPity
	Registry.Ui.reveal(player, reveal)
	Registry.Progression.questEvent(player, "crack", 1)
end

local function crackStart(player: Player, cycle: number)
	if cracking[player] or cycle ~= currentCycle then
		return
	end
	local manifest = manifests[cycle]
	if not manifest or not manifest.strongbox or cracked[cycle][player] then
		return
	end
	cracking[player] = { cycle = cycle, started = os.clock() }
	task.delay(CRACK_SECONDS, function()
		local c = cracking[player]
		cracking[player] = nil
		if c and c.cycle == cycle and player.Parent == Players then
			finishCrack(player, cycle)
		end
	end)
end

local function getOdds(player: Player, kind: string): any
	if kind == "wild" then
		return { rows = Odds.wildRarities(Train.serverLuck() * eventLuck()), note = Odds.ROUNDING_NOTE }
	elseif kind == "species" then
		return { rows = Odds.wildSpecies(Train.serverLuck() * eventLuck()), note = Odds.ROUNDING_NOTE }
	elseif kind == "reserved" then
		local luck = Train.personalLuck(player)
		local base = Luck.personal({ activeMinutes = Registry.Session.activeMinutes(player) })
		return {
			rows = Odds.reserved(Registry.Ranch.band(player), luck),
			withoutPaidLuck = Odds.reserved(Registry.Ranch.band(player), base),
			note = Odds.ROUNDING_NOTE,
		}
	elseif kind == "mutations" then
		local luck = Train.personalLuck(player)
		return { rows = Odds.mutations(luck, Registry.Weather.current()), note = Odds.ROUNDING_NOTE }
	elseif kind == "egg" then
		return { rows = Odds.egg(Registry.Ranch.band(player)), note = Odds.ROUNDING_NOTE }
	end
	return nil
end

-- Schedules the next Golden Express on mature servers.
local function scheduleGolden(cycle: number)
	if goldenCycle >= cycle then
		return
	end
	if Registry.Session.serverAge() < TrainConfig.goldenExpress.minServerAgeSeconds then
		return
	end
	local gap = loot:int(TrainConfig.goldenExpress.everyCyclesMin, TrainConfig.goldenExpress.everyCyclesMax)
	goldenCycle = cycle + gap
	Workspace:SetAttribute("GoldenCycle", goldenCycle)
end

function Train.init()
	serverSeed = Rng.derive(game.JobId ~= "" and game.JobId or tostring(os.time()), os.time() % 100000)
	-- Start the first train arriving two seconds after the server boots.
	epoch = now() + 2
	Workspace:SetAttribute("TrainEpoch", epoch)
	Workspace:SetAttribute("ServerLuck", 1)
	Workspace:SetAttribute("ServerLuckUntil", 0)
	print(`[Train] server seed {serverSeed}`)
end

function Train.start()
	Net.on("BuyCage", buyCage)
	Net.on("CrackStart", crackStart)
	Net.onInvoke("GetOdds", getOdds)

	-- The next train's cages are rolled while the current train is behind the ranches (late in its
	-- departing run), so cage contents never visibly swap in front of players.
	local ROLL_AHEAD_AT = TrainConfig.arriveSeconds + TrainConfig.dwellSeconds + 8
	local rolledUpTo = -1
	RunService.Heartbeat:Connect(function()
		local state = TrainClock.at(epoch, now())
		if rolledUpTo < state.cycle then
			rolledUpTo = state.cycle
			rollTrain(state.cycle)
		end
		if state.inCycle >= ROLL_AHEAD_AT and rolledUpTo < state.cycle + 1 then
			rolledUpTo = state.cycle + 1
			scheduleGolden(state.cycle + 1)
			rollTrain(state.cycle + 1)
			if state.cycle + 2 == goldenCycle then
				Registry.Ui.announce("The GOLDEN EXPRESS arrives on the next train!", "golden")
			end
		end
		currentCycle = state.cycle
	end)
	Players.PlayerRemoving:Connect(function(player)
		cracking[player] = nil
	end)
	-- New players get the current (and already-rolled next) train right away.
	Players.PlayerAdded:Connect(function(player)
		task.wait(3)
		if player.Parent == Players then
			sendManifest(player, currentCycle)
			sendManifest(player, currentCycle + 1)
		end
	end)
end

return Train
