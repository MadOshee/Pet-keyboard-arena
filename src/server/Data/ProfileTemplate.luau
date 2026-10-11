--!strict
-- Default profile for new players (docs/design.md section 9). ProfileStore
-- deep-copies this, and Reconcile() adds new fields to existing profiles,
-- so fields added in later stages need no migration step.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EggConfig = require(ReplicatedStorage.Shared.Config.EggConfig)
local PetConfig = require(ReplicatedStorage.Shared.Config.PetConfig)
local Types = require(ReplicatedStorage.Shared.Types)

local CURRENT_SCHEMA_VERSION = 1

local template: Types.Profile = {
	SchemaVersion = CURRENT_SCHEMA_VERSION,
	Coins = 0,
	Pets = {},
	Equipped = {},
	PetCapacity = PetConfig.StartCapacity,
	Eggs = {},
	EggCapacity = EggConfig.StartEggCapacity,
	Incubators = {},
	-- PendingOffer stays nil until a rewarded round.
	Stats = {
		RoundsPlayed = 0,
		Wins = 0,
		KeysPainted = 0,
	},
	ProcessedPurchases = {},
	Tutorial = { Done = false },
}

-- One empty table per starting incubator (separate tables, not one shared).
for _ = 1, EggConfig.StartIncubators do
	table.insert(template.Incubators, {})
end

return {
	CurrentSchemaVersion = CURRENT_SCHEMA_VERSION,
	Template = template,
}
