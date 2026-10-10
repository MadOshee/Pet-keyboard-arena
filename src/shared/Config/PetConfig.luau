--!strict
-- Pet kinds, themes and bonus values (docs/design.md 4.3 "Питомцы", 4.4).
-- Each theme gives one stat, so picking an egg theme is a real choice (D2).
-- Model is the model name under ReplicatedStorage.Assets.Pets; the game
-- still works without it (pets then show as colored balls).
-- No requires or Roblox types: Lune tests load this file directly.
-- Colors live in Config/PetStyle.

export type Stat = "Speed" | "PaintRadius" | "Luck" | "Coins"

export type Theme = {
	Name: string,
	Stat: Stat,
}

export type PetKind = {
	Name: string,
	Theme: string,
	Rarity: string,
	Model: string,
}

-- Lowest to highest. EggRoller and the UI use this order.
local RARITIES = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }

local THEMES: { [string]: Theme } = {
	Basic = { Name = "Basic", Stat = "Coins" },
	Forest = { Name = "Forest", Stat = "Speed" },
	Arctic = { Name = "Arctic", Stat = "PaintRadius" },
	Volcanic = { Name = "Volcanic", Stat = "Luck" },
}

local function pet(name: string, theme: string, rarity: string, model: string?): PetKind
	return { Name = name, Theme = theme, Rarity = rarity, Model = model or name }
end

-- Keys are stable ids saved in profiles: never rename or remove one.
local PETS: { [string]: PetKind } = {
	Doggy = pet("Doggy", "Basic", "Common"),
	Kitty = pet("Kitty", "Basic", "Common"),
	Bunny = pet("Bunny", "Basic", "Uncommon"),
	Fox = pet("Fox", "Basic", "Rare"),
	Bear = pet("Bear", "Basic", "Epic"),
	Cow = pet("Cow", "Basic", "Legendary"),

	Deer = pet("Deer", "Forest", "Common"),
	Squirrel = pet("Squirrel", "Forest", "Common"),
	Owl = pet("Owl", "Forest", "Uncommon"),
	Lynx = pet("Lynx", "Forest", "Rare"),
	Tiger = pet("Tiger", "Forest", "Epic"),
	Lion = pet("Lion", "Forest", "Legendary"),

	Penguin = pet("Penguin", "Arctic", "Common"),
	SnowSquirrel = pet("Snow Squirrel", "Arctic", "Common"),
	ArcticFox = pet("Arctic Fox", "Arctic", "Uncommon"),
	PolarBear = pet("Polar Bear", "Arctic", "Rare"),
	SnowTiger = pet("Snow Tiger", "Arctic", "Epic"),
	FrostDefender = pet("Frost Defender", "Arctic", "Legendary"),

	VolcanicDoggy = pet("Volcanic Doggy", "Volcanic", "Common"),
	VolcanicKitty = pet("Volcanic Kitty", "Volcanic", "Common"),
	MoltenPiggy = pet("Molten Piggy", "Volcanic", "Uncommon"),
	FirePanda = pet("Fire Panda", "Volcanic", "Rare"),
	InfernoDragon = pet("Inferno Dragon", "Volcanic", "Epic"),
	BlazingPhoenix = pet("Blazing Phoenix", "Volcanic", "Legendary"),
}

-- Bonus of one pet as a fraction (0.04 = +4%), by stat and rarity.
local BONUS: { [string]: { [string]: number } } = {
	Speed = { Common = 0.01, Uncommon = 0.02, Rare = 0.04, Epic = 0.06, Legendary = 0.09 },
	PaintRadius = { Common = 0.02, Uncommon = 0.04, Rare = 0.08, Epic = 0.12, Legendary = 0.18 },
	Luck = { Common = 0.05, Uncommon = 0.10, Rare = 0.20, Epic = 0.30, Legendary = 0.45 },
	Coins = { Common = 0.05, Uncommon = 0.10, Rare = 0.20, Epic = 0.30, Legendary = 0.45 },
}

-- Caps on the sum of all equipped pets (D5).
local CAPS: { [string]: number } = {
	Speed = 0.25,
	PaintRadius = 0.5,
	Luck = 1,
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
	-- Coins for selling a pet, or for a hatch when the inventory is full.
	SellValue = table.freeze({ Common = 5, Uncommon = 10, Rare = 25, Epic = 60, Legendary = 150 }),
})
