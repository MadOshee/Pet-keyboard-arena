--!strict
-- Round outcome, coin and XP formulas (docs/design.md 4.5). Pure Luau, tested
-- with Lune. The config table is RoundConfig.Coins.

export type CoinConfig = {
	Win: number,
	Draw: number,
	Lose: number,
	KeysPerBonusCoin: number,
	MaxBonusCoins: number,
	MaxMultiplier: number,
}

export type XPConfig = {
	Win: number,
	Draw: number,
	Lose: number,
	KeysPerBonusXP: number,
	MaxBonusXP: number,
}

local Reward = {}

function Reward.DecideWinner(redScore: number, blueScore: number): "Red" | "Blue" | "Draw"
	if redScore > blueScore then
		return "Red"
	elseif blueScore > redScore then
		return "Blue"
	end
	return "Draw"
end

function Reward.OutcomeFor(
	team: "Red" | "Blue",
	winner: "Red" | "Blue" | "Draw"
): "Win" | "Lose" | "Draw"
	if winner == "Draw" then
		return "Draw"
	end
	return if winner == team then "Win" else "Lose"
end

-- `multiplier` is 1 + coin bonuses (pets, game passes); it is capped here.
function Reward.Coins(
	outcome: "Win" | "Lose" | "Draw",
	keysPainted: number,
	multiplier: number,
	config: CoinConfig
): number
	local base = if outcome == "Win"
		then config.Win
		elseif outcome == "Draw" then config.Draw
		else config.Lose
	local bonus = math.min(math.floor(keysPainted / config.KeysPerBonusCoin), config.MaxBonusCoins)
	local cappedMultiplier = math.clamp(multiplier, 1, config.MaxMultiplier)
	return math.floor((base + bonus) * cappedMultiplier)
end

-- XP for a round: by outcome plus a capped bonus for painted keys.
function Reward.XP(outcome: "Win" | "Lose" | "Draw", keysPainted: number, config: XPConfig): number
	local base = if outcome == "Win"
		then config.Win
		elseif outcome == "Draw" then config.Draw
		else config.Lose
	return base + math.min(math.floor(keysPainted / config.KeysPerBonusXP), config.MaxBonusXP)
end

-- A player's share of the best painter on their team, 0..1.
function Reward.ContributionPct(keysPainted: number, bestOnTeam: number): number
	if bestOnTeam <= 0 then
		return 0
	end
	return math.clamp(keysPainted / bestOnTeam, 0, 1)
end

return Reward
