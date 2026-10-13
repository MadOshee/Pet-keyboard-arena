--!strict
-- Egg rules (docs/design.md 4.3 "Яйца", 4.5; numbers in docs/pet-balance.md).
-- After a rewarded round a player gets 4 eggs, each with a rolled theme and a
-- rolled rarity; the picked egg hatches on a platform of the player's plot.
-- No requires or Roblox types: Lune tests load this file directly.

local OFFER_THEMES = table.freeze({
	"Basic",
	"Forest",
	"Surfing",
	"Arctic",
	"Ice",
	"Volcanic",
	"Infernal",
	"Dragon",
	"Holographic",
	"Space",
	"Cyborg",
	"Nebula",
	"Underworld",
	"Dark",
	"Glitched",
	"Glitch",
	"Patriotic",
	"Season 1",
	"SpinToWin",
	"Royal",
	"Sparkletime",
})

-- Each egg comes up THEME_STEP times as often as the one after it.
local THEME_STEP = 0.75
local THEME_WEIGHTS: { [string]: number } = {}
for index, theme in OFFER_THEMES do
	THEME_WEIGHTS[theme] = math.floor(100 * THEME_STEP ^ (index - 1) * 100 + 0.5) / 100
end

return table.freeze({
	-- Egg themes, cheapest first: PetConfig.ThemeOrder (a test checks they
	-- match). Offers are sorted in this order.
	OfferThemes = OFFER_THEMES,
	EggsPerOffer = 4,
	-- How often each theme comes up in an offer slot: rarer eggs hatch pets
	-- that earn more (PetConfig.Themes IncomeMultiplier).
	ThemeWeights = table.freeze(THEME_WEIGHTS),

	-- Base weights in PetConfig.Rarities order (Common .. Legendary).
	BaseWeights = table.freeze({ 50, 28, 15, 6, 1 }),
	-- A rarity of rank r (Common = 0) has its weight multiplied by
	-- (1 + bonus) ^ r, where bonus adds up the values below and pet Luck.
	OutcomeBonus = table.freeze({ Win = 0.35, Draw = 0.15, Lose = 0 }),
	ContributionBonus = 0.3, -- times the share of the team's best painter (0..1)

	-- Coins for the 1st..5th reroll of one offer; no more rerolls after that.
	RerollCosts = table.freeze({ 50, 100, 200, 400, 800 }),

	-- Incubation time by rarity (D3), counted in real time, offline too.
	HatchSeconds = table.freeze({
		Common = 30,
		Uncommon = 120,
		Rare = 300,
		Epic = 900,
		Legendary = 1800,
	}) :: { [string]: number },
	SpeedUpCoinsPerSecond = 2,
	StartEggCapacity = 20,
	-- "Incubators" are the platforms of the base building: 10 on the ground
	-- floor, then 10 on the second floor. Each holds an egg or a pet.
	StartIncubators = 3,
	MaxIncubators = 20,
	-- Coins for the 4th to the 20th platform.
	IncubatorPrices = table.freeze({
		1500,
		5000,
		15000,
		30000,
		50000,
		80000,
		120000,
		160000,
		200000,
		250000,
		300000,
		400000,
		500000,
		650000,
		800000,
		1000000,
		1200000,
	}),
	-- +PetSlotsStep pet slots; the price doubles with every purchase.
	PetSlotsStep = 25,
	PetSlotsBasePrice = 2000,

	-- Model name under ReplicatedStorage.Assets.Eggs for a theme.
	ModelName = function(theme: string): string
		return theme .. " Egg"
	end,
})
