--!strict
-- A player's final bonuses from equipped pets, capped (docs/design.md 4.4).
-- Other services read the numbers they need from here instead of looking at
-- pets directly: WalkSpeed and paint radius in the round, Luck for egg odds,
-- the coin multiplier for rewards and Power for team balance.
-- Stage 3 adds temporary arena power-ups on top of these.

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

local function recalculate(player: Player)
	if player.Parent ~= Players then
		cache[player] = nil
		return
	end
	local stats = StatCalculator.Totals(PetService:GetEquipped(player) :: any, PetConfig :: any)
	cache[player] = stats
	StatsService.StatsChanged:Fire(player, stats)
end

function StatsService:Init() end

function StatsService:Start()
	PetService.EquippedChanged:Connect(recalculate)
	Players.PlayerRemoving:Connect(function(player)
		cache[player] = nil
	end)
end

function StatsService:GetStats(player: Player): Types.Stats
	return cache[player] or StatCalculator.Zero()
end

function StatsService:GetWalkSpeed(player: Player): number
	return ArenaConfig.BaseWalkSpeed * (1 + StatsService:GetStats(player).Speed)
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

function StatsService:GetPower(player: Player): number
	return StatCalculator.Power(StatsService:GetStats(player))
end

return StatsService
