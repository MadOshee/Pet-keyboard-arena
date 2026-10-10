--!strict
-- Robux purchase helpers (docs/design.md 4.6, section 10). Pure Luau,
-- tested with Lune; the config is ShopConfig.

local Purchases = {}

-- Name of the item with this id, or nil (id 0 never matches).
function Purchases.KeyForId(items: { [string]: { Id: number } }, id: number): string?
	if id == 0 then
		return nil
	end
	for key, item in items do
		if item.Id == id then
			return key
		end
	end
	return nil
end

-- Records `purchaseId` in `history` (oldest first, at most `size` ids).
-- Returns false when it was already there, so the item is not granted twice.
function Purchases.Remember(history: { string }, purchaseId: string, size: number): boolean
	if table.find(history, purchaseId) then
		return false
	end
	table.insert(history, purchaseId)
	while #history > size do
		table.remove(history, 1)
	end
	return true
end

-- Item names sorted by their Order field, for the shop list.
function Purchases.Sorted(items: { [string]: { Order: number } }): { string }
	local keys = {}
	for key in items do
		table.insert(keys, key)
	end
	table.sort(keys, function(a, b)
		return items[a].Order < items[b].Order
	end)
	return keys
end

-- Luck for an egg offer with the potion's bonus, never above the cap.
function Purchases.LuckWithPotion(luck: number, bonus: number, cap: number): number
	return math.min(luck + bonus, math.max(cap, luck))
end

return Purchases
