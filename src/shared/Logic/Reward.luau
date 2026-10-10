--!strict
-- Round outcome and coin formulas (docs/design.md 4.5). Pure Luau, tested
-- with Lune. The config table is RoundConfig.Coins.

export type CoinConfig = {
	Win: number,
	Draw: number,
	Lose: number,
	KeysPerBonusCoin: number,
	MaxBonusCoins: number,
	MaxMultiplier: number,
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

return Reward
