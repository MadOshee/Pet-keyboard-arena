--!strict
-- Registry of every RemoteEvent (docs/design.md section 10).
-- The server creates these under ReplicatedStorage.Remotes; clients only wait.
-- Round phase, timer and score replicate as ReplicatedStorage attributes,
-- and Ready/Team/EquippedPets as Player attributes, so they need no remotes.
-- The pending egg offer travels inside the profile (DataSync).

return table.freeze({
	ClientToServer = table.freeze({
		"SetReady", -- (false) leave the match queue
		"JoinQueue", -- (mode: "Solo" | "Party") at the hub portal
		"EggPick", -- (offerId: string, slot: number)
		"EggReroll", -- (offerId: string)
		"PetEquip", -- (petId: string, equip: boolean)
		"PetSell", -- (petId: string)
		"BatSwing", -- () the server picks the target
		"BuyUpgrade", -- (upgradeId: "Incubator" | "PetSlots")
		"GoToPlot", -- () teleport to your plot outside a round
		"PlatformAction", -- (index: number, action: Types.PlatformActionKind, id: string?)
		"PartyInvite", -- (targetUserId: number)
		"PartyRespond", -- (inviterUserId: number, accept: boolean)
		"PartyLeave", -- ()
		"TutorialDone", -- () the first-time tips were finished or skipped
		"SendFeedback", -- (text: string) a message for the developers
	}),
	ServerToClient = table.freeze({
		"DataSync", -- (profile: Types.Profile) full snapshot to the owner
		"RoundResult", -- (result: Types.RoundResultPayload) to each participant
		"EggPicked", -- (result: Types.EggPickedPayload) to the owner
		"PetHatched", -- (result: Types.PetHatchedPayload) to the owner
		"OfflineIncome", -- (result: Types.OfflineIncomePayload) to the owner on join
		"ActionResult", -- (action: string, reason: Types.ActionError) refusals only
		"BatSwingFx", -- (attacker: Model, hit: boolean) character of a player or bot, to all
		"KnockedOut", -- (victim: Model, attacker: Model, direction: Vector3, seconds) to all
		"ArenaFell", -- () to a player who just fell off the arena
		"ArenaRespawn", -- () to a player dropped in above the arena after falling off
		"PartyUpdate", -- (party: Types.PartyPayload) to each player
		"PowerUpEvent", -- (kind: string, userId: number, position: Vector3) to all
	}),
})
