--!strict
-- Robux items (docs/design.md 4.6). Id 0 means "not created yet": the shop
-- shows the item as coming soon and nothing can be bought. Ivan creates the
-- passes and products in Creator Hub and the ids go here.
-- No requires or Roblox types: Lune tests load this file directly.

export type Pass = { Id: number, Order: number }
export type Product = { Id: number, Order: number, Coins: number? }

local GAME_PASSES: { [string]: Pass } = {
	VIP = { Id = 0, Order = 1 }, -- VIP tag over the head, +1 incubator
	FastHatch = { Id = 0, Order = 2 }, -- eggs hatch 30% faster
	DoubleCoins = { Id = 0, Order = 3 }, -- x2 coins after a round
}

local PRODUCTS: { [string]: Product } = {
	SpeedUpEgg = { Id = 0, Order = 1 }, -- finishes the egg with the most time left
	Reroll = { Id = 0, Order = 2 }, -- one reroll without coins
	LuckPotion = { Id = 0, Order = 3 }, -- +Luck for the next egg offers
	Coins1000 = { Id = 0, Order = 4, Coins = 1000 },
	Coins5000 = { Id = 0, Order = 5, Coins = 5000 },
	Coins15000 = { Id = 0, Order = 6, Coins = 15000 },
}

return table.freeze({
	GamePasses = table.freeze(GAME_PASSES),
	Products = table.freeze(PRODUCTS),

	FastHatchMultiplier = 0.7,
	DoubleCoinsMultiplier = 2,
	LuckPotionBonus = 0.5, -- still capped by PetConfig.Caps.Luck
	LuckPotionOffers = 5,
	VipExtraIncubators = 1,
	-- How many recent purchase ids the profile keeps to stop double grants.
	PurchaseHistorySize = 50,
})
