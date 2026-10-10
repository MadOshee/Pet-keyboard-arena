--!strict
-- Tracks who wants to play the next rounds (docs/design.md 4.3 "Готовность").
-- Ready is sticky until the player turns it off or is marked AFK, and is
-- mirrored to the "Ready" Player attribute for the HUD.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local Guard = require(script.Parent.Parent.Util.Guard)
local NetService = require(script.Parent.NetService)
local PlayerDataService = require(script.Parent.PlayerDataService)

local ReadyService = {}

ReadyService.ReadyChanged = Signal.new() :: Signal.Signal<Player, boolean>

local ready: { [Player]: boolean } = {}

function ReadyService:Init() end

function ReadyService:Start()
	NetService:On("SetReady", { PerSecond = 2, Burst = 4 }, function(player, value)
		if not Guard.Boolean(value) or not PlayerDataService:IsLoaded(player) then
			return
		end
		ReadyService:SetReady(player, value :: boolean)
	end)

	Players.PlayerRemoving:Connect(function(player)
		ready[player] = nil
	end)
end

function ReadyService:IsReady(player: Player): boolean
	return ready[player] == true
end

function ReadyService:SetReady(player: Player, value: boolean)
	if (ready[player] == true) == value then
		return
	end
	if value then
		ready[player] = true
	else
		ready[player] = nil
	end
	player:SetAttribute("Ready", value)
	ReadyService.ReadyChanged:Fire(player, value)
end

return ReadyService
