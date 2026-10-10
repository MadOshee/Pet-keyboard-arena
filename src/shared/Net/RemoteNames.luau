--!strict
-- Registry of every RemoteEvent (docs/design.md section 10).
-- The server creates these under ReplicatedStorage.Remotes; clients only wait.
-- Round phase, timer and score replicate as ReplicatedStorage attributes,
-- and Ready/Team/EquippedPets as Player attributes, so they need no remotes.
-- The pending egg offer travels inside the profile (DataSync).

return table.freeze({
	ClientToServer = table.freeze({
		"SetReady", -- (ready: boolean)
		"EggPick", -- (offerId: string, slot: number)
		"EggReroll", -- (offerId: string)
		"PetEquip", -- (petId: string, equip: boolean)
		"PetSell", -- (petId: string)
		"BatSwing", -- () the server picks the target
	}),
	ServerToClient = table.freeze({
		"DataSync", -- (profile: Types.Profile) full snapshot to the owner
		"RoundResult", -- (result: Types.RoundResultPayload) to each participant
		"PetHatched", -- (result: Types.PetHatchedPayload) to the owner
		"ActionResult", -- (action: string, reason: Types.ActionError) refusals only
		"BatSwingFx", -- (attackerUserId: number) to all, swing effect
		"KnockedOut", -- (victimUserId, attackerUserId, direction: Vector3, seconds) to all
		"PowerUpEvent", -- (kind: string, userId: number, position: Vector3) to all
	}),
})
