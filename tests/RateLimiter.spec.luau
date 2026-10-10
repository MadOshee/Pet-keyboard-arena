local RateLimiter = require("../src/server/Util/RateLimiter")

local tests = {}

function tests.allowsBurstThenBlocks()
	local now = 0
	local limiter = RateLimiter.new(1, 3, function()
		return now
	end)
	assert(limiter:Allow("a") and limiter:Allow("a") and limiter:Allow("a"))
	assert(not limiter:Allow("a"), "fourth request should be blocked")
end

function tests.refillsOverTime()
	local now = 0
	local limiter = RateLimiter.new(2, 1, function()
		return now
	end)
	assert(limiter:Allow("a"))
	assert(not limiter:Allow("a"))
	now = 0.5
	assert(limiter:Allow("a"), "one token should refill after 0.5s at 2/s")
end

function tests.keysAreIndependent()
	local limiter = RateLimiter.new(1, 1, function()
		return 0
	end)
	assert(limiter:Allow("a"))
	assert(limiter:Allow("b"))
	assert(not limiter:Allow("a"))
end

return tests
