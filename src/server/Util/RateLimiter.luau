--!strict
-- Token-bucket rate limiter keyed by anything (usually a Player).
-- `ratePerSecond` tokens refill per second up to `burst`. Pure Luau with an
-- injectable clock, tested with Lune.

export type RateLimiter = {
	Allow: (self: RateLimiter, key: any) -> boolean,
	Forget: (self: RateLimiter, key: any) -> (),
}

type Bucket = { Tokens: number, Updated: number }

local RateLimiter = {}

function RateLimiter.new(ratePerSecond: number, burst: number, clock: (() -> number)?): RateLimiter
	local now = clock or os.clock
	local buckets: { [any]: Bucket } = {}

	local limiter = {}

	function limiter.Allow(_self: any, key: any): boolean
		local time = now()
		local bucket = buckets[key]
		if bucket == nil then
			bucket = { Tokens = burst, Updated = time }
			buckets[key] = bucket
		else
			bucket.Tokens = math.min(burst, bucket.Tokens + (time - bucket.Updated) * ratePerSecond)
			bucket.Updated = time
		end

		if bucket.Tokens >= 1 then
			bucket.Tokens -= 1
			return true
		end
		return false
	end

	function limiter.Forget(_self: any, key: any)
		buckets[key] = nil
	end

	return (limiter :: any) :: RateLimiter
end

return RateLimiter
