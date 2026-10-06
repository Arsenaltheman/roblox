--!strict
-- Player saves via ProfileStore (session locking prevents duplication across servers).
-- Version guard: a server never loads a profile written by newer code (rolling updates).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ProfileStore = require("@game/ServerStorage/Packages/ProfileStore")
local Profile = require("@game/ReplicatedStorage/Shared/Sim/Profile")
local Signal = require("@game/ReplicatedStorage/Shared/Util/Signal")

-- Bump the store name only for a deliberate wipe (never in normal updates).
local STORE_NAME = "PlayerData_v1"

local Data = {}

Data.loaded = Signal.new() :: Signal.Signal<Player, Profile.Data>
Data.releasing = Signal.new() :: Signal.Signal<Player, Profile.Data>

local store: any = ProfileStore.New(STORE_NAME, Profile.template())
local profiles: { [Player]: any } = {}

function Data.get(player: Player): Profile.Data?
	local profile = profiles[player]
	return if profile then profile.Data else nil
end

function Data.isLoaded(player: Player): boolean
	return profiles[player] ~= nil
end

-- Yields until the player's data is loaded (or they leave). Returns nil if they left.
function Data.waitFor(player: Player): Profile.Data?
	while player.Parent == Players and profiles[player] == nil do
		task.wait(0.1)
	end
	return Data.get(player)
end

-- Ask ProfileStore to save soon (used after important changes: purchases, steals, Frontiers).
function Data.saveNow(player: Player)
	local profile = profiles[player]
	if profile then
		profile:Save()
	end
end

-- Connect to the next completed save of this player's profile (used to confirm Robux purchases).
function Data.afterNextSave(player: Player, fn: () -> ()): boolean
	local profile = profiles[player]
	if not profile then
		return false
	end
	local connection
	connection = profile.OnAfterSave:Connect(function()
		connection:Disconnect()
		fn()
	end)
	profile:Save()
	return true
end

local function onPlayerAdded(player: Player)
	local profile = store:StartSessionAsync(tostring(player.UserId), {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})
	if profile == nil then
		if player.Parent == Players then
			player:Kick("We couldn't load your ranch. Please rejoin in a moment.")
		end
		return
	end

	profile:AddUserId(player.UserId)
	profile:Reconcile()

	local result = Profile.migrate(profile.Data)
	if not result.ok then
		-- "newer" means this server runs old code: don't touch the data, send them to a fresh server.
		profile:EndSession()
		player:Kick(
			if result.reason == "newer"
				then "The game just updated! Please rejoin."
				else "We couldn't load your ranch safely. Please rejoin."
		)
		warn(`[Data] migrate failed for {player.UserId}: {result.reason}`)
		return
	end
	profile.Data = result.data

	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		if player.Parent == Players then
			player:Kick("Your ranch was opened in another server.")
		end
	end)

	if player.Parent ~= Players then
		profile:EndSession()
		return
	end

	local data = profile.Data :: Profile.Data
	local now = os.time()
	if data.Meta.Created == 0 then
		data.Meta.Created = now
	end
	data.Meta.Joins += 1
	data.Meta.LastJoin = now
	profiles[player] = profile
	Data.loaded:Fire(player, data)
end

function Data.init()
	if RunService:IsStudio() then
		-- Studio without API access uses an in-memory store so playtests still work.
		local ok = pcall(function()
			game:GetService("DataStoreService"):GetDataStore("__probe"):GetAsync("probe")
		end)
		if not ok then
			store = store.Mock
			warn("[Data] Studio has no DataStore access: using a temporary mock store (nothing is saved).")
		end
	end
end

function Data.start()
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		local profile = profiles[player]
		if profile then
			Data.releasing:Fire(player, profile.Data)
			profile.Data.LastSeen = os.time()
			profile:EndSession()
		end
		profiles[player] = nil
	end)
end

return Data
