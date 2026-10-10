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
		Arctic = Color3.fromRGB(120, 210, 245),
		Volcanic = Color3.fromRGB(245, 110, 60),
	}) :: { [string]: Color3 },
})
