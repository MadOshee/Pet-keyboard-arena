--!strict
-- Pays out after each round (docs/design.md 4.5): coins (with the pet Coins
-- multiplier and the 2x pass), XP and an egg offer whose odds depend on the outcome, the
-- player's share of their team's painting, pet Luck and the luck potion. Listens to
-- RoundService.RoundEnded, so a reward is tied to one RoundId and can only
-- be granted once per participant.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PetConfig = require(ReplicatedStorage.Shared.Config.PetConfig)
local RoundConfig = require(ReplicatedStorage.Shared.Config.RoundConfig)
local ShopConfig = require(ReplicatedStorage.Shared.Config.ShopConfig)
local Purchases = require(ReplicatedStorage.Shared.Logic.Purchases)
local Reward = require(ReplicatedStorage.Shared.Logic.Reward)
local Types = require(ReplicatedStorage.Shared.Types)
local EggService = require(script.Parent.EggService)
local GamePassService = require(script.Parent.GamePassService)
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
	local xp = if rewarded then Reward.XP(outcome, keys, RoundConfig.XP) else 0
	-- The 2x pass doubles the final sum (design 4.5).
	if GamePassService:Owns(player, "DoubleCoins") then
		coins *= ShopConfig.DoubleCoinsMultiplier
	end
	local luck = StatsService:GetLuck(player)
	local usePotion = false

	PlayerDataService:Update(player, function(data)
		-- One luck potion charge per rewarded offer.
		if rewarded and data.LuckPotionOffers > 0 then
			data.LuckPotionOffers -= 1
			usePotion = true
		end
		data.Stats.RoundsPlayed += 1
		data.Stats.KeysPainted += keys
		if outcome == "Win" then
			data.Stats.Wins += 1
		end
		data.Coins += coins
		data.XP += xp
	end)

	if usePotion then
		luck = Purchases.LuckWithPotion(luck, ShopConfig.LuckPotionBonus, PetConfig.Caps.Luck)
	end

	if rewarded then
		EggService:CreateOffer(player, {
			Outcome = outcome,
			ContributionPct = Reward.ContributionPct(keys, bestOnTeam),
			Luck = luck,
		})
	else
		ReadyService:SetReady(player, false)
	end

	local payload: Types.RoundResultPayload = {
		Outcome = outcome,
		Winner = result.Winner,
		KeysPainted = keys,
		Coins = coins,
		XP = xp,
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
			-- An error for one player must not skip everyone after them.
			local ok, err = pcall(function()
				rewardParticipant(player, team, result, if team == "Red" then bestRed else bestBlue)
			end)
			if not ok then
				warn(`[RewardService] reward failed for {player.UserId}: {err}`)
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastRewardedRound[player] = nil
	end)
end

return RewardService
