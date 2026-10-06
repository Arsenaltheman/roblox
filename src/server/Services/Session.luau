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

function Session.touch(player: Player)
	local i = info[player]
	if i then
		i.lastActive = os.clock()
	end
end

function Session.init()
	Guard.activity:Connect(Session.touch)
end

function Session.start()
	local function added(player: Player)
		local now = os.clock()
		info[player] = { joined = now, lastActive = now, activeSeconds = 0 }
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
			if root then
				local position = root.Position
				if i.lastPosition and (position - i.lastPosition).Magnitude > 0.5 then
					i.lastActive = os.clock()
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
