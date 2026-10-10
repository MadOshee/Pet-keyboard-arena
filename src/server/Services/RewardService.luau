--!strict
-- Pays out after each round (docs/design.md 4.5). Listens to
-- RoundService.RoundEnded, so a reward is tied to one RoundId and can only
-- be granted once per participant.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RoundConfig = require(ReplicatedStorage.Shared.Config.RoundConfig)
local Reward = require(ReplicatedStorage.Shared.Logic.Reward)
local Types = require(ReplicatedStorage.Shared.Types)
local NetService = require(script.Parent.NetService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local ReadyService = require(script.Parent.ReadyService)
local RoundService = require(script.Parent.RoundService)

local RewardService = {}

local lastRewardedRound: { [Player]: number } = {}

local function rewardParticipant(
	player: Player,
	team: Types.TeamId,
	result: RoundService.RoundResult
)
	if player.Parent ~= Players or (lastRewardedRound[player] or 0) >= result.RoundId then
		return
	end
	lastRewardedRound[player] = result.RoundId

	local keys = result.KeysPainted[player] or 0
	local outcome: Types.Outcome = Reward.OutcomeFor(team, result.Winner)
	local rewarded = keys >= RoundConfig.MinKeysForReward
	-- Stage 2 feeds pet Coins bonuses into the multiplier.
	local coins = if rewarded then Reward.Coins(outcome, keys, 1, RoundConfig.Coins) else 0

	PlayerDataService:Update(player, function(data)
		data.Stats.RoundsPlayed += 1
		data.Stats.KeysPainted += keys
		if outcome == "Win" then
			data.Stats.Wins += 1
		end
		data.Coins += coins
	end)

	if not rewarded then
		ReadyService:SetReady(player, false)
	end

	local payload: Types.RoundResultPayload = {
		Outcome = outcome,
		KeysPainted = keys,
		Coins = coins,
		Rewarded = rewarded,
	}
	NetService:FireClient("RoundResult", player, payload)
end

function RewardService:Init() end

function RewardService:Start()
	RoundService.RoundEnded:Connect(function(result)
		for player: Player, team: Types.TeamId in result.Teams do
			rewardParticipant(player, team, result)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastRewardedRound[player] = nil
	end)
end

return RewardService
