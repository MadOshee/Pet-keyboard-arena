--!strict
-- Registry of every RemoteEvent (docs/design.md section 10).
-- The server creates these under ReplicatedStorage.Remotes; clients only wait.
-- Round phase, timer and score replicate as ReplicatedStorage attributes,
-- and Ready/Team as Player attributes, so they need no remotes.

return table.freeze({
	ClientToServer = table.freeze({
		"SetReady", -- (ready: boolean)
	}),
	ServerToClient = table.freeze({
		"DataSync", -- (profile: Types.Profile) full snapshot to the owner
		"RoundResult", -- (result: Types.RoundResultPayload) to each participant
	}),
})
