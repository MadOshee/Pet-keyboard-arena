--!strict
-- Default profile for new players (docs/design.md section 9). ProfileStore
-- deep-copies this, and Reconcile() adds new fields to existing profiles.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)

local CURRENT_SCHEMA_VERSION = 1

local template: Types.Profile = {
	SchemaVersion = CURRENT_SCHEMA_VERSION,
	Coins = 0,
	Stats = {
		RoundsPlayed = 0,
		Wins = 0,
		KeysPainted = 0,
	},
	ProcessedPurchases = {},
	Tutorial = { Done = false },
}

return {
	CurrentSchemaVersion = CURRENT_SCHEMA_VERSION,
	Template = template,
}
