--!strict
-- A player's final bonuses from equipped pets, capped (docs/design.md 4.4).
-- Other services read the numbers they need from here instead of looking at
-- pets directly: WalkSpeed and paint radius in the round, Luck for egg odds,
-- the coin multiplier for rewards, bat Power for knockback, and the team
-- balance weight.
-- Arena power-ups add a temporary speed boost on top (outside the pet cap).
-- The player's level adds +1% per level to every stat, also outside the pet
-- caps (Logic/Levels).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArenaConfig = require(ReplicatedStorage.Shared.Config.ArenaConfig)
local PetConfig = require(ReplicatedStorage.Shared.Config.PetConfig)
local RoundConfig = require(ReplicatedStorage.Shared.Config.RoundConfig)
local Levels = require(ReplicatedStorage.Shared.Logic.Levels)
local StatCalculator = require(ReplicatedStorage.Shared.Logic.StatCalculator)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local Types = require(ReplicatedStorage.Shared.Types)
local PetService = require(script.Parent.PetService)
local PlayerDataService = require(script.Parent.PlayerDataService)

local StatsService = {}

StatsService.StatsChanged = Signal.new() :: Signal.Signal<Player, Types.Stats>

local cache: { [Player]: Types.Stats } = {}
local speedBoost: { [Player]: { Multiplier: number, Ends: number } } = {}
local levelBonus: { [Player]: number } = {}
local levels: { [Player]: number } = {}

StatsService.LevelChanged = Signal.new() :: Signal.Signal<Player, number>

local function updateLevel(player: Player, data: Types.Profile)
	local level = Levels.FromXP(data.XP or 0, RoundConfig.Levels).Level
	levelBonus[player] = Levels.Bonus(level, RoundConfig.Levels)
	if levels[player] ~= level then
		levels[player] = level
		StatsService.LevelChanged:Fire(player, level)
	end
end

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
	PlayerDataService.ProfileLoaded:Connect(updateLevel)
	PlayerDataService.Changed:Connect(updateLevel)
end

function StatsService:Start()
	Players.PlayerRemoving:Connect(function(player)
		cache[player] = nil
		speedBoost[player] = nil
		levelBonus[player] = nil
		levels[player] = nil
	end)
end

function StatsService:GetStats(player: Player): Types.Stats
	return cache[player] or StatCalculator.Zero()
end

-- The player's level from XP (1 until the profile loads).
function StatsService:GetLevel(player: Player): number
	return levels[player] or 1
end

-- +1% to every stat per level above 1, as a fraction.
function StatsService:GetLevelBonus(player: Player): number
	return levelBonus[player] or 0
end

function StatsService:GetWalkSpeed(player: Player): number
	local speed = ArenaConfig.BaseWalkSpeed
		* (1 + StatsService:GetStats(player).Speed + StatsService:GetLevelBonus(player))
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
	return ArenaConfig.BasePaintRadius
		* (1 + StatsService:GetStats(player).PaintRadius + StatsService:GetLevelBonus(player))
end

function StatsService:GetLuck(player: Player): number
	return StatsService:GetStats(player).Luck + StatsService:GetLevelBonus(player)
end

-- 1 + Coins bonus; Reward.Coins applies the overall multiplier cap.
function StatsService:GetCoinMultiplier(player: Player): number
	return 1 + StatsService:GetStats(player).Coins
end

-- Bat Power bonus (0 = base knockback).
function StatsService:GetPower(player: Player): number
	return StatsService:GetStats(player).Power + StatsService:GetLevelBonus(player)
end

-- How much stronger than a new player the pets and the level make them,
-- for team balance (Ivan 2026-10-14: pet bonuses and level). The pets give
-- Speed + Area + Power; each level above 1 adds RoundConfig.LevelWeight.
function StatsService:GetTeamWeight(player: Player): number
	return StatCalculator.TeamWeight(StatsService:GetStats(player))
		+ RoundConfig.LevelWeight * (StatsService:GetLevel(player) - 1)
end

return StatsService
