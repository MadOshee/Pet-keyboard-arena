--!strict
-- Parties of up to 3 players (docs/design.md 4.3 "Группы"). Anyone on the
-- server can be invited; invites expire after 30 s. A party always plays on
-- one team: LocalMatchSource hands ready members to TeamBalancer as one
-- group. Each player gets their own view through PartyUpdate, and the
-- "PartyId" Player attribute (0 when solo) lets every client see groups.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Parties = require(ReplicatedStorage.Shared.Logic.Parties)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local Types = require(ReplicatedStorage.Shared.Types)
local Guard = require(script.Parent.Parent.Util.Guard)
local NetService = require(script.Parent.NetService)

local MAX_SIZE = 3
local INVITE_SECONDS = 30
local MAX_USER_ID = 2 ^ 53

local PartyService = {}

PartyService.PartyChanged = Signal.new() :: Signal.Signal<()>

local state = Parties.new(MAX_SIZE)
-- user id -> os.clock() until which a member away at a cross-server match
-- keeps their party seat (MatchmakingService).
local awayUntil: { [number]: number } = {}

local function refuse(player: Player, action: string, reason: string)
	NetService:FireClient("ActionResult", player, action, reason)
end

-- Sends every player their own party view and refreshes the attributes.
local function syncAll()
	local now = os.clock()
	for _, player in Players:GetPlayers() do
		local party = Parties.Get(state, player.UserId)
		player:SetAttribute("PartyId", if party then party.Id else 0)
		local payload: Types.PartyPayload = {
			Members = Parties.MembersOf(state, player.UserId),
			Leader = if party then party.Leader else player.UserId,
			Invites = Parties.InvitesFor(state, player.UserId, now),
		}
		NetService:FireClient("PartyUpdate", player, payload)
	end
	PartyService.PartyChanged:Fire()
end

local function onInvite(player: Player, targetUserId: unknown)
	if not Guard.Integer(targetUserId, 1, MAX_USER_ID) then
		return
	end
	local target = Players:GetPlayerByUserId(targetUserId :: number)
	if target == nil then
		refuse(player, "PartyInvite", "InvalidTarget")
		return
	end
	local ok, reason =
		Parties.Invite(state, player.UserId, (target :: Player).UserId, os.clock(), INVITE_SECONDS)
	if not ok then
		refuse(player, "PartyInvite", reason or "InvalidTarget")
		return
	end
	syncAll()
end

local function onRespond(player: Player, inviterUserId: unknown, accept: unknown)
	if not Guard.Integer(inviterUserId, 1, MAX_USER_ID) or not Guard.Boolean(accept) then
		return
	end
	local ok, reason = Parties.Respond(
		state,
		player.UserId,
		inviterUserId :: number,
		accept :: boolean,
		os.clock()
	)
	if not ok then
		refuse(player, "PartyRespond", reason or "NoInvite")
	end
	syncAll()
end

local function onLeave(player: Player)
	if Parties.Leave(state, player.UserId) then
		syncAll()
	end
end

function PartyService:Init() end

function PartyService:Start()
	NetService:On("PartyInvite", { PerSecond = 1, Burst = 3 }, onInvite)
	NetService:On("PartyRespond", { PerSecond = 2, Burst = 4 }, onRespond)
	NetService:On("PartyLeave", { PerSecond = 1, Burst = 2 }, onLeave)

	Players.PlayerAdded:Connect(function(player)
		awayUntil[player.UserId] = nil
		syncAll()
	end)
	Players.PlayerRemoving:Connect(function(player)
		local userId = player.UserId
		local holdUntil = awayUntil[userId]
		if holdUntil and holdUntil > os.clock() then
			-- Away at a match: keep the seat until they are back or time runs out.
			task.delay(holdUntil - os.clock(), function()
				if awayUntil[userId] == holdUntil and not Players:GetPlayerByUserId(userId) then
					awayUntil[userId] = nil
					Parties.Remove(state, userId)
					syncAll()
				end
			end)
			return
		end
		awayUntil[userId] = nil
		Parties.Remove(state, userId)
		task.defer(syncAll)
	end)

	-- Drop expired invites so their popups close.
	task.spawn(function()
		while true do
			task.wait(1)
			local before = 0
			for _, pending in state.Invites do
				for _ in pending do
					before += 1
				end
			end
			Parties.Expire(state, os.clock())
			local after = 0
			for _, pending in state.Invites do
				for _ in pending do
					after += 1
				end
			end
			if after ~= before then
				syncAll()
			end
		end
	end)
end

-- Members who leave this server for a match keep their party for
-- `seconds`, so they find it again when they come back.
function PartyService:HoldWhileAway(userIds: { number }, seconds: number)
	local holdUntil = os.clock() + seconds
	for _, userId in userIds do
		awayUntil[userId] = holdUntil
	end
end

-- User ids of everyone in the player's party (just the player when solo).
function PartyService:GetMemberIds(player: Player): { number }
	return Parties.MembersOf(state, player.UserId)
end

return PartyService
