local EggConfig = require("../src/shared/Config/EggConfig")
local Incubation = require("../src/shared/Logic/Incubation")
local PetConfig = require("../src/shared/Config/PetConfig")

local tests = {}

function tests.hatchTimesGrowWithTheme()
	local previous = 0
	for _, theme in EggConfig.OfferThemes do
		local seconds = Incubation.HatchSeconds(theme, EggConfig)
		assert(seconds > previous, `{theme} should take longer`)
		previous = seconds
	end
	assert(Incubation.HatchSeconds("Basic", EggConfig) == 30)
	assert(Incubation.HatchSeconds("Forest", EggConfig) == 60)
	assert(Incubation.HatchSeconds("Unknown", EggConfig) == 30)
end

function tests.rerollCostIsAShareOfTheBalance()
	assert(Incubation.RerollCost(10000, 0, EggConfig) == 500)
	assert(Incubation.RerollCost(10000, 1, EggConfig) == 1000)
	assert(Incubation.RerollCost(10000, 2, EggConfig) == 1500)
	assert(Incubation.RerollCost(10000, 3, EggConfig) == nil)
	assert(Incubation.RerollCost(12345, 0, EggConfig) == 617)
	-- Never under the minimum, so a reroll is never free.
	assert(Incubation.RerollCost(0, 0, EggConfig) == EggConfig.RerollMinCost)
	assert(Incubation.RerollCost(100, 0, EggConfig) == EggConfig.RerollMinCost)
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
	assert(Incubation.NextIncubatorPrice(9, EggConfig) == 120000)
	assert(Incubation.NextIncubatorPrice(19, EggConfig) == 1200000)
	assert(Incubation.NextIncubatorPrice(20, EggConfig) == nil)
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
