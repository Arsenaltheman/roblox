--!strict
-- Thin typed wrapper over RemoteEvents. The server creates the remotes; clients wait for them.
-- Every client -> server message goes through: guard (rate limit) -> schema check -> handler.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local RemoteNames = require("./RemoteNames")
local Schemas = require("./Schemas")

local FOLDER_NAME = "Remotes"
local UNRELIABLE = { Fx = true, ClientLog = true }

local Net = {}

-- Set by the server's GuardService: return false to drop the request (rate limited / blocked).
local guard: ((player: Player, name: string) -> boolean)? = nil
-- Called when a request fails schema validation (counts as a strike).
local onInvalid: ((player: Player, name: string) -> ())? = nil

local folder: Folder? = nil
local remotes: { [string]: Instance } = {}

local function getFolder(): Folder
	local cached = folder
	if cached then
		return cached
	end
	local f: Folder
	if RunService:IsServer() then
		local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		f = if existing then existing :: Folder else Instance.new("Folder")
		f.Name = FOLDER_NAME
		f.Parent = ReplicatedStorage
	else
		f = ReplicatedStorage:WaitForChild(FOLDER_NAME) :: Folder
	end
	folder = f
	return f
end

local function remote(name: string, className: string): Instance
	local cached = remotes[name]
	if cached then
		return cached
	end
	local f = getFolder()
	local instance: Instance
	if RunService:IsServer() then
		local existing = f:FindFirstChild(name)
		if existing then
			instance = existing
		else
			instance = Instance.new(className)
			instance.Name = name
			instance.Parent = f
		end
	else
		instance = f:WaitForChild(name)
	end
	remotes[name] = instance
	return instance
end

local function eventClass(name: string): string
	return if UNRELIABLE[name] then "UnreliableRemoteEvent" else "RemoteEvent"
end

-- Server: create every remote up front so clients never wait on a missing one.
function Net.initServer()
	for _, name in RemoteNames.clientToServer do
		remote(name, eventClass(name))
	end
	for _, name in RemoteNames.serverToClient do
		remote(name, eventClass(name))
	end
	for _, name in RemoteNames.functions do
		remote(name, "RemoteFunction")
	end
end

function Net.setGuard(
	fn: (player: Player, name: string) -> boolean,
	invalid: (player: Player, name: string) -> ()
)
	guard = fn
	onInvalid = invalid
end

-- Server: handle a client -> server event.
function Net.on(name: string, handler: (player: Player, ...any) -> ())
	assert(RunService:IsServer(), "Net.on is server-only")
	local event = remote(name, eventClass(name)) :: any
	event.OnServerEvent:Connect(function(player: Player, ...)
		if guard and not guard(player, name) then
			return
		end
		local count = select("#", ...)
		if not Schemas.validate(name, { ... }, count) then
			if onInvalid then
				onInvalid(player, name)
			end
			return
		end
		handler(player, ...)
	end)
end

-- Server: answer a client request (RemoteFunction). Invalid requests return nil.
function Net.onInvoke(name: string, handler: (player: Player, ...any) -> any)
	assert(RunService:IsServer(), "Net.onInvoke is server-only")
	local fn = remote(name, "RemoteFunction") :: RemoteFunction
	fn.OnServerInvoke = function(player: Player, ...)
		if guard and not guard(player, name) then
			return nil
		end
		local count = select("#", ...)
		if not Schemas.validate(name, { ... }, count) then
			if onInvalid then
				onInvalid(player, name)
			end
			return nil
		end
		return handler(player, ...)
	end
end

-- Server -> one client.
function Net.send(player: Player, name: string, ...: any)
	(remote(name, eventClass(name)) :: any):FireClient(player, ...)
end

-- Server -> everyone.
function Net.broadcast(name: string, ...: any)
	(remote(name, eventClass(name)) :: any):FireAllClients(...)
end

-- Client -> server.
function Net.request(name: string, ...: any)
	(remote(name, eventClass(name)) :: any):FireServer(...)
end

-- Client: ask the server and wait for the answer.
function Net.invoke(name: string, ...: any): any
	return (remote(name, "RemoteFunction") :: RemoteFunction):InvokeServer(...)
end

-- Client: listen for server -> client messages.
function Net.listen(name: string, handler: (...any) -> ()): RBXScriptConnection
	return (remote(name, eventClass(name)) :: any).OnClientEvent:Connect(handler)
end

return Net
