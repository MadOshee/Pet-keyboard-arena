--!strict
-- Player-facing text in one place, ready for a LocalizationTable later.

return table.freeze({
	Phase = table.freeze({
		Intermission = "Next round",
		Countdown = "Get ready",
		Playing = "Paint!",
		Results = "Results",
	}),
	Ready = "READY",
	NotReady = "PLAY",
	YourTeam = "Your team: %s",
	TeamName = table.freeze({ Red = "RED", Blue = "BLUE" }),
	Outcome = table.freeze({ Win = "Victory!", Lose = "Defeat", Draw = "Draw" }),
	Coins = "%d coins",
	CoinsGained = "+%d coins",
	NoReward = "Paint at least %d keys to earn a reward",
	Winner = table.freeze({ Red = "RED wins!", Blue = "BLUE wins!", Draw = "Draw!" }),
})
