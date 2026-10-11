--!strict
-- Registry of every RemoteEvent (docs/design.md section 10).
-- The server creates these under ReplicatedStorage.Remotes; clients only wait.
-- Round phase, timer and score replicate as ReplicatedStorage attributes,
-- and Ready/Team/EquippedPets as Player attributes, so they need no remotes.
-- The pending egg offer travels inside the profile (DataSync). Incubators
-- are used through ProximityPrompts on the plot (PlotService), not remotes.

return table.freeze({
	ClientToServer = table.freeze({
		"SetReady", -- (ready: boolean)
		"EggPick", -- (offerId: string, slot: number)
		"EggReroll", -- (offerId: string)
		"PetEquip", -- (petId: string, equip: boolean)
		"PetSell", -- (petId: string)
		"BatSwing", -- () the server picks the target
		"BuyUpgrade", -- (upgradeId: "Incubator" | "PetSlots")
		"GoToPlot", -- () teleport to your plot outside a round
		"PartyInvite", -- (targetUserId: number)
		"PartyRespond", -- (inviterUserId: number, accept: boolean)
		"PartyLeave", -- ()
	}),
	ServerToClient = table.freeze({
		"DataSync", -- (profile: Types.Profile) full snapshot to the owner
		"RoundResult", -- (result: Types.RoundResultPayload) to each participant
		"EggPicked", -- (result: Types.EggPickedPayload) to the owner
		"PetHatched", -- (result: Types.PetHatchedPayload) to the owner
		"ActionResult", -- (action: string, reason: Types.ActionError) refusals only
		"BatSwingFx", -- (attacker: Model) character of a player or bot, to all
		"KnockedOut", -- (victim: Model, attacker: Model, direction: Vector3, seconds) to all
		"PartyUpdate", -- (party: Types.PartyPayload) to each player
		"PowerUpEvent", -- (kind: string, userId: number, position: Vector3) to all
	}),
})
