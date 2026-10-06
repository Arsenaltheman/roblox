--!strict
-- The Prize Wheel. Spins are free only: one each UTC day, one per HEISTS_PER_SPIN delivered heists
-- and one per 5 minutes played (stored up to MAX_STORED). They are never sold for Robux. Jackpot:
-- at most one per UTC day, guaranteed by the JACKPOT_GUARANTEE_SPIN-th spin of the day.
-- The server rolls and grants the prize first; the client's spin animation only shows the result.

local Players = game:GetService("Players")

local Species = require("@game/ReplicatedStorage/Shared/Config/Species")
local WheelConfig = require("@game/ReplicatedStorage/Shared/Config/Wheel")
local NumberFormat = require("@game/ReplicatedStorage/Shared/Sim/NumberFormat")
local Profile = require("@game/ReplicatedStorage/Shared/Sim/Profile")
local Net = require("@game/ReplicatedStorage/Shared/Net/Net")
local Registry = require("../Registry")

local Wheel = {}

local random = Random.new()
local spinning: { [Player]: boolean } = {}

local function spins(player: Player): number
	local d = Registry.Data.get(player)
	return if d then d.Stats.Spins or 0 else 0
end

local function mirror(player: Player)
	player:SetAttribute("Spins", spins(player))
	local d = Registry.Data.get(player)
	if d then
		local today = WheelConfig.day(os.time())
		player:SetAttribute("JackpotToday", (d.Stats.JackpotDay or 0) == today)
		player:SetAttribute(
			"SpinsToday",
			if (d.Stats.SpinDay or 0) == today then d.Stats.SpinsToday or 0 else 0
		)
	end
end

function Wheel.addSpins(player: Player, count: number, reason: string)
	local d = Registry.Data.get(player)
	if not d or count <= 0 then
		return
	end
	local before = d.Stats.Spins or 0
	d.Stats.Spins = math.min(WheelConfig.MAX_STORED, before + count)
	if d.Stats.Spins > before then
		mirror(player)
		Registry.Ui.toast(player, `+1 FREE SPIN! ({reason})`)
		Registry.Ui.fx(player, "spinEarned", d.Stats.Spins)
	end
end

-- Called by Heist after each delivery.
function Wheel.heistDelivered(player: Player)
	local d = Registry.Data.get(player)
	if d and (d.Stats.Heists or 0) % WheelConfig.HEISTS_PER_SPIN == 0 then
		Wheel.addSpins(player, 1, "heist streak")
	end
end

local function grant(player: Player, segment: WheelConfig.Segment): string
	local d = Registry.Data.get(player)
	if not d then
		return ""
	end
	if segment.kind == "cash" then
		local amount = math.max(250, Registry.Ranch.income(player) * segment.amount)
		Registry.Wallet.addCash(player, amount, "Wheel")
		return `+{NumberFormat.cash(amount)}`
	elseif segment.kind == "nuggets" then
		Registry.Wallet.addNuggets(player, segment.amount, "Wheel")
		return `+{segment.amount} Gold Nuggets`
	elseif segment.kind == "spins" then
		d.Stats.Spins = math.min(WheelConfig.MAX_STORED, (d.Stats.Spins or 0) + segment.amount)
		return "+1 Free Spin"
	end
	-- Critter: a few tiers above your best (at least tier 3), never above the top non-secret tier.
	local tier = math.clamp(Profile.bestTier(d) + segment.amount, 3, 38)
	local species = Species.byTier[tier]
	local cid = Registry.Ranch.addCritter(player, { species = species.id, tier = tier, src = "wheel" })
	if cid then
		Registry.Ui.reveal(player, { kind = "wheel", species = species.id, tier = tier })
		return `a {species.name}!`
	end
	-- Pens full of better critters: pay its value instead.
	local amount = math.max(250, Registry.Ranch.income(player) * 1800)
	Registry.Wallet.addCash(player, amount, "WheelFallback")
	return `+{NumberFormat.cash(amount)}`
end

local function spin(player: Player)
	if spinning[player] or not Registry.LiveConfig.enabled("ff.wheel") then
		return
	end
	local d = Registry.Data.get(player)
	if not d or (d.Stats.Spins or 0) <= 0 then
		Registry.Ui.toast(player, "No spins left. Pull heists or come back tomorrow!")
		return
	end
	spinning[player] = true
	d.Stats.Spins -= 1
	-- Daily jackpot rules: at most one per UTC day, and guaranteed by the Nth spin of the day.
	local today = WheelConfig.day(os.time())
	if (d.Stats.SpinDay or 0) ~= today then
		d.Stats.SpinDay = today
		d.Stats.SpinsToday = 0
	end
	local jackpotToday = (d.Stats.JackpotDay or 0) == today
	local index = WheelConfig.pickFor(random:NextNumber(), jackpotToday, d.Stats.SpinsToday or 0)
	d.Stats.SpinsToday = (d.Stats.SpinsToday or 0) + 1
	if WheelConfig.segments[index].id == WheelConfig.JACKPOT_ID then
		d.Stats.JackpotDay = today
	end
	local segment = WheelConfig.segments[index]
	local prizeText = grant(player, segment)
	d.Stats.WheelSpins = (d.Stats.WheelSpins or 0) + 1
	Registry.Progression.questEvent(player, "spin", 1)
	mirror(player)
	Registry.Ui.pushState(player)
	Registry.Data.saveNow(player)
	Net.send(player, "WheelResult", index, prizeText)
	if segment.id == "jackpot" then
		Registry.Ui.announce(`{player.DisplayName} hit the JACKPOT on the Prize Wheel!`, "golden")
	end
	-- The client animation takes ~5 s; don't allow overlapping spins meanwhile.
	task.delay(4.5, function()
		spinning[player] = nil
	end)
end

function Wheel.init() end

function Wheel.start()
	Net.on("SpinWheel", spin)
	Registry.Data.loaded:Connect(function(player: Player, d: any)
		-- Daily free spin.
		local today = WheelConfig.day(os.time())
		if (d.Stats.LastSpinDay or 0) < today then
			d.Stats.LastSpinDay = today
			d.Stats.Spins = math.min(WheelConfig.MAX_STORED, (d.Stats.Spins or 0) + WheelConfig.DAILY_SPINS)
		end
		mirror(player)
	end)
	-- Playtime spins.
	task.spawn(function()
		while true do
			task.wait(60)
			for _, player in Players:GetPlayers() do
				local d = Registry.Data.get(player)
				if d then
					d.Stats.WheelPlay = (d.Stats.WheelPlay or 0) + 60
					if d.Stats.WheelPlay >= WheelConfig.PLAY_SECONDS_PER_SPIN then
						d.Stats.WheelPlay = 0
						Wheel.addSpins(player, 1, "5 minutes played")
					end
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		spinning[player] = nil
	end)
end

return Wheel
