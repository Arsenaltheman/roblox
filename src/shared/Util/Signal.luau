--!strict
-- Minimal signal for in-process events between services/controllers.

export type Connection = { Disconnect: (self: Connection) -> (), connected: boolean }
export type Signal<T...> = {
	Connect: (self: Signal<T...>, fn: (T...) -> ()) -> Connection,
	Once: (self: Signal<T...>, fn: (T...) -> ()) -> Connection,
	Fire: (self: Signal<T...>, T...) -> (),
	DisconnectAll: (self: Signal<T...>) -> (),
}

local Signal = {}
Signal.__index = Signal

function Signal.new<T...>(): Signal<T...>
	return (setmetatable({ _handlers = {} }, Signal) :: any) :: Signal<T...>
end

function Signal.Connect(self: any, fn)
	local connection = { connected = true }
	function connection.Disconnect(c)
		c.connected = false
		local index = table.find(self._handlers, c)
		if index then
			table.remove(self._handlers, index)
		end
	end
	connection.fn = fn
	table.insert(self._handlers, connection)
	return connection
end

function Signal.Once(self: any, fn)
	local connection
	connection = Signal.Connect(self, function(...)
		connection:Disconnect()
		fn(...)
	end)
	return connection
end

function Signal.Fire(self: any, ...)
	-- Copy so handlers can disconnect while firing.
	for _, connection: any in table.clone(self._handlers) do
		if connection.connected then
			local ok, err = pcall(connection.fn, ...)
			if not ok then
				warn("[Signal] handler error: " .. tostring(err))
			end
		end
	end
end

function Signal.DisconnectAll(self: any)
	for _, connection in self._handlers do
		connection.connected = false
	end
	table.clear(self._handlers)
end

return Signal
