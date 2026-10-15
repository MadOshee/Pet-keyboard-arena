--!strict
-- Robux items (docs/design.md 4.6). Id 0 means "not created yet": the shop
-- shows the item as coming soon and nothing can be bought. Ivan creates the
-- passes and products in Creator Hub and the ids go here.
-- No requires or Roblox types: Lune tests load this file directly.

export type Pass = { Id: number, Order: number, Robux: number? }
export type Product = { Id: number, Order: number, Coins: number?, Robux: number? }

local GAME_PASSES: { [string]: Pass } = {
	VIP = { Id = 0, Order = 1 }, -- VIP tag over the head, +1 incubator
	FastHatch = { Id = 0, Order = 2 }, -- eggs hatch 30% faster
	-- The pack Shop's X2 Money: x2 coins after a round, for ever.
	DoubleCoins = { Id = 2036390606, Order = 3, Robux = 99 },
	-- The pack Shop's X2 Luck (Ivan 2026-10-14): super rare eggs come up
	-- twice as often in offers, for ever.
	DoubleLuck = { Id = 2036732634, Order = 4, Robux = 99 },
}

local PRODUCTS: { [string]: Product } = {
	SpeedUpEgg = { Id = 0, Order = 1 }, -- finishes the egg with the most time left
	-- One reroll without coins. Robux: the planned price, shown until the
	-- product exists (Ivan: 10 for now).
	Reroll = { Id = 3718741699, Order = 2, Robux = 10 },
	LuckPotion = { Id = 0, Order = 3 }, -- +Luck for the next egg offers
	-- Server Luck (Ivan 2026-10-14): x2 luck for everyone on the server for
	-- 15 minutes, like X2 Luck.
	ServerLuck = { Id = 3718741314, Order = 4, Robux = 39 },
	Coins1000 = { Id = 0, Order = 5, Coins = 1000 },
	Coins5000 = { Id = 0, Order = 6, Coins = 5000 },
	Coins15000 = { Id = 0, Order = 7, Coins = 15000 },
}

return table.freeze({
	GamePasses = table.freeze(GAME_PASSES),
	Products = table.freeze(PRODUCTS),

	FastHatchMultiplier = 0.7,
	DoubleCoinsMultiplier = 2,
	LuckPotionBonus = 0.5, -- still capped by PetConfig.Caps.Luck
	LuckPotionOffers = 5,
	VipExtraIncubators = 1,
	-- X2 Luck and Server Luck each multiply the super rare eggs' chances;
	-- both together give x4.
	LuckMultiplier = 2,
	ServerLuckSeconds = 15 * 60,
	-- How many recent purchase ids the profile keeps to stop double grants.
	PurchaseHistorySize = 200,
})
