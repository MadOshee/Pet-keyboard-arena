local Reward = require("../src/shared/Logic/Reward")

local CONFIG = {
	Win = 40,
	Draw = 40,
	Lose = 20,
	KeysPerBonusCoin = 2,
	MaxBonusCoins = 30,
	MaxMultiplier = 2,
}

local tests = {}

function tests.decidesWinner()
	assert(Reward.DecideWinner(10, 5) == "Red")
	assert(Reward.DecideWinner(5, 10) == "Blue")
	assert(Reward.DecideWinner(7, 7) == "Draw")
end

function tests.outcomeForEachTeam()
	assert(Reward.OutcomeFor("Red", "Red") == "Win")
	assert(Reward.OutcomeFor("Blue", "Red") == "Lose")
	assert(Reward.OutcomeFor("Blue", "Draw") == "Draw")
end

function tests.coinsAddKeyBonus()
	assert(Reward.Coins("Win", 0, 1, CONFIG) == 40)
	assert(Reward.Coins("Lose", 21, 1, CONFIG) == 30)
	assert(Reward.Coins("Draw", 5, 1, CONFIG) == 42)
end

function tests.keyBonusIsCapped()
	assert(Reward.Coins("Win", 1000, 1, CONFIG) == 70)
end

function tests.multiplierIsCappedAndNeverBelowOne()
	assert(Reward.Coins("Win", 0, 5, CONFIG) == 80)
	assert(Reward.Coins("Win", 0, 0.1, CONFIG) == 40)
	assert(Reward.Coins("Win", 0, 1.5, CONFIG) == 60)
end

function tests.contributionIsShareOfBest()
	assert(Reward.ContributionPct(5, 10) == 0.5)
	assert(Reward.ContributionPct(10, 10) == 1)
	assert(Reward.ContributionPct(0, 0) == 0)
	assert(Reward.ContributionPct(12, 10) == 1)
end

return tests
