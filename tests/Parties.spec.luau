local Parties = require("../src/shared/Logic/Parties")

local TTL = 30

local function members(state, userId: number): string
	local list = Parties.MembersOf(state, userId)
	table.sort(list)
	return table.concat(list, ",")
end

local tests = {}

function tests.inviteAndAcceptFormsParty()
	local state = Parties.new(3)
	assert(Parties.Invite(state, 1, 2, 0, TTL))
	assert(Parties.Respond(state, 2, 1, true, 5))
	assert(members(state, 1) == "1,2")
	assert((Parties.Get(state, 2) :: any).Leader == 1)
end

function tests.declineRemovesInvite()
	local state = Parties.new(3)
	Parties.Invite(state, 1, 2, 0, TTL)
	assert(Parties.Respond(state, 2, 1, false, 1))
	local ok, reason = Parties.Respond(state, 2, 1, true, 2)
	assert(not ok and reason == "NoInvite")
	assert(members(state, 2) == "2")
end

function tests.invitesExpire()
	local state = Parties.new(3)
	Parties.Invite(state, 1, 2, 0, TTL)
	local ok, reason = Parties.Respond(state, 2, 1, true, TTL + 1)
	assert(not ok and reason == "NoInvite")
end

function tests.partyIsCapped()
	local state = Parties.new(3)
	for target = 2, 3 do
		Parties.Invite(state, 1, target, 0, TTL)
		Parties.Respond(state, target, 1, true, 1)
	end
	local ok, reason = Parties.Invite(state, 1, 4, 2, TTL)
	assert(not ok and reason == "PartyFull")
	-- An invite sent before the party filled up cannot overfill it.
	local state2 = Parties.new(2)
	Parties.Invite(state2, 1, 2, 0, TTL)
	Parties.Invite(state2, 1, 3, 0, TTL)
	Parties.Respond(state2, 2, 1, true, 1)
	local ok2, reason2 = Parties.Respond(state2, 3, 1, true, 1)
	assert(not ok2 and reason2 == "PartyFull")
end

function tests.cannotInviteSelfOrMember()
	local state = Parties.new(3)
	assert(select(2, Parties.Invite(state, 1, 1, 0, TTL)) == "Self")
	Parties.Invite(state, 1, 2, 0, TTL)
	Parties.Respond(state, 2, 1, true, 1)
	assert(select(2, Parties.Invite(state, 2, 1, 2, TTL)) == "AlreadyTogether")
end

function tests.leaderLeavingPromotesNext()
	local state = Parties.new(3)
	for target = 2, 3 do
		Parties.Invite(state, 1, target, 0, TTL)
		Parties.Respond(state, target, 1, true, 1)
	end
	Parties.Leave(state, 1)
	assert(members(state, 2) == "2,3")
	assert((Parties.Get(state, 2) :: any).Leader == 2)
	assert(members(state, 1) == "1")
end

function tests.partyOfOneDissolves()
	local state = Parties.new(3)
	Parties.Invite(state, 1, 2, 0, TTL)
	Parties.Respond(state, 2, 1, true, 1)
	Parties.Leave(state, 2)
	assert(Parties.Get(state, 1) == nil)
	assert(members(state, 1) == "1")
end

function tests.joiningAnotherPartyLeavesTheOld()
	local state = Parties.new(3)
	Parties.Invite(state, 1, 2, 0, TTL)
	Parties.Respond(state, 2, 1, true, 1)
	Parties.Invite(state, 3, 2, 2, TTL)
	Parties.Respond(state, 2, 3, true, 3)
	assert(members(state, 2) == "2,3")
	assert(members(state, 1) == "1")
end

function tests.removeDropsInvites()
	local state = Parties.new(3)
	Parties.Invite(state, 1, 2, 0, TTL)
	Parties.Invite(state, 2, 3, 0, TTL)
	Parties.Remove(state, 2)
	assert(#Parties.InvitesFor(state, 2, 1) == 0)
	assert(#Parties.InvitesFor(state, 3, 1) == 0)
end

function tests.expireCleansUp()
	local state = Parties.new(3)
	Parties.Invite(state, 1, 2, 0, TTL)
	Parties.Expire(state, TTL)
	assert(state.Invites[2] == nil)
end

return tests
