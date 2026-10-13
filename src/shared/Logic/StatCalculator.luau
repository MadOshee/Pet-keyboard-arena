--!strict
-- Sums equipped pet buffs and applies the caps (docs/design.md 4.4, D5).
-- Every pet kind lists its own buffs (PetConfig.Pets[kind].Buffs); unknown
-- kinds (removed from the config) give nothing. Pure Luau, tested with
-- Lune; the config is PetConfig.

export type Stats = {
	Speed: number,
	PaintRadius: number,
	Luck: number,
	Power: number,
	Coins: number,
}

export type PetLike = {
	Kind: string,
	Rarity: string,
}

export type Config = {
	Pets: { [string]: { Buffs: { [string]: number } } },
	Caps: { [string]: number },
}

local StatCalculator = {}

function StatCalculator.Zero(): Stats
	return { Speed = 0, PaintRadius = 0, Luck = 0, Power = 0, Coins = 0 }
end

-- Stat -> fraction this pet adds when equipped; empty for unknown kinds.
function StatCalculator.PetBuffs(pet: PetLike, config: Config): { [string]: number }
	local kind = config.Pets[pet.Kind]
	return if kind then kind.Buffs else {}
end

function StatCalculator.Totals(pets: { PetLike }, config: Config): Stats
	local sums: { [string]: number } = StatCalculator.Zero() :: any
	for _, pet in pets do
		for stat, value in StatCalculator.PetBuffs(pet, config) do
			if sums[stat] then
				sums[stat] += value
			end
		end
	end
	local function capped(stat: string): number
		return math.min(sums[stat], config.Caps[stat] or 0)
	end
	return {
		Speed = capped("Speed"),
		PaintRadius = capped("PaintRadius"),
		Luck = capped("Luck"),
		Power = capped("Power"),
		Coins = capped("Coins"),
	}
end

-- Team-balance weight: only bonuses that change the round itself count.
function StatCalculator.TeamWeight(stats: Stats): number
	return stats.Speed + stats.PaintRadius + stats.Power
end

return StatCalculator
