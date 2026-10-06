--!strict
-- Trading Post: in-game items bought with Cash or Gold Nuggets. Stock rotates every 5 minutes
-- (a real timer, same for the whole server). Equipping cosmetics also lives here.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Cosmetics = require("@game/ReplicatedStorage/Shared/Config/Cosmetics")
local Profile = require("@game/ReplicatedStorage/Shared/Sim/Profile")
local Rng = require("@game/ReplicatedStorage/Shared/Sim/Rng")
local Net = require("@game/ReplicatedStorage/Shared/Net/Net")
local Registry = require("../Registry")

local Shop = {}

local stock: { string } = {}
local nextRestock = 0
local restockIndex = 0

local function now(): number
	return Workspace:GetServerTimeNow()
end

-- Cosmetics that can appear in the rotating stock (priced in Nuggets).
local buyable: { Cosmetics.Cosmetic } = {}
for _, cosmetic in Cosmetics.list do
	if cosmetic.nuggets then
		table.insert(buyable, cosmetic)
	end
end

local function restock()
	restockIndex += 1
	local rng = Rng.new(Rng.derive(game.JobId ~= "" and game.JobId or "studio", restockIndex))
	local pool = table.clone(buyable)
	stock = {}
	for _ = 1, math.min(Cosmetics.stockSize, #pool) do
		local i = rng:int(1, #pool)
		table.insert(stock, (table.remove(pool, i) :: Cosmetics.Cosmetic).id)
	end
	nextRestock = now() + Cosmetics.restockSeconds
	Workspace:SetAttribute("ShopRestockAt", nextRestock)
	for _, player in Players:GetPlayers() do
		Registry.Ui.pushState(player)
	end
end

function Shop.stockView(_player: Player): { any }
	return { items = stock, restockAt = nextRestock }
end

-- Static items always available: Hatchery egg (Nuggets).
function Shop.buy(player: Player, key: string)
	if key == "HatcheryEgg" then
		Registry.Eggs.buyHatchery(player)
		return
	end
	local cosmetic = Cosmetics.byId[key]
	if not cosmetic or not cosmetic.nuggets or not table.find(stock, key) then
		Registry.Ui.toast(player, "That's not in stock right now.")
		return
	end
	local d = Registry.Data.get(player)
	if not d then
		return
	end
	if d.Owned[key] then
		Registry.Ui.toast(player, "You already own that.")
		return
	end
	if not Registry.Wallet.trySpendNuggets(player, cosmetic.nuggets, "Cosmetic:" .. key) then
		Registry.Ui.toast(player, "Not enough Gold Nuggets.")
		return
	end
	d.Owned[key] = true
	d.Equipped[cosmetic.slot] = key
	Registry.Ui.reveal(player, { kind = "cosmetic", id = key })
	Shop.applyEquipped(player)
end

-- Random cosmetic from a strongbox (free). Duplicates become Nuggets.
function Shop.grantRandomCosmetic(player: Player, rng: any): string?
	local d = Registry.Data.get(player)
	if not d or #buyable == 0 then
		return nil
	end
	local pick = buyable[rng:int(1, #buyable)]
	if d.Owned[pick.id] then
		Registry.Wallet.addNuggets(
			player,
			math.max(10, math.floor((pick.nuggets or 40) / 4)),
			"CosmeticDuplicate"
		)
		return nil
	end
	d.Owned[pick.id] = true
	return pick.id
end

-- The companion slot holds a critter id, not a cosmetic. Drops it when that critter is gone
-- (sold, stolen, Frontier reset) or being carried off, and publishes its look for other clients.
local function applyCompanion(player: Player, d: Profile.Data)
	local cid = d.Equipped.companion
	local critter = if cid then d.Critters[cid] else nil
	if cid and (not critter or critter.it) then
		(d.Equipped :: { [string]: string? }).companion = nil
		critter = nil
	end
	player:SetAttribute("Equip_companion", if critter then critter.s else nil)
	player:SetAttribute("CompanionTier", if critter then critter.tier else nil)
	player:SetAttribute("CompanionMutation", if critter then (critter.m or "") else nil)
end

-- Publishes equipped cosmetics as attributes so every client can render them.
function Shop.applyEquipped(player: Player)
	local d = Registry.Data.get(player)
	if not d then
		return
	end
	applyCompanion(player, d)
	for slot, id in d.Equipped do
		if slot ~= "companion" then
			player:SetAttribute("Equip_" .. slot, id)
		end
	end
	if Registry.Monetization.owns(player, "VIP") and not d.Equipped.lassoTrail then
		player:SetAttribute("Equip_lassoTrail", "trail_gold")
	end
	player:SetAttribute("VIP", Registry.Monetization.owns(player, "VIP"))
	player:SetAttribute("Club", Registry.Monetization.isSubscribed(player))
	Registry.Ui.pushState(player)
end

local function equip(player: Player, slot: string, id: string)
	local d = Registry.Data.get(player)
	if not d then
		return
	end
	if id == "" then
		d.Equipped[slot] = nil
		-- applyEquipped only sets slots that are still equipped, so clear this one for everyone.
		player:SetAttribute("Equip_" .. slot, nil)
	elseif slot == "companion" then
		-- One of your own critters (any pen, Branded too), as long as a thief isn't carrying it.
		local critter = d.Critters[id]
		if not critter or critter.it then
			return
		end
		d.Equipped.companion = id
	else
		local cosmetic = Cosmetics.byId[id]
		local vipTrail = id == "trail_gold" and Registry.Monetization.owns(player, "VIP")
		if not cosmetic or cosmetic.slot ~= slot or not (d.Owned[id] or vipTrail) then
			return
		end
		d.Equipped[slot] = id
	end
	Shop.applyEquipped(player)
end

local function setting(player: Player, key: string, value: any)
	local d = Registry.Data.get(player)
	if not d then
		return
	end
	local settings = d.Settings :: any
	local current = settings[key]
	if current == nil or typeof(current) ~= typeof(value) then
		return
	end
	if key == "Quality" and not table.find({ "auto", "low", "medium", "high" }, value) then
		return
	end
	settings[key] = value
	Registry.Ui.pushState(player)
end

function Shop.init()
	restock()
end

function Shop.start()
	Net.on("Equip", equip)
	Net.on("Setting", setting)
	local function premiumPerks(player: Player)
		local d = Registry.Data.get(player)
		if d and Registry.Monetization.isPremium(player) and not d.Owned.hat_premium then
			d.Owned.hat_premium = true
			Registry.Ui.toast(player, "Roblox Premium perks: +10% income and the Premium Top Hat (Wardrobe)!")
			Registry.Ui.pushState(player)
		end
	end
	Registry.Data.loaded:Connect(function(player)
		Shop.applyEquipped(player)
		premiumPerks(player)
	end)
	Players.PlayerMembershipChanged:Connect(function(player)
		premiumPerks(player)
		Registry.Ui.pushState(player)
	end)
	Registry.Monetization.passChanged:Connect(function(player)
		Shop.applyEquipped(player)
	end)
	RunService.Heartbeat:Connect(function()
		if now() >= nextRestock then
			restock()
		end
	end)
end

return Shop
