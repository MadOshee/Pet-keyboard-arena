local EggConfig = require("../src/shared/Config/EggConfig")
local PetConfig = require("../src/shared/Config/PetConfig")

local tests = {}

function tests.everyPetHasKnownThemeAndRarity()
	for kind, entry in PetConfig.Pets do
		assert(PetConfig.Themes[entry.Theme] ~= nil, `{kind}: unknown theme`)
		assert(table.find(PetConfig.Rarities, entry.Rarity) ~= nil, `{kind}: unknown rarity`)
		assert(#entry.Model > 0, `{kind}: no model name`)
	end
end

function tests.everyOfferThemeHasEveryRarity()
	assert(#EggConfig.OfferThemes == EggConfig.EggsPerOffer)
	for _, theme in EggConfig.OfferThemes do
		assert(PetConfig.Themes[theme] ~= nil, `{theme}: not in PetConfig.Themes`)
		for _, rarity in PetConfig.Rarities do
			local found = false
			for _, entry in PetConfig.Pets do
				if entry.Theme == theme and entry.Rarity == rarity then
					found = true
				end
			end
			assert(found, `no {rarity} pet in {theme}`)
		end
	end
end

function tests.tablesCoverEveryRarity()
	for _, rarity in PetConfig.Rarities do
		assert(PetConfig.SellValue[rarity] ~= nil, `no sell value for {rarity}`)
		for stat, byRarity in PetConfig.Bonus do
			assert(byRarity[rarity] ~= nil, `no {stat} bonus for {rarity}`)
		end
	end
	assert(#EggConfig.BaseWeights == #PetConfig.Rarities)
end

function tests.everyThemeStatHasBonusAndCap()
	for name, theme in PetConfig.Themes do
		assert(PetConfig.Bonus[theme.Stat] ~= nil, `{name}: no bonus table`)
		assert(PetConfig.Caps[theme.Stat] ~= nil, `{name}: no cap`)
	end
end

function tests.rerollCostsGrow()
	for index = 2, #EggConfig.RerollCosts do
		assert(EggConfig.RerollCosts[index] > EggConfig.RerollCosts[index - 1])
	end
end

return tests
