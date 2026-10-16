--!strict
-- Cross-server matches (docs/design.md 5.2, stage 12; Ivan 2026-10-14).
--
-- Hub servers: every group queued at the portal (a solo player or a party)
-- becomes a ticket in the shared MemoryStore queue. One hub at a time holds
-- the matchmaker lock and forms matches with Logic/Matchmaker: up to
-- MatchConfig.MaxHumans players from any servers, started when full or when
-- the oldest ticket has waited WaitSeconds. For each match it reserves an
-- arena server, stores the roster under the reserved server's id and tells
-- each ticket's hub where to go; that hub teleports its players there.
--
-- Arena servers: read their roster, wait for the players (RoundService
-- plays the match), then send everyone back to the hub server they came
-- from, with the party kept there for them (PartyService:HoldWhileAway).
--
-- Anything that fails (MemoryStore, the reservation, the teleport, no
-- match in GiveUpSeconds) falls back to a match on the player's own hub
-- server, so the queue never gets stuck. In Studio the mode is "Local" and
-- nothing here runs: RoundService plays every match on the server itself.

local HttpService = game:GetService("HttpService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local MatchConfig = require(ReplicatedStorage.Shared.Config.MatchConfig)
local RoundConfig = require(ReplicatedStorage.Shared.Config.RoundConfig)
local Strings = require(ReplicatedStorage.Shared.Config.Strings)
local Types = require(ReplicatedStorage.Shared.Types)
local Matchmaker = require(ReplicatedStorage.Shared.Logic.Matchmaker)
local TeamBalancer = require(ReplicatedStorage.Shared.Logic.TeamBalancer)
local LocalMatchSource = require(script.Parent.Parent.Match.LocalMatchSource)
local MatchMode = require(script.Parent.Parent.Match.MatchMode)
local NetService = require(script.Parent.NetService)
local PartyService = require(script.Parent.PartyService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local ReadyService = require(script.Parent.ReadyService)
local StatsService = require(script.Parent.StatsService)

local TELEPORT_RETRIES = 2
local ROSTER_READ_TRIES = 10

type OwnTicket = {
	Ticket: Matchmaker.Ticket,
	Players: { Player },
	RefreshedAt: number,
	Teleporting: boolean,
	TeleportedAt: number,
}

type Assignment = {
	PlaceId: number,
	AccessCode: string,
}

local MatchmakingService = {}

-- Hub state.
local ownTickets: { [string]: OwnTicket } = {}
local ticketOf: { [Player]: string } = {}
local playsHere: { [Player]: boolean } = {}
-- When each queued player pressed PvP (unix seconds): "Match in N" counts
-- from that moment, before their ticket is written (Ivan 2026-10-16).
local queuedAt: { [Player]: number } = {}

-- Arena state.
local roster: Matchmaker.Roster? = nil
local rosterRead = false
local returning: { [Player]: number } = {} -- player -> teleport attempts
-- Each player's round result, taken back to the hub in the teleport data so
-- the egg offer there shows the winner and the rewards.
local results: { [Player]: Types.RoundResultPayload } = {}

local maps: { [string]: MemoryStoreSortedMap } = {}

local function map(name: string): MemoryStoreSortedMap
	if not maps[name] then
		maps[name] = MemoryStoreService:GetSortedMap(name)
	end
	return maps[name]
end

local function unixNow(): number
	return DateTime.now().UnixTimestampMillis / 1000
end

-- Runs a MemoryStore or teleport call; logs and returns false on error.
local function call(label: string, fn: () -> (any, any)): (boolean, any, any)
	local ok, first, second = pcall(fn)
	if not ok then
		warn(`[Matchmaking] {label}: {first}`)
	end
	return ok, first, second
end

-- Players a match may hold: the arena place takes MaxHumans; a reserved
-- server of the hub place only as many as the hub's Max Players.
local function maxHumans(): number
	if MatchConfig.ArenaPlaceId ~= 0 then
		return MatchConfig.MaxHumans
	end
	return math.min(MatchConfig.MaxHumans, Players.MaxPlayers)
end

local function arenaPlaceId(): number
	return if MatchConfig.ArenaPlaceId ~= 0 then MatchConfig.ArenaPlaceId else game.PlaceId
end

------------------------------------------------------------------------
-- Hub: tickets
------------------------------------------------------------------------

local function setQueueAttributes(player: Player, endsAt: number?, found: boolean?)
	if player.Parent == Players then
		player:SetAttribute("QueueEndsAt", endsAt)
		player:SetAttribute("MatchFound", found)
	end
end

local function forget(id: string)
	local own = ownTickets[id]
	if own == nil then
		return
	end
	ownTickets[id] = nil
	for _, player in own.Players do
		if ticketOf[player] == id then
			ticketOf[player] = nil
			setQueueAttributes(player, nil, nil)
		end
	end
	task.spawn(call, "remove ticket", function()
		return map(MatchConfig.Maps.Queue):RemoveAsync(id)
	end)
end

-- The ticket's players play on this server instead (RoundService).
local function playHere(id: string)
	local own = ownTickets[id]
	if own == nil then
		return
	end
	local members = own.Players
	forget(id)
	for _, player in members do
		if player.Parent == Players and ReadyService:IsReady(player) then
			playsHere[player] = true
		end
	end
end

local function writeTicket(ticket: Matchmaker.Ticket): boolean
	return (
		call("write ticket", function()
			return map(MatchConfig.Maps.Queue):SetAsync(
				ticket.Id,
				ticket,
				MatchConfig.TicketSeconds,
				ticket.JoinedAt
			)
		end)
	)
end

-- Extends the ticket's expiry, but never brings back a ticket the
-- matchmaker has already taken out of the queue.
local function refreshTicket(ticket: Matchmaker.Ticket)
	call("refresh ticket", function()
		return map(MatchConfig.Maps.Queue):UpdateAsync(ticket.Id, function(current)
			if current == nil then
				return nil
			end
			return current, ticket.JoinedAt
		end, MatchConfig.TicketSeconds)
	end)
end

local function addTicket(group: { Player })
	local members, power = {}, 0
	local joinedAt = unixNow()
	for _, player in group do
		table.insert(members, player.UserId)
		power += StatsService:GetTeamWeight(player)
		joinedAt = math.min(joinedAt, queuedAt[player] or joinedAt)
	end
	local ticket: Matchmaker.Ticket = {
		Id = HttpService:GenerateGUID(false),
		Members = members,
		Power = power,
		HubPlaceId = game.PlaceId,
		HubJobId = game.JobId,
		JoinedAt = joinedAt,
	}
	local own: OwnTicket = {
		Ticket = ticket,
		Players = group,
		RefreshedAt = os.clock(),
		Teleporting = false,
		TeleportedAt = 0,
	}
	ownTickets[ticket.Id] = own
	local endsAt = joinedAt + MatchConfig.WaitSeconds
	for _, player in group do
		ticketOf[player] = ticket.Id
		setQueueAttributes(player, endsAt, nil)
	end
	if not writeTicket(ticket) and ownTickets[ticket.Id] == own then
		playHere(ticket.Id)
	end
end

local function teleportToArena(id: string, assignment: Assignment)
	local own = ownTickets[id]
	if own == nil or own.Teleporting then
		return
	end
	own.Teleporting = true
	own.TeleportedAt = os.clock()
	local going: { Player } = {}
	local userIds: { number } = {}
	for _, player in own.Players do
		if player.Parent == Players and ReadyService:IsReady(player) then
			table.insert(going, player)
			table.insert(userIds, player.UserId)
			-- The countdown keeps running to 0 while the teleport starts.
			local endsAt = player:GetAttribute("QueueEndsAt")
			setQueueAttributes(player, if type(endsAt) == "number" then endsAt else nil, true)
		end
	end
	if #going == 0 then
		forget(id)
		return
	end
	PartyService:HoldWhileAway(userIds, MatchConfig.AwaySeconds)

	local options = Instance.new("TeleportOptions")
	options.ReservedServerAccessCode = assignment.AccessCode
	options:SetTeleportData({ Match = true })
	local sent = false
	for attempt = 1, TELEPORT_RETRIES do
		sent = call("teleport to arena", function()
			return TeleportService:TeleportAsync(assignment.PlaceId, going, options)
		end)
		if sent then
			break
		end
		task.wait(attempt * 2)
	end
	task.spawn(call, "remove assignment", function()
		return map(MatchConfig.Maps.Assignments):RemoveAsync(id)
	end)
	if not sent then
		own.Teleporting = false
		playHere(id)
	end
end

-- Drops tickets whose players left the queue, refreshes the rest and asks
-- whether the matchmaker found them a match.
local function serviceOwnTickets()
	local now = os.clock()
	for id, own in ownTickets do
		if own.Teleporting then
			-- Players who did not leave fell back to a match here.
			if now - own.TeleportedAt > MatchConfig.AssignmentSeconds then
				ownTickets[id] = nil
			end
			continue
		end
		local intact = true
		for _, player in own.Players do
			if
				player.Parent ~= Players
				or not ReadyService:IsReady(player)
				or player:GetAttribute("Team") ~= nil
			then
				intact = false
				break
			end
		end
		if not intact then
			-- The members still queued get a new ticket on the next pass.
			forget(id)
			continue
		end
		if unixNow() - own.Ticket.JoinedAt >= MatchConfig.GiveUpSeconds then
			playHere(id)
			continue
		end
		if now - own.RefreshedAt >= MatchConfig.RefreshSeconds then
			own.RefreshedAt = now
			task.spawn(refreshTicket, own.Ticket)
		end
		task.spawn(function()
			local ok, assignment = call("read assignment", function()
				return map(MatchConfig.Maps.Assignments):GetAsync(id)
			end)
			if ok and type(assignment) == "table" and ownTickets[id] == own then
				teleportToArena(id, assignment :: Assignment)
			end
		end)
	end
end

local function hubTick()
	serviceOwnTickets()
	local groups = LocalMatchSource.CollectParticipants(function(player)
		return ticketOf[player] == nil
			and not playsHere[player]
			and player:GetAttribute("Team") == nil
	end)
	for _, group in groups do
		task.spawn(addTicket, group)
	end
end

------------------------------------------------------------------------
-- Hub: the matchmaker (only the lock holder)
------------------------------------------------------------------------

local function holdsLock(): boolean
	local ok, lock = call("matchmaker lock", function()
		return map(MatchConfig.Maps.Lock):UpdateAsync("lock", function(current)
			return Matchmaker.TakeLock(current, game.JobId, unixNow(), MatchConfig.LockSeconds)
		end, MatchConfig.LockSeconds)
	end)
	return ok and type(lock) == "table" and lock.JobId == game.JobId
end

local function readQueue(): { Matchmaker.Ticket }?
	local ok, items = call("read queue", function()
		return map(MatchConfig.Maps.Queue):GetRangeAsync(Enum.SortDirection.Ascending, 200)
	end)
	if not ok or type(items) ~= "table" then
		return nil
	end
	local tickets = {}
	for _, item in items do
		local value = item.value
		if type(value) == "table" and type(value.Members) == "table" then
			table.insert(tickets, value :: Matchmaker.Ticket)
		end
	end
	return tickets
end

local function startMatch(chosen: { Matchmaker.Ticket }): boolean
	local placeId = arenaPlaceId()
	local ok, accessCode, serverId = call("reserve server", function()
		return TeleportService:ReserveServer(placeId)
	end)
	if not ok or type(accessCode) ~= "string" or type(serverId) ~= "string" then
		return false
	end
	local now = unixNow()
	local saved = call("write roster", function()
		return map(MatchConfig.Maps.Rosters):SetAsync(
			serverId,
			Matchmaker.Roster(chosen, now),
			MatchConfig.RosterSeconds
		)
	end)
	if not saved then
		return false
	end
	local assignment: Assignment = { PlaceId = placeId, AccessCode = accessCode }
	for _, ticket in chosen do
		call("write assignment", function()
			return map(MatchConfig.Maps.Assignments):SetAsync(
				ticket.Id,
				assignment,
				MatchConfig.AssignmentSeconds
			)
		end)
		call("claim ticket", function()
			return map(MatchConfig.Maps.Queue):RemoveAsync(ticket.Id)
		end)
	end
	return true
end

local function matchmakerTick()
	if not holdsLock() then
		return
	end
	local queue = readQueue()
	if queue == nil then
		return
	end
	local tickets: { Matchmaker.Ticket } = queue :: { Matchmaker.Ticket }
	local config = {
		MaxHumans = maxHumans(),
		-- A little early, so the teleport starts as "Match in N" reaches 0.
		WaitSeconds = MatchConfig.WaitSeconds - MatchConfig.StartLeadSeconds,
		MinTeamSize = RoundConfig.MinTeamSize,
		MaxTeamSize = RoundConfig.MaxTeamSize,
	}
	for _ = 1, MatchConfig.MaxMatchesPerTick do
		local picked = Matchmaker.Pick(tickets, unixNow(), config, TeamBalancer.Assign)
		if picked == nil then
			return
		end
		local chosen = picked :: { Matchmaker.Ticket }
		if not startMatch(chosen) then
			return
		end
		local taken = {}
		for _, ticket in chosen do
			taken[ticket.Id] = true
		end
		local left = {}
		for _, ticket in tickets do
			if not taken[ticket.Id] then
				table.insert(left, ticket)
			end
		end
		tickets = left
	end
end

------------------------------------------------------------------------
-- Arena
------------------------------------------------------------------------

local function readRoster()
	for attempt = 1, ROSTER_READ_TRIES do
		local ok, value = call("read roster", function()
			return map(MatchConfig.Maps.Rosters):GetAsync(game.PrivateServerId)
		end)
		if ok and type(value) == "table" and type(value.Tickets) == "table" then
			roster = value :: Matchmaker.Roster
			break
		end
		if ok and value == nil and attempt >= 3 then
			break -- no roster for this server (not made by the matchmaker)
		end
		task.wait(1)
	end
	rosterRead = true
end

local function hubPlaceId(): number
	if roster and #roster.Tickets > 0 then
		return roster.Tickets[1].HubPlaceId
	end
	return game.PlaceId
end

local function teleportHome(players: { Player }, jobId: string, placeId: number)
	local options = Instance.new("TeleportOptions")
	if jobId ~= "" then
		options.ServerInstanceId = jobId
	end
	local carried: { [string]: Types.RoundResultPayload } = {}
	for _, player in players do
		carried[tostring(player.UserId)] = results[player]
	end
	options:SetTeleportData({ FromMatch = true, Results = carried })
	local sent = call("teleport home", function()
		return TeleportService:TeleportAsync(placeId, players, options)
	end)
	if not sent and jobId ~= "" then
		-- Their hub server is gone or full: any hub server will do.
		teleportHome(players, "", placeId)
	elseif not sent then
		-- RoundService asks again in a moment.
		for _, player in players do
			returning[player] = nil
		end
	end
end

local function isInRoster(player: Player): boolean
	return roster == nil or Matchmaker.TicketOf(roster :: Matchmaker.Roster, player.UserId) ~= nil
end

------------------------------------------------------------------------
-- Hub: the round result a player brought back from the arena
------------------------------------------------------------------------

local OUTCOMES = { Win = true, Lose = true, Draw = true }
local WINNERS = { Red = true, Blue = true, Draw = true }

-- Teleport data can be forged by a client, so only a well-formed result
-- passes; it is only shown, never paid (the arena already paid it).
local function readResult(value: any): Types.RoundResultPayload?
	if
		type(value) ~= "table"
		or not OUTCOMES[value.Outcome]
		or not WINNERS[value.Winner]
		or type(value.KeysPainted) ~= "number"
		or type(value.Coins) ~= "number"
		or type(value.XP) ~= "number"
		or type(value.Rewarded) ~= "boolean"
	then
		return nil
	end
	return {
		Outcome = value.Outcome,
		Winner = value.Winner,
		KeysPainted = value.KeysPainted,
		Coins = value.Coins,
		XP = value.XP,
		Rewarded = value.Rewarded,
	}
end

-- Sends the result from the arena to the player once their data is here,
-- so the egg offer shows who won and what they got.
local function deliverResult(player: Player, profile: Types.Profile)
	local ok, joinData = pcall(function()
		return player:GetJoinData()
	end)
	if not ok or type(joinData) ~= "table" or joinData.SourcePlaceId ~= arenaPlaceId() then
		return
	end
	local data = joinData.TeleportData
	if type(data) ~= "table" or type(data.Results) ~= "table" then
		return
	end
	local result = readResult(data.Results[tostring(player.UserId)])
	if result and profile.PendingOffer then
		NetService:FireClient("RoundResult", player, result)
	end
end

------------------------------------------------------------------------
-- Public
------------------------------------------------------------------------

function MatchmakingService:Init() end

function MatchmakingService:Start()
	local mode = MatchMode.Get()

	ReadyService.ReadyChanged:Connect(function(player, ready)
		if ready and mode == "Hub" then
			-- "Match in N" right away, before the ticket is written.
			queuedAt[player] = unixNow()
			setQueueAttributes(player, queuedAt[player] + MatchConfig.WaitSeconds, nil)
		end
		if not ready then
			queuedAt[player] = nil
			playsHere[player] = nil
			local id = ticketOf[player]
			if id and ownTickets[id] and not ownTickets[id].Teleporting then
				forget(id)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		playsHere[player] = nil
		queuedAt[player] = nil
		returning[player] = nil
		results[player] = nil
		local id = ticketOf[player]
		ticketOf[player] = nil
		local own = id and ownTickets[id]
		if own and not own.Teleporting then
			forget(id :: string)
		end
	end)

	if mode == "Hub" then
		task.spawn(function()
			while true do
				task.wait(MatchConfig.TickSeconds)
				hubTick()
			end
		end)
		task.spawn(function()
			while true do
				task.wait(MatchConfig.TickSeconds)
				matchmakerTick()
			end
		end)
	elseif mode == "Arena" then
		task.spawn(readRoster)
		-- LEAVE QUEUE while waiting for the match: back to the hub.
		ReadyService.LeaveRequested:Connect(function(player)
			if player:GetAttribute("Team") == nil then
				MatchmakingService:ReturnToHub({ player })
			end
		end)
		TeleportService.TeleportInitFailed:Connect(function(player, result, message)
			local attempts = returning[player]
			if attempts == nil or player.Parent ~= Players then
				return
			end
			warn(`[Matchmaking] return of {player.UserId} failed: {result} {message}`)
			if attempts < TELEPORT_RETRIES + 1 then
				returning[player] = attempts + 1
				task.delay(attempts * 2, teleportHome, { player }, "", hubPlaceId())
			else
				player:Kick(Strings.ReturnFailed)
			end
		end)
	end
	if mode == "Hub" then
		PlayerDataService.ProfileLoaded:Connect(deliverResult)
		TeleportService.TeleportInitFailed:Connect(function(player, result, message)
			local id = ticketOf[player]
			if id == nil then
				return
			end
			warn(`[Matchmaking] teleport of {player.UserId} failed: {result} {message}`)
			setQueueAttributes(player, nil, nil)
			ticketOf[player] = nil
			if ReadyService:IsReady(player) then
				playsHere[player] = true
			end
		end)
	end
end

-- Whether RoundService plays this queued player's match on this server.
function MatchmakingService:PlaysHere(player: Player): boolean
	local mode = MatchMode.Get()
	if mode == "Local" then
		return true
	elseif mode == "Hub" then
		return playsHere[player] == true
	end
	return isInRoster(player)
end

-- Arena: waits (up to `timeout`) until the roster has been read.
function MatchmakingService:WaitForRoster(timeout: number)
	local deadline = os.clock() + timeout
	while not rosterRead and os.clock() < deadline do
		task.wait(0.25)
	end
end

-- Arena: true when every roster player is here with their data loaded.
function MatchmakingService:AllArrived(): boolean
	if roster == nil then
		return false
	end
	local present = {}
	for _, player in Players:GetPlayers() do
		if PlayerDataService:IsLoaded(player) then
			present[player.UserId] = true
		end
	end
	return Matchmaker.AllArrived(roster :: Matchmaker.Roster, present)
end

-- Arena: the groups to play, the roster's parties kept together. Without a
-- roster every player here is a group of one.
function MatchmakingService:ArenaGroups(): { { Player } }
	local present: { [number]: boolean } = {}
	for _, player in Players:GetPlayers() do
		if PlayerDataService:IsLoaded(player) and returning[player] == nil then
			present[player.UserId] = true
		end
	end
	local groups: { { Player } } = {}
	if roster == nil then
		for userId in present do
			local player = Players:GetPlayerByUserId(userId)
			if player then
				table.insert(groups, { player })
			end
		end
		return groups
	end
	for _, userIds in Matchmaker.PresentGroups(roster :: Matchmaker.Roster, present) do
		local group = {}
		for _, userId in userIds do
			local player = Players:GetPlayerByUserId(userId)
			if player then
				table.insert(group, player)
			end
		end
		table.insert(groups, group)
	end
	return groups
end

-- Arena: the result to take back to the hub with this player.
function MatchmakingService:SetRoundResult(player: Player, result: Types.RoundResultPayload)
	if MatchMode.IsArena() then
		results[player] = result
	end
end

-- Arena: true once the player is on the way back to the hub.
function MatchmakingService:IsReturning(player: Player): boolean
	return returning[player] ~= nil
end

-- Arena: whether this player belongs to the match here.
function MatchmakingService:IsExpected(player: Player): boolean
	return isInRoster(player)
end

-- Arena: sends the players back to the hub servers they came from, each
-- hub's players together; a gone or full hub means any hub server.
function MatchmakingService:ReturnToHub(players: { Player })
	local byUserId: { [number]: Player } = {}
	local userIds: { number } = {}
	for _, player in players do
		if player.Parent == Players and returning[player] == nil then
			returning[player] = 1
			byUserId[player.UserId] = player
			table.insert(userIds, player.UserId)
		end
	end
	for _, group in Matchmaker.ReturnGroups(roster, userIds, hubPlaceId()) do
		local going = {}
		for _, userId in group.UserIds do
			table.insert(going, byUserId[userId])
		end
		task.spawn(teleportHome, going, group.HubJobId, group.HubPlaceId)
	end
end

return MatchmakingService
