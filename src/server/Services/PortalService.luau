--!strict
-- The portal on the hub island (World.Portal, built by tools/world). A
-- player who walks up to it picks SOLO GAME or PARTY GAME in a window
-- (PortalController); the server checks the request and puts the player,
-- or their whole party, into the match queue. RoundService then counts
-- down and teleports everyone queued to the arena.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArenaConfig = require(ReplicatedStorage.Shared.Config.ArenaConfig)
local Types = require(ReplicatedStorage.Shared.Types)
local MatchMode = require(script.Parent.Parent.Match.MatchMode)
local Guard = require(script.Parent.Parent.Util.Guard)
local NetService = require(script.Parent.NetService)
local PartyService = require(script.Parent.PartyService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local ReadyService = require(script.Parent.ReadyService)

local PortalService = {}

local function portalPosition(): Vector3?
	local world = workspace:FindFirstChild("World")
	local portal = world and world:FindFirstChild("Portal")
	if portal and portal:IsA("Model") then
		return portal:GetPivot().Position
	end
	return nil
end

local function refuse(player: Player, reason: Types.ActionError)
	NetService:FireClient("ActionResult", player, "JoinQueue", reason)
end

local function canQueue(player: Player): boolean
	-- An arena server already is the match.
	return PlayerDataService:IsLoaded(player)
		and player:GetAttribute("Team") == nil
		and not MatchMode.IsArena()
end

local function isNearPortal(player: Player): boolean
	local position = portalPosition()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if position == nil or not (root and root:IsA("BasePart")) then
		return false
	end
	local offset = (root :: BasePart).Position - (position :: Vector3)
	return Vector3.new(offset.X, 0, offset.Z).Magnitude <= ArenaConfig.PortalServerRadius
end

local function onJoin(player: Player, mode: unknown)
	if mode ~= "Solo" and mode ~= "Party" then
		return
	end
	if not canQueue(player) then
		refuse(player, "InMatch")
		return
	end
	if not isNearPortal(player) then
		refuse(player, "TooFar")
		return
	end
	if mode == "Solo" then
		ReadyService:SetReady(player, true, "Solo")
		return
	end
	local members = PartyService:GetMemberIds(player)
	if #members < 2 then
		refuse(player, "NoParty")
		return
	end
	-- The whole party goes, wherever its members are on the hub.
	for _, userId in members do
		local member = Players:GetPlayerByUserId(userId)
		if member and canQueue(member) then
			ReadyService:SetReady(member, true, "Party")
		end
	end
end

function PortalService:Init() end

function PortalService:Start()
	NetService:On("JoinQueue", { PerSecond = 2, Burst = 3 }, function(player, mode)
		if Guard.String(mode, 8) then
			onJoin(player, mode)
		end
	end)
end

return PortalService
