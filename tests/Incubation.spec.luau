local EggConfig = require("../src/shared/Config/EggConfig")
local Incubation = require("../src/shared/Logic/Incubation")
local PetConfig = require("../src/shared/Config/PetConfig")

local tests = {}

function tests.hatchTimesGrowWithRarity()
	local previous = 0
	for _, rarity in PetConfig.Rarities do
		local seconds = Incubation.HatchSeconds(rarity, EggConfig)
		assert(seconds > previous, `{rarity} should take longer`)
		previous = seconds
	end
	assert(Incubation.HatchSeconds("Unknown", EggConfig) == 30)
end

function tests.speedUpCostsPerRemainingSecond()
	assert(Incubation.SpeedUpCost(100, 90, EggConfig) == 20)
	assert(Incubation.SpeedUpCost(100, 99.5, EggConfig) == 2)
	assert(Incubation.SpeedUpCost(100, 120, EggConfig) == 0)
end

function tests.incubatorPrices()
	assert(Incubation.NextIncubatorPrice(3, EggConfig) == 1500)
	assert(Incubation.NextIncubatorPrice(4, EggConfig) == 5000)
	assert(Incubation.NextIncubatorPrice(5, EggConfig) == 15000)
	assert(Incubation.NextIncubatorPrice(6, EggConfig) == nil)
end

function tests.petSlotPriceDoubles()
	local start = PetConfig.StartCapacity
	assert(Incubation.NextPetSlotsPrice(start, start, EggConfig) == 2000)
	assert(Incubation.NextPetSlotsPrice(start + 25, start, EggConfig) == 4000)
	assert(Incubation.NextPetSlotsPrice(start + 50, start, EggConfig) == 8000)
end

function tests.rarestEggWins()
	local eggs = {
		a = { Rarity = "Common" },
		b = { Rarity = "Epic" },
		c = { Rarity = "Rare" },
	}
	assert(Incubation.RarestEgg(eggs, PetConfig.Rarities) == "b")
	assert(Incubation.RarestEgg({}, PetConfig.Rarities) == nil)
end

function tests.rarestEggTieIsStable()
	local eggs = { z = { Rarity = "Rare" }, a = { Rarity = "Rare" } }
	assert(Incubation.RarestEgg(eggs, PetConfig.Rarities) == "a")
end

return tests
