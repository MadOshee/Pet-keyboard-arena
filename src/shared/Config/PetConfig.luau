--!strict
-- Pet kinds, themes, buffs and plot income (docs/design.md 4.3 "Питомцы",
-- 4.4; numbers in docs/pet-balance.md). The eggs and pets of the Pets & Eggs
-- pack. Each egg theme has a main stat, so picking an egg is a real choice
-- (D2); an egg's best pet adds three stats, the next one two (Ivan).
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
	-- Place in its egg, weakest first.
	Order: number,
	Model: string,
	-- Stat -> fraction (0.05 = +5%) this pet adds when equipped.
	Buffs: { [string]: number },
	-- Coins per second while the pet stands on a plot platform.
	Income: number,
}

-- Lowest to highest. EggRoller and the UI use this order.
local RARITIES = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }

-- Main buff of a pet as a fraction, by stat and rarity, for the first egg.
-- Each later egg adds BONUS_PER_EGG of it. The second and third buffs are
-- about half of the main one.
local BONUS: { [string]: { [string]: number } } = {
	Speed = { Common = 0.02, Uncommon = 0.03, Rare = 0.05, Epic = 0.08, Legendary = 0.12 },
	PaintRadius = { Common = 0.03, Uncommon = 0.05, Rare = 0.08, Epic = 0.12, Legendary = 0.18 },
	Luck = { Common = 0.05, Uncommon = 0.08, Rare = 0.12, Epic = 0.2, Legendary = 0.3 },
	Power = { Common = 0.04, Uncommon = 0.06, Rare = 0.1, Epic = 0.15, Legendary = 0.25 },
	Coins = { Common = 0.05, Uncommon = 0.08, Rare = 0.12, Epic = 0.2, Legendary = 0.3 },
}
local BONUS_PER_EGG = 0.05
local EXTRA_SHARE = 0.5

-- Coins per second on a platform by rarity, times the egg's multiplier.
local RARITY_INCOME: { [string]: number } = {
	Common = 1,
	Uncommon = 3,
	Rare = 10,
	Epic = 40,
	Legendary = 200,
}

type EggSpec = {
	Name: string,
	Stat: Stat,
	IncomeMultiplier: number,
	-- The best pet adds both, the second best the first one (Ivan: at most
	-- three buffs; the best pet of an egg 3, the one before it 2, others 1).
	Extras: { Stat },
	-- Model names under Assets.Pets, weakest first.
	Pets: { string },
}

-- The eggs of the Pets & Eggs pack, cheapest first (EggConfig.OfferThemes
-- and ThemeWeights follow this order). Name is the egg model's name without
-- " Egg". Ivan: every egg holds 8 pets, 2 Common, 2 Uncommon, 2 Rare, 1 Epic
-- and 1 Legendary. The pack's eggs hold 4 to 11 pets, so extra pets moved
-- to a close egg (Dark Dragon to Dark, the cubes to Glitch), the Slime egg
-- went into Royal, and Rat, Bull and Inferno Cube are left out.
local EGGS: { EggSpec } = {
	{
		Name = "Basic",
		Stat = "Coins",
		IncomeMultiplier = 1,
		Extras = { "Speed", "Luck" },
		Pets = { "Doggy", "Kitty", "Bunny", "Piggy", "Ducky", "Bear", "Fox", "Cow" },
	},
	{
		Name = "Forest",
		Stat = "Speed",
		IncomeMultiplier = 1.2,
		Extras = { "PaintRadius", "Coins" },
		Pets = { "Squirrel", "Deer", "Owl", "Panda", "Lynx", "Elephant", "Tiger", "Lion" },
	},
	{
		Name = "Surfing",
		Stat = "Speed",
		IncomeMultiplier = 1.6,
		Extras = { "Coins", "PaintRadius" },
		Pets = {
			"Floaty Ducky",
			"Surfing Doggy",
			"Surfing Kitty",
			"Shark",
			"Beach Boi",
			"Bucket O' Shells",
			"Seaweed Monster",
			"Tidal God",
		},
	},
	{
		Name = "Arctic",
		Stat = "PaintRadius",
		IncomeMultiplier = 1.9,
		Extras = { "Power", "Speed" },
		Pets = {
			"Penguin",
			"Snow Squirrel",
			"Arctic Fox",
			"Polar Bear",
			"Mammoth",
			"Snow Tiger",
			"King Penguin",
			"Frost Defender",
		},
	},
	{
		Name = "Ice",
		Stat = "Power",
		IncomeMultiplier = 2.2,
		Extras = { "PaintRadius", "Speed" },
		Pets = {
			"Ice Doggy",
			"Ice Kitty",
			"Walrus",
			"Moose",
			"Eagle",
			"Ice Golem",
			"Frost Wisp",
			"Frigidus",
		},
	},
	{
		Name = "Volcanic",
		Stat = "Luck",
		IncomeMultiplier = 2.6,
		Extras = { "Power", "Coins" },
		Pets = {
			"Volcanic Doggy",
			"Volcanic Kitty",
			"Molten Piggy",
			"Volcanic Golem",
			"Molten Cow",
			"Fire Panda",
			"Inferno Dragon",
			"Blazing Phoenix",
		},
	},
	{
		Name = "Infernal",
		Stat = "Power",
		IncomeMultiplier = 3,
		Extras = { "Luck", "Speed" },
		Pets = {
			"Imp",
			"Hell Bat",
			"Inferno Mimic",
			"Flame Wisp",
			"Infernus",
			"Infernal Revenant",
			"Cerberus",
			"Blazing Guardian",
		},
	},
	{
		Name = "Dragon",
		Stat = "Power",
		IncomeMultiplier = 3.5,
		Extras = { "Coins", "Luck" },
		Pets = {
			"Dragon",
			"Bone Dragon",
			"Ruby Dragon",
			"Rex",
			"Phoenix",
			"Hydra",
			"Kitsune",
			"King Hydra",
		},
	},
	{
		Name = "Holographic",
		Stat = "Luck",
		IncomeMultiplier = 4,
		Extras = { "PaintRadius", "Coins" },
		Pets = {
			"Holo Doggy",
			"Holo Kitty",
			"Holo Butterfly",
			"Holo Dino",
			"Rainbow Shock",
			"Chroma Wisp",
			"Holocorn",
			"Prisma",
		},
	},
	{
		Name = "Space",
		Stat = "Speed",
		IncomeMultiplier = 5,
		Extras = { "Luck", "Power" },
		Pets = {
			"Space Snail",
			"Space Mouse",
			"Space Doggy",
			"Space Kitty",
			"Astronaut",
			"Alien",
			"Cool Sun",
			"Planetarium",
		},
	},
	{
		Name = "Cyborg",
		Stat = "Power",
		IncomeMultiplier = 6,
		Extras = { "Speed", "PaintRadius" },
		Pets = {
			"Cyborg Doggy",
			"Cyborg Owl",
			"Cyborg Deer",
			"Cyborg Racoon",
			"Cyber Comet",
			"Omega One",
			"Robotic Leviathan",
			"Giant Robot",
		},
	},
	{
		Name = "Nebula",
		Stat = "Luck",
		IncomeMultiplier = 7,
		Extras = { "Speed", "Coins" },
		Pets = {
			"Nebula Bunny",
			"Nebula Bear",
			"Nebula Golem",
			"Hexarium",
			"Luminous",
			"Nebular Demon",
			"Astra",
			"Astra Hydra",
		},
	},
	{
		Name = "Underworld",
		Stat = "PaintRadius",
		IncomeMultiplier = 8,
		Extras = { "Power", "Luck" },
		Pets = {
			"Bat",
			"Ghost",
			"Crawler",
			"Punk Bat",
			"Werewolf",
			"Crimson Eye",
			"Phantom",
			"Messor",
		},
	},
	{
		Name = "Dark",
		Stat = "Power",
		IncomeMultiplier = 9.5,
		Extras = { "Luck", "Coins" },
		Pets = {
			"Sapphire Demon",
			"Vesp",
			"Dark Dragon",
			"Dark Berserker",
			"Dark Phoenix",
			"Neon Abyss",
			"Dark Defender",
			"The Overseer",
		},
	},
	{
		Name = "Glitched",
		Stat = "Coins",
		IncomeMultiplier = 11,
		Extras = { "Luck", "Power" },
		Pets = {
			"Bruh",
			"Coder Pet",
			"Glitched Cube",
			"Glitched Doggy",
			"Glitched Bunny",
			"Glitched Fox",
			"Glitched Crawler",
			"Missing 404",
		},
	},
	{
		Name = "Glitch",
		Stat = "Luck",
		IncomeMultiplier = 13,
		Extras = { "Coins", "Speed" },
		Pets = {
			"Virus Cube",
			"Tetra Cube",
			"Parade Cube",
			"Patriot Cuboid",
			"Glitch",
			"Fracture",
			"Virus CORE",
			"CORE",
		},
	},
	{
		Name = "Patriotic",
		Stat = "Speed",
		IncomeMultiplier = 15,
		Extras = { "Power", "Coins" },
		Pets = {
			"Patriotic Doggy",
			"Patriotic Shock",
			"Patriotic Star",
			"Patriotic Robot",
			"Patriotic Mimic",
			"Patriot Dragon",
			"Patrius",
			"Liberty",
		},
	},
	{
		Name = "Season 1",
		Stat = "Coins",
		IncomeMultiplier = 17.5,
		Extras = { "Speed", "PaintRadius" },
		Pets = {
			"Mimic",
			"Chicken",
			"Sunny Bunny",
			"Sunny Bear",
			"Seaside Dogcat",
			"Dogcat",
			"Unicorn",
			"Delightful Trio",
		},
	},
	{
		Name = "SpinToWin",
		Stat = "Luck",
		IncomeMultiplier = 20,
		Extras = { "Coins", "PaintRadius" },
		Pets = {
			"Crystal Doggy",
			"Crystal Kitty",
			"Crystal Bat",
			"Crystal Butterfly",
			"White Sparkletime",
			"Crystal Cuboid",
			"Amethyst Golem",
			"Brilliant Gem",
		},
	},
	{
		Name = "Royal",
		Stat = "Coins",
		IncomeMultiplier = 25,
		Extras = { "Luck", "Power" },
		Pets = {
			"Slime Cube",
			"Slime Doggy",
			"Slime Kitty",
			"Slime Bat",
			"Royal Heart",
			"Aureus",
			"Empyreus",
			"Queen Kitty",
		},
	},
	{
		Name = "Sparkletime",
		Stat = "Luck",
		IncomeMultiplier = 30,
		Extras = { "Coins", "Speed" },
		Pets = {
			"Red Sparkletime",
			"Pink Sparkletime",
			"Purple Sparkletime",
			"Blue Sparkletime",
			"Cyan Sparkletime",
			"Green Sparkletime",
			"Black Sparkletime",
			"Gold Sparkletime",
		},
	},
}

-- Rarity of the pets in an egg, weakest first.
local RARITY_BY_PLACE =
	{ "Common", "Common", "Uncommon", "Uncommon", "Rare", "Rare", "Epic", "Legendary" }

-- Whole percents.
local function percent(value: number): number
	return math.floor(value * 100 + 0.5) / 100
end

-- Keys are stable ids saved in profiles: the model name without spaces and
-- punctuation. Never rename or remove one.
local function keyOf(name: string): string
	return (name:gsub("[^%w]", ""))
end

local THEMES: { [string]: Theme } = {}
local THEME_ORDER: { string } = {}
local PETS: { [string]: PetKind } = {}
for tier, egg in EGGS do
	THEMES[egg.Name] = {
		Name = egg.Name,
		Stat = egg.Stat,
		IncomeMultiplier = egg.IncomeMultiplier,
	}
	table.insert(THEME_ORDER, egg.Name)
	local scale = 1 + BONUS_PER_EGG * (tier - 1)
	assert(#egg.Pets == #RARITY_BY_PLACE, egg.Name .. ": an egg holds 8 pets")
	for order, name in egg.Pets do
		local fromBest = #egg.Pets - order + 1
		local rarity = RARITY_BY_PLACE[order]
		local main = percent(BONUS[egg.Stat][rarity] * scale)
		local buffs: { [string]: number } = { [egg.Stat] = main }
		local extras = if fromBest == 1 then 2 elseif fromBest == 2 then 1 else 0
		for index = 1, extras do
			local stat = egg.Extras[index]
			-- Whole percents, rounded up: half of +25% is +13%.
			local full = math.floor(BONUS[stat][rarity] * scale * 100 + 0.5)
			buffs[stat] = math.ceil(full * EXTRA_SHARE) / 100
		end
		local key = keyOf(name)
		assert(PETS[key] == nil, "duplicate pet " .. key)
		PETS[key] = {
			Name = name,
			Theme = egg.Name,
			Rarity = rarity,
			Order = order,
			Model = name,
			Buffs = table.freeze(buffs),
			Income = math.floor(RARITY_INCOME[rarity] * egg.IncomeMultiplier + 0.5),
		}
	end
end

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
	-- Egg themes, cheapest first.
	ThemeOrder = table.freeze(THEME_ORDER),
	Pets = table.freeze(PETS),
	Bonus = table.freeze(BONUS),
	BonusPerEgg = BONUS_PER_EGG,
	Caps = table.freeze(CAPS),
	MaxEquipped = 3,
	StartCapacity = 50,
	-- Order of stats in the UI.
	StatOrder = table.freeze({ "Speed", "Power", "PaintRadius", "Luck", "Coins" }),
	RarityIncome = table.freeze(RARITY_INCOME),
	-- Offline earnings count at most this long.
	OfflineIncomeMaxSeconds = 24 * 60 * 60,
	-- Coins for selling a pet, or for a hatch when the inventory is full.
	SellValue = table.freeze({ Common = 5, Uncommon = 10, Rare = 25, Epic = 60, Legendary = 150 }),
})
