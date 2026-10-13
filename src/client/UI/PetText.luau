--!strict
-- Texts about a pet kind shared by the inventory, the Pets index and the
-- platforms: its buffs ("+5% Speed") in PetConfig.StatOrder.

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

export type Buff = { Stat: string, Text: string }

-- The kind's buffs in PetConfig.StatOrder; empty for unknown kinds.
function PetText.Buffs(kind: string): { Buff }
	local entry = PetConfig.Pets[kind]
	local buffs: { Buff } = {}
	if entry == nil then
		return buffs
	end
	for _, stat in PetConfig.StatOrder do
		local value = entry.Buffs[stat]
		if value then
			table.insert(buffs, { Stat = stat, Text = PetText.Bonus(stat, value) })
		end
	end
	return buffs
end

-- One line per buff of the kind; empty for unknown kinds.
function PetText.BuffLines(kind: string): { string }
	local lines = {}
	for _, buff in PetText.Buffs(kind) do
		table.insert(lines, buff.Text)
	end
	return lines
end

return PetText
