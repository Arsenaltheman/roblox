--!strict
-- The one big contextual action button: figures out the best thing to do where you stand
-- (BUY / CRACK / STEAL / LASSO / GRAB / LOCK / PICK LOCK) and sends it to the server.
-- Keyboard: E. Gamepad: ButtonX. Mobile: the big button.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Layout = require("@game/ReplicatedStorage/Shared/Config/Layout")
local Rarities = require("@game/ReplicatedStorage/Shared/Config/Rarities")
local Species = require("@game/ReplicatedStorage/Shared/Config/Species")
local NumberFormat = require("@game/ReplicatedStorage/Shared/Sim/NumberFormat")
local TrainClock = require("@game/ReplicatedStorage/Shared/Sim/TrainClock")
local Net = require("@game/ReplicatedStorage/Shared/Net/Net")
local TrainView = require("./TrainView")
local HeistView = require("./HeistView")
local Sound = require("./Sound")
local Store = require("../Store")

local LASSO_RANGE = 40
local STEAL_RANGE = 9
local PLATE_RANGE = 8

local Context = {}

local localPlayer = Players.LocalPlayer

type Action = {
	kind: string,
	label: string,
	sub: string,
	run: () -> (),
}

local current: Action? = nil
local cracked: { [number]: boolean } = {}

local function myRoot(): BasePart?
	local character = localPlayer.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function myRanchIndex(): number?
	return localPlayer:GetAttribute("Ranch") :: number?
end

local function ranchesFolder(): Instance?
	local town = Workspace:FindFirstChild("Town")
	return town and town:FindFirstChild("Ranches")
end

local function cageAction(rootPos: Vector3): Action?
	local epoch = Workspace:GetAttribute("TrainEpoch") :: number?
	if not epoch then
		return nil
	end
	local state = TrainClock.at(epoch, Workspace:GetServerTimeNow())
	if not state.doorsOpen then
		return nil
	end
	local manifest = TrainView.manifest(state.cycle)
	if not manifest then
		return nil
	end
	local best: any = nil
	local bestScore = math.huge
	for _, cage in manifest.cages do
		if (cage.o == 0 or cage.o == localPlayer.UserId) and not TrainView.isSold(state.cycle, cage.id) then
			local pos = TrainView.cageWorldPosition(cage.id)
			if pos then
				local d = (pos - rootPos).Magnitude
				if d <= Layout.reach then
					-- Prefer your reserved cage, then the closest.
					local score = d - (if cage.o == localPlayer.UserId then 100 else 0)
					if score < bestScore then
						best, bestScore = cage, score
					end
				end
			end
		end
	end
	if not best then
		return nil
	end
	local cage = best
	local cycle = state.cycle
	local name = Species.byId[cage.s].name
	return {
		kind = "buy",
		label = "BUY " .. NumberFormat.cash(cage.p),
		sub = (if cage.m then cage.m .. " " else "") .. name,
		run = function()
			Sound.play("lassoThrow", 0.05)
			Net.request("BuyCage", cycle, cage.id)
		end,
	}
end

local function crackAction(rootPos: Vector3): Action?
	local epoch = Workspace:GetAttribute("TrainEpoch") :: number?
	if not epoch then
		return nil
	end
	local state = TrainClock.at(epoch, Workspace:GetServerTimeNow())
	if state.phase ~= "dwelling" or not state.hasStrongbox or cracked[state.cycle] then
		return nil
	end
	local pos = TrainView.strongboxPosition()
	if not pos or (pos - rootPos).Magnitude > Layout.reach + 6 then
		return nil
	end
	local cycle = state.cycle
	return {
		kind = "crack",
		label = "CRACK!",
		sub = "Strongbox",
		run = function()
			cracked[cycle] = true
			Store.grab({ started = os.clock(), duration = 1.5 })
			Net.request("CrackStart", cycle)
		end,
	}
end

local function lassoAction(rootPos: Vector3): Action?
	local bestPlayer: Player? = nil
	local bestDist = LASSO_RANGE * (if localPlayer:GetAttribute("Pass_GoldenLasso") then 1.5 else 1)
	for _, other in Players:GetPlayers() do
		if other ~= localPlayer and other:GetAttribute("Wanted") then
			local character = other.Character
			local r = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if r then
				local d = (r.Position - rootPos).Magnitude
				-- Thieves carrying YOUR critter win ties.
				if other:GetAttribute("CarryingFrom") == localPlayer.UserId then
					d -= 15
				end
				if d < bestDist then
					bestPlayer, bestDist = other, d
				end
			end
		end
	end
	if bestPlayer then
		local target = bestPlayer
		return {
			kind = "lasso",
			label = "LASSO!",
			sub = target.DisplayName,
			run = function()
				Sound.play("lassoThrow", 0.05)
				Net.request("Lasso", target.UserId)
			end,
		}
	end
	-- Tutorial bandit
	local npcs = Workspace:FindFirstChild("NPCs")
	if npcs then
		for _, npc in npcs:GetChildren() do
			if npc:GetAttribute("TutorialFor") == localPlayer.UserId then
				local r = npc:FindFirstChild("HumanoidRootPart") :: BasePart?
				if r and (r.Position - rootPos).Magnitude < LASSO_RANGE * 1.5 then
					return {
						kind = "lasso",
						label = "LASSO!",
						sub = "Bandit Bart",
						run = function()
							Sound.play("lassoThrow", 0.05)
							Net.request("Lasso", 1)
						end,
					}
				end
			end
		end
	end
	return nil
end

local function stealAction(rootPos: Vector3): Action?
	if localPlayer:GetAttribute("Wanted") then
		return nil
	end
	local ranches = ranchesFolder()
	if not ranches then
		return nil
	end
	local mine = myRanchIndex()
	local best: BasePart? = nil
	local bestRanch = 0
	local bestDist = STEAL_RANGE
	for _, ranch in ranches:GetChildren() do
		local index = ranch:GetAttribute("Index") :: number?
		local owner = ranch:GetAttribute("Owner") :: number?
		if index and index ~= mine and owner and owner ~= 0 then
			local pens = ranch:FindFirstChild("Pens")
			if pens then
				for _, pad in pens:GetChildren() do
					if
						pad:IsA("BasePart")
						and (pad:GetAttribute("Critter") or "") ~= ""
						and not pad:GetAttribute("InTransit")
					then
						local d = (pad.Position - rootPos).Magnitude
						if d < bestDist then
							best, bestRanch, bestDist = pad, index, d
						end
					end
				end
			end
		end
	end
	if not best then
		return nil
	end
	local pad = best
	local ranchIndex = bestRanch
	local speciesId = pad:GetAttribute("Critter") :: string
	local tier = (pad:GetAttribute("Tier") :: number?) or 1
	local protected = pad:GetAttribute("Branded") == true
	return {
		kind = if protected then "protected" else "steal",
		label = if protected then "BRANDED" else "STEAL",
		sub = Rarities.forTier(tier).name
			.. " "
			.. (Species.byId[speciesId] and Species.byId[speciesId].name or ""),
		run = function()
			if protected then
				Store.toast("Branded critters can't be stolen.")
				return
			end
			Net.request("StealStart", ranchIndex, pad:GetAttribute("Cid") :: string)
		end,
	}
end

local function banditAction(rootPos: Vector3): Action?
	local town = Workspace:FindFirstChild("Town")
	local camp = town and town:FindFirstChild("BanditCamp")
	local loot = camp and camp:FindFirstChild("Loot")
	if not loot then
		return nil
	end
	for _, pad in loot:GetChildren() do
		if pad:IsA("BasePart") and (pad.Position - rootPos).Magnitude <= STEAL_RANGE then
			local n = pad:GetAttribute("BanditPen") :: number
			return {
				kind = "grab",
				label = "GRAB",
				sub = "Wait till he naps!",
				run = function()
					Net.request("StealStart", 9, tostring(n))
				end,
			}
		end
	end
	return nil
end

-- LASSO the Bandit King during his raid (Config/Boss).
local BOSS_RANGE = 45
local function bossAction(rootPos: Vector3): Action?
	local king = Workspace:FindFirstChild("BanditKing")
	local root = king and king:FindFirstChild("Root") :: BasePart?
	if not king or not root then
		return nil
	end
	local hp = (king:GetAttribute("Hp") :: number?) or 0
	if hp <= 0 or (root.Position - rootPos).Magnitude > BOSS_RANGE then
		return nil
	end
	return {
		kind = "lasso",
		label = "LASSO KING!",
		sub = `{hp} / {(king:GetAttribute("MaxHp") :: number?) or hp} HP`,
		run = function()
			Net.request("HitBoss")
		end,
	}
end

-- GRAB a crate off a heist nest (the server starts the guards chasing).
local function heistAction(rootPos: Vector3): Action?
	if
		localPlayer:GetAttribute("HeistCarry") == true
		or (localPlayer:GetAttribute("Carrying") or "") ~= ""
	then
		return nil
	end
	local zone, nest, species, tier = HeistView.nearestCrate(rootPos)
	if not zone or not nest then
		return nil
	end
	local rarity = Rarities.forTier(tier or 1)
	return {
		kind = "grab",
		label = "GRAB!",
		sub = `{rarity.name} {HeistView.speciesName(species)}`,
		run = function()
			Net.request("HeistGrab", zone, nest)
		end,
	}
end

local function plateAction(rootPos: Vector3): Action?
	local ranches = ranchesFolder()
	local mine = myRanchIndex()
	if not ranches or not mine then
		return nil
	end
	local ranch = ranches:FindFirstChild("Ranch" .. mine)
	local plate = ranch and ranch:FindFirstChild("LockPlate") :: BasePart?
	if plate and (plate.Position - rootPos).Magnitude <= PLATE_RANGE then
		local lockedUntil = (ranch :: Instance):GetAttribute("LockedUntil") :: number? or 0
		if Workspace:GetServerTimeNow() >= lockedUntil then
			return {
				kind = "lock",
				label = "LOCK",
				sub = "Close the gate",
				run = function()
					Net.request("Lock")
				end,
			}
		end
	end
	-- Lockpick another ranch's locked gate.
	local state = Store.state()
	if state and (state.lockpicks or 0) > 0 then
		for _, other in ranches:GetChildren() do
			local index = other:GetAttribute("Index") :: number?
			local gate = other:FindFirstChild("Gate") :: BasePart?
			local lockedUntil = (other:GetAttribute("LockedUntil") :: number?) or 0
			if
				index
				and index ~= mine
				and gate
				and Workspace:GetServerTimeNow() < lockedUntil
				and (gate.Position - rootPos).Magnitude < 14
			then
				return {
					kind = "lockpick",
					label = "PICK LOCK",
					sub = `{state.lockpicks} left`,
					run = function()
						Net.request("Lockpick", index)
					end,
				}
			end
		end
	end
	return nil
end

function Context.execute()
	local action = current
	if action then
		action.run()
	end
end

function Context.init() end

function Context.start()
	ContextActionService:BindAction("CritterAction", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			Context.execute()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.E, Enum.KeyCode.ButtonX)

	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.1 then
			return
		end
		accumulator = 0
		local root = myRoot()
		if not root then
			current = nil
			Store.action({ kind = "", label = "", sub = "" })
			return
		end
		local pos = root.Position
		local action = lassoAction(pos)
			or bossAction(pos)
			or cageAction(pos)
			or crackAction(pos)
			or stealAction(pos)
			or banditAction(pos)
			or heistAction(pos)
			or plateAction(pos)
		current = action
		local previous = Store.action()
		local nextValue = if action
			then { kind = action.kind, label = action.label, sub = action.sub }
			else { kind = "", label = "", sub = "" }
		if
			previous.kind ~= nextValue.kind
			or previous.label ~= nextValue.label
			or previous.sub ~= nextValue.sub
		then
			Store.action(nextValue)
		end
		-- Grab progress ring finishes on its own.
		local grab = Store.grab()
		if grab and os.clock() - grab.started > grab.duration + 0.3 then
			Store.grab(nil)
		end
	end)
end

return Context
