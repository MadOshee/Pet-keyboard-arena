--!strict
-- Round timing, team sizes and coin rewards (docs/design.md 4.3, 4.5).
-- Replicated to clients: nothing secret, and the server never trusts a
-- client-reported value from here.

return table.freeze({
	IntermissionSeconds = 15,
	CountdownSeconds = 3,
	PlayingSeconds = 60,
	ResultsSeconds = 5,

	-- Stage 1 has no bots yet, so a single ready player can start a round.
	-- Stage 4 adds bots that fill teams up to MinTeamSize.
	MinParticipants = 1,
	MinTeamSize = 4,
	MaxTeamSize = 6,

	-- A participant who painted fewer keys is treated as AFK: no reward,
	-- and their ready flag is cleared.
	MinKeysForReward = 3,

	Coins = table.freeze({
		Win = 40,
		Draw = 40,
		Lose = 20,
		KeysPerBonusCoin = 2,
		MaxBonusCoins = 30,
		MaxMultiplier = 2,
	}),
})
