--!strict
-- Variant A match source (docs/design.md 5.2): round participants are the
-- ready players on this server. Variant B will swap in a teleport-based
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

-- Each inner list is one group that must stay on one team: the ready
-- members of a party, or a solo ready player.
function LocalMatchSource.CollectParticipants(): { { Player } }
	local groups: { { Player } } = {}
	local placed: { [Player]: boolean } = {}
	for _, player in Players:GetPlayers() do
		if placed[player] or not isEligible(player) then
			continue
		end
		local group = {}
		for _, userId in PartyService:GetMemberIds(player) do
			local member = Players:GetPlayerByUserId(userId)
			if member and not placed[member] and isEligible(member) then
				placed[member] = true
				table.insert(group, member)
			end
		end
		table.insert(groups, group)
	end
	return groups
end

return LocalMatchSource
