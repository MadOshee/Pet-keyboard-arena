--!strict
-- Splits round participants into two teams (docs/design.md 4.3 "Команды").
-- Groups (parties) are never split; teams are balanced by head count first,
-- then by total power (sum of in-round pet bonuses). Missing seats up to
-- the team size are reported as bot slots. Pure Luau, tested with Lune.

export type Group = {
	Members: { number }, -- user ids
	Power: number,
}

export type Assignment = {
	TeamSize: number,
	Red: { number },
	Blue: { number },
	RedBots: number,
	BlueBots: number,
	Waiting: { number }, -- user ids that did not fit this round
}

export type Limits = {
	MinTeamSize: number,
	MaxTeamSize: number,
}

local TeamBalancer = {}

function TeamBalancer.TeamSize(humanCount: number, limits: Limits): number
	return math.clamp(math.ceil(humanCount / 2), limits.MinTeamSize, limits.MaxTeamSize)
end

function TeamBalancer.Assign(groups: { Group }, limits: Limits): Assignment
	local humanCount = 0
	for _, group in groups do
		humanCount += #group.Members
	end
	local teamSize = TeamBalancer.TeamSize(humanCount, limits)

	-- Place big groups first so they still fit, strongest first within a size.
	local ordered = table.clone(groups)
	table.sort(ordered, function(a, b)
		if #a.Members ~= #b.Members then
			return #a.Members > #b.Members
		end
		return a.Power > b.Power
	end)

	local result: Assignment = {
		TeamSize = teamSize,
		Red = {},
		Blue = {},
		RedBots = 0,
		BlueBots = 0,
		Waiting = {},
	}
	local redPower, bluePower = 0, 0

	for _, group in ordered do
		local size = #group.Members
		local redFits = #result.Red + size <= teamSize
		local blueFits = #result.Blue + size <= teamSize

		local toRed: boolean
		if redFits and blueFits then
			if #result.Red ~= #result.Blue then
				toRed = #result.Red < #result.Blue
			else
				toRed = redPower <= bluePower
			end
		elseif redFits or blueFits then
			toRed = redFits
		else
			for _, userId in group.Members do
				table.insert(result.Waiting, userId)
			end
			continue
		end

		local team = if toRed then result.Red else result.Blue
		for _, userId in group.Members do
			table.insert(team, userId)
		end
		if toRed then
			redPower += group.Power
		else
			bluePower += group.Power
		end
	end

	result.RedBots = teamSize - #result.Red
	result.BlueBots = teamSize - #result.Blue
	return result
end

return TeamBalancer
