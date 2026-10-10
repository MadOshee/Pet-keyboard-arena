local MovementCheck = require("../src/shared/Logic/MovementCheck")

local SETTINGS = { Factor = 1.5, Margin = 2 }

local tests = {}

function tests.normalWalkIsFine()
	-- 16 studs/s for 0.1 s = 1.6 studs.
	assert(not MovementCheck.IsSuspicious(0, 0, 1.6, 0, 0.1, 16, SETTINGS))
end

function tests.teleportIsSuspicious()
	assert(MovementCheck.IsSuspicious(0, 0, 30, 0, 0.1, 16, SETTINGS))
end

function tests.limitIncludesFactorAndMargin()
	-- allowed = 16 * 0.1 * 1.5 + 2 = 4.4
	assert(not MovementCheck.IsSuspicious(0, 0, 4.3, 0, 0.1, 16, SETTINGS))
	assert(MovementCheck.IsSuspicious(0, 0, 3.2, 3.2, 0.1, 16, SETTINGS))
end

function tests.fasterWalkSpeedAllowsMore()
	assert(MovementCheck.IsSuspicious(0, 0, 6, 0, 0.1, 16, SETTINGS))
	assert(not MovementCheck.IsSuspicious(0, 0, 6, 0, 0.1, 30, SETTINGS))
end

return tests
