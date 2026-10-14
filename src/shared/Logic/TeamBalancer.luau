--!strict
-- Splits match participants into two teams (docs/design.md 4.3 "Команды").
-- Groups (parties) are never split. Every possible split is tried (there
-- are at most a dozen groups) and the best one wins: first the closest
-- head count, then the closest team strength. A player's strength is 1 plus
-- their weight (pet bonuses and level, StatsService:GetTeamWeight); a bot
-- that fills an empty seat counts as BotStrength. Team size is half the
-- players, at least MinTeamSize and at most MaxTeamSize; it grows when the
-- parties do not fit otherwise. Pure Luau, tested with Lune.

export type Group = {
	Members: { number }, -- user ids
	Power: number, -- sum of the members' weights
}

export type Assignment = {
	TeamSize: number,
	Red: { number },
	Blue: { number },
	RedBots: number,
	BlueBots: number,
	RedStrength: number,
	BlueStrength: number,
	Waiting: { number }, -- user ids that did not fit this match
}

export type Limits = {
	MinTeamSize: number,
	MaxTeamSize: number,
	BotStrength: number?,
}

-- More groups than this are not searched exhaustively (2^n splits).
local MAX_SEARCH_GROUPS = 16
local DEFAULT_BOT_STRENGTH = 0.8

local TeamBalancer = {}

function TeamBalancer.TeamSize(humanCount: number, limits: Limits): number
	return math.clamp(math.ceil(humanCount / 2), limits.MinTeamSize, limits.MaxTeamSize)
end

type Split = {
	Mask: number,
	TeamSize: number,
	RedStrength: number,
	BlueStrength: number,
}

-- Best split of `groups` for one team size, or nil if the groups do not fit.
local function bestSplit(groups: { Group }, teamSize: number, botStrength: number): Split?
	local count = #groups
	local best: Split? = nil
	local bestHeads, bestGap = math.huge, math.huge
	-- Group 1 always goes to Red: the mirrored split is the same match.
	for mask = 0, 2 ^ (count - 1) - 1 do
		local full = mask * 2 + 1
		local redHeads, blueHeads, redPower, bluePower = 0, 0, 0, 0
		for index, group in groups do
			local size = #group.Members
			if bit32.btest(full, 2 ^ (index - 1)) then
				redHeads += size
				redPower += size + group.Power
			else
				blueHeads += size
				bluePower += size + group.Power
			end
		end
		if redHeads <= teamSize and blueHeads <= teamSize then
			local redStrength = redPower + (teamSize - redHeads) * botStrength
			local blueStrength = bluePower + (teamSize - blueHeads) * botStrength
			local heads = math.abs(redHeads - blueHeads)
			local gap = math.abs(redStrength - blueStrength)
			if heads < bestHeads or (heads == bestHeads and gap < bestGap - 1e-9) then
				bestHeads, bestGap = heads, gap
				best = {
					Mask = full,
					TeamSize = teamSize,
					RedStrength = redStrength,
					BlueStrength = blueStrength,
				}
			end
		end
	end
	return best
end

local function humansIn(groups: { Group }): number
	local count = 0
	for _, group in groups do
		count += #group.Members
	end
	return count
end

-- `groups` in queue order: when not everyone fits, the last ones wait.
function TeamBalancer.Assign(groups: { Group }, limits: Limits): Assignment
	local botStrength = limits.BotStrength or DEFAULT_BOT_STRENGTH
	local playing: { Group } = {}
	local waiting: { Group } = {}
	local seats = limits.MaxTeamSize * 2
	local taken = 0
	for _, group in groups do
		local size = #group.Members
		if size > 0 and size <= limits.MaxTeamSize and taken + size <= seats then
			if #playing < MAX_SEARCH_GROUPS then
				table.insert(playing, group)
				taken += size
				continue
			end
		end
		table.insert(waiting, group)
	end

	local split: Split? = nil
	while #playing > 0 do
		local size = TeamBalancer.TeamSize(humansIn(playing), limits)
		while split == nil and size <= limits.MaxTeamSize do
			split = bestSplit(playing, size, botStrength)
			size += 1
		end
		if split then
			break
		end
		-- The parties cannot share two teams: the newest group waits.
		table.insert(waiting, 1, table.remove(playing) :: Group)
	end

	local teamSize = if split then split.TeamSize else limits.MinTeamSize
	local result: Assignment = {
		TeamSize = teamSize,
		Red = {},
		Blue = {},
		RedBots = 0,
		BlueBots = 0,
		RedStrength = if split then split.RedStrength else teamSize * botStrength,
		BlueStrength = if split then split.BlueStrength else teamSize * botStrength,
		Waiting = {},
	}
	for index, group in playing do
		local toRed = split ~= nil and bit32.btest(split.Mask, 2 ^ (index - 1))
		local team = if toRed then result.Red else result.Blue
		for _, userId in group.Members do
			table.insert(team, userId)
		end
	end
	for _, group in waiting do
		for _, userId in group.Members do
			table.insert(result.Waiting, userId)
		end
	end
	result.RedBots = teamSize - #result.Red
	result.BlueBots = teamSize - #result.Blue
	return result
end

return TeamBalancer
