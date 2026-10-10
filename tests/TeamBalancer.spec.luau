local TeamBalancer = require("../src/shared/Logic/TeamBalancer")

local LIMITS = { MinTeamSize = 4, MaxTeamSize = 6 }

local function solo(userId: number, power: number?)
	return { Members = { userId }, Power = power or 0 }
end

local function contains(list: { number }, value: number): boolean
	return table.find(list, value) ~= nil
end

local tests = {}

function tests.teamSizeStaysWithinLimits()
	assert(TeamBalancer.TeamSize(1, LIMITS) == 4)
	assert(TeamBalancer.TeamSize(9, LIMITS) == 5)
	assert(TeamBalancer.TeamSize(12, LIMITS) == 6)
	assert(TeamBalancer.TeamSize(20, LIMITS) == 6)
end

function tests.fillsMissingSeatsWithBots()
	local result = TeamBalancer.Assign({ solo(1), solo(2), solo(3) }, LIMITS)
	assert(result.TeamSize == 4)
	assert(#result.Red + #result.Blue == 3)
	assert(result.RedBots + result.BlueBots == 5, `bots {result.RedBots}+{result.BlueBots}`)
	assert(math.abs(#result.Red - #result.Blue) <= 1)
end

function tests.keepsPartiesTogether()
	local party = { Members = { 10, 11, 12 }, Power = 0 }
	local result = TeamBalancer.Assign({ solo(1), party, solo(2), solo(3) }, LIMITS)
	local inRed = contains(result.Red, 10)
	for _, userId in party.Members do
		assert(contains(result.Red, userId) == inRed, "party was split")
		assert(
			contains(result.Red, userId) or contains(result.Blue, userId),
			"party member missing"
		)
	end
end

function tests.balancesPowerBetweenEqualTeams()
	local result =
		TeamBalancer.Assign({ solo(1, 100), solo(2, 90), solo(3, 10), solo(4, 0) }, LIMITS)
	assert(
		contains(result.Red, 1) ~= contains(result.Red, 2),
		"two strongest players ended up together"
	)
end

function tests.putsOverflowInWaiting()
	local groups = {}
	for userId = 1, 13 do
		table.insert(groups, solo(userId))
	end
	local result = TeamBalancer.Assign(groups, LIMITS)
	assert(#result.Red == 6 and #result.Blue == 6)
	assert(#result.Waiting == 1)
	assert(result.RedBots == 0 and result.BlueBots == 0)
end

return tests
