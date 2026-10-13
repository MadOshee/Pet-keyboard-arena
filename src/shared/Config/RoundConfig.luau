--!strict
-- Round timing, team sizes, coin and XP rewards (docs/design.md 4.3, 4.5).
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

	-- Money and XP doubled by Ivan 2026-10-13 (bonus +1 per key, not per 2).
	Coins = table.freeze({
		Win = 80,
		Draw = 80,
		Lose = 40,
		KeysPerBonusCoin = 1,
		MaxBonusCoins = 60,
		MaxMultiplier = 2,
	}),

	-- XP after a rewarded round and the level it adds up to (Ivan
	-- 2026-10-13: the round rewards window shows money and XP).
	XP = table.freeze({
		Win = 100,
		Draw = 70,
		Lose = 50,
		KeysPerBonusXP = 1,
		MaxBonusXP = 50,
	}),
	Levels = table.freeze({
		Base = 100,
		Step = 50,
		-- Round money +10% for every level above 1 (Ivan 2026-10-13).
		CoinBonusPerLevel = 0.1,
	}),
})
