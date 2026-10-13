--!strict
-- A player's final bonuses from equipped pets, capped (docs/design.md 4.4).
-- Other services read the numbers they need from here instead of looking at
-- pets directly: WalkSpeed and paint radius in the round, Luck for egg odds,
-- the coin multiplier for rewards, bat Power for knockback, and the team
-- balance weight.
-- Arena power-ups add a temporary speed boost on top (outside the pet cap).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArenaConfig = require(ReplicatedStorage.Shared.Config.ArenaConfig)
local PetConfig = require(ReplicatedStorage.Shared.Config.PetConfig)
local StatCalculator = require(ReplicatedStorage.Shared.Logic.StatCalculator)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local Types = require(ReplicatedStorage.Shared.Types)
local PetService = require(script.Parent.PetService)

local StatsService = {}

StatsService.StatsChanged = Signal.new() :: Signal.Signal<Player, Types.Stats>

local cache: { [Player]: Types.Stats } = {}
local speedBoost: { [Player]: { Multiplier: number, Ends: number } } = {}

local function recalculate(player: Player)
	if player.Parent ~= Players then
		cache[player] = nil
		return
	end
	local stats = StatCalculator.Totals(PetService:GetEquipped(player) :: any, PetConfig :: any)
	cache[player] = stats
	StatsService.StatsChanged:Fire(player, stats)
end

-- Connected in Init: PetService starts first and may already publish pets
-- for profiles that loaded early.
function StatsService:Init()
	PetService.EquippedChanged:Connect(recalculate)
end

function StatsService:Start()
	Players.PlayerRemoving:Connect(function(player)
		cache[player] = nil
		speedBoost[player] = nil
	end)
end

function StatsService:GetStats(player: Player): Types.Stats
	return cache[player] or StatCalculator.Zero()
end

function StatsService:GetWalkSpeed(player: Player): number
	local speed = ArenaConfig.BaseWalkSpeed * (1 + StatsService:GetStats(player).Speed)
	local boost = speedBoost[player]
	if boost and os.clock() < boost.Ends then
		speed *= boost.Multiplier
	end
	return speed
end

-- Temporary multiplier on top of pets (the Speed power-up). The caller
-- applies the new WalkSpeed to the humanoid.
function StatsService:SetSpeedBoost(player: Player, multiplier: number, seconds: number)
	speedBoost[player] = { Multiplier = multiplier, Ends = os.clock() + seconds }
end

function StatsService:ClearSpeedBoost(player: Player)
	speedBoost[player] = nil
end

function StatsService:GetPaintRadius(player: Player): number
	return ArenaConfig.BasePaintRadius * (1 + StatsService:GetStats(player).PaintRadius)
end

function StatsService:GetLuck(player: Player): number
	return StatsService:GetStats(player).Luck
end

-- 1 + Coins bonus; Reward.Coins applies the overall multiplier cap.
function StatsService:GetCoinMultiplier(player: Player): number
	return 1 + StatsService:GetStats(player).Coins
end

-- Bat Power bonus (0 = base knockback).
function StatsService:GetPower(player: Player): number
	return StatsService:GetStats(player).Power
end

-- How strong the player's pets make them, for team balance.
function StatsService:GetTeamWeight(player: Player): number
	return StatCalculator.TeamWeight(StatsService:GetStats(player))
end

return StatsService
