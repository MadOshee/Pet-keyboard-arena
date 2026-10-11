--!strict
-- Developer Products through ProcessReceipt, and the VIP pass extras
-- (docs/design.md 4.6, section 10). Every grant goes through
-- PlayerDataService:GrantPurchase, which records the purchase id in the same
-- update and confirms to Roblox only after a save, so a product is given
-- exactly once even if Roblox repeats the receipt.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShopConfig = require(ReplicatedStorage.Shared.Config.ShopConfig)
local Purchases = require(ReplicatedStorage.Shared.Logic.Purchases)
local Types = require(ReplicatedStorage.Shared.Types)
local EggService = require(script.Parent.EggService)
local GamePassService = require(script.Parent.GamePassService)
local PlayerDataService = require(script.Parent.PlayerDataService)

local VIP_TAG_NAME = "VipTag"

local MonetizationService = {}

-- What each product does to the profile. Runs inside one profile update.
local GRANTS: { [string]: (data: Types.Profile) -> () } = {
	SpeedUpEgg = function(data)
		EggService:GrantSpeedUp(data)
	end,
	Reroll = function(data)
		data.FreeRerolls += 1
	end,
	LuckPotion = function(data)
		data.LuckPotionOffers += ShopConfig.LuckPotionOffers
	end,
}

local function grantFor(key: string): ((data: Types.Profile) -> ())?
	local grant = GRANTS[key]
	if grant then
		return grant
	end
	local coins = ShopConfig.Products[key] and ShopConfig.Products[key].Coins
	if coins then
		return function(data)
			data.Coins += coins :: number
		end
	end
	return nil
end

local function processReceipt(receipt: any): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if player == nil then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local key = Purchases.KeyForId(ShopConfig.Products :: any, receipt.ProductId)
	local grant = key and grantFor(key :: string)
	if grant == nil then
		warn(`[Monetization] unknown product {receipt.ProductId}`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return PlayerDataService:GrantPurchase(player, receipt.PurchaseId, grant :: any)
end

local function addVipTag(player: Player, character: Model)
	local head = character:WaitForChild("Head", 10)
	if head == nil or head:FindFirstChild(VIP_TAG_NAME) then
		return
	end
	local tag = Instance.new("BillboardGui")
	tag.Name = VIP_TAG_NAME
	tag.Size = UDim2.fromScale(2.2, 0.8)
	tag.StudsOffset = Vector3.new(0, 2.2, 0)
	tag.MaxDistance = 80
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = "VIP"
	label.TextColor3 = Color3.fromRGB(255, 210, 60)
	label.TextStrokeTransparency = 0.3
	label.Parent = tag
	tag.Parent = head
	if player.Parent ~= Players then
		tag:Destroy()
	end
end

local function applyVip(player: Player)
	EggService:GrantVipIncubator(player)
	if player.Character then
		task.spawn(addVipTag, player, player.Character)
	end
end

function MonetizationService:Init() end

function MonetizationService:Start()
	MarketplaceService.ProcessReceipt = processReceipt

	GamePassService.PassAdded:Connect(function(player, key)
		if key == "VIP" and PlayerDataService:IsLoaded(player) then
			applyVip(player)
		end
	end)
	-- The pass check and the profile load can finish in either order.
	PlayerDataService.ProfileLoaded:Connect(function(player)
		if GamePassService:Owns(player, "VIP") then
			applyVip(player)
		end
	end)
	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character)
			if GamePassService:Owns(player, "VIP") then
				addVipTag(player, character)
			end
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
end

return MonetizationService
