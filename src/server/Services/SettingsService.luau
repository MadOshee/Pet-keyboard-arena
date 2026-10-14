--!strict
-- Saves the Settings window's switches (music, sound effects, visual
-- effects; Ivan 2026-10-14) in the profile, so they follow the player to
-- any server. The client applies them itself; the server only stores them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerSettings = require(ReplicatedStorage.Shared.Logic.PlayerSettings)
local NetService = require(script.Parent.NetService)
local PlayerDataService = require(script.Parent.PlayerDataService)

local SettingsService = {}

function SettingsService:Init() end

function SettingsService:Start()
	NetService:On("SetSetting", { PerSecond = 4, Burst = 8 }, function(player, name, on)
		if not PlayerSettings.IsValid(name, on) then
			return
		end
		local data = PlayerDataService:Get(player)
		if data == nil or PlayerSettings.Get(data.Settings :: any, name :: string) == on then
			return
		end
		PlayerDataService:Update(player, function(profile)
			if profile.Settings == nil then
				profile.Settings = { Music = true, Sfx = true, Vfx = true }
			end
			(profile.Settings :: any)[name :: string] = on
		end)
	end)
end

return SettingsService
