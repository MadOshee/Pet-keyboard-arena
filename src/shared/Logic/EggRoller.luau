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

export type OfferConfig = OddsConfig & {
	EggsPerOffer: number,
	EggsByOutcome: { [string]: number }?,
	ThemeWeights: { [string]: number },
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

-- How many eggs an offer after this round outcome holds.
function EggRoller.OfferSize(context: Context, config: OfferConfig): number
	local byOutcome = config.EggsByOutcome
	return (if byOutcome then byOutcome[context.Outcome] else nil) or config.EggsPerOffer
end

-- OfferSize eggs. Each rolls its theme by ThemeWeights (rarer eggs come
-- up less often, repeats are fine) and its rarity by Weights. `themes` gives
-- the theme order, cheapest first; the offer is sorted by it.
function EggRoller.RollOffer(
	context: Context,
	themes: { string },
	rarities: { string },
	config: OfferConfig,
	rng: Rng
): { Egg }
	local weights = EggRoller.Weights(context, config)
	local themeWeights = table.create(#themes)
	for index, theme in themes do
		themeWeights[index] = config.ThemeWeights[theme] or 0
	end
	local size = EggRoller.OfferSize(context, config)
	local picks = table.create(size)
	for index = 1, size do
		picks[index] = {
			Theme = EggRoller.PickIndex(themeWeights, rng),
			Rarity = EggRoller.PickIndex(weights, rng),
		}
	end
	table.sort(picks, function(a, b)
		if a.Theme ~= b.Theme then
			return a.Theme < b.Theme
		end
		return a.Rarity < b.Rarity
	end)
	local eggs = table.create(#picks)
	for index, pick in picks do
		eggs[index] = { Theme = themes[pick.Theme], Rarity = rarities[pick.Rarity] }
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

-- The pets an egg of this theme and rarity can hatch. Small eggs have no
-- pet of some rarities: then the nearest rarity in `rarities` order, the
-- lower one on a tie. Empty when the theme has no pets at all.
function EggRoller.HatchKinds(
	pets: { [string]: PetEntry },
	theme: string,
	rarity: string,
	rarities: { string }?
): { string }
	local kinds = EggRoller.KindsFor(pets, theme, rarity)
	local order: { string } = rarities or {}
	local rank = table.find(order, rarity)
	if #kinds > 0 or rank == nil then
		return kinds
	end
	local start = rank :: number
	for step = 1, #order do
		for _, near in { order[start - step], order[start + step] } :: { string } do
			kinds = EggRoller.KindsFor(pets, theme, near)
			if #kinds > 0 then
				return kinds
			end
		end
	end
	return kinds
end

-- One of HatchKinds, all equally likely. Nil when the theme has no pets.
function EggRoller.RollPet(
	pets: { [string]: PetEntry },
	theme: string,
	rarity: string,
	rng: Rng,
	rarities: { string }?
): string?
	local kinds = EggRoller.HatchKinds(pets, theme, rarity, rarities)
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
