--!strict
-- Party rules (docs/design.md 4.3 "Группы"): up to MaxSize players, one
-- leader, invites that expire. When the leader leaves, the next member
-- leads; a party of one dissolves. Players are user ids, so this is pure
-- Luau tested with Lune; PartyService wraps it for real players.

export type Party = {
	Id: number,
	Leader: number,
	Members: { number },
}

export type State = {
	MaxSize: number,
	NextId: number,
	Parties: { [number]: Party },
	PartyOf: { [number]: number }, -- user id -> party id
	Invites: { [number]: { [number]: number } }, -- target -> inviter -> expires at
}

export type InviteError = "Self" | "AlreadyTogether" | "PartyFull" | "AlreadyInvited"
export type RespondError = "NoInvite" | "PartyFull"

local Parties = {}

function Parties.new(maxSize: number): State
	return { MaxSize = maxSize, NextId = 1, Parties = {}, PartyOf = {}, Invites = {} }
end

function Parties.Get(state: State, userId: number): Party?
	local partyId = state.PartyOf[userId]
	return if partyId then state.Parties[partyId] else nil
end

-- Everyone in the user's party, or just the user when solo.
function Parties.MembersOf(state: State, userId: number): { number }
	local party = Parties.Get(state, userId)
	return if party then table.clone(party.Members) else { userId }
end

local function sizeOf(state: State, userId: number): number
	local party = Parties.Get(state, userId)
	return if party then #party.Members else 1
end

function Parties.Invite(
	state: State,
	from: number,
	to: number,
	now: number,
	ttl: number
): (boolean, InviteError?)
	if from == to then
		return false, "Self"
	end
	local fromParty = state.PartyOf[from]
	if fromParty ~= nil and fromParty == state.PartyOf[to] then
		return false, "AlreadyTogether"
	end
	if sizeOf(state, from) >= state.MaxSize then
		return false, "PartyFull"
	end
	local pending = state.Invites[to]
	if pending and (pending[from] or 0) > now then
		return false, "AlreadyInvited"
	end
	state.Invites[to] = pending or {}
	state.Invites[to][from] = now + ttl
	return true, nil
end

-- Removes `userId` from their party. Returns the party they left, if any.
function Parties.Leave(state: State, userId: number): Party?
	local party = Parties.Get(state, userId)
	if party == nil then
		return nil
	end
	local current = party :: Party
	local index = table.find(current.Members, userId)
	if index then
		table.remove(current.Members, index)
	end
	state.PartyOf[userId] = nil
	if #current.Members <= 1 then
		for _, member in current.Members do
			state.PartyOf[member] = nil
		end
		table.clear(current.Members)
		state.Parties[current.Id] = nil
	elseif current.Leader == userId then
		current.Leader = current.Members[1]
	end
	return current
end

function Parties.Respond(
	state: State,
	target: number,
	inviter: number,
	accept: boolean,
	now: number
): (boolean, RespondError?)
	local pending = state.Invites[target]
	local expires = pending and pending[inviter]
	if pending == nil or expires == nil or expires <= now then
		return false, "NoInvite"
	end
	pending[inviter] = nil
	if not accept then
		return true, nil
	end
	if sizeOf(state, inviter) >= state.MaxSize then
		return false, "PartyFull"
	end

	Parties.Leave(state, target)
	local party = Parties.Get(state, inviter)
	if party == nil then
		local id = state.NextId
		state.NextId += 1
		party = { Id = id, Leader = inviter, Members = { inviter } }
		state.Parties[id] = party :: Party
		state.PartyOf[inviter] = id
	end
	local joined = party :: Party
	table.insert(joined.Members, target)
	state.PartyOf[target] = joined.Id
	return true, nil
end

-- Forgets a user who left the game: their party seat and all their invites.
function Parties.Remove(state: State, userId: number)
	Parties.Leave(state, userId)
	state.Invites[userId] = nil
	for _, pending in state.Invites do
		pending[userId] = nil
	end
end

function Parties.Expire(state: State, now: number)
	for target, pending in state.Invites do
		for inviter, expires in pending do
			if expires <= now then
				pending[inviter] = nil
			end
		end
		if next(pending) == nil then
			state.Invites[target] = nil
		end
	end
end

-- Inviters with a live invite for `target`.
function Parties.InvitesFor(state: State, target: number, now: number): { number }
	local result = {}
	local pending: { [number]: number } = state.Invites[target] or {}
	for inviter, expires in pending do
		if expires > now then
			table.insert(result, inviter)
		end
	end
	table.sort(result)
	return result
end

return Parties
