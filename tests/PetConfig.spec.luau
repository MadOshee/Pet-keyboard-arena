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
	for _, theme in EggConfig.OfferThemes do
		assert(EggConfig.ThemeWeights[theme] ~= nil, `{theme}: no theme weight`)
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
	for _, stat in PetConfig.StatOrder do
		assert(
			PetConfig.Bonus[stat] ~= nil and PetConfig.Caps[stat] ~= nil,
			`{stat}: no bonus or cap`
		)
	end
end

function tests.everyPetHasBuffsAndIncome()
	for kind, entry in PetConfig.Pets do
		local main = PetConfig.Themes[entry.Theme].Stat
		assert(entry.Buffs[main] == PetConfig.Bonus[main][entry.Rarity], `{kind}: wrong main buff`)
		for stat, value in entry.Buffs do
			assert(table.find(PetConfig.StatOrder, stat) ~= nil, `{kind}: unknown stat {stat}`)
			assert(value > 0, `{kind}: empty buff {stat}`)
		end
		assert(entry.Income > 0, `{kind}: no income`)
	end
end

function tests.rarerEggsAndPetsEarnMore()
	local function income(theme: string, rarity: string): number
		for _, entry in PetConfig.Pets do
			if entry.Theme == theme and entry.Rarity == rarity then
				return entry.Income
			end
		end
		error(`no {rarity} pet in {theme}`)
	end
	for themeIndex, theme in EggConfig.OfferThemes do
		for rank = 2, #PetConfig.Rarities do
			local rarity = PetConfig.Rarities[rank]
			assert(income(theme, rarity) > income(theme, PetConfig.Rarities[rank - 1]))
		end
		if themeIndex > 1 then
			local cheaper = EggConfig.OfferThemes[themeIndex - 1]
			assert(income(theme, "Common") > income(cheaper, "Common"))
		end
	end
	-- The rarest pet of the rarest egg earns thousands per second.
	assert(income("Volcanic", "Legendary") >= 1000)
end

function tests.rerollCostsGrow()
	for index = 2, #EggConfig.RerollCosts do
		assert(EggConfig.RerollCosts[index] > EggConfig.RerollCosts[index - 1])
	end
end

return tests
