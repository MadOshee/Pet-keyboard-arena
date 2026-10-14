--!strict
-- Which job this server does (docs/design.md 5.2, stage 12):
-- "Local": matches stay on this server, as before (Studio, an unpublished
--   place, or MatchConfig.CrossServer off).
-- "Hub": the plaza and plots; queued players go to the shared matchmaking
--   queue and play on an arena server.
-- "Arena": a reserved server made for one match (or any server of the
--   arena place); it plays that match and sends everyone back.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MatchConfig = require(ReplicatedStorage.Shared.Config.MatchConfig)

export type Mode = "Local" | "Hub" | "Arena"

local function detect(): Mode
	if not MatchConfig.CrossServer or RunService:IsStudio() or game.PlaceId == 0 then
		return "Local"
	end
	if MatchConfig.ArenaPlaceId ~= 0 and game.PlaceId == MatchConfig.ArenaPlaceId then
		return "Arena"
	end
	-- A reserved server (TeleportService:ReserveServer) has a private
	-- server id and no owner; a paid private server has an owner.
	if game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0 then
		return "Arena"
	end
	return "Hub"
end

local mode: Mode = detect()

local MatchMode = {}

function MatchMode.Get(): Mode
	return mode
end

function MatchMode.IsArena(): boolean
	return mode == "Arena"
end

function MatchMode.IsHub(): boolean
	return mode == "Hub"
end

return MatchMode
