--!strict
-- Who owns which Game Pass (docs/design.md 4.6). Checked once on join and
-- updated when a pass is bought in game. Mirrored to Player attributes
-- "Pass_<name>" for the client. Other services only ask Owns(); the passes'
-- effects live where the rules are (EggService, RewardService,
-- MonetizationService).

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShopConfig = require(ReplicatedStorage.Shared.Config.ShopConfig)
local Purchases = require(ReplicatedStorage.Shared.Logic.Purchases)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)

local CHECK_ATTEMPTS = 4

local GamePassService = {}

-- (player, pass name) when a player gains a pass.
GamePassService.PassAdded = Signal.new() :: Signal.Signal<Player, string>

local owned: { [Player]: { [string]: boolean } } = {}

local function grant(player: Player, key: string)
	local passes = owned[player]
	if passes == nil or passes[key] then
		return
	end
	passes[key] = true
	player:SetAttribute(`Pass_{key}`, true)
	GamePassService.PassAdded:Fire(player, key)
end

local function check(player: Player)
	owned[player] = {}
	for key, pass in ShopConfig.GamePasses do
		if pass.Id ~= 0 then
			task.spawn(function()
				-- Retry with backoff: a failed web call must not cost a paid pass.
				for attempt = 1, CHECK_ATTEMPTS do
					local ok, result = pcall(function()
						return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.Id)
					end)
					if ok then
						if result and player.Parent == Players then
							grant(player, key)
						end
						return
					end
					if player.Parent ~= Players then
						return
					end
					task.wait(2 ^ attempt)
				end
			end)
		end
	end
end

function GamePassService:Init() end

function GamePassService:Start()
	Players.PlayerAdded:Connect(check)
	for _, player in Players:GetPlayers() do
		check(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		owned[player] = nil
	end)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		local key = Purchases.KeyForId(ShopConfig.GamePasses :: any, passId)
		if key then
			grant(player, key :: string)
		end
	end)
end

function GamePassService:Owns(player: Player, key: string): boolean
	local passes = owned[player]
	return passes ~= nil and passes[key] == true
end

return GamePassService
