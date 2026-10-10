local Signal = require("../src/shared/Util/Signal")

local tests = {}

function tests.firesHandlersInOrderWithArguments()
	local signal = Signal.new()
	local log = {}
	signal:Connect(function(a, b)
		table.insert(log, `1:{a}{b}`)
	end)
	signal:Connect(function(a, b)
		table.insert(log, `2:{a}{b}`)
	end)
	signal:Fire("x", "y")
	assert(table.concat(log, ",") == "1:xy,2:xy", table.concat(log, ","))
end

function tests.disconnectStopsHandler()
	local signal = Signal.new()
	local count = 0
	local connection = signal:Connect(function()
		count += 1
	end)
	signal:Fire()
	connection:Disconnect()
	signal:Fire()
	assert(count == 1 and connection.Connected == false)
end

function tests.disconnectDuringFireIsSafe()
	local signal = Signal.new()
	local count = 0
	local second
	signal:Connect(function()
		second:Disconnect()
	end)
	second = signal:Connect(function()
		count += 1
	end)
	signal:Fire()
	assert(count == 0, "handler disconnected mid-fire should not run")
end

return tests
