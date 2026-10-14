local Matchmaker = require("../src/shared/Logic/Matchmaker")
local TeamBalancer = require("../src/shared/Logic/TeamBalancer")

local CONFIG = { MaxHumans = 12, WaitSeconds = 15, MinTeamSize = 4, MaxTeamSize = 6 }

local nextId = 0
local function ticket(members: { number }, joinedAt: number, hub: string?)
	nextId += 1
	return {
		Id = `t{nextId}`,
		Members = members,
		Power = 0,
		HubPlaceId = 100,
		HubJobId = hub or "hubA",
		JoinedAt = joinedAt,
	}
end

local function pick(tickets, now)
	return Matchmaker.Pick(tickets, now, CONFIG, TeamBalancer.Assign)
end

local tests = {}

function tests.waitsBeforeStartingASmallMatch()
	assert(pick({ ticket({ 1 }, 100) }, 105) == nil)
	local chosen = pick({ ticket({ 1 }, 100) }, 115)
	assert(chosen and #chosen == 1, "a lone player plays with bots after the wait")
end

function tests.nothingQueuedNoMatch()
	assert(pick({}, 1000) == nil)
end

function tests.fullMatchStartsAtOnce()
	local tickets = {}
	for userId = 1, 12 do
		table.insert(
			tickets,
			ticket({ userId }, 100 + userId, if userId % 2 == 0 then "hubA" else "hubB")
		)
	end
	local chosen = pick(tickets, 113)
	assert(chosen and #chosen == 12)
end

function tests.mixesServersAndKeepsQueueOrder()
	local tickets = {
		ticket({ 20 }, 130, "hubC"),
		ticket({ 1, 2, 3 }, 100, "hubA"),
		ticket({ 10, 11 }, 110, "hubB"),
	}
	local chosen = pick(tickets, 116)
	assert(chosen and #chosen == 3)
	assert(chosen[1].Members[1] == 1, "oldest first")
end

function tests.overflowWaitsForNextMatch()
	local tickets = {}
	for index = 1, 4 do
		table.insert(tickets, ticket({ index * 10, index * 10 + 1, index * 10 + 2 }, 100 + index))
	end
	table.insert(tickets, ticket({ 99 }, 200))
	local chosen = pick(tickets, 120)
	assert(chosen and #chosen == 4, "four parties of three fill 6v6")
	for _, chosenTicket in chosen do
		assert(chosenTicket.Members[1] ~= 99)
	end
end

function tests.smallerHubCapStillFillsWithSolos()
	local config = table.clone(CONFIG)
	config.MaxHumans = 6
	local tickets = { ticket({ 1, 2, 3 }, 100), ticket({ 4, 5, 6 }, 101), ticket({ 7 }, 102) }
	local chosen = Matchmaker.Pick(tickets, 101, config, TeamBalancer.Assign)
	assert(chosen and #chosen == 2, "full at 6 humans")
end

function tests.lockGoesToOneServer()
	local lock = Matchmaker.TakeLock(nil, "A", 10, 10)
	assert(lock and lock.JobId == "A")
	assert(Matchmaker.TakeLock(lock, "B", 15, 10) == nil, "B must not steal a live lock")
	local renewed = Matchmaker.TakeLock(lock, "A", 15, 10)
	assert(renewed and renewed.ExpiresAt == 25)
	local taken = Matchmaker.TakeLock(lock, "B", 21, 10)
	assert(taken and taken.JobId == "B", "an expired lock is free")
end

function tests.rosterGroupsAndArrivals()
	local roster = Matchmaker.Roster({ ticket({ 1, 2 }, 1, "hubA"), ticket({ 3 }, 2, "hubB") }, 5)
	assert(not Matchmaker.AllArrived(roster, { [1] = true, [3] = true }))
	assert(Matchmaker.AllArrived(roster, { [1] = true, [2] = true, [3] = true }))
	local groups = Matchmaker.PresentGroups(roster, { [1] = true, [3] = true })
	assert(#groups == 2 and #groups[1] == 1 and groups[2][1] == 3)
end

function tests.playersReturnToTheirOwnHub()
	local roster = Matchmaker.Roster({ ticket({ 1, 2 }, 1, "hubA"), ticket({ 3 }, 2, "hubB") }, 5)
	local groups = Matchmaker.ReturnGroups(roster, { 1, 3, 2, 50 }, 777)
	assert(#groups == 3)
	assert(groups[1].HubJobId == "hubA" and #groups[1].UserIds == 2)
	assert(groups[2].HubJobId == "hubB")
	assert(groups[3].HubPlaceId == 777 and groups[3].HubJobId == "", "stranger goes to any hub")
end

return tests
