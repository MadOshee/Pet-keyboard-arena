local PetConfig = require("../src/shared/Config/PetConfig")
local StatCalculator = require("../src/shared/Logic/StatCalculator")

local function near(a: number, b: number): boolean
	return math.abs(a - b) < 1e-9
end

local function pet(kind: string, rarity: string)
	return { Kind = kind, Rarity = rarity }
end

local tests = {}

function tests.noPetsGivesZero()
	local stats = StatCalculator.Totals({}, PetConfig)
	assert(stats.Speed == 0 and stats.PaintRadius == 0 and stats.Luck == 0 and stats.Coins == 0)
end

function tests.eachThemeBoostsItsStat()
	local stats = StatCalculator.Totals({
		pet("Fox", "Rare"), -- Basic: Coins
		pet("Lynx", "Rare"), -- Forest: Speed
		pet("PolarBear", "Rare"), -- Arctic: PaintRadius
	}, PetConfig)
	assert(near(stats.Coins, 0.2))
	assert(near(stats.Speed, 0.04))
	assert(near(stats.PaintRadius, 0.08))
	assert(stats.Luck == 0)
end

function tests.bonusesStack()
	local stats = StatCalculator.Totals({
		pet("Tiger", "Epic"),
		pet("Lynx", "Rare"),
		pet("Deer", "Common"),
	}, PetConfig)
	assert(near(stats.Speed, 0.06 + 0.04 + 0.01))
end

function tests.capsApply()
	-- 3 legendary Volcanic pets: 1.35 Luck, capped to 1.
	local luck = StatCalculator.Totals({
		pet("BlazingPhoenix", "Legendary"),
		pet("BlazingPhoenix", "Legendary"),
		pet("BlazingPhoenix", "Legendary"),
	}, PetConfig)
	assert(near(luck.Luck, PetConfig.Caps.Luck))
	-- 3 legendary Forest pets: 0.27 Speed, capped to 0.25.
	local speed = StatCalculator.Totals({
		pet("Lion", "Legendary"),
		pet("Lion", "Legendary"),
		pet("Lion", "Legendary"),
	}, PetConfig)
	assert(near(speed.Speed, PetConfig.Caps.Speed))
end

function tests.unknownKindsGiveNothing()
	local stats = StatCalculator.Totals({ pet("RemovedPet", "Legendary") }, PetConfig)
	assert(stats.Speed == 0 and stats.Coins == 0)
	local stat, value = StatCalculator.PetBonus(pet("RemovedPet", "Rare"), PetConfig)
	assert(stat == nil and value == 0)
end

function tests.powerCountsOnlyRoundStats()
	local power = StatCalculator.Power({ Speed = 0.1, PaintRadius = 0.2, Luck = 1, Coins = 1 })
	assert(near(power, 0.3))
end

return tests
