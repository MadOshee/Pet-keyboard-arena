--!strict
-- Incubator and upgrade math (docs/design.md 4.3 "Яйца", 4.5). Pure Luau,
-- tested with Lune; the config is EggConfig.

export type Config = {
	HatchSeconds: { [string]: number },
	SpeedUpCoinsPerSecond: number,
	StartIncubators: number,
	MaxIncubators: number,
	IncubatorPrices: { number },
	PetSlotsStep: number,
	PetSlotsBasePrice: number,
}

export type EggLike = { Rarity: string }

local Incubation = {}

function Incubation.HatchSeconds(rarity: string, config: Config): number
	return config.HatchSeconds[rarity] or config.HatchSeconds.Common or 30
end

-- Coins to finish an egg now; 0 when it is already ready.
function Incubation.SpeedUpCost(hatchAt: number, now: number, config: Config): number
	local remaining = math.max(0, math.ceil(hatchAt - now))
	return remaining * config.SpeedUpCoinsPerSecond
end

-- Price of the next incubator, or nil at the maximum.
function Incubation.NextIncubatorPrice(owned: number, config: Config): number?
	if owned >= config.MaxIncubators then
		return nil
	end
	return config.IncubatorPrices[owned - config.StartIncubators + 1]
end

-- Price of the next +PetSlotsStep pet slots; doubles after each purchase.
function Incubation.NextPetSlotsPrice(
	capacity: number,
	startCapacity: number,
	config: Config
): number
	local bought = math.max(0, (capacity - startCapacity) // config.PetSlotsStep)
	return config.PetSlotsBasePrice * 2 ^ bought
end

-- Id of the rarest stored egg (ties by id for a stable choice), or nil.
function Incubation.RarestEgg(eggs: { [string]: EggLike }, rarities: { string }): string?
	local bestId: string? = nil
	local bestRank = 0
	for id, egg in eggs do
		local rank = table.find(rarities, egg.Rarity) or 0
		if rank > bestRank or (rank == bestRank and bestId ~= nil and id < (bestId :: string)) then
			bestId, bestRank = id, rank
		end
	end
	return bestId
end

return Incubation
