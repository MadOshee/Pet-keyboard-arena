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
	assert(result.Waiting[1] == 13, "the last in the queue waits")
end

function tests.threePartiesOfThreeAllPlay()
	local groups = {
		{ Members = { 1, 2, 3 }, Power = 0 },
		{ Members = { 4, 5, 6 }, Power = 0 },
		{ Members = { 7, 8, 9 }, Power = 0 },
	}
	local result = TeamBalancer.Assign(groups, LIMITS)
	assert(#result.Waiting == 0, `{#result.Waiting} waiting`)
	assert(result.TeamSize == 6)
	assert(#result.Red + #result.Blue == 9)
end

function tests.keepsHeadCountEven()
	-- A strong solo must not end up alone against three players.
	local result = TeamBalancer.Assign({ solo(1, 3), solo(2, 0), solo(3, 0), solo(4, 0) }, LIMITS)
	assert(#result.Red == 2 and #result.Blue == 2)
end

function tests.weakSolosGoAgainstStrongParty()
	local party = { Members = { 10, 11 }, Power = 2 }
	local result = TeamBalancer.Assign(
		{ party, solo(1, 0.1), solo(2, 0.1), solo(3, 1.5), solo(4, 0.1) },
		LIMITS
	)
	local partyRed = contains(result.Red, 10)
	assert(contains(result.Red, 3) ~= partyRed, "strongest solo joined the strong party")
end

function tests.oddCountGivesExtraHumanToWeakerSide()
	-- 5 players: the side with 3 humans should be the weaker humans, since
	-- the other side gets a bot.
	local result =
		TeamBalancer.Assign({ solo(1, 1), solo(2, 1), solo(3, 0), solo(4, 0), solo(5, 0) }, LIMITS)
	assert(math.abs(result.RedStrength - result.BlueStrength) < 1, "teams too far apart")
	local three = if #result.Red == 3 then result.Red else result.Blue
	assert(
		not (contains(three, 1) and contains(three, 2)),
		"both strong players on the bigger side"
	)
end

function tests.strengthCountsBots()
	local result = TeamBalancer.Assign(
		{ solo(1, 0), solo(2, 0) },
		{ MinTeamSize = 4, MaxTeamSize = 6, BotStrength = 0.5 }
	)
	assert(result.RedBots == 3 and result.BlueBots == 3)
	assert(math.abs(result.RedStrength - 2.5) < 1e-6, `{result.RedStrength}`)
end

function tests.noPlayersMeansOnlyBots()
	local result = TeamBalancer.Assign({}, LIMITS)
	assert(result.TeamSize == 4 and result.RedBots == 4 and result.BlueBots == 4)
end

return tests
