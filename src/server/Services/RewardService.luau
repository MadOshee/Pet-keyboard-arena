--!strict
-- Pays out after each round (docs/design.md 4.5): coins (with the pet Coins
-- multiplier) and an egg offer whose odds depend on the outcome, the
-- player's share of their team's painting and pet Luck. Listens to
-- RoundService.RoundEnded, so a reward is tied to one RoundId and can only
-- be granted once per participant.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RoundConfig = require(ReplicatedStorage.Shared.Config.RoundConfig)
local Reward = require(ReplicatedStorage.Shared.Logic.Reward)
local Types = require(ReplicatedStorage.Shared.Types)
local EggService = require(script.Parent.EggService)
local NetService = require(script.Parent.NetService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local ReadyService = require(script.Parent.ReadyService)
local RoundService = require(script.Parent.RoundService)
local StatsService = require(script.Parent.StatsService)

local RewardService = {}

local lastRewardedRound: { [Player]: number } = {}

local function rewardParticipant(
	player: Player,
	team: Types.TeamId,
	result: RoundService.RoundResult,
	bestOnTeam: number
)
	if player.Parent ~= Players or (lastRewardedRound[player] or 0) >= result.RoundId then
		return
	end
	lastRewardedRound[player] = result.RoundId

	local keys = result.KeysPainted[player] or 0
	local outcome: Types.Outcome = Reward.OutcomeFor(team, result.Winner)
	local rewarded = keys >= RoundConfig.MinKeysForReward
	local multiplier = StatsService:GetCoinMultiplier(player)
	local coins = if rewarded then Reward.Coins(outcome, keys, multiplier, RoundConfig.Coins) else 0

	PlayerDataService:Update(player, function(data)
		data.Stats.RoundsPlayed += 1
		data.Stats.KeysPainted += keys
		if outcome == "Win" then
			data.Stats.Wins += 1
		end
		data.Coins += coins
	end)

	if rewarded then
		EggService:CreateOffer(player, {
			Outcome = outcome,
			ContributionPct = Reward.ContributionPct(keys, bestOnTeam),
			Luck = StatsService:GetLuck(player),
		})
	else
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
		local bestRed, bestBlue = 0, 0
		for player: Player, team: Types.TeamId in result.Teams do
			local keys = result.KeysPainted[player] or 0
			if team == "Red" then
				bestRed = math.max(bestRed, keys)
			else
				bestBlue = math.max(bestBlue, keys)
			end
		end
		for player: Player, team: Types.TeamId in result.Teams do
			rewardParticipant(player, team, result, if team == "Red" then bestRed else bestBlue)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastRewardedRound[player] = nil
	end)
end

return RewardService
