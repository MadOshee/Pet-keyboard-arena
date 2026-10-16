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
	-- The dark "RED TEAM WINS!" screen after a match, then back to the hub
	-- (Ivan 2026-10-16).
	ResultsSeconds = 3,

	-- One ready player is enough: bots fill both teams up to the team size
	-- (MinTeamSize at least, D6).
	MinParticipants = 1,
	MinTeamSize = 4,
	MaxTeamSize = 6,

	-- Team balance (Logic/TeamBalancer, Ivan 2026-10-14): a new player
	-- counts as 1, plus their pet bonuses (Speed + Area + Power, 0.25 =
	-- +25%), plus LevelWeight for each level above 1 (a level gives +1% to
	-- each of those three stats). A bot in an empty seat counts as
	-- BotStrength: no pets and a simple brain.
	LevelWeight = 0.03,
	BotStrength = 0.8,

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
		-- +1% to every stat (Speed, Area, Luck, Power, Money) for each level
		-- above 1 (Ivan 2026-10-14; was +10% round money only).
		BonusPerLevel = 0.01,
	}),
})
