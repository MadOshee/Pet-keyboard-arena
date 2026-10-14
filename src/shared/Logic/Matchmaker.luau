--!strict
-- Decisions of the cross-server matchmaker (MatchmakingService), without
-- Roblox APIs so they are tested with Lune: which queued tickets make the
-- next match, who holds the matchmaker lock, the arena roster and how the
-- players go back to their hubs afterwards.

-- One queued group: a solo player or a party, from one hub server.
export type Ticket = {
	Id: string,
	Members: { number }, -- user ids
	Power: number, -- sum of the members' team weights
	HubPlaceId: number,
	HubJobId: string,
	JoinedAt: number, -- unix seconds
}

export type PickConfig = {
	MaxHumans: number,
	WaitSeconds: number,
	MinTeamSize: number,
	MaxTeamSize: number,
}

type Group = { Members: { number }, Power: number }
-- TeamBalancer.Assign, passed in so this module needs no require.
export type Assign = (groups: { Group }, limits: any) -> { Waiting: { number } }

export type Lock = {
	JobId: string,
	ExpiresAt: number,
}

-- What the arena server reads: the groups that were matched.
export type Roster = {
	Tickets: { Ticket },
	CreatedAt: number,
}

export type ReturnGroup = {
	HubPlaceId: number,
	HubJobId: string,
	UserIds: { number },
}

local Matchmaker = {}

local function oldestFirst(a: Ticket, b: Ticket): boolean
	if a.JoinedAt ~= b.JoinedAt then
		return a.JoinedAt < b.JoinedAt
	end
	return a.Id < b.Id
end

-- The tickets of the next match, oldest first, or nil if it is too early:
-- a match starts when it is full or its oldest ticket has waited long
-- enough. A ticket that would not fit (too many players, or parties that
-- cannot share two teams) is left for the next match.
function Matchmaker.Pick(
	tickets: { Ticket },
	now: number,
	config: PickConfig,
	assign: Assign
): { Ticket }?
	local ordered = table.clone(tickets)
	table.sort(ordered, oldestFirst)
	local chosen: { Ticket } = {}
	local groups: { Group } = {}
	local humans = 0
	for _, ticket in ordered do
		local size = #ticket.Members
		if size == 0 or humans + size > config.MaxHumans then
			continue
		end
		table.insert(groups, { Members = ticket.Members, Power = ticket.Power })
		local assignment = assign(groups, config)
		if #assignment.Waiting > 0 then
			table.remove(groups)
			continue
		end
		table.insert(chosen, ticket)
		humans += size
	end
	if #chosen == 0 then
		return nil
	end
	if humans >= config.MaxHumans or now - chosen[1].JoinedAt >= config.WaitSeconds then
		return chosen
	end
	return nil
end

-- New lock value for MemoryStore UpdateAsync, or nil to leave it (another
-- live server holds it).
function Matchmaker.TakeLock(current: Lock?, jobId: string, now: number, seconds: number): Lock?
	if current == nil or current.JobId == jobId or current.ExpiresAt <= now then
		return { JobId = jobId, ExpiresAt = now + seconds }
	end
	return nil
end

function Matchmaker.Roster(tickets: { Ticket }, now: number): Roster
	return { Tickets = table.clone(tickets), CreatedAt = now }
end

-- The roster ticket that holds `userId`, if any.
function Matchmaker.TicketOf(roster: Roster, userId: number): Ticket?
	for _, ticket in roster.Tickets do
		if table.find(ticket.Members, userId) then
			return ticket
		end
	end
	return nil
end

-- The roster's groups, keeping only the players present on the arena.
function Matchmaker.PresentGroups(roster: Roster, present: { [number]: boolean }): { { number } }
	local groups = {}
	for _, ticket in roster.Tickets do
		local members = {}
		for _, userId in ticket.Members do
			if present[userId] then
				table.insert(members, userId)
			end
		end
		if #members > 0 then
			table.insert(groups, members)
		end
	end
	return groups
end

-- True when every roster player is on the arena.
function Matchmaker.AllArrived(roster: Roster, present: { [number]: boolean }): boolean
	for _, ticket in roster.Tickets do
		for _, userId in ticket.Members do
			if not present[userId] then
				return false
			end
		end
	end
	return true
end

-- Players grouped by the hub server they came from, so each group goes
-- back to that server together. Players missing from the roster go to
-- `fallbackPlaceId` on any server.
function Matchmaker.ReturnGroups(
	roster: Roster?,
	userIds: { number },
	fallbackPlaceId: number
): { ReturnGroup }
	local byHub: { [string]: ReturnGroup } = {}
	local order: { ReturnGroup } = {}
	for _, userId in userIds do
		local ticket = if roster then Matchmaker.TicketOf(roster, userId) else nil
		local placeId = if ticket then ticket.HubPlaceId else fallbackPlaceId
		local jobId = if ticket then ticket.HubJobId else ""
		local key = `{placeId}/{jobId}`
		local group = byHub[key]
		if group == nil then
			group = { HubPlaceId = placeId, HubJobId = jobId, UserIds = {} }
			byHub[key] = group
			table.insert(order, group)
		end
		table.insert(group.UserIds, userId)
	end
	return order
end

return Matchmaker
