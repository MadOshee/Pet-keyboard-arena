--!strict
-- Round timing, team sizes and coin rewards (docs/design.md 4.3, 4.5).
-- Replicated to clients: nothing secret, and the server never trusts a
-- client-reported value from here.

return table.freeze({
	-- Countdown after the first player enters the portal, so friends and
	-- other players can join the same match before the teleport.
	StartingSeconds = 10,
	CountdownSeconds = 3,
	PlayingSeconds = 60,
	ResultsSeconds = 5,

	-- One ready player is enough: bots fill both teams up to the team size
	-- (MinTeamSize at least, D6).
	MinParticipants = 1,
	MinTeamSize = 4,
	MaxTeamSize = 6,

	-- A participant who painted fewer keys is treated as AFK: no reward.
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
