--!strict
-- Pet kinds, themes, buffs and plot income (docs/design.md 4.3 "Питомцы",
-- 4.4; numbers in docs/pet-balance.md). Each theme has a main stat, so picking
-- an egg theme is a real choice (D2); rarer pets add more stats.
-- Model is the model name under ReplicatedStorage.Assets.Pets; the game
-- still works without it (pets then show as colored balls).
-- No requires or Roblox types: Lune tests load this file directly.
-- Colors live in Config/PetStyle.

export type Stat = "Speed" | "PaintRadius" | "Luck" | "Power" | "Coins"

export type Theme = {
	Name: string,
	-- The stat every pet of this theme boosts most.
	Stat: Stat,
	-- Coins per second of this theme's pets, times RarityIncome.
	IncomeMultiplier: number,
}

export type PetKind = {
	Name: string,
	Theme: string,
	Rarity: string,
	Model: string,
	-- Stat -> fraction (0.05 = +5%) this pet adds when equipped.
	Buffs: { [string]: number },
	-- Coins per second while the pet stands on a plot platform.
	Income: number,
}

-- Lowest to highest. EggRoller and the UI use this order.
local RARITIES = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }

-- Eggs from cheapest to rarest (EggConfig.ThemeWeights): a rarer egg gives
-- pets that earn more on the plot.
local THEMES: { [string]: Theme } = {
	Basic = { Name = "Basic", Stat = "Coins", IncomeMultiplier = 1 },
	Forest = { Name = "Forest", Stat = "Speed", IncomeMultiplier = 3 },
	Arctic = { Name = "Arctic", Stat = "PaintRadius", IncomeMultiplier = 10 },
	Volcanic = { Name = "Volcanic", Stat = "Luck", IncomeMultiplier = 25 },
}

-- Main buff of a pet as a fraction, by stat and rarity. A pet gets its
-- theme's stat at this value and each extra stat at about half of it.
local BONUS: { [string]: { [string]: number } } = {
	Speed = { Common = 0.02, Uncommon = 0.03, Rare = 0.05, Epic = 0.08, Legendary = 0.12 },
	PaintRadius = { Common = 0.03, Uncommon = 0.05, Rare = 0.08, Epic = 0.12, Legendary = 0.18 },
	Luck = { Common = 0.05, Uncommon = 0.08, Rare = 0.12, Epic = 0.2, Legendary = 0.3 },
	Power = { Common = 0.04, Uncommon = 0.06, Rare = 0.1, Epic = 0.15, Legendary = 0.25 },
	Coins = { Common = 0.05, Uncommon = 0.08, Rare = 0.12, Epic = 0.2, Legendary = 0.3 },
}
local EXTRA_SHARE = 0.5

-- Coins per second on a platform by rarity, times the theme's multiplier.
local RARITY_INCOME: { [string]: number } = {
	Common = 1,
	Uncommon = 3,
	Rare = 10,
	Epic = 40,
	Legendary = 200,
}

local function pet(
	name: string,
	theme: string,
	rarity: string,
	extras: { Stat },
	model: string?
): PetKind
	local main = THEMES[theme].Stat
	local buffs: { [string]: number } = { [main] = BONUS[main][rarity] }
	for _, stat in extras do
		-- Whole percents, rounded up: half of +25% is +13%.
		local full = math.floor(BONUS[stat][rarity] * 100 + 0.5)
		buffs[stat] = math.ceil(full * EXTRA_SHARE) / 100
	end
	return {
		Name = name,
		Theme = theme,
		Rarity = rarity,
		Model = model or name,
		Buffs = table.freeze(buffs),
		Income = RARITY_INCOME[rarity] * THEMES[theme].IncomeMultiplier,
	}
end

-- Keys are stable ids saved in profiles: never rename or remove one.
-- Common and Uncommon pets boost one stat; Rare adds one more, Epic two,
-- Legendary all five.
local PETS: { [string]: PetKind } = {
	Doggy = pet("Doggy", "Basic", "Common", {}),
	Kitty = pet("Kitty", "Basic", "Common", {}),
	Bunny = pet("Bunny", "Basic", "Uncommon", {}),
	Fox = pet("Fox", "Basic", "Rare", { "Speed" }),
	Bear = pet("Bear", "Basic", "Epic", { "Power", "PaintRadius" }),
	Cow = pet("Cow", "Basic", "Legendary", { "Speed", "PaintRadius", "Luck", "Power" }),

	Deer = pet("Deer", "Forest", "Common", {}),
	Squirrel = pet("Squirrel", "Forest", "Common", {}),
	Owl = pet("Owl", "Forest", "Uncommon", {}),
	Lynx = pet("Lynx", "Forest", "Rare", { "Luck" }),
	Tiger = pet("Tiger", "Forest", "Epic", { "Power", "Coins" }),
	Lion = pet("Lion", "Forest", "Legendary", { "PaintRadius", "Luck", "Power", "Coins" }),

	Penguin = pet("Penguin", "Arctic", "Common", {}),
	SnowSquirrel = pet("Snow Squirrel", "Arctic", "Common", {}),
	ArcticFox = pet("Arctic Fox", "Arctic", "Uncommon", {}),
	PolarBear = pet("Polar Bear", "Arctic", "Rare", { "Power" }),
	SnowTiger = pet("Snow Tiger", "Arctic", "Epic", { "Speed", "Power" }),
	FrostDefender = pet(
		"Frost Defender",
		"Arctic",
		"Legendary",
		{ "Speed", "Luck", "Power", "Coins" }
	),

	VolcanicDoggy = pet("Volcanic Doggy", "Volcanic", "Common", {}),
	VolcanicKitty = pet("Volcanic Kitty", "Volcanic", "Common", {}),
	MoltenPiggy = pet("Molten Piggy", "Volcanic", "Uncommon", {}),
	FirePanda = pet("Fire Panda", "Volcanic", "Rare", { "Coins" }),
	InfernoDragon = pet("Inferno Dragon", "Volcanic", "Epic", { "Power", "PaintRadius" }),
	BlazingPhoenix = pet(
		"Blazing Phoenix",
		"Volcanic",
		"Legendary",
		{ "Speed", "PaintRadius", "Power", "Coins" }
	),
}

-- Caps on the sum of all equipped pets (D5).
local CAPS: { [string]: number } = {
	Speed = 0.25,
	PaintRadius = 0.5,
	Luck = 1,
	Power = 0.6,
	Coins = 1,
}

return table.freeze({
	Rarities = table.freeze(RARITIES),
	Themes = table.freeze(THEMES),
	Pets = table.freeze(PETS),
	Bonus = table.freeze(BONUS),
	Caps = table.freeze(CAPS),
	MaxEquipped = 3,
	StartCapacity = 50,
	-- Order of stats in the UI.
	StatOrder = table.freeze({ "Speed", "PaintRadius", "Luck", "Power", "Coins" }),
	RarityIncome = table.freeze(RARITY_INCOME),
	-- Offline earnings count at most this long.
	OfflineIncomeMaxSeconds = 24 * 60 * 60,
	-- Coins for selling a pet, or for a hatch when the inventory is full.
	SellValue = table.freeze({ Common = 5, Uncommon = 10, Rare = 25, Epic = 60, Legendary = 150 }),
})
