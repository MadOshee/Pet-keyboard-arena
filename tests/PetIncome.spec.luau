local PetConfig = require("../src/shared/Config/PetConfig")
local PetIncome = require("../src/shared/Logic/PetIncome")

local tests = {}

local config = {
	IncomePerSecond = { Common = 1, Rare = 5 },
	OfflineIncomeMaxSeconds = 100,
}

function tests.ratesGrowWithRarity()
	local previous = 0
	for _, rarity in PetConfig.Rarities do
		local rate = PetIncome.Rate(rarity, PetConfig)
		assert(rate > previous, `{rarity} should earn more`)
		previous = rate
	end
	assert(PetIncome.Rate("Unknown", PetConfig) == 0)
end

function tests.everyPetEarnsForThePeriod()
	local earners = { { Rarity = "Common" }, { Rarity = "Rare" } }
	assert(PetIncome.Earned(earners, 10, 20, config) == 60)
	assert(PetIncome.Earned(earners, 20, 20, config) == 0)
	assert(PetIncome.Earned({}, 0, 50, config) == 0)
end

function tests.longAbsenceIsCapped()
	local earners = { { Rarity = "Common" } }
	assert(PetIncome.Earned(earners, 0, 1000, config) == 100)
end

function tests.hatchedPetEarnsFromItsHatch()
	-- Hatched at 15 inside the period 10..20.
	assert(PetIncome.Earned({ { Rarity = "Rare", From = 15 } }, 10, 20, config) == 25)
	-- Hatched before the period: the whole period.
	assert(PetIncome.Earned({ { Rarity = "Rare", From = 5 } }, 10, 20, config) == 50)
	-- Hatched before the offline cap starts: only the capped period.
	assert(PetIncome.Earned({ { Rarity = "Common", From = 1 } }, 0, 1000, config) == 100)
	-- Not hatched yet.
	assert(PetIncome.Earned({ { Rarity = "Rare", From = 30 } }, 10, 20, config) == 0)
end

function tests.placedPetsMapToTheirPlatform()
	local placed = PetIncome.PlacedPets({ {}, { PetId = "a" }, {}, { PetId = "b" } })
	assert(placed.a == 2 and placed.b == 4)
	assert(next(PetIncome.PlacedPets({ {}, {} })) == nil)
end

return tests
