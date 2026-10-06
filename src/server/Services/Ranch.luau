--!strict
-- Ranches: plot assignment, pens, income, collecting, selling, locking and Frontiers (rebirths).
-- Pen pads carry attributes (Critter, Tier, Mutation, Cid, Branded, InTransit) that clients read to
-- render critters, so the server never builds critter models itself.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Economy = require("@game/ReplicatedStorage/Shared/Sim/Economy")
local Almanac = require("@game/ReplicatedStorage/Shared/Sim/Almanac")
local EconomyConfig = require("@game/ReplicatedStorage/Shared/Config/Economy")
local Profile = require("@game/ReplicatedStorage/Shared/Sim/Profile")
local Progression = require("@game/ReplicatedStorage/Shared/Config/Progression")
local Species = require("@game/ReplicatedStorage/Shared/Config/Species")
local Mutations = require("@game/ReplicatedStorage/Shared/Config/Mutations")
local Layout = require("@game/ReplicatedStorage/Shared/Config/Layout")
local Net = require("@game/ReplicatedStorage/Shared/Net/Net")
local Signal = require("@game/ReplicatedStorage/Shared/Util/Signal")
local Registry = require("../Registry")

local PLATE_REACH = 9
local LOCK_COOLDOWN = 10

local Ranch = {}

Ranch.critterAdded = Signal.new() :: Signal.Signal<Player, string>
Ranch.frontierReached = Signal.new() :: Signal.Signal<Player, number>

type State = {
	index: number,
	uncollected: number,
	lockedUntil: number,
	lockReadyAt: number,
	lastAutoQuest: number?,
	pickedUntil: number,
	shieldUntil: number,
}

local states: { [Player]: State } = {}
local ownerByIndex: { [number]: Player? } = {}

local function now(): number
	return Workspace:GetServerTimeNow()
end

function Ranch.indexOf(player: Player): number?
	local s = states[player]
	return if s then s.index else nil
end

function Ranch.ownerOf(index: number): Player?
	return ownerByIndex[index]
end

function Ranch.state(player: Player)
	return states[player]
end

local function model(player: Player): Model?
	local s = states[player]
	return if s then Registry.World.ranchModel(s.index) else nil
end

local function padFor(player: Player, pen: number): BasePart?
	local m = model(player)
	local pens = m and m:FindFirstChild("Pens")
	return pens and pens:FindFirstChild("Pen" .. pen) :: BasePart?
end

-- Best tier band for this player (used for reserved cages and exclusives).
function Ranch.band(player: Player): number
	local d = Registry.Data.get(player)
	if not d then
		return 1
	end
	return Economy.bandTier(d.Cash, Ranch.baseIncomeForBand(player))
end

-- Income without exclusives' band dependency (avoids circular band <-> income).
function Ranch.baseIncomeForBand(player: Player): number
	local d = Registry.Data.get(player)
	if not d then
		return 0
	end
	local total = 0
	for _, critter in d.Critters do
		if critter.p > 0 and not critter.it and not Species.byId[critter.s].exclusive then
			total += Economy.critterIncome({ tier = critter.tier, mutation = critter.m })
		end
	end
	return total
end

local function friendsInServer(player: Player): number
	local count = 0
	for _, other in Players:GetPlayers() do
		if other ~= player then
			local ok, isFriend = pcall(function()
				return player:IsFriendsWithAsync(other.UserId)
			end)
			if ok and isFriend then
				count += 1
			end
		end
	end
	return count
end

local friendCache: { [Player]: { count: number, at: number } } = {}

local function friends(player: Player): number
	local cached = friendCache[player]
	if cached and os.clock() - cached.at < 30 then
		return cached.count
	end
	local count = friendsInServer(player)
	friendCache[player] = { count = count, at = os.clock() }
	return count
end

function Ranch.context(player: Player): Economy.IncomeContext
	local d = Registry.Data.get(player)
	return {
		frontier = if d then d.Frontier else 0,
		passes = Registry.Monetization.passes(player),
		friends = friends(player),
		eventActive = Registry.LiveOps.incomeEventActive(),
		timedDoubleCash = Registry.Monetization.timedBoostActive(player, "DoubleCash"),
		incomeScale = Registry.LiveConfig.get("econ.incomeScale"),
		almanacSets = if d then Almanac.completedSets(d.Almanac) else 0,
	}
end

-- Current income per second.
function Ranch.income(player: Player): number
	local d = Registry.Data.get(player)
	if not d then
		return 0
	end
	local band = Economy.bandTier(d.Cash, Ranch.baseIncomeForBand(player))
	local base = 0
	for _, critter in d.Critters do
		if critter.p > 0 and not critter.it then
			local tier = critter.tier
			if Species.byId[critter.s].exclusive then
				tier = Economy.exclusiveTier(critter.s, band)
			end
			base += Economy.critterIncome({ tier = tier, mutation = critter.m })
		end
	end
	return base * Economy.multiplier(Ranch.context(player))
end

-- Refresh one pen pad's attributes from save data.
local function syncPad(player: Player, pen: number)
	local pad = padFor(player, pen)
	if not pad then
		return
	end
	local d = Registry.Data.get(player)
	local found: Profile.Critter? = nil
	local foundId = ""
	if d then
		for cid, critter in d.Critters do
			if critter.p == pen then
				found = critter
				foundId = cid
				break
			end
		end
	end
	if found then
		pad:SetAttribute("Critter", found.s)
		pad:SetAttribute("Tier", found.tier)
		pad:SetAttribute("Mutation", found.m or "")
		pad:SetAttribute("Cid", foundId)
		pad:SetAttribute("Branded", found.br)
		pad:SetAttribute("InTransit", found.it)
	else
		pad:SetAttribute("Critter", "")
		pad:SetAttribute("Tier", 0)
		pad:SetAttribute("Mutation", "")
		pad:SetAttribute("Cid", "")
		pad:SetAttribute("Branded", false)
		pad:SetAttribute("InTransit", false)
	end
end

function Ranch.syncAll(player: Player)
	for pen = 1, Layout.maxPens do
		syncPad(player, pen)
	end
	local m = model(player)
	local d = Registry.Data.get(player)
	if m and d then
		local pens = Economy.pens(d.Frontier, Registry.Monetization.passes(player))
		m:SetAttribute("Pens", pens)
		m:SetAttribute("SafePens", Economy.safePens(d.Frontier))
		m:SetAttribute("Frontier", d.Frontier)
	end
end

function Ranch.syncCritter(player: Player, cid: string)
	local d = Registry.Data.get(player)
	local critter = d and d.Critters[cid]
	if critter and critter.p > 0 then
		syncPad(player, critter.p)
	end
end

local function pensUsed(d: Profile.Data): { [number]: string }
	local used = {}
	for cid, critter in d.Critters do
		if critter.p > 0 then
			used[critter.p] = cid
		end
	end
	return used
end

local function critterIncomeOf(critter: Profile.Critter, band: number): number
	local tier = critter.tier
	if Species.byId[critter.s] and Species.byId[critter.s].exclusive then
		tier = Economy.exclusiveTier(critter.s, band)
	end
	return Economy.critterIncome({ tier = tier, mutation = critter.m })
end

-- Pens 1..safePens are Safe Pens (can't be stolen from). The best critters are moved there.
local function sortSafePens(player: Player)
	local d = Registry.Data.get(player)
	if not d then
		return
	end
	local safe = Economy.safePens(d.Frontier)
	if safe == 0 then
		return
	end
	local band = Ranch.band(player)
	local placed = {}
	for cid, critter in d.Critters do
		if critter.p > 0 and not critter.it then
			table.insert(placed, cid)
		end
	end
	table.sort(placed, function(a, b)
		return critterIncomeOf(d.Critters[a], band) > critterIncomeOf(d.Critters[b], band)
	end)
	-- Swap the top `safe` critters into pens 1..safe.
	for slot = 1, math.min(safe, #placed) do
		local cid = placed[slot]
		local critter = d.Critters[cid]
		if critter.p ~= slot then
			local used = pensUsed(d)
			local occupant = used[slot]
			if occupant then
				d.Critters[occupant].p = critter.p
			end
			critter.p = slot
		end
	end
end

-- Weakest non-branded placed critter (candidate to replace).
local function weakest(player: Player, d: Profile.Data): (string?, number)
	local band = Ranch.band(player)
	local bestId, bestIncome = nil, math.huge
	for cid, critter in d.Critters do
		if critter.p > 0 and not critter.br and not critter.it then
			local inc = critterIncomeOf(critter, band)
			if inc < bestIncome then
				bestId, bestIncome = cid, inc
			end
		end
	end
	return bestId, bestIncome
end

-- Would a new critter fit (free pen, or better than the weakest)?
function Ranch.canAccept(player: Player, tier: number, mutation: string?): boolean
	local d = Registry.Data.get(player)
	if not d then
		return false
	end
	local pens = Economy.pens(d.Frontier, Registry.Monetization.passes(player))
	local used = pensUsed(d)
	local count = 0
	for _ in used do
		count += 1
	end
	if count < pens then
		return true
	end
	local _, weakestIncome = weakest(player, d)
	return Economy.critterIncome({ tier = tier, mutation = mutation }) > weakestIncome
end

export type NewCritter = {
	species: string,
	tier: number,
	mutation: string?,
	src: string,
	paidRandom: boolean?,
	branded: boolean?,
	originalOwner: number?,
}

-- Adds a critter to the player's ranch. Replaces the weakest (50% refund) if pens are full.
-- Returns the new critter id, or nil if there's no room and it isn't better.
function Ranch.addCritter(player: Player, new: NewCritter): string?
	local d = Registry.Data.get(player)
	if not d then
		return nil
	end
	local pens = Economy.pens(d.Frontier, Registry.Monetization.passes(player))
	local used = pensUsed(d)
	local freePen: number? = nil
	for pen = 1, pens do
		if used[pen] == nil then
			freePen = pen
			break
		end
	end
	if freePen == nil then
		local victim, victimIncome = weakest(player, d)
		if
			victim == nil
			or Economy.critterIncome({ tier = new.tier, mutation = new.mutation }) <= victimIncome
		then
			return nil
		end
		local old = d.Critters[victim]
		freePen = old.p
		d.Critters[victim] = nil
		Registry.Wallet.addCash(player, Economy.sellValue({ tier = old.tier, mutation = old.m }), "Replace")
	end
	local cid = Profile.newCritterId(d)
	d.Critters[cid] = {
		s = new.species,
		tier = new.tier,
		m = new.mutation,
		p = freePen :: number,
		src = new.src,
		uid = new.originalOwner or player.UserId,
		pr = new.paidRandom == true,
		br = new.branded == true,
		it = false,
		born = os.time(),
	}
	-- Almanac: bit 0 = plain, bit i = mutation i.
	local bit = 0
	if new.mutation then
		for i, mutation in Mutations.list do
			if mutation.id == new.mutation then
				bit = i
			end
		end
	end
	d.Almanac[new.species] = bit32.bor(d.Almanac[new.species] or 0, bit32.lshift(1, bit))
	sortSafePens(player)
	Ranch.syncAll(player)
	Ranch.critterAdded:Fire(player, cid)
	Registry.Ui.pushState(player)
	return cid
end

function Ranch.removeCritter(player: Player, cid: string): Profile.Critter?
	local d = Registry.Data.get(player)
	if not d then
		return nil
	end
	local critter = d.Critters[cid]
	if not critter then
		return nil
	end
	d.Critters[cid] = nil
	if critter.p > 0 then
		syncPad(player, critter.p)
	end
	Registry.Ui.pushState(player)
	return critter
end

function Ranch.grantExclusive(player: Player, speciesId: string)
	local species = Species.byId[speciesId]
	assert(species and species.exclusive, "not an exclusive species: " .. speciesId)
	local cid = Ranch.addCritter(player, {
		species = speciesId,
		tier = species.tier,
		src = "robux",
		branded = true,
	})
	if not cid then
		-- Pens full of better critters: exclusives always get a pen (replace the weakest regardless).
		local d = Registry.Data.get(player)
		if d then
			local victim = weakest(player, d)
			if victim then
				Ranch.removeCritter(player, victim)
			end
			Ranch.addCritter(
				player,
				{ species = speciesId, tier = species.tier, src = "robux", branded = true }
			)
		end
	end
	Registry.Ui.reveal(player, { kind = "exclusive", species = speciesId, tier = species.tier })
end

function Ranch.isLocked(index: number): boolean
	local owner = ownerByIndex[index]
	local s = owner and states[owner]
	return s ~= nil and now() < s.lockedUntil and now() >= s.pickedUntil
end

function Ranch.targetInfo(index: number, cid: string): any
	local owner = ownerByIndex[index]
	local s = owner and states[owner]
	local d = owner and Registry.Data.get(owner)
	if not owner or not s or not d then
		return nil
	end
	local critter = d.Critters[cid]
	if not critter or critter.p == 0 then
		return nil
	end
	return {
		owner = owner,
		critter = critter,
		info = {
			ownerShieldUntil = s.shieldUntil,
			lockedUntil = s.lockedUntil,
			pickedUntil = s.pickedUntil,
			critterTier = critter.tier,
			critterBranded = critter.br,
			critterInSafePen = critter.p <= Economy.safePens(d.Frontier),
			critterInTransit = critter.it,
		},
	}
end

function Ranch.applyLockpick(index: number, seconds: number): boolean
	local owner = ownerByIndex[index]
	local s = owner and states[owner]
	if not s then
		return false
	end
	s.pickedUntil = now() + seconds
	local m = Registry.World.ranchModel(index)
	if m then
		m:SetAttribute("PickedUntil", s.pickedUntil)
	end
	return true
end

-- Player's distance to a named plate on their ranch.
local function nearPlate(player: Player, plateName: string): boolean
	local m = model(player)
	local plate = m and m:FindFirstChild(plateName) :: BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not plate or not root then
		return false
	end
	return (root.Position - plate.Position).Magnitude <= PLATE_REACH
end

function Ranch.collect(player: Player, auto: boolean?)
	local s = states[player]
	if not s or s.uncollected <= 0 then
		return
	end
	if not auto and not nearPlate(player, "CollectPlate") then
		return
	end
	local amount = s.uncollected
	s.uncollected = 0
	Registry.Wallet.addCash(player, amount, "Collect")
	Registry.Ui.fx(player, "collect", amount)
	Registry.Progression.onboard(player, "FirstCollect")
	-- Quests count collects; automatic ones (Auto-Collect, standing on the plate) at most once a minute.
	if not auto or os.clock() - (s.lastAutoQuest or 0) >= 60 then
		if auto then
			s.lastAutoQuest = os.clock()
		end
		Registry.Progression.questEvent(player, "collect", 1)
	end
end

local function lock(player: Player)
	local s = states[player]
	local d = Registry.Data.get(player)
	if not s or not d or not nearPlate(player, "LockPlate") then
		return
	end
	local t = now()
	if t < s.lockedUntil or t < s.lockReadyAt then
		return
	end
	s.lockedUntil = t + Economy.lockSeconds(d.Frontier, Registry.Monetization.passes(player))
	s.lockReadyAt = s.lockedUntil + LOCK_COOLDOWN
	local m = model(player)
	if m then
		m:SetAttribute("LockedUntil", s.lockedUntil)
	end
	Registry.Ui.fx(player, "lock", 0)
	Registry.Progression.questEvent(player, "lock", 1)
end

local function sell(player: Player, cid: string)
	local d = Registry.Data.get(player)
	local critter = d and d.Critters[cid]
	if not d or not critter or critter.br or critter.it then
		return
	end
	Ranch.removeCritter(player, cid)
	Registry.Wallet.addCash(player, Economy.sellValue({ tier = critter.tier, mutation = critter.m }), "Sell")
end

local function place(player: Player, cid: string, pen: number)
	local d = Registry.Data.get(player)
	local critter = d and d.Critters[cid]
	if not d or not critter or critter.it then
		return
	end
	local pens = Economy.pens(d.Frontier, Registry.Monetization.passes(player))
	if pen < 1 or pen > pens then
		return
	end
	local used = pensUsed(d)
	local occupant = used[pen]
	if occupant and occupant ~= cid then
		if d.Critters[occupant].it then
			return
		end
		d.Critters[occupant].p = critter.p
	end
	critter.p = pen
	sortSafePens(player)
	Ranch.syncAll(player)
end

local function frontier(player: Player)
	local d = Registry.Data.get(player)
	if not d then
		return
	end
	if not Economy.canFrontier(d.Frontier, d.Cash, Profile.bestTier(d)) then
		return
	end
	local n = d.Frontier + 1
	-- Reset: keep only Branded critters (and nothing mid-steal).
	for cid, critter in d.Critters do
		if not critter.br and not critter.it then
			d.Critters[cid] = nil
		end
	end
	local spent = d.Cash
	d.Cash = 0
	Registry.Telemetry.economy(player, "Cash", -spent, 0, "Frontier")
	d.Frontier = n
	Registry.Wallet.addCash(player, Economy.frontierPurse(n), "FrontierPurse")
	local s = states[player]
	if s then
		s.uncollected = 0
	end
	sortSafePens(player)
	Ranch.syncAll(player)
	Registry.Data.saveNow(player)
	Registry.Telemetry.progression(player, "Frontier", n)
	Registry.Progression.onboard(player, "FirstFrontier")
	Ranch.frontierReached:Fire(player, n)
	Registry.Ui.reveal(player, { kind = "frontier", level = n })
	Registry.Ui.announce(`{player.DisplayName} reached Frontier {n}!`, "frontier")
end

local function assign(player: Player)
	local d = Registry.Data.waitFor(player)
	if not d or states[player] then
		return
	end
	local index: number? = nil
	for i = 1, #Layout.ranches do
		if ownerByIndex[i] == nil then
			index = i
			break
		end
	end
	if not index then
		player:Kick("This server is full. Please join another one.")
		return
	end
	ownerByIndex[index] = player
	local remainingShield = math.max(0, Progression.newbieShieldSeconds - (d.Stats.PlaySeconds or 0))
	states[player] = {
		index = index,
		uncollected = 0,
		lockedUntil = 0,
		lockReadyAt = 0,
		pickedUntil = 0,
		shieldUntil = now() + remainingShield,
	}
	-- Critters that were mid-steal when a server crashed come home.
	for _, critter in d.Critters do
		critter.it = false
	end
	local m = Registry.World.ranchModel(index)
	if m then
		m:SetAttribute("Owner", player.UserId)
		m:SetAttribute("OwnerName", player.DisplayName)
		m:SetAttribute("ShieldUntil", states[player].shieldUntil)
		m:SetAttribute("LockedUntil", 0)
		local sign = m:FindFirstChild("Sign")
		if sign then
			for _, gui in sign:GetChildren() do
				local text = gui:FindFirstChild("Text") :: TextLabel?
				if text then
					text.Text = string.upper(player.DisplayName) .. "'S RANCH"
				end
			end
		end
	end
	player:SetAttribute("Ranch", index)
	-- Pens may have shrunk (e.g. a pass ended): unplace anything beyond the limit.
	local pens = Economy.pens(d.Frontier, Registry.Monetization.passes(player))
	for _, critter in d.Critters do
		if critter.p > pens then
			critter.p = 0
		end
	end
	-- Re-place unplaced critters into free pens.
	local used = pensUsed(d)
	for _, critter in d.Critters do
		if critter.p == 0 then
			for pen = 1, pens do
				if used[pen] == nil then
					critter.p = pen
					used[pen] = "x"
					break
				end
			end
		end
	end
	sortSafePens(player)
	Ranch.syncAll(player)
	-- Teleport to the platform (spawn) happens via SpawnLocation; first-time players get the tutorial.
	Registry.Progression.playerReady(player)
end

local function release(player: Player)
	local s = states[player]
	if not s then
		return
	end
	-- Uncollected cash isn't lost when leaving.
	if s.uncollected > 0 then
		local d = Registry.Data.get(player)
		if d then
			d.Cash = Economy.clampCash(d.Cash + s.uncollected)
		end
	end
	local m = Registry.World.ranchModel(s.index)
	if m then
		m:SetAttribute("Owner", 0)
		m:SetAttribute("OwnerName", "")
		m:SetAttribute("LockedUntil", 0)
		for pen = 1, Layout.maxPens do
			local pens = m:FindFirstChild("Pens")
			local pad = pens and pens:FindFirstChild("Pen" .. pen)
			if pad then
				pad:SetAttribute("Critter", "")
				pad:SetAttribute("Cid", "")
				pad:SetAttribute("Tier", 0)
			end
		end
		local sign = m:FindFirstChild("Sign")
		if sign then
			for _, gui in sign:GetChildren() do
				local text = gui:FindFirstChild("Text") :: TextLabel?
				if text then
					text.Text = "OPEN RANCH"
				end
			end
		end
	end
	ownerByIndex[s.index] = nil
	states[player] = nil
	friendCache[player] = nil
end

function Ranch.init() end

function Ranch.start()
	Registry.Data.loaded:Connect(function(player)
		task.spawn(assign, player)
	end)
	Registry.Data.releasing:Connect(function(player)
		release(player)
	end)
	Players.PlayerRemoving:Connect(release)

	Net.on("Collect", function(player)
		Ranch.collect(player)
	end)
	Net.on("Lock", lock)
	Net.on("Sell", sell)
	Net.on("Place", place)
	Net.on("Frontier", frontier)

	-- Income tick (1 Hz). Uncollected cash caps at uncollectedCapSeconds of income.
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 1 then
			return
		end
		local step = accumulator
		accumulator = 0
		for player, s in states do
			local inc = Ranch.income(player)
			local d = Registry.Data.get(player)
			if d then
				d.Stats.PlaySeconds = (d.Stats.PlaySeconds or 0) + step
			end
			if Registry.Monetization.owns(player, "AutoCollect") then
				if inc > 0 then
					s.uncollected += inc * step
					if s.uncollected >= inc * 5 then
						Ranch.collect(player, true)
					end
				end
			else
				local cap = inc * EconomyConfig.uncollectedCapSeconds
				s.uncollected = math.min(s.uncollected + inc * step, math.max(cap, s.uncollected))
				-- Standing on the plate collects automatically.
				if s.uncollected > 0 and nearPlate(player, "CollectPlate") then
					Ranch.collect(player)
				end
			end
			player:SetAttribute("Income", inc)
			player:SetAttribute("Uncollected", s.uncollected)
		end
	end)
end

return Ranch
