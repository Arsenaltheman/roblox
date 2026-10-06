--!strict
-- Per-server session facts: time in server, active minutes (Active Luck meter), server age.
-- A player is "active" if they moved or sent a request in the last idleAfterSeconds.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LuckConfig = require("@game/ReplicatedStorage/Shared/Config/Luck")
local Guard = require("./Guard")

local Session = {}

type Info = {
	joined: number,
	lastActive: number,
	activeSeconds: number,
	lastPosition: Vector3?,
	-- Movement sanity check state.
	lastCharacter: Model?,
	lastGood: Vector3?,
	consecutive: number?,
	violations: { number },
	suspiciousUntil: number?,
	dashUntil: number?,
}

local info: { [Player]: Info } = {}
local serverStart = os.clock()

function Session.serverAge(): number
	return os.clock() - serverStart
end

function Session.timeInServer(player: Player): number
	local i = info[player]
	return if i then os.clock() - i.joined else 0
end

function Session.activeMinutes(player: Player): number
	local i = info[player]
	return if i then i.activeSeconds / 60 else 0
end

function Session.isActive(player: Player): boolean
	local i = info[player]
	return i ~= nil and os.clock() - i.lastActive <= LuckConfig.idleAfterSeconds
end

-- Only real play counts as activity (a script pinging Setting/Sprint/ClientLog every 90 s used to
-- keep Active Luck, gifts and egg laying running).
local ACTIVE_REMOTES = {
	BuyCage = true,
	Collect = true,
	HeistGrab = true,
	StealStart = true,
	Lasso = true,
	HitBoss = true,
	CrackStart = true,
	Hatch = true,
	UseGear = true,
	SpinWheel = true,
}

function Session.touch(player: Player, remote: string?)
	local i = info[player]
	if i and (remote == nil or ACTIVE_REMOTES[remote]) then
		i.lastActive = os.clock()
	end
end

-- Movement sanity: true for a few seconds after a position jump the character couldn't have made.
-- Deliveries, grabs, steals and lassos are refused while suspicious.
function Session.isSuspicious(player: Player): boolean
	local i = info[player]
	return i ~= nil and os.clock() < (i.suspiciousUntil or 0)
end

-- The Grapple Hook legitimately moves a player ~60 studs in a second.
function Session.grantDash(player: Player, seconds: number)
	local i = info[player]
	if i then
		i.dashUntil = os.clock() + seconds
	end
end

local function canSample(character: Model): boolean
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Sit or humanoid.PlatformStand then
		return false
	end
	local state = humanoid:GetState()
	return state ~= Enum.HumanoidStateType.Dead
		and state ~= Enum.HumanoidStateType.Physics
		and state ~= Enum.HumanoidStateType.Seated
end

function Session.init()
	Guard.activity:Connect(Session.touch)
end

function Session.start()
	local function added(player: Player)
		local now = os.clock()
		info[player] = { joined = now, lastActive = now, activeSeconds = 0, violations = {} }
	end
	for _, player in Players:GetPlayers() do
		added(player)
	end
	Players.PlayerAdded:Connect(added)
	Players.PlayerRemoving:Connect(function(player)
		info[player] = nil
	end)

	-- Once a second: movement counts as activity; active time accumulates.
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 1 then
			return
		end
		local step = accumulator
		accumulator = 0
		for player, i in info do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root and character then
				local position = root.Position
				if i.lastPosition and (position - i.lastPosition).Magnitude > 0.5 then
					i.lastActive = os.clock()
				end
				-- Movement sanity check (horizontal). WalkSpeed is server-authored and already includes
				-- boots, spurs, carrying, sprint, bursts and stuns.
				local humanoid = character:FindFirstChildOfClass("Humanoid")
				if i.lastCharacter ~= character or not canSample(character) or not humanoid then
					i.lastCharacter = character
					i.lastGood = position
					i.consecutive = 0
				elseif i.lastGood then
					local moved = ((position - i.lastGood) * Vector3.new(1, 0, 1)).Magnitude
					local dash = if os.clock() < (i.dashUntil or 0) then 60 else 0
					local allowed = humanoid.WalkSpeed * step * 1.25 + 8 + dash
					if moved > allowed then
						i.consecutive = (i.consecutive or 0) + 1
						table.insert(i.violations, os.clock())
						-- One bad sample can be lag; two in a row (or a cross-map jump) is not.
						if i.consecutive >= 2 or moved > allowed + 150 then
							character:PivotTo(CFrame.new(i.lastGood + Vector3.new(0, 1, 0)))
							i.suspiciousUntil = os.clock() + 5
						end
						local recent = 0
						for _, at in i.violations do
							if os.clock() - at < 60 then
								recent += 1
							end
						end
						if recent >= 6 then
							table.clear(i.violations)
							Guard.strike(player, "movement")
						end
					else
						i.consecutive = 0
						i.lastGood = position
					end
				else
					i.lastGood = position
				end
				i.lastPosition = position
			end
			if os.clock() - i.lastActive <= LuckConfig.idleAfterSeconds then
				i.activeSeconds += step
			end
			player:SetAttribute("ActiveMinutes", math.floor(i.activeSeconds / 60))
		end
	end)
end

return Session
