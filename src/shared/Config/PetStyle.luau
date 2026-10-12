--!strict
-- Colors for rarities and egg themes in the UI and pet placeholders.

return table.freeze({
	Rarity = table.freeze({
		Common = Color3.fromRGB(200, 200, 205),
		Uncommon = Color3.fromRGB(110, 220, 110),
		Rare = Color3.fromRGB(80, 160, 255),
		Epic = Color3.fromRGB(190, 100, 255),
		Legendary = Color3.fromRGB(255, 190, 40),
	}) :: { [string]: Color3 },
	Theme = table.freeze({
		Basic = Color3.fromRGB(255, 206, 84),
		Forest = Color3.fromRGB(96, 196, 96),
		Slime = Color3.fromRGB(120, 230, 90),
		Surfing = Color3.fromRGB(70, 190, 230),
		Arctic = Color3.fromRGB(120, 210, 245),
		Ice = Color3.fromRGB(160, 225, 255),
		Volcanic = Color3.fromRGB(245, 110, 60),
		Infernal = Color3.fromRGB(220, 50, 40),
		Dragon = Color3.fromRGB(200, 70, 70),
		Holographic = Color3.fromRGB(230, 140, 255),
		Space = Color3.fromRGB(90, 90, 200),
		Cyborg = Color3.fromRGB(150, 160, 175),
		Nebula = Color3.fromRGB(170, 90, 230),
		Underworld = Color3.fromRGB(110, 60, 140),
		Dark = Color3.fromRGB(80, 60, 110),
		Glitched = Color3.fromRGB(80, 230, 140),
		Glitch = Color3.fromRGB(60, 210, 220),
		Patriotic = Color3.fromRGB(70, 110, 230),
		["Season 1"] = Color3.fromRGB(255, 170, 80),
		SpinToWin = Color3.fromRGB(150, 110, 255),
		Royal = Color3.fromRGB(255, 200, 60),
		Sparkletime = Color3.fromRGB(255, 120, 200),
	}) :: { [string]: Color3 },
	-- Buff colors (Ivan's picture, 2026-10-12).
	Stat = table.freeze({
		Speed = Color3.fromRGB(255, 240, 40),
		Power = Color3.fromRGB(255, 90, 60),
		PaintRadius = Color3.fromRGB(70, 200, 255),
		Luck = Color3.fromRGB(110, 230, 70),
		Coins = Color3.fromRGB(110, 230, 70),
	}) :: { [string]: Color3 },
})
