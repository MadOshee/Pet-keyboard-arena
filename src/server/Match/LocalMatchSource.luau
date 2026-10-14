--!strict
-- Variant A match source (docs/design.md 5.2): round participants are the
-- queued players on this server. With cross-server matches (variant B) the
-- hub hands the same groups to MatchmakingService as tickets, and plays here
-- only those `include` lets through (Studio, or when matchmaking failed).

local Players = game:GetService("Players")

local Services = script.Parent.Parent.Services
local PartyService = require(Services.PartyService)
local PlayerDataService = require(Services.PlayerDataService)
local ReadyService = require(Services.ReadyService)

local LocalMatchSource = {}

export type Include = (player: Player) -> boolean

local function isEligible(player: Player, include: Include?): boolean
	return ReadyService:IsReady(player)
		and PlayerDataService:IsLoaded(player)
		and (include == nil or include(player))
end

-- Each inner list is one group that must stay on one team: the members of
-- a party queued with PARTY GAME, or a solo player.
function LocalMatchSource.CollectParticipants(include: Include?): { { Player } }
	local groups: { { Player } } = {}
	local placed: { [Player]: boolean } = {}
	for _, player in Players:GetPlayers() do
		if placed[player] or not isEligible(player, include) then
			continue
		end
		local group = {}
		if ReadyService:GetMode(player) == "Party" then
			for _, userId in PartyService:GetMemberIds(player) do
				local member = Players:GetPlayerByUserId(userId)
				if
					member
					and not placed[member]
					and isEligible(member, include)
					and ReadyService:GetMode(member) == "Party"
				then
					placed[member] = true
					table.insert(group, member)
				end
			end
		end
		if not placed[player] then
			placed[player] = true
			table.insert(group, player)
		end
		table.insert(groups, group)
	end
	return groups
end

-- True when at least one player is waiting for a match.
function LocalMatchSource.HasParticipants(include: Include?): boolean
	for _, player in Players:GetPlayers() do
		if isEligible(player, include) then
			return true
		end
	end
	return false
end

return LocalMatchSource
