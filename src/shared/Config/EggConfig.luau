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

-- Percent chance of each theme in an offer slot (Ivan): 13 eggs at 5% or
-- more, then 8 super rare eggs under 5% that glow orange. Ivan
-- (2026-10-14): common eggs more often, rare ones very rare, since X2 Luck
-- and Server Luck double the super rare chances (x4 together: still under
-- 2%).
local THEME_PERCENTS = {
	15.5,
	11.5,
	9.5,
	8.5,
	7.5,
	7,
	6.5,
	6,
	5.7,
	5.5,
	5.3,
	5.2,
	5,
	0.5,
	0.3,
	0.2,
	0.12,
	0.08,
	0.05,
	0.03,
	0.02,
}
local SUPER_RARE_PERCENT = 5
-- Hatch time of each theme, rarer eggs longer (Ivan: Basic 30 s, Forest
-- 1 min and so on).
local THEME_HATCH_SECONDS = {
	30,
	60,
	90,
	120,
	180,
	240,
	300,
	420,
	600,
	780,
	900,
	1200,
	1500,
	1800,
	2100,
	2700,
	3600,
	4500,
	5400,
	6300,
	7200,
}
local THEME_WEIGHTS: { [string]: number } = {}
local HATCH_SECONDS: { [string]: number } = {}
local SUPER_RARE: { [string]: boolean } = {}
for index, theme in OFFER_THEMES do
	THEME_WEIGHTS[theme] = THEME_PERCENTS[index]
	HATCH_SECONDS[theme] = THEME_HATCH_SECONDS[index]
	SUPER_RARE[theme] = THEME_PERCENTS[index] < SUPER_RARE_PERCENT
end

return table.freeze({
	-- Egg themes, cheapest first: PetConfig.ThemeOrder (a test checks they
	-- match). Offers are sorted in this order.
	OfferThemes = OFFER_THEMES,
	EggsPerOffer = 4,
	-- A lost round offers only 2 eggs (Ivan).
	EggsByOutcome = table.freeze({ Win = 4, Draw = 4, Lose = 2 }) :: { [string]: number },
	-- How often each theme comes up in an offer slot, in percent: rarer eggs
	-- hatch pets that earn more (PetConfig.Themes IncomeMultiplier).
	ThemeWeights = table.freeze(THEME_WEIGHTS),
	-- Themes under 5%: an orange glow on the offer screen and in Pets.
	SuperRare = table.freeze(SUPER_RARE),

	-- Base weights in PetConfig.Rarities order (Common .. Legendary).
	BaseWeights = table.freeze({ 50, 28, 15, 6, 1 }),
	-- A rarity of rank r (Common = 0) has its weight multiplied by
	-- (1 + bonus) ^ r, where bonus adds up the values below and pet Luck.
	OutcomeBonus = table.freeze({ Win = 0.35, Draw = 0.15, Lose = 0 }),
	ContributionBonus = 0.3, -- times the share of the team's best painter (0..1)

	-- Money rerolls of one offer (Ivan): the 1st costs 5% of the balance, the
	-- 2nd 10%, the 3rd 15%, at least RerollMinCost; then only bought (Robux)
	-- rerolls, which have no limit.
	RerollShares = table.freeze({ 0.05, 0.1, 0.15 }),
	RerollMinCost = 10,

	-- Incubation time by egg theme, counted in real time, offline too.
	HatchSeconds = table.freeze(HATCH_SECONDS),
	SpeedUpCoinsPerSecond = 2,
	StartEggCapacity = 20,
	-- "Incubators" are the platforms of the base building: 10 on the ground
	-- floor, then 10 on the second floor. Each holds an egg or a pet.
	StartIncubators = 3,
	MaxIncubators = 20,
	-- Coins for the 4th to the 20th platform. Ivan (2026-10-14): very
	-- expensive, millions first, then billions.
	IncubatorPrices = table.freeze({
		1_000_000,
		2_000_000,
		4_000_000,
		7_500_000,
		12_000_000,
		20_000_000,
		35_000_000,
		60_000_000,
		100_000_000,
		175_000_000,
		300_000_000,
		500_000_000,
		850_000_000,
		1_500_000_000,
		2_500_000_000,
		5_000_000_000,
		10_000_000_000,
	}),
	-- +PetSlotsStep pet slots; the price doubles with every purchase.
	PetSlotsStep = 25,
	PetSlotsBasePrice = 2000,

	-- Model name under ReplicatedStorage.Assets.Eggs for a theme.
	ModelName = function(theme: string): string
		return theme .. " Egg"
	end,
})
