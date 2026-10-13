local Levels = require("../src/shared/Logic/Levels")

local CONFIG = { Base = 100, Step = 50 }

local tests = {}

function tests.needGrowsEachLevel()
	assert(Levels.Need(1, CONFIG) == 100)
	assert(Levels.Need(2, CONFIG) == 150)
	assert(Levels.Need(5, CONFIG) == 300)
end

function tests.levelFromTotalXp()
	local start = Levels.FromXP(0, CONFIG)
	assert(start.Level == 1 and start.Into == 0 and start.Need == 100)
	local almost = Levels.FromXP(99, CONFIG)
	assert(almost.Level == 1 and almost.Into == 99)
	local two = Levels.FromXP(100, CONFIG)
	assert(two.Level == 2 and two.Into == 0 and two.Need == 150)
	local three = Levels.FromXP(260, CONFIG)
	assert(three.Level == 3 and three.Into == 10 and three.Need == 200)
end

function tests.badXpCountsAsZero()
	assert(Levels.FromXP(-5, CONFIG).Level == 1)
	assert(Levels.FromXP(12.7, CONFIG).Into == 12)
end

return tests
