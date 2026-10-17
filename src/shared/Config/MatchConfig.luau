--!strict
-- Cross-server matchmaking (docs/design.md 5.2, stage 12; Ivan 2026-10-14).
-- Hub servers put queued players into one shared MemoryStore queue; one hub
-- at a time (the lock holder) forms matches of up to MaxHumans and reserves
-- an arena server for each. In Studio, or before the game is published,
-- matches stay on the local server as before.

return table.freeze({
	-- false keeps every match on its own server (the old behavior).
	CrossServer = true,
	-- Place id of the arena place (Creator Hub: add a place to the game,
	-- set its Max Players to 12, publish this same file there). 0 = the
	-- arena runs on a reserved server of the hub place, so a match holds at
	-- most as many players as the hub's Max Players.
	ArenaPlaceId = 86203411093378,

	-- 6 v 6.
	MaxHumans = 12,
	-- A match starts once the oldest ticket has waited this long, or right
	-- away when MaxHumans are queued. Missing seats are bots.
	WaitSeconds = 10,
	-- The matchmaker starts a match this much before the wait runs out:
	-- reserving the arena and telling the hubs takes a few seconds.
	StartLeadSeconds = 7,
	-- The hub then teleports its players when "Match in N" shows this
	-- number (Ivan 2026-10-17: the arena loads from "Match in 3").
	TeleportAtSeconds = 3,
	-- A ticket that got no match in this time plays on its own server.
	GiveUpSeconds = 45,
	-- How long the arena waits for everyone to arrive before it starts.
	ArrivalSeconds = 20,
	-- How long a hub keeps a party together for members away at a match.
	AwaySeconds = 240,

	TicketSeconds = 60, -- MemoryStore expiry, refreshed while queued
	RefreshSeconds = 20,
	AssignmentSeconds = 120,
	RosterSeconds = 900,
	LockSeconds = 10,
	-- Hub servers say they are alive this often; the arena sends players
	-- back to their own hub only while it is (else any hub server), so a
	-- hub closed meanwhile never gives "Teleport Failed 771" (Ivan 2026-10-17).
	HubAliveRefreshSeconds = 10,
	HubAliveSeconds = 30,
	TickSeconds = 1,
	MaxMatchesPerTick = 5,

	Maps = table.freeze({
		Queue = "MatchQueue",
		Assignments = "MatchAssignments",
		Rosters = "MatchRosters",
		Lock = "MatchmakerLock",
		Hubs = "HubServers",
	}),
})
