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

function tests.everyPackEggIsOffered()
	assert(#EggConfig.OfferThemes == #PetConfig.ThemeOrder)
	for index, theme in PetConfig.ThemeOrder do
		assert(EggConfig.OfferThemes[index] == theme, `{theme}: OfferThemes order differs`)
		assert(EggConfig.ThemeWeights[theme] ~= nil, `{theme}: no theme weight`)
	end
end

-- Ivan: 8 pets in every egg, 2 Common, 2 Uncommon, 2 Rare, 1 Epic, 1 Legendary.
function tests.everyEggHoldsEightPetsByRarity()
	local expected = { Common = 2, Uncommon = 2, Rare = 2, Epic = 1, Legendary = 1 }
	for _, theme in EggConfig.OfferThemes do
		local count = { Common = 0, Uncommon = 0, Rare = 0, Epic = 0, Legendary = 0 }
		for _, entry in PetConfig.Pets do
			if entry.Theme == theme then
				count[entry.Rarity] += 1
			end
		end
		for rarity, wanted in expected do
			assert(count[rarity] == wanted, `{theme}: {count[rarity]} {rarity}, expected {wanted}`)
		end
	end
end

-- Ivan: at most 3 buffs; an egg's best pet has 3, the one before it 2, the
-- others 1.
function tests.buffCountsFollowPlaceInEgg()
	local sizes = {}
	for _, entry in PetConfig.Pets do
		sizes[entry.Theme] = (sizes[entry.Theme] or 0) + 1
	end
	for kind, entry in PetConfig.Pets do
		local count = 0
		for _ in entry.Buffs do
			count += 1
		end
		local fromBest = sizes[entry.Theme] - entry.Order + 1
		local expected = if fromBest == 1 then 3 elseif fromBest == 2 then 2 else 1
		assert(count == expected, `{kind}: {count} buffs, expected {expected}`)
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
		local tier = table.find(PetConfig.ThemeOrder, entry.Theme) :: number
		local expected = PetConfig.Bonus[main][entry.Rarity]
			* (1 + PetConfig.BonusPerEgg * (tier - 1))
		assert(
			math.abs(entry.Buffs[main] - math.floor(expected * 100 + 0.5) / 100) < 1e-9,
			`{kind}: wrong main buff`
		)
		for stat, value in entry.Buffs do
			assert(table.find(PetConfig.StatOrder, stat) ~= nil, `{kind}: unknown stat {stat}`)
			assert(value > 0, `{kind}: empty buff {stat}`)
		end
		assert(entry.Income > 0, `{kind}: no income`)
	end
end

function tests.rarerEggsAndPetsEarnMore()
	local function best(theme: string, rarity: string?): number
		local income = 0
		for _, entry in PetConfig.Pets do
			if entry.Theme == theme and (rarity == nil or entry.Rarity == rarity) then
				income = math.max(income, entry.Income)
			end
		end
		return income
	end
	for themeIndex, theme in EggConfig.OfferThemes do
		assert(best(theme, "Legendary") > best(theme, "Epic"), `{theme}: Legendary earns most`)
		if themeIndex > 1 then
			local cheaper = EggConfig.OfferThemes[themeIndex - 1]
			assert(best(theme, "Legendary") > best(cheaper, "Legendary"), `{theme}: earns more`)
		end
	end
	-- Ivan, 2026-10-13: five times the first table. The weakest pet earns
	-- $5/s, the best pet of the rarest egg tens of thousands.
	assert(best("Basic", "Common") == 5)
	assert(best("Sparkletime") >= 25000)
end

function tests.rerollSharesGrow()
	assert(#EggConfig.RerollShares == 3)
	for index = 2, #EggConfig.RerollShares do
		assert(EggConfig.RerollShares[index] > EggConfig.RerollShares[index - 1])
	end
end

return tests
