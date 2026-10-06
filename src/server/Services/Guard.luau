--!strict
-- Anti-exploit front door: rate limits every request and counts strikes for malformed ones.
-- More than STRIKE_LIMIT strikes in STRIKE_WINDOW seconds kicks the player (never an auto-ban:
-- false positives must cost a rejoin, not an account).

local Players = game:GetService("Players")

local Net = require("@game/ReplicatedStorage/Shared/Net/Net")
local RateLimit = require("@game/ReplicatedStorage/Shared/Sim/RateLimit")
local Signal = require("@game/ReplicatedStorage/Shared/Util/Signal")

local STRIKE_LIMIT = 10
local STRIKE_WINDOW = 60

local Guard = {}

Guard.activity = Signal.new() :: Signal.Signal<Player>

local limiters: { [Player]: RateLimit.Limiter } = {}
local strikes: { [Player]: { number } } = {}

function Guard.strike(player: Player, reason: string)
	local list = strikes[player]
	if not list then
		list = {}
		strikes[player] = list
	end
	local now = os.clock()
	table.insert(list, now)
	while #list > 0 and now - list[1] > STRIKE_WINDOW do
		table.remove(list, 1)
	end
	if #list > STRIKE_LIMIT then
		warn(`[Guard] kicking {player.UserId}: {reason}`)
		player:Kick("Connection problem detected. Please rejoin.")
	end
end

function Guard.allow(player: Player, name: string): boolean
	local limiter = limiters[player]
	if not limiter then
		limiter = RateLimit.newLimiter()
		limiters[player] = limiter
	end
	if not limiter:allow(name, os.clock()) then
		-- Dropped silently. No strike: real players mash buttons (lasso, buy), and kicking them
		-- for it is worse than ignoring a few extra requests. Malformed requests still strike.
		return false
	end
	Guard.activity:Fire(player)
	return true
end

function Guard.init()
	Net.setGuard(Guard.allow, function(player, name)
		Guard.strike(player, "invalid:" .. name)
	end)
end

function Guard.start()
	Players.PlayerRemoving:Connect(function(player)
		limiters[player] = nil
		strikes[player] = nil
	end)
end

return Guard
