--!strict
-- Game passes, developer products and the rules Roblox requires around them:
-- * Receipts are idempotent (a purchase id is granted once) and confirmed only after the save completes.
-- * Products that change random outcomes are hidden/blocked when PolicyService restricts paid random items
--   (and when the policy lookup fails, we treat the player as restricted).
-- * No purchase prompts within 2 minutes of a loss (robbed / bad reveal).

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local PolicyService = game:GetService("PolicyService")

local Products = require("@game/ReplicatedStorage/Shared/Config/Products")
local Economy = require("@game/ReplicatedStorage/Shared/Sim/Economy")
local Profile = require("@game/ReplicatedStorage/Shared/Sim/Profile")
local Signal = require("@game/ReplicatedStorage/Shared/Util/Signal")
local Registry = require("../Registry")

local Monetization = {}

Monetization.passChanged = Signal.new() :: Signal.Signal<Player, string>

type Policy = { randomRestricted: boolean, tradingAllowed: boolean }

local ownedPasses: { [Player]: { [string]: boolean } } = {}
local policies: { [Player]: Policy } = {}
local lastLoss: { [Player]: number } = {}

local productByAssetId: { [number]: Products.Product } = {}
for _, product in Products.list do
	if product.id then
		productByAssetId[product.id] = product
	end
end

function Monetization.policy(player: Player): Policy
	return policies[player] or { randomRestricted = true, tradingAllowed = false }
end

function Monetization.owns(player: Player, key: string): boolean
	local owned = ownedPasses[player]
	if owned and owned[key] then
		return true
	end
	local d = Registry.Data.get(player)
	return d ~= nil and d.Owned["pass:" .. key] == true
end

-- The Economy.Passes table used by every formula.
function Monetization.isPremium(player: Player): boolean
	return player.MembershipType == Enum.MembershipType.Premium
end

-- Sheriff's Club: a Roblox Subscription (status cached per player). In Studio without an id, a
-- test purchase grants 30 days in d.Boosts.Club instead.
local subscribed: { [Player]: boolean } = {}

local function refreshSubscription(player: Player)
	local id = Products.subscription.id
	if id == "" then
		return
	end
	local ok, status = pcall(function()
		return MarketplaceService:GetUserSubscriptionStatusAsync(player, id)
	end)
	if ok and status then
		subscribed[player] = (status :: any).IsSubscribed == true
	end
end

function Monetization.isSubscribed(player: Player): boolean
	if subscribed[player] then
		return true
	end
	local d = Registry.Data.get(player)
	return d ~= nil and (d.Boosts.Club or 0) > os.time()
end

function Monetization.passes(player: Player): Economy.Passes
	return {
		Premium = Monetization.isPremium(player),
		Club = Monetization.isSubscribed(player),
		DoubleCash = Monetization.owns(player, "DoubleCash"),
		VIP = Monetization.owns(player, "VIP"),
		IronLock = Monetization.owns(player, "IronLock"),
		BigRanch = Monetization.owns(player, "BigRanch"),
		HeavySaddlebag = Monetization.owns(player, "HeavySaddlebag"),
	}
end

function Monetization.timedBoostActive(player: Player, key: string): boolean
	local d = Registry.Data.get(player)
	return d ~= nil and (d.Boosts[key] or 0) > os.time()
end

-- Can this product be offered to this player right now?
function Monetization.canOffer(player: Player, key: string): (boolean, string?)
	local product = Products.byKey[key]
	if not product then
		return false, "unknown"
	end
	if product.random and Monetization.policy(player).randomRestricted then
		return false, "Not available in your region"
	end
	if key == "StarterPack" then
		local d = Registry.Data.get(player)
		if d and d.StarterPack then
			return false, "Already claimed"
		end
	end
	if
		(key == "GoldenLocomotive" or key == "DiamondDesperado")
		and not Registry.Ranch.canPlaceExclusive(player)
	then
		return false, "Every pen holds a branded critter. Get more pens first."
	end
	if key == "InstantHatch" and not Registry.Eggs.hasUnready(player) then
		return false, "No egg is waiting to hatch."
	end
	return true, nil
end

-- Record a loss so we don't push purchases at an upset player.
function Monetization.noteLoss(player: Player)
	lastLoss[player] = os.clock()
end

function Monetization.mayPrompt(player: Player): boolean
	local t = lastLoss[player]
	return t == nil or os.clock() - t >= Products.noPromptAfterLossSeconds
end

-- Set below (grant is defined after this function).
local studioGrant: (Player, Products.Product) -> ()
local promptSubscription: (Player) -> ()

function Monetization.prompt(player: Player, key: string)
	local product = Products.byKey[key]
	if product and product.kind == "subscription" then
		promptSubscription(player)
		return
	end
	if product and not product.id and RunService:IsStudio() then
		-- No Roblox id yet: in Studio, simulate the purchase for free so every item can be tested.
		-- Live servers never take this path.
		local okOffer, why = Monetization.canOffer(player, key)
		if not okOffer then
			Registry.Ui.toast(player, why or "Not available")
			return
		end
		studioGrant(player, product)
		return
	end
	if not product or not product.id then
		Registry.Ui.toast(player, "Coming soon! (The owner hasn't created this item on Roblox yet.)")
		return
	end
	local ok, reason = Monetization.canOffer(player, key)
	if not ok then
		Registry.Ui.toast(player, reason or "Not available")
		return
	end
	if product.kind == "pass" then
		MarketplaceService:PromptGamePassPurchase(player, product.id)
	elseif product.kind == "product" then
		MarketplaceService:PromptProductPurchase(player, product.id)
	end
end

-- Subscriptions have no numeric id; they're prompted by their subscription id string.
promptSubscription = function(player: Player)
	local id = Products.subscription.id
	if id == "" then
		if RunService:IsStudio() then
			local d = Registry.Data.get(player)
			if d then
				d.Boosts.Club = math.max(d.Boosts.Club or 0, os.time()) + 30 * 86400
				d.Owned.hat_club = true
				Registry.Ui.toast(player, "[STUDIO TEST] Sheriff's Club granted for 30 days.")
				Registry.Ui.pushState(player)
				Monetization.passChanged:Fire(player, "SheriffClub")
			end
		else
			Registry.Ui.toast(
				player,
				"Coming soon! (The owner hasn't created the subscription on Roblox yet.)"
			)
		end
		return
	end
	pcall(function()
		MarketplaceService:PromptSubscriptionPurchase(player, id)
	end)
end

-- Effects of developer products. Returns false if it can't be granted now (retry later).
local function grant(player: Player, product: Products.Product): boolean
	local d = Registry.Data.get(player)
	if not d then
		return false
	end
	local key = product.key
	local cashBag = Products.cashBagSeconds[key]
	if cashBag then
		local income = Registry.Ranch.income(player)
		return Registry.Wallet.addCash(player, Economy.cashBag(cashBag, income), "Robux:" .. key)
	elseif key == "ServerLuck2" or key == "ServerLuck3" or key == "ServerLuck5" then
		local mult = tonumber(string.sub(key, -1)) :: number
		Registry.Train.addServerLuck(mult)
		return true
	elseif key == "InstantHatch" then
		return Registry.Eggs.readyNow(player)
	elseif key == "Lockpick" then
		d.Stats.Lockpicks = (d.Stats.Lockpicks or 0) + 1
		return true
	elseif key == "StarterPack" then
		if d.StarterPack then
			-- Already granted (e.g. re-purchase): still a valid receipt; give cash instead of a duplicate.
			return Registry.Wallet.addCash(
				player,
				Economy.cashBag(3600, Registry.Ranch.income(player)),
				"Robux:StarterPackRepeat"
			)
		end
		d.StarterPack = true
		d.Boosts.DoubleCash = math.max(d.Boosts.DoubleCash or 0, os.time()) + 30 * 60
		d.Owned["hat_StarterStetson"] = true
		Registry.Ranch.grantExclusive(player, "DeputyDuck")
		return true
	elseif key == "GoldenLocomotive" or key == "DiamondDesperado" then
		return Registry.Ranch.grantExclusive(player, key)
	end
	warn("[Monetization] no grant for product " .. key)
	return false
end

local granting: { [string]: boolean } = {}

local function processReceipt(receipt): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local d = Registry.Data.waitFor(player)
	if not d then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local product = productByAssetId[receipt.ProductId]
	if not product then
		warn(`[Monetization] unknown product id {receipt.ProductId}`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local purchaseId = tostring(receipt.PurchaseId)
	-- Idempotency: a purchase id is granted at most once, even if Roblox retries.
	local alreadyHad = table.find(d.Receipts, purchaseId) ~= nil
	if not alreadyHad then
		-- Guard against Roblox re-invoking for the same purchase while grant() is running.
		if granting[purchaseId] then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		granting[purchaseId] = true
		local ok, granted = pcall(grant, player, product)
		granting[purchaseId] = nil
		if not ok or not granted then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		Profile.recordReceipt(d, purchaseId)
		d.RobuxSpent += receipt.CurrencySpent or 0
		Registry.Telemetry.custom(player, "Purchase:" .. product.key, receipt.CurrencySpent)
	end
	-- Only confirm once the grant is safely saved.
	local saved = false
	Registry.Data.afterSaveWhere(player, function(lastSaved)
		return table.find(lastSaved.Receipts or {}, purchaseId) ~= nil
	end, function()
		saved = true
	end)
	local deadline = os.clock() + 15
	while not saved and os.clock() < deadline and player.Parent == Players do
		task.wait(0.2)
	end
	if not saved then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	Registry.Ui.toast(player, `Thanks! {product.name} is yours.`)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

local function loadPlayer(player: Player)
	-- Policy (fail closed: restricted).
	local policy: Policy = { randomRestricted = true, tradingAllowed = false }
	local ok, info = pcall(function()
		return PolicyService:GetPolicyInfoForPlayerAsync(player)
	end)
	if ok and type(info) == "table" then
		policy.randomRestricted = info.ArePaidRandomItemsRestricted ~= false
		policy.tradingAllowed = info.IsPaidItemTradingAllowed == true
	end
	policies[player] = policy
	player:SetAttribute("RandomRestricted", policy.randomRestricted)

	-- Pass ownership.
	local owned = {}
	for _, product in Products.list do
		if product.kind == "pass" and product.id then
			local okPass, has = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, product.id :: number)
			end)
			if okPass and has then
				owned[product.key] = true
				player:SetAttribute("Pass_" .. product.key, true)
			end
		end
	end
	ownedPasses[player] = owned
end

studioGrant = function(player: Player, product: Products.Product)
	if product.kind == "pass" then
		local owned = ownedPasses[player] or {}
		owned[product.key] = true
		ownedPasses[player] = owned
		player:SetAttribute("Pass_" .. product.key, true)
		Monetization.passChanged:Fire(player, product.key)
	elseif product.kind == "product" then
		if not grant(player, product) then
			Registry.Ui.toast(player, "[STUDIO TEST] Couldn't grant that right now.")
			return
		end
		Registry.Ui.pushState(player)
	end
	Registry.Ui.toast(player, `[STUDIO TEST] {product.name} granted for free (no Robux in Studio).`)
end

function Monetization.init()
	MarketplaceService.ProcessReceipt = processReceipt
end

function Monetization.start()
	-- Subscription status: on join and whenever Roblox reports a change.
	Players.PlayerAdded:Connect(function(player)
		task.spawn(refreshSubscription, player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(refreshSubscription, player)
	end
	pcall(function()
		MarketplaceService.UserSubscriptionStatusChanged:Connect(
			function(player: Player, subscriptionId: string)
				if subscriptionId == Products.subscription.id then
					refreshSubscription(player)
					local d = Registry.Data.get(player)
					if d and subscribed[player] then
						d.Owned.hat_club = true
					end
					Monetization.passChanged:Fire(player, "SheriffClub")
					Registry.Ui.pushState(player)
				end
			end
		)
	end)
	Players.PlayerRemoving:Connect(function(player)
		subscribed[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(loadPlayer, player)
	end
	Players.PlayerAdded:Connect(loadPlayer)
	Players.PlayerRemoving:Connect(function(player)
		ownedPasses[player] = nil
		policies[player] = nil
		lastLoss[player] = nil
	end)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		for _, product in Products.list do
			if product.id == passId then
				local owned = ownedPasses[player] or {}
				owned[product.key] = true
				ownedPasses[player] = owned
				player:SetAttribute("Pass_" .. product.key, true)
				Monetization.passChanged:Fire(player, product.key)
				Registry.Ui.toast(player, `{product.name} unlocked!`)
			end
		end
	end)

	local Net = require("@game/ReplicatedStorage/Shared/Net/Net")
	Net.on("ShopBuy", function(player, key: string, _qty: number)
		if Products.byKey[key] then
			Monetization.prompt(player, key)
		else
			Registry.Shop.buy(player, key)
		end
	end)
end

return Monetization
