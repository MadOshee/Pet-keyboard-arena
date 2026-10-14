local PetConfig = require("../src/shared/Config/PetConfig")
local Purchases = require("../src/shared/Logic/Purchases")
local ShopConfig = require("../src/shared/Config/ShopConfig")

local tests = {}

function tests.keyForId()
	local items = { A = { Id = 11 }, B = { Id = 22 }, C = { Id = 0 } }
	assert(Purchases.KeyForId(items, 22) == "B")
	assert(Purchases.KeyForId(items, 33) == nil)
	assert(Purchases.KeyForId(items, 0) == nil, "id 0 is never a real item")
end

function tests.rememberRejectsDuplicates()
	local history = {}
	assert(Purchases.Remember(history, "p1", 3))
	assert(not Purchases.Remember(history, "p1", 3))
	assert(#history == 1)
end

function tests.rememberKeepsNewest()
	local history = {}
	for i = 1, 5 do
		Purchases.Remember(history, `p{i}`, 3)
	end
	assert(#history == 3)
	assert(history[1] == "p3" and history[3] == "p5")
end

function tests.sortedByOrder()
	local keys = Purchases.Sorted(ShopConfig.Products :: any)
	assert(keys[1] == "SpeedUpEgg")
	assert(keys[#keys] == "Coins15000")
	assert(#Purchases.Sorted(ShopConfig.GamePasses :: any) == 4)
end

function tests.luckMultipliersStack()
	assert(Purchases.LuckMultiplier(false, false, 2) == 1)
	assert(Purchases.LuckMultiplier(true, false, 2) == 2)
	assert(Purchases.LuckMultiplier(false, true, 2) == 2)
	assert(Purchases.LuckMultiplier(true, true, 2) == 4)
end

function tests.luckPotionRespectsCap()
	local cap = PetConfig.Caps.Luck
	assert(Purchases.LuckWithPotion(0.2, 0.5, cap) == 0.7)
	assert(Purchases.LuckWithPotion(0.8, 0.5, cap) == cap)
	assert(Purchases.LuckWithPotion(cap, 0.5, cap) == cap)
end

function tests.coinPacksHaveCoins()
	for key, product in ShopConfig.Products do
		if string.sub(key, 1, 5) == "Coins" then
			assert((product.Coins or 0) > 0, key)
		end
	end
end

return tests
