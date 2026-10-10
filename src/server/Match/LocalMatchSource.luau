--!strict
-- Variant A match source (docs/design.md 5.2): round participants are the
-- ready players on this server. Variant B will swap in a teleport-based
-- source with the same CollectParticipants() shape.

local Players = game:GetService("Players")

local Services = script.Parent.Parent.Services
local PlayerDataService = require(Services.PlayerDataService)
local ReadyService = require(Services.ReadyService)

local LocalMatchSource = {}

-- Each inner list is one group (party) that must stay on one team.
-- Stage 6 adds parties; until then every player is their own group.
function LocalMatchSource.CollectParticipants(): { { Player } }
	local groups: { { Player } } = {}
	for _, player in Players:GetPlayers() do
		if ReadyService:IsReady(player) and PlayerDataService:IsLoaded(player) then
			table.insert(groups, { player })
		end
	end
	return groups
end

return LocalMatchSource
