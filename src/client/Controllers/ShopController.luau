--!strict
-- Shop window (docs/design.md 4.5-4.6). Coin upgrades: the next incubator
-- and more pet slots, priced with the same Incubation math the server uses.
-- Robux items: Game Passes and Developer Products from ShopConfig; items
-- with id 0 are not created yet and show SOON. The client only opens the
-- Roblox purchase prompt; the server grants the item (MonetizationService).
-- Also wires the pack's Shop window (Ivan 2026-10-14): Server Luck, X2 Money
-- and X2 Luck, buyable; the pack's crate and starter pack blocks are
-- removed (Ivan 2026-10-14).

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EggConfig = require(ReplicatedStorage.Shared.Config.EggConfig)
local PetConfig = require(ReplicatedStorage.Shared.Config.PetConfig)
local ShopConfig = require(ReplicatedStorage.Shared.Config.ShopConfig)
local Strings = require(ReplicatedStorage.Shared.Config.Strings)
local Incubation = require(ReplicatedStorage.Shared.Logic.Incubation)
local Purchases = require(ReplicatedStorage.Shared.Logic.Purchases)
local Types = require(ReplicatedStorage.Shared.Types)
local Money = require(ReplicatedStorage.Shared.Util.Money)
local Widgets = require(script.Parent.Parent.UI.Widgets)
local ClientNet = require(script.Parent.Parent.Util.ClientNet)
local DataController = require(script.Parent.DataController)
local PackUiController = require(script.Parent.PackUiController)

local player = Players.LocalPlayer

local ROW_HEIGHT = 0.16
local GREEN = Color3.fromRGB(64, 170, 90)
local GREY = Color3.fromRGB(120, 120, 130)
local DARK = Color3.fromRGB(90, 90, 100)
-- The pack Shop's blocks: list order (Ivan: the luck and money ones first)
-- and what each Buy button sells. ExclusiveOffer and StarterPack are removed.
local PACK_ORDER: { [string]: number } = {
	ServerLuck = 1,
	X2Money = 2,
	X2luck = 3,
}
local PACK_REMOVED = { "ExclusiveOffer", "StarterPack" }
type PackItem = { Block: string, Path: { string }, Key: string, IsPass: boolean }
local PACK_ITEMS: { PackItem } = {
	{ Block = "ServerLuck", Path = { "Buttons", "Buy" }, Key = "ServerLuck", IsPass = false },
	{ Block = "X2Money", Path = { "Button", "Buy" }, Key = "DoubleCoins", IsPass = true },
	{ Block = "X2luck", Path = { "Button", "Buy" }, Key = "DoubleLuck", IsPass = true },
}

local ShopController = {}

type Row = {
	Label: TextLabel,
	Button: TextButton,
}

local window: Frame
local list: ScrollingFrame
local incubatorRow: Row
local slotsRow: Row
local passRows: { [string]: Row } = {}
local lastIncubators: number? = nil
local lastCapacity: number? = nil
local rowCount = 0

local function makeRow(name: string, onBuy: () -> ()): Row
	rowCount += 1
	local row = Instance.new("Frame")
	row.Name = name
	row.LayoutOrder = rowCount
	row.Size = UDim2.fromScale(1, ROW_HEIGHT)
	row.BackgroundColor3 = Color3.fromRGB(52, 56, 80)
	row.Parent = list
	Widgets.Corner(row, 0.2)
	local label = Widgets.Label("Text", row, UDim2.fromScale(0.6, 0.8), UDim2.fromScale(0.03, 0.1))
	label.TextXAlignment = Enum.TextXAlignment.Left
	local button =
		Widgets.Button("Buy", row, UDim2.fromScale(0.32, 0.7), UDim2.fromScale(0.65, 0.15), GREEN)
	button.Activated:Connect(onBuy)
	return { Label = label, Button = button }
end

local function makeHeader(text: string)
	rowCount += 1
	local header = Widgets.Label("Header", list, UDim2.fromScale(1, ROW_HEIGHT * 0.7), UDim2.new())
	header.LayoutOrder = rowCount
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.TextColor3 = Color3.fromRGB(180, 200, 255)
	header.Text = text
end

local function setEnabled(row: Row, enabled: boolean, color: Color3)
	row.Button.Active = enabled
	row.Button.AutoButtonColor = enabled
	row.Button.BackgroundColor3 = color
end

local function setCoinPrice(row: Row, price: number?, coins: number)
	if price then
		row.Button.Text = string.format(Strings.ShopBuy, Money.Format(price))
		setEnabled(row, true, if coins >= price then GREEN else GREY)
	else
		row.Button.Text = Strings.ShopMaxed
		setEnabled(row, false, DARK)
	end
end

-- Asks Roblox for the Robux price once and writes it on the button.
local function loadRobuxPrice(row: Row, id: number, infoType: Enum.InfoType)
	task.spawn(function()
		local ok, info = pcall(function()
			return MarketplaceService:GetProductInfo(id, infoType)
		end)
		local price = ok and type(info) == "table" and (info :: any).PriceInRobux
		if type(price) == "number" and row.Button.Active then
			row.Button.Text = string.format(Strings.ShopRobuxPrice, price)
		end
	end)
end

local function refreshPasses()
	for key, row in passRows do
		if player:GetAttribute(`Pass_{key}`) == true then
			row.Button.Text = Strings.ShopOwned
			setEnabled(row, false, DARK)
		end
	end
end

local function refresh(profile: Types.Profile?)
	if profile == nil then
		return
	end
	local data = profile :: Types.Profile
	local owned = #data.Incubators
	-- A purchase went through: more incubators or pet slots than before.
	if
		(lastIncubators ~= nil and owned > (lastIncubators :: number))
		or (lastCapacity ~= nil and data.PetCapacity > (lastCapacity :: number))
	then
		Widgets.PlaySound("Purchase")
	end
	lastIncubators, lastCapacity = owned, data.PetCapacity

	-- The free VIP incubator does not move the price list (EggService).
	local extra = if data.VipIncubator then ShopConfig.VipExtraIncubators else 0
	local incubatorPrice = if owned < EggConfig.MaxIncubators
		then Incubation.NextIncubatorPrice(owned - extra, EggConfig :: any)
		else nil
	incubatorRow.Label.Text = if incubatorPrice
		then string.format(Strings.ShopIncubator, owned + 1, EggConfig.MaxIncubators)
		else Strings.ShopIncubatorMax
	setCoinPrice(incubatorRow, incubatorPrice, data.Coins)

	slotsRow.Label.Text =
		string.format(Strings.ShopPetSlots, EggConfig.PetSlotsStep, data.PetCapacity)
	setCoinPrice(
		slotsRow,
		Incubation.NextPetSlotsPrice(data.PetCapacity, PetConfig.StartCapacity, EggConfig :: any),
		data.Coins
	)
end

local function addRobuxRow(key: string, id: number, isPass: boolean)
	local row = makeRow(key, function()
		if id == 0 then
			return
		end
		if isPass then
			MarketplaceService:PromptGamePassPurchase(player, id)
		else
			MarketplaceService:PromptProductPurchase(player, id)
		end
	end)
	row.Label.Text = (Strings.ShopItems :: any)[key] or key
	if id == 0 then
		row.Button.Text = Strings.ShopSoon
		setEnabled(row, false, DARK)
	else
		row.Button.Text = "R$"
		loadRobuxPrice(row, id, if isPass then Enum.InfoType.GamePass else Enum.InfoType.Product)
	end
	if isPass then
		passRows[key] = row
		player:GetAttributeChangedSignal(`Pass_{key}`):Connect(refreshPasses)
	end
end

local function findPath(root: Instance, path: { string }): Instance?
	local node: Instance? = root
	for _, name in path do
		node = node and (node :: Instance):FindFirstChild(name)
	end
	return node
end

-- The price on a pack Buy button: the pack writes the Robux sign, a space
-- and the number, so only the number changes.
local function setPackPrice(button: Instance, text: string, keepSign: boolean)
	local label = findPath(button, { "Container", "Price" })
	if label and label:IsA("TextLabel") then
		local value = if keepSign then (string.gsub(label.Text, "%d+", text)) else text
		Widgets.SetText(label, value)
	end
end

local function wirePackItem(scrolling: Instance, item: PackItem)
	local block = scrolling:FindFirstChild(item.Block)
	local found = block and findPath(block, item.Path)
	if not (found and found:IsA("GuiButton")) then
		return
	end
	local button = found :: GuiButton
	local entry: any = if item.IsPass
		then ShopConfig.GamePasses[item.Key]
		else ShopConfig.Products[item.Key]
	local id: number = entry.Id
	if entry.Robux then
		setPackPrice(button, tostring(entry.Robux), true)
	end
	if id ~= 0 then
		task.spawn(function()
			local ok, info = pcall(function()
				return MarketplaceService:GetProductInfo(
					id,
					if item.IsPass then Enum.InfoType.GamePass else Enum.InfoType.Product
				)
			end)
			local price = ok and type(info) == "table" and (info :: any).PriceInRobux
			if type(price) == "number" and button.Interactable then
				setPackPrice(button, tostring(price), true)
			end
		end)
	end
	Widgets.AnimatePress(button)
	button.MouseButton1Click:Connect(function()
		Widgets.PlaySound("Click")
		-- Id 0: the item is not created in Creator Hub yet, nothing to buy.
		if id == 0 then
			return
		end
		if item.IsPass then
			MarketplaceService:PromptGamePassPurchase(player, id)
		else
			MarketplaceService:PromptProductPurchase(player, id)
		end
	end)
	if item.IsPass then
		local function owned()
			if player:GetAttribute(`Pass_{item.Key}`) == true then
				setPackPrice(button, Strings.ShopOwned, false)
				button.Interactable = false
			end
		end
		player:GetAttributeChangedSignal(`Pass_{item.Key}`):Connect(owned)
		owned()
	end
end

-- Server Luck's text shows the time left while it runs on this server.
local function watchServerLuck(scrolling: Instance)
	local block = scrolling:FindFirstChild("ServerLuck")
	local desc = block and block:FindFirstChild("Desc")
	if not (desc and desc:IsA("TextLabel")) then
		return
	end
	local label = desc :: TextLabel
	local idle = label.Text
	local shown = ""
	RunService.Heartbeat:Connect(function()
		local ends = workspace:GetAttribute("ServerLuckUntil")
		local left = if type(ends) == "number" then ends - workspace:GetServerTimeNow() else 0
		local text = if left > 0
			then string.format(
				Strings.ShopServerLuckActive,
				string.format("%d:%02d", left // 60, math.floor(left % 60))
			)
			else idle
		if text ~= shown then
			shown = text
			label.Text = text
		end
	end)
end

local function wirePackShop()
	local shopWindow = PackUiController:GetWindow("Shop")
	local scrolling = shopWindow and shopWindow:FindFirstChild("Scrolling")
	if scrolling == nil then
		return
	end
	local blocks = scrolling :: Instance
	for name, order in PACK_ORDER do
		local block = blocks:FindFirstChild(name)
		if block and block:IsA("GuiObject") then
			block.LayoutOrder = order
		end
	end
	for _, name in PACK_REMOVED do
		local block = blocks:FindFirstChild(name)
		if block then
			block:Destroy()
		end
	end
	-- The pack's canvas is twice the window high for all five blocks; with
	-- three left it would scroll into empty space, so it follows the blocks.
	if blocks:IsA("ScrollingFrame") then
		blocks.CanvasSize = UDim2.new(blocks.CanvasSize.X, UDim.new(0, 0))
		blocks.AutomaticCanvasSize = Enum.AutomaticSize.Y
	end
	for _, item in PACK_ITEMS do
		wirePackItem(blocks, item)
	end
	watchServerLuck(blocks)
end

function ShopController:Init()
	local gui = Widgets.ScreenGui("Shop", 3)

	local toggle =
		Widgets.MenuButton("ShopButton", Strings.ShopButton, "Shop", Color3.fromRGB(255, 40, 90), 1)

	window = Widgets.Panel(
		"Window",
		gui,
		UDim2.fromScale(0.46, 0.66),
		UDim2.fromScale(0.5, 0.5),
		Color3.fromRGB(230, 40, 60)
	)
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.Visible = false
	Widgets.AspectRatio(window, 1.1)

	local title =
		Widgets.Label("Title", window, UDim2.fromScale(0.7, 0.09), UDim2.fromScale(0.04, 0.03))
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = Strings.ShopTitle
	local close = Widgets.Button(
		"Close",
		window,
		UDim2.fromScale(0.09, 0.09),
		UDim2.fromScale(0.88, 0.03),
		Color3.fromRGB(200, 70, 70)
	)
	close.Text = "X"

	list = Instance.new("ScrollingFrame")
	list.Name = "List"
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Size = UDim2.fromScale(0.92, 0.82)
	list.Position = UDim2.fromScale(0.04, 0.15)
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.ScrollBarThickness = 8
	list.Parent = window
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0.015, 0)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	incubatorRow = makeRow("Incubator", function()
		ClientNet.Fire("BuyUpgrade", "Incubator")
	end)
	slotsRow = makeRow("PetSlots", function()
		ClientNet.Fire("BuyUpgrade", "PetSlots")
	end)
	makeHeader(Strings.ShopRobuxHeader)
	for _, key in Purchases.Sorted(ShopConfig.GamePasses :: any) do
		addRobuxRow(key, ShopConfig.GamePasses[key].Id, true)
	end
	for _, key in Purchases.Sorted(ShopConfig.Products :: any) do
		addRobuxRow(key, ShopConfig.Products[key].Id, false)
	end
	refreshPasses()

	toggle.Activated:Connect(function()
		window.Visible = not window.Visible
		if window.Visible then
			refresh(DataController:Get())
		end
	end)
	close.Activated:Connect(function()
		window.Visible = false
	end)
	-- The shop works only in the lobby, like the other plot buttons.
	local function updateVisible()
		local inLobby = player:GetAttribute("Team") == nil
		toggle.Visible = inLobby
		if not inLobby then
			window.Visible = false
		end
	end
	player:GetAttributeChangedSignal("Team"):Connect(updateVisible)
	updateVisible()

	gui.Parent = player:WaitForChild("PlayerGui")
end

function ShopController:Start()
	wirePackShop()
	DataController.Changed:Connect(refresh)
	refresh(DataController:Get())
end

return ShopController
