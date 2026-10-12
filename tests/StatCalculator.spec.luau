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
	for _, stat in PetConfig.StatOrder do
		assert((stats :: any)[stat] == 0, `{stat} should be 0`)
	end
end

function tests.eachThemeBoostsItsStat()
	local stats = StatCalculator.Totals({
		pet("Doggy", "Common"), -- Basic: Coins
		pet("Deer", "Common"), -- Forest: Speed
		pet("Penguin", "Common"), -- Arctic: PaintRadius
	}, PetConfig)
	assert(near(stats.Coins, 0.05))
	assert(near(stats.Speed, 0.02))
	assert(near(stats.PaintRadius, 0.03))
	assert(stats.Luck == 0 and stats.Power == 0)
end

function tests.rarePetsAddExtraStatsAtAboutHalf()
	local buffs = StatCalculator.PetBuffs(pet("Tiger", "Epic"), PetConfig)
	assert(near(buffs.Speed, 0.08))
	assert(near(buffs.Power, 0.08)) -- half of 15%, rounded up
	assert(near(buffs.Coins, 0.1))
	local count = 0
	for _ in StatCalculator.PetBuffs(pet("Lion", "Legendary"), PetConfig) do
		count += 1
	end
	assert(count == #PetConfig.StatOrder, "a legendary boosts every stat")
end

function tests.bonusesStack()
	local stats = StatCalculator.Totals({
		pet("Tiger", "Epic"),
		pet("Lynx", "Rare"),
		pet("Deer", "Common"),
	}, PetConfig)
	assert(near(stats.Speed, 0.08 + 0.05 + 0.02))
	assert(near(stats.Luck, 0.06))
end

function tests.capsApply()
	-- 3 legendary Forest pets: 0.36 Speed, capped.
	local speed = StatCalculator.Totals({
		pet("Lion", "Legendary"),
		pet("Lion", "Legendary"),
		pet("Lion", "Legendary"),
	}, PetConfig)
	assert(near(speed.Speed, PetConfig.Caps.Speed))
	-- 3 legendary Arctic pets: 0.54 PaintRadius, capped.
	local area = StatCalculator.Totals({
		pet("FrostDefender", "Legendary"),
		pet("FrostDefender", "Legendary"),
		pet("FrostDefender", "Legendary"),
	}, PetConfig)
	assert(near(area.PaintRadius, PetConfig.Caps.PaintRadius))
end

function tests.unknownKindsGiveNothing()
	local stats = StatCalculator.Totals({ pet("RemovedPet", "Legendary") }, PetConfig)
	assert(stats.Speed == 0 and stats.Coins == 0)
	assert(next(StatCalculator.PetBuffs(pet("RemovedPet", "Rare"), PetConfig)) == nil)
end

function tests.teamWeightCountsOnlyRoundStats()
	local weight = StatCalculator.TeamWeight({
		Speed = 0.1,
		PaintRadius = 0.2,
		Luck = 1,
		Power = 0.3,
		Coins = 1,
	})
	assert(near(weight, 0.6))
end

return tests
