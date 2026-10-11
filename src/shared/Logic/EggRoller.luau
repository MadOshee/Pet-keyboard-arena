--!strict
-- Egg odds and rolls (docs/design.md 4.3 "Яйца", 13). Winning, a bigger share
-- of the team's painting and pet Luck all shift weight toward rarer eggs.
-- Configs and the random source are passed in, so this is pure Luau tested
-- with Lune. `rng` returns a number in [0, 1).

export type Rng = () -> number

export type Context = {
	Outcome: string, -- "Win" | "Draw" | "Lose"
	ContributionPct: number,
	Luck: number,
}

export type OddsConfig = {
	BaseWeights: { number },
	OutcomeBonus: { [string]: number },
	ContributionBonus: number,
}

export type Egg = {
	Theme: string,
	Rarity: string,
}

export type PetEntry = {
	Theme: string,
	Rarity: string,
}

local EggRoller = {}

-- The total upward shift: 0 for a losing AFK-level round without Luck.
function EggRoller.Bonus(context: Context, config: OddsConfig): number
	local outcomeBonus = config.OutcomeBonus[context.Outcome] or 0
	local contribution = math.clamp(context.ContributionPct, 0, 1)
	return outcomeBonus + contribution * config.ContributionBonus + math.max(context.Luck, 0)
end

-- One weight per rarity, lowest first.
function EggRoller.Weights(context: Context, config: OddsConfig): { number }
	local factor = 1 + EggRoller.Bonus(context, config)
	local weights = table.create(#config.BaseWeights)
	for rank, base in config.BaseWeights do
		weights[rank] = base * factor ^ (rank - 1)
	end
	return weights
end

-- Weights scaled to sum to 1, for showing odds to players.
function EggRoller.Odds(weights: { number }): { number }
	local total = 0
	for _, weight in weights do
		total += weight
	end
	local odds = table.create(#weights)
	for index, weight in weights do
		odds[index] = weight / total
	end
	return odds
end

function EggRoller.PickIndex(weights: { number }, rng: Rng): number
	local total = 0
	for _, weight in weights do
		total += weight
	end
	local roll = rng() * total
	for index, weight in weights do
		roll -= weight
		if roll < 0 then
			return index
		end
	end
	return #weights
end

-- One egg per theme, each with its own rarity roll.
function EggRoller.RollOffer(
	context: Context,
	themes: { string },
	rarities: { string },
	config: OddsConfig,
	rng: Rng
): { Egg }
	local weights = EggRoller.Weights(context, config)
	local eggs = table.create(#themes)
	for index, theme in themes do
		eggs[index] = { Theme = theme, Rarity = rarities[EggRoller.PickIndex(weights, rng)] }
	end
	return eggs
end

-- Pet kinds of a theme and rarity, sorted so rolls are reproducible.
function EggRoller.KindsFor(pets: { [string]: PetEntry }, theme: string, rarity: string): { string }
	local kinds = {}
	for kind, entry in pets do
		if entry.Theme == theme and entry.Rarity == rarity then
			table.insert(kinds, kind)
		end
	end
	table.sort(kinds)
	return kinds
end

-- A pet's rarity always equals its egg's rarity. Nil when the config has no
-- pet for that theme and rarity (the PetConfig test prevents that).
function EggRoller.RollPet(
	pets: { [string]: PetEntry },
	theme: string,
	rarity: string,
	rng: Rng
): string?
	local kinds = EggRoller.KindsFor(pets, theme, rarity)
	if #kinds == 0 then
		return nil
	end
	return kinds[math.min(math.floor(rng() * #kinds) + 1, #kinds)]
end

-- Slot of the rarest egg (the first one on ties), used for auto-pick.
function EggRoller.BestSlot(eggs: { Egg }, rarities: { string }): number
	local bestSlot, bestRank = 1, 0
	for slot, egg in eggs do
		local rank = table.find(rarities, egg.Rarity) or 0
		if rank > bestRank then
			bestSlot, bestRank = slot, rank
		end
	end
	return bestSlot
end

return EggRoller
