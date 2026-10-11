--!strict
-- Remembers that a player finished or skipped the first-time tips
-- (docs/design.md 12, stage 7). The client decides which tip to show; the
-- server only stores Tutorial.Done.

local NetService = require(script.Parent.NetService)
local PlayerDataService = require(script.Parent.PlayerDataService)

local TutorialService = {}

function TutorialService:Init() end

function TutorialService:Start()
	NetService:On("TutorialDone", { PerSecond = 1, Burst = 2 }, function(player)
		local data = PlayerDataService:Get(player)
		if data and not data.Tutorial.Done then
			PlayerDataService:Update(player, function(profile)
				profile.Tutorial.Done = true
			end)
		end
	end)
end

return TutorialService
