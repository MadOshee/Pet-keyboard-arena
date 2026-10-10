--!strict
-- Type checks for remote arguments. Anything a client sends is untrusted:
-- check the type and range before using it. Pure Luau, tested with Lune.

local Guard = {}

function Guard.Boolean(value: unknown): boolean
	return type(value) == "boolean"
end

function Guard.Integer(value: unknown, min: number, max: number): boolean
	if type(value) ~= "number" then
		return false
	end
	local number = value :: number
	-- Rejects NaN and infinities as well as fractions.
	return number == number and number % 1 == 0 and number >= min and number <= max
end

function Guard.String(value: unknown, maxLength: number): boolean
	return type(value) == "string" and #value > 0 and #value <= maxLength
end

return Guard
