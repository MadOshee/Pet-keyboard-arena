--!strict
-- Shows every player's name and level over their head (Ivan 2026-10-14),
-- on the hub and on the arena; in a match the name takes the team color.
-- The tag itself is Util/Nameplate (bots use it too, BotService).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TeamColors = require(ReplicatedStorage.Shared.Config.TeamColors)
local Nameplate = require(script.Parent.Parent.Util.Nameplate)
local StatsService = require(script.Parent.StatsService)

local NameplateService = {}

local function refresh(player: Player)
	local character = player.Character
	if character == nil then
		return
	end
	local gui = Nameplate.Attach(character :: Model)
	if gui == nil then
		return
	end
	local team = player:GetAttribute("Team")
	local color = if team == "Red" or team == "Blue" then TeamColors.ForTeam(team) else nil
	Nameplate.Set(gui :: BillboardGui, player.DisplayName, StatsService:GetLevel(player), color)
end

local function watch(player: Player)
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("HumanoidRootPart", 10)
		refresh(player)
	end)
	-- The avatar finishes loading after the spawn; check the tag again.
	player.CharacterAppearanceLoaded:Connect(function()
		refresh(player)
	end)
	player:GetAttributeChangedSignal("Team"):Connect(function()
		refresh(player)
	end)
	if player.Character then
		task.spawn(refresh, player)
	end
end

function NameplateService:Init() end

function NameplateService:Start()
	StatsService.LevelChanged:Connect(refresh)
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
end

return NameplateService
