--!strict
-- Minimal synchronous signal. Handlers run in connection order on Fire and
-- must not yield. Pure Luau, so modules using it stay testable with Lune.

export type Connection = {
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
}

export type Signal<T...> = {
	Connect: (self: Signal<T...>, handler: (T...) -> ()) -> Connection,
	Fire: (self: Signal<T...>, T...) -> (),
	DisconnectAll: (self: Signal<T...>) -> (),
}

type Handler = { Fn: (...any) -> (), Connection: Connection }

local Signal = {}

function Signal.new<T...>(): Signal<T...>
	local handlers: { Handler } = {}

	local function disconnect(connection: Connection)
		if not connection.Connected then
			return
		end
		connection.Connected = false
		for index, handler in handlers do
			if handler.Connection == connection then
				table.remove(handlers, index)
				break
			end
		end
	end

	local signal = {}

	function signal.Connect(_self: any, handler: (...any) -> ()): Connection
		local connection = { Connected = true, Disconnect = disconnect }
		table.insert(handlers, { Fn = handler, Connection = connection })
		return connection
	end

	function signal.Fire(_self: any, ...: any)
		for _, handler in table.clone(handlers) do
			if handler.Connection.Connected then
				handler.Fn(...)
			end
		end
	end

	function signal.DisconnectAll(_self: any)
		for _, handler in handlers do
			handler.Connection.Connected = false
		end
		table.clear(handlers)
	end

	return (signal :: any) :: Signal<T...>
end

return Signal
