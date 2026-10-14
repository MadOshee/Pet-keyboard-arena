--!strict
-- Developer Products through ProcessReceipt, and the VIP pass extras
-- (docs/design.md 4.6, section 10). Server Luck also goes to every player
-- on the server and to those who join while it runs. Every grant goes through
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
-- Workspace attribute: os.time when this server's Server Luck ends.
local SERVER_LUCK_ATTRIBUTE = "ServerLuckUntil"

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
	-- The buyer's own share; everyone else on the server gets it in
	-- startServerLuck once the purchase is saved.
	ServerLuck = function(data)
		local now = os.time()
		data.ServerLuckUntil = math.max(data.ServerLuckUntil, now) + ShopConfig.ServerLuckSeconds
	end,
}

-- Server Luck receipts already shared out on this server, so a replayed
-- receipt does not add another 15 minutes.
local sharedLuck: { [string]: true } = {}

local function serverLuckUntil(): number
	local value = workspace:GetAttribute(SERVER_LUCK_ATTRIBUTE)
	return if type(value) == "number" then value else 0
end

-- Gives a player the server's running Server Luck. Saved in the profile, so
-- it goes with them to the arena server and the round's egg offer.
local function shareServerLuck(player: Player)
	local ends = serverLuckUntil()
	if ends <= os.time() or not PlayerDataService:IsLoaded(player) then
		return
	end
	PlayerDataService:Update(player, function(data)
		data.ServerLuckUntil = math.max(data.ServerLuckUntil, ends)
	end)
end

-- Server Luck (Ivan 2026-10-14): x2 luck for everyone on this server for
-- ShopConfig.ServerLuckSeconds, added on top of a running one.
local function startServerLuck(purchaseId: string)
	if sharedLuck[purchaseId] then
		return
	end
	sharedLuck[purchaseId] = true
	local now = os.time()
	workspace:SetAttribute(
		SERVER_LUCK_ATTRIBUTE,
		math.max(serverLuckUntil(), now) + ShopConfig.ServerLuckSeconds
	)
	for _, player in Players:GetPlayers() do
		shareServerLuck(player)
	end
end

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
	local decision = PlayerDataService:GrantPurchase(player, receipt.PurchaseId, grant :: any)
	if key == "ServerLuck" and decision == Enum.ProductPurchaseDecision.PurchaseGranted then
		startServerLuck(receipt.PurchaseId)
	end
	return decision
end

local function addVipTag(player: Player, character: Model)
	local head = character:WaitForChild("Head", 10)
	if head == nil or head:FindFirstChild(VIP_TAG_NAME) then
		return
	end
	local tag = Instance.new("BillboardGui")
	tag.Name = VIP_TAG_NAME
	tag.Size = UDim2.fromScale(2.2, 0.8)
	-- Above the name and level tag (Util/Nameplate).
	tag.StudsOffset = Vector3.new(0, 4, 0)
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
		-- Joining while Server Luck runs counts too.
		shareServerLuck(player)
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
