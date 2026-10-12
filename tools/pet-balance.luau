--!strict
-- Prints the pet tables of docs/pet-balance.md from the configs, so the
-- document always matches the game: `lune run tools/pet-balance`.

local EggConfig = require("../src/shared/Config/EggConfig")
local PetConfig = require("../src/shared/Config/PetConfig")
local EggRoller = require("../src/shared/Logic/EggRoller")

local STAT_NAMES = {
	Speed = "Speed",
	PaintRadius = "Area",
	Luck = "Luck",
	Power = "Power",
	Coins = "Coins",
}

local function percent(value: number): string
	local text = string.format("%.2f", value * 100):gsub("0+$", ""):gsub("%.$", "")
	return text .. "%"
end

local function number(value: number): string
	local text = tostring(math.floor(value))
	local formatted = text:reverse():gsub("(%d%d%d)", "%1 "):reverse()
	return (formatted:gsub("^ ", ""))
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

-- Pets per theme and rarity, to split an egg's chance between them.
local function sameKind(theme: string, rarity: string): number
	local count = 0
	for _, entry in PetConfig.Pets do
		if entry.Theme == theme and entry.Rarity == rarity then
			count += 1
		end
	end
	return count
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
	"| Яйцо | Питомец | Редкость | Доход на платформе, монет/с | Баффы при экипировке | Шанс за одно яйцо (поражение) |"
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
		local rankA = table.find(PetConfig.Rarities, PetConfig.Pets[a].Rarity) or 0
		local rankB = table.find(PetConfig.Rarities, PetConfig.Pets[b].Rarity) or 0
		if rankA ~= rankB then
			return rankA < rankB
		end
		return a < b
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
		local rank = table.find(PetConfig.Rarities, entry.Rarity) or 1
		local chance = themeWeights[theme]
			/ themeTotal
			* loseOdds[rank]
			/ sameKind(theme, entry.Rarity)
		print(
			`| {theme} | {entry.Name} | {entry.Rarity} | {number(entry.Income)} | {table.concat(
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
