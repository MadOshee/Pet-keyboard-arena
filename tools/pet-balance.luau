--!strict
-- Prints the pet tables of docs/pet-balance.md from the configs, so the
-- document always matches the game: `lune run tools/pet-balance`.

local EggConfig = require("../src/shared/Config/EggConfig")
local PetConfig = require("../src/shared/Config/PetConfig")
local EggRoller = require("../src/shared/Logic/EggRoller")
local Money = require("../src/shared/Util/Money")

local STAT_NAMES = {
	Speed = "Speed",
	PaintRadius = "Area",
	Luck = "Luck",
	Power = "Power",
	Coins = "Money",
}

-- Enough decimals to show tiny chances: 0.0012%.
local function percent(value: number): string
	local scaled = value * 100
	local decimals = 2
	if scaled > 0 and scaled < 0.01 then
		decimals = math.ceil(-math.log10(scaled)) + 1
	end
	local text = string.format(`%.{decimals}f`, scaled):gsub("0+$", ""):gsub("%.$", "")
	return text .. "%"
end

local themeWeights = EggConfig.ThemeWeights :: { [string]: number }
local themeTotal = 0
for _, weight in themeWeights do
	themeTotal += weight
end
local loseOdds = EggRoller.Odds(
	EggRoller.Weights({ Outcome = "Lose", ContributionPct = 0, Luck = 0 }, EggConfig)
)
local winOdds =
	EggRoller.Odds(EggRoller.Weights({ Outcome = "Win", ContributionPct = 1, Luck = 0 }, EggConfig))

-- Chance that one egg of the theme hatches this kind, after a lost round.
local function hatchChance(theme: string, kind: string): number
	local chance = 0
	for rank, rarity in PetConfig.Rarities do
		local kinds = EggRoller.HatchKinds(PetConfig.Pets, theme, rarity, PetConfig.Rarities)
		if table.find(kinds, kind) then
			chance += loseOdds[rank] / #kinds
		end
	end
	return chance * themeWeights[theme] / themeTotal
end

print(
	"| Яйцо | Шанс в слоте | Главный бафф | Множитель дохода |"
)
print("|---|---|---|---|")
for _, theme in EggConfig.OfferThemes do
	local info = PetConfig.Themes[theme]
	print(
		`| {theme} | {percent(themeWeights[theme] / themeTotal)} | {STAT_NAMES[info.Stat]} | ×{info.IncomeMultiplier} |`
	)
end
print()
print("| Редкость | Поражение | Победа и лучший вклад |")
print("|---|---|---|")
for index, rarity in PetConfig.Rarities do
	print(`| {rarity} | {percent(loseOdds[index])} | {percent(winOdds[index])} |`)
end
print()
print(
	"| Яйцо | Питомец | Редкость | Доход на платформе | Баффы при экипировке | Шанс за одно яйцо (поражение) |"
)
print("|---|---|---|---|---|---|")
for _, theme in EggConfig.OfferThemes do
	local kinds = {}
	for kind, entry in PetConfig.Pets do
		if entry.Theme == theme then
			table.insert(kinds, kind)
		end
	end
	table.sort(kinds, function(a, b)
		return PetConfig.Pets[a].Order < PetConfig.Pets[b].Order
	end)
	for _, kind in kinds do
		local entry = PetConfig.Pets[kind]
		local buffs = {}
		for _, stat in PetConfig.StatOrder do
			local value = entry.Buffs[stat]
			if value then
				table.insert(buffs, `+{percent(value)} {STAT_NAMES[stat]}`)
			end
		end
		local chance = hatchChance(theme, kind)
		print(
			`| {theme} | {entry.Name} | {entry.Rarity} | {Money.Format(entry.Income)}/s | {table.concat(
				buffs,
				", "
			)} | {percent(chance)} |`
		)
	end
end
print()
print(
	"| Бафф | Common | Uncommon | Rare | Epic | Legendary | Потолок (3 питомца) |"
)
print("|---|---|---|---|---|---|---|")
for _, stat in PetConfig.StatOrder do
	local row = {}
	for _, rarity in PetConfig.Rarities do
		table.insert(row, "+" .. percent(PetConfig.Bonus[stat][rarity]))
	end
	print(`| {STAT_NAMES[stat]} | {table.concat(row, " | ")} | +{percent(PetConfig.Caps[stat])} |`)
end
