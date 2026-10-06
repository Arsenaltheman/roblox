--!strict
-- Eggs: ranch critters lay them while you play (capped), gifts/strongboxes/Hatchery give them, and
-- hatching rolls the result (free randomness; odds shown in the egg panel).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Progression = require("@game/ReplicatedStorage/Shared/Config/Progression")
local Rarities = require("@game/ReplicatedStorage/Shared/Config/Rarities")
local Species = require("@game/ReplicatedStorage/Shared/Config/Species")
local Economy = require("@game/ReplicatedStorage/Shared/Sim/Economy")
local Loot = require("@game/ReplicatedStorage/Shared/Sim/Loot")
local Rng = require("@game/ReplicatedStorage/Shared/Sim/Rng")
local Net = require("@game/ReplicatedStorage/Shared/Net/Net")
local Registry = require("../Registry")

-- Gifts and strongboxes may exceed the "laid" cap up to this many waiting eggs.
local HARD_CAP = 8

local Eggs = {}

local rng = Rng.new(os.time() + 17)
local layTimers: { [Player]: number } = {}

function Eggs.give(player: Player, parentTier: number, source: string): boolean
	local d = Registry.Data.get(player)
	if not d or not Registry.LiveConfig.enabled("ff.eggs") then
		return false
	end
	if #d.Eggs >= HARD_CAP then
		-- Too many waiting: turn it into cash so nothing is silently lost.
		Registry.Wallet.addCash(
			player,
			Economy.price(math.clamp(parentTier, 1, Rarities.maxTier)) * 0.5,
			"EggOverflow"
		)
		return false
	end
	local now = os.time()
	table.insert(d.Eggs, {
		tier = math.clamp(parentTier, 1, Rarities.maxTier),
		laidAt = now,
		-- Gambler mastery: -5% hatch time per perk.
		hatchAt = now + math.floor(
			Progression.eggs.hatchSeconds * (1 - Registry.Skills.perkValue(player, "Gambler") / 100)
		),
	})
	Registry.Ui.fx(player, "egg", #d.Eggs)
	Registry.Ui.pushState(player)
	Registry.Telemetry.custom(player, "EggFrom:" .. source)
	return true
end

local function hatch(player: Player, slot: number)
	local d = Registry.Data.get(player)
	if not d then
		return
	end
	local egg = d.Eggs[slot]
	if not egg or os.time() < egg.hatchAt then
		return
	end
	local cap = Economy.carryLimit(d.Frontier, Registry.Monetization.passes(player)) + 3
	local tier = Loot.hatch(rng, egg.tier, cap)
	table.remove(d.Eggs, slot)
	local species = Species.byTier[tier]
	local cid = Registry.Ranch.addCritter(player, { species = species.id, tier = tier, src = "egg" })
	local reveal: { [string]: any } = {
		kind = "egg",
		species = species.id,
		tier = tier,
		rarity = Rarities.forTier(tier).id,
		kept = cid ~= nil,
	}
	if not cid then
		local value = Economy.sellValue({ tier = tier })
		Registry.Wallet.addCash(player, value, "EggSold")
		reveal.soldFor = value
	end
	d.Stats.Hatches = (d.Stats.Hatches or 0) + 1
	Registry.Ui.reveal(player, reveal)
	Registry.Progression.questEvent(player, "hatch", 1)
	Registry.Progression.onboard(player, "FirstEgg")
	if Rarities.indexOf(reveal.rarity) >= 5 then
		Registry.Ui.announce(
			`{player.DisplayName} hatched a {string.upper(reveal.rarity)} {species.name}!`,
			reveal.rarity
		)
	end
	Registry.Ui.pushState(player)
end

-- Hatchery: buy an egg with Gold Nuggets (earned only).
function Eggs.buyHatchery(player: Player): boolean
	local d = Registry.Data.get(player)
	if not d or not Registry.LiveConfig.enabled("ff.eggs") then
		return false
	end
	if #d.Eggs >= HARD_CAP then
		Registry.Ui.toast(player, "Your egg basket is full! Hatch some eggs first.")
		return false
	end
	if not Registry.Wallet.trySpendNuggets(player, Progression.eggs.hatcheryCost, "Hatchery") then
		Registry.Ui.toast(player, "Not enough Gold Nuggets.")
		return false
	end
	return Eggs.give(player, Registry.Ranch.band(player), "Hatchery")
end

-- Instant Hatch (Robux): the egg hatching soonest becomes ready now. False if none is waiting.
function Eggs.hasUnready(player: Player): boolean
	local d = Registry.Data.get(player)
	if not d then
		return false
	end
	for _, egg in d.Eggs do
		if egg.hatchAt > os.time() then
			return true
		end
	end
	return false
end

function Eggs.readyNow(player: Player): boolean
	local d = Registry.Data.get(player)
	if not d then
		return false
	end
	local best: any = nil
	for _, egg in d.Eggs do
		if egg.hatchAt > os.time() and (best == nil or egg.hatchAt < best.hatchAt) then
			best = egg
		end
	end
	if not best then
		return false
	end
	best.hatchAt = os.time()
	Registry.Ui.fx(player, "egg", #d.Eggs)
	Registry.Ui.toast(player, "Your egg is ready! Open EGGS and hatch it.")
	Registry.Ui.pushState(player)
	return true
end

function Eggs.init() end

function Eggs.start()
	Net.on("Hatch", hatch)
	Players.PlayerRemoving:Connect(function(player)
		layTimers[player] = nil
	end)
	-- Laying: one egg per layEverySeconds of active play, from a random placed critter.
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 1 then
			return
		end
		local step = accumulator
		accumulator = 0
		for _, player in Players:GetPlayers() do
			local d = Registry.Data.get(player)
			if d and Registry.Ranch.indexOf(player) and Registry.Session.isActive(player) then
				local t = (layTimers[player] or 0) + step
				if t >= Progression.eggs.layEverySeconds then
					t = 0
					if #d.Eggs < Progression.eggs.maxWaiting then
						local parents = {}
						for _, critter in d.Critters do
							if critter.p > 0 and not critter.it and not Species.byId[critter.s].exclusive then
								table.insert(parents, critter)
							end
						end
						if #parents > 0 then
							local parent = parents[rng:int(1, #parents)]
							if Eggs.give(player, parent.tier, "Laid") then
								Registry.Ui.toast(player, `{Species.byId[parent.s].name} laid an egg!`)
							end
						end
					end
				end
				layTimers[player] = t
			end
		end
	end)
end

return Eggs
