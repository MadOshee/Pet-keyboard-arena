--!strict
-- The match queue (docs/design.md 4.3 "Готовность"). A player joins it at
-- the portal on the hub island (PortalService) as "Solo" or "Party" and
-- leaves it with the LEAVE button, when marked AFK, or after their match.
-- Mirrored to the "Ready" and "QueueMode" Player attributes for the HUD.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local Types = require(ReplicatedStorage.Shared.Types)
local Guard = require(script.Parent.Parent.Util.Guard)
local NetService = require(script.Parent.NetService)

local ReadyService = {}

ReadyService.ReadyChanged = Signal.new() :: Signal.Signal<Player, boolean>

local queued: { [Player]: Types.QueueMode } = {}

function ReadyService:Init() end

function ReadyService:Start()
	-- Clients may only leave the queue here; joining goes through the portal.
	NetService:On("SetReady", { PerSecond = 2, Burst = 4 }, function(player, value)
		if Guard.Boolean(value) and value == false then
			ReadyService:SetReady(player, false)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		queued[player] = nil
	end)
end

function ReadyService:IsReady(player: Player): boolean
	return queued[player] ~= nil
end

-- "Party" players go into the match together with their queued party.
function ReadyService:GetMode(player: Player): Types.QueueMode?
	return queued[player]
end

function ReadyService:SetReady(player: Player, value: boolean, mode: Types.QueueMode?)
	local newMode: Types.QueueMode? = if value then mode or "Solo" else nil
	if queued[player] == newMode then
		return
	end
	local wasReady = queued[player] ~= nil
	if newMode then
		queued[player] = newMode
	else
		queued[player] = nil
	end
	player:SetAttribute("Ready", value)
	player:SetAttribute("QueueMode", newMode)
	if wasReady ~= value then
		ReadyService.ReadyChanged:Fire(player, value)
	end
end

return ReadyService
