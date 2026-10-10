local Guard = require("../src/server/Util/Guard")

local tests = {}

function tests.boolean()
	assert(Guard.Boolean(true) and Guard.Boolean(false))
	assert(not Guard.Boolean(nil) and not Guard.Boolean(1) and not Guard.Boolean("true"))
end

function tests.integerRejectsNanFractionsAndRange()
	assert(Guard.Integer(3, 1, 4))
	assert(not Guard.Integer(0 / 0, 1, 4))
	assert(not Guard.Integer(math.huge, 1, math.huge))
	assert(not Guard.Integer(2.5, 1, 4))
	assert(not Guard.Integer(5, 1, 4))
	assert(not Guard.Integer("3", 1, 4))
end

function tests.stringLength()
	assert(Guard.String("abc", 3))
	assert(not Guard.String("", 3))
	assert(not Guard.String("abcd", 3))
	assert(not Guard.String(12, 3))
end

return tests
