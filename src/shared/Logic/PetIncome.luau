--!strict
-- Coins from pets standing on the plot platforms (docs/design.md 4.3
-- "Участок", 4.5). A pet earns PetConfig.IncomePerSecond for its rarity
-- every second, offline too, but offline time counts at most
-- OfflineIncomeMaxSeconds. Pure Luau, tested with Lune.

export type Config = {
	IncomePerSecond: { [string]: number },
	OfflineIncomeMaxSeconds: number,
}

-- One platform as the income math sees it: a pet of Rarity, earning since
-- From (os.time) when it started inside the period, for example an egg that
-- hatched while its owner was away.
export type Earner = {
	Rarity: string,
	From: number?,
}

-- A platform entry of the profile (Types.Incubator).
export type SlotLike = {
	PetId: string?,
}

local PetIncome = {}

function PetIncome.Rate(rarity: string, config: Config): number
	return config.IncomePerSecond[rarity] or 0
end

-- Coins earned from `lastAt` to `now` (both os.time). The period is cut to
-- the last OfflineIncomeMaxSeconds, so a long absence pays a capped amount.
function PetIncome.Earned(earners: { Earner }, lastAt: number, now: number, config: Config): number
	local start = math.max(lastAt, now - config.OfflineIncomeMaxSeconds)
	local total = 0
	for _, earner in earners do
		local from = math.max(start, earner.From or start)
		if now > from then
			total += PetIncome.Rate(earner.Rarity, config) * (now - from)
		end
	end
	return math.floor(total)
end

-- Pet id -> platform index for the pets standing on platforms.
function PetIncome.PlacedPets(slots: { SlotLike }): { [string]: number }
	local placed = {}
	for index, slot in slots do
		if slot.PetId ~= nil then
			placed[slot.PetId :: string] = index
		end
	end
	return placed
end

return PetIncome
