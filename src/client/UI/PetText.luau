--!strict
-- Texts about a pet kind shared by the inventory, the Pets index and the
-- platforms: its buffs ("+5% Speed") in PetConfig.StatOrder and its income.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PetConfig = require(ReplicatedStorage.Shared.Config.PetConfig)
local Strings = require(ReplicatedStorage.Shared.Config.Strings)

local PetText = {}

local function percent(value: number): number
	return math.floor(value * 100 + 0.5)
end

function PetText.Bonus(stat: string, value: number): string
	return string.format(Strings.Bonus, percent(value), (Strings.StatName :: any)[stat] or stat)
end

-- One line per buff of the kind; empty for unknown kinds.
function PetText.BuffLines(kind: string): { string }
	local entry = PetConfig.Pets[kind]
	local lines = {}
	if entry == nil then
		return lines
	end
	for _, stat in PetConfig.StatOrder do
		local value = entry.Buffs[stat]
		if value then
			table.insert(lines, PetText.Bonus(stat, value))
		end
	end
	return lines
end

-- 1234567 -> "1,234,567".
function PetText.Number(value: number): string
	local text = tostring(math.floor(value))
	local formatted = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (formatted:gsub("^,", ""))
end

return PetText
