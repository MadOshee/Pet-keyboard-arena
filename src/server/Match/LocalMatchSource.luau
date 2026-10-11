--!strict
-- Variant A match source (docs/design.md 5.2): round participants are the
-- queued players on this server. Variant B will swap in a teleport-based
-- source with the same CollectParticipants() shape.

local Players = game:GetService("Players")

local Services = script.Parent.Parent.Services
local PartyService = require(Services.PartyService)
local PlayerDataService = require(Services.PlayerDataService)
local ReadyService = require(Services.ReadyService)

local LocalMatchSource = {}

local function isEligible(player: Player): boolean
	return ReadyService:IsReady(player) and PlayerDataService:IsLoaded(player)
end

-- Each inner list is one group that must stay on one team: the members of
-- a party queued with PARTY GAME, or a solo player.
function LocalMatchSource.CollectParticipants(): { { Player } }
	local groups: { { Player } } = {}
	local placed: { [Player]: boolean } = {}
	for _, player in Players:GetPlayers() do
		if placed[player] or not isEligible(player) then
			continue
		end
		local group = {}
		if ReadyService:GetMode(player) == "Party" then
			for _, userId in PartyService:GetMemberIds(player) do
				local member = Players:GetPlayerByUserId(userId)
				if
					member
					and not placed[member]
					and isEligible(member)
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
function LocalMatchSource.HasParticipants(): boolean
	for _, player in Players:GetPlayers() do
		if isEligible(player) then
			return true
		end
	end
	return false
end

return LocalMatchSource
