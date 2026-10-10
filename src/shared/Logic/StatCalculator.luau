--!strict
-- Sums equipped pet bonuses and applies the caps (docs/design.md 4.4, D5).
-- Unknown pet kinds (removed from the config) give nothing. Pure Luau,
-- tested with Lune; the config is PetConfig.

export type Stats = {
	Speed: number,
	PaintRadius: number,
	Luck: number,
	Coins: number,
}

export type PetLike = {
	Kind: string,
	Rarity: string,
}

export type Config = {
	Pets: { [string]: { Theme: string } },
	Themes: { [string]: { Stat: string } },
	Bonus: { [string]: { [string]: number } },
	Caps: { [string]: number },
}

local StatCalculator = {}

function StatCalculator.Zero(): Stats
	return { Speed = 0, PaintRadius = 0, Luck = 0, Coins = 0 }
end

-- The stat a pet boosts and by how much; nil for unknown kinds.
function StatCalculator.PetBonus(pet: PetLike, config: Config): (string?, number)
	local kind = config.Pets[pet.Kind]
	local theme = kind and config.Themes[kind.Theme]
	if theme == nil then
		return nil, 0
	end
	local byRarity = config.Bonus[theme.Stat]
	return theme.Stat, (byRarity and byRarity[pet.Rarity]) or 0
end

function StatCalculator.Totals(pets: { PetLike }, config: Config): Stats
	local sums: { [string]: number } = { Speed = 0, PaintRadius = 0, Luck = 0, Coins = 0 }
	for _, pet in pets do
		local stat, value = StatCalculator.PetBonus(pet, config)
		if stat and sums[stat] then
			sums[stat] += value
		end
	end
	return {
		Speed = math.min(sums.Speed, config.Caps.Speed or 0),
		PaintRadius = math.min(sums.PaintRadius, config.Caps.PaintRadius or 0),
		Luck = math.min(sums.Luck, config.Caps.Luck or 0),
		Coins = math.min(sums.Coins, config.Caps.Coins or 0),
	}
end

-- Team-balance weight: only bonuses that change the round itself count.
function StatCalculator.Power(stats: Stats): number
	return stats.Speed + stats.PaintRadius
end

return StatCalculator
