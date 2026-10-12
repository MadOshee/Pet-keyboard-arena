--!strict
-- Pet inventory window: list, equip up to 3, sell with a confirm tap
-- (docs/design.md 4.3 "Питомцы"). Reads the profile mirror and sends only
-- pet ids; the server checks ownership, slots and the round lock. Pets
-- standing on plot platforms are on the plot, not in this list.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EggConfig = require(ReplicatedStorage.Shared.Config.EggConfig)
local PetConfig = require(ReplicatedStorage.Shared.Config.PetConfig)
local PetStyle = require(ReplicatedStorage.Shared.Config.PetStyle)
local Strings = require(ReplicatedStorage.Shared.Config.Strings)
local Incubation = require(ReplicatedStorage.Shared.Logic.Incubation)
local PetIncome = require(ReplicatedStorage.Shared.Logic.PetIncome)
local StatCalculator = require(ReplicatedStorage.Shared.Logic.StatCalculator)
local Types = require(ReplicatedStorage.Shared.Types)
local AssetModels = require(script.Parent.Parent.UI.AssetModels)
local PetText = require(script.Parent.Parent.UI.PetText)
local Widgets = require(script.Parent.Parent.UI.Widgets)
local ClientNet = require(script.Parent.Parent.Util.ClientNet)
local DataController = require(script.Parent.DataController)

local player = Players.LocalPlayer

local CONFIRM_SECONDS = 3

local InventoryController = {}

local gui: ScreenGui
local window: Frame
local titleLabel: TextLabel
local slotsButton: TextButton
local statsLabel: TextLabel
local emptyLabel: TextLabel
local list: ScrollingFrame
local confirmPetId: string? = nil
-- Pet ids and equipped list the cards were last built from; DataSync for
-- coins or offers does not rebuild 50 viewports.
local builtKey: string? = nil
local confirmToken = 0

local function rarityRank(rarity: string): number
	return table.find(PetConfig.Rarities, rarity) or 0
end

local function statsText(profile: Types.Profile): string
	local equipped = {}
	for _, petId in profile.Equipped do
		local pet = profile.Pets[petId]
		if pet then
			table.insert(equipped, pet)
		end
	end
	local stats = StatCalculator.Totals(equipped :: any, PetConfig :: any) :: any
	local parts = {}
	for _, stat in PetConfig.StatOrder do
		if stats[stat] > 0 then
			table.insert(parts, PetText.Bonus(stat, stats[stat]))
		end
	end
	return string.format(Strings.EquippedCount, #equipped, PetConfig.MaxEquipped)
		.. "   "
		.. table.concat(parts, " · ")
end

local function buildCard(petId: string, pet: Types.PetInstance, equipped: boolean, order: number)
	local entry = PetConfig.Pets[pet.Kind]
	local rarityColor = PetStyle.Rarity[pet.Rarity] or Color3.new(1, 1, 1)

	local card = Instance.new("Frame")
	card.Name = petId
	card.LayoutOrder = order
	card.BackgroundColor3 = if equipped
		then Color3.fromRGB(60, 74, 60)
		else Color3.fromRGB(52, 56, 80)
	card.Parent = list
	Widgets.Corner(card, 0.08)
	Widgets.Stroke(card, rarityColor, if equipped then 3 else 1.5)

	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(0.9, 0.42)
	holder.Position = UDim2.fromScale(0.05, 0.02)
	holder.Parent = card
	AssetModels.Viewport(holder, AssetModels.Pet(pet.Kind), rarityColor)

	local name =
		Widgets.Label("Name", card, UDim2.fromScale(0.9, 0.12), UDim2.fromScale(0.05, 0.44))
	name.Text = if entry then entry.Name else pet.Kind
	local rarity =
		Widgets.Label("Rarity", card, UDim2.fromScale(0.9, 0.09), UDim2.fromScale(0.05, 0.56))
	rarity.Text = (Strings.Rarity :: any)[pet.Rarity] or pet.Rarity
	rarity.TextColor3 = rarityColor
	local bonus =
		Widgets.Label("Bonus", card, UDim2.fromScale(0.9, 0.09), UDim2.fromScale(0.05, 0.65))
	bonus.Text = table.concat(PetText.BuffLines(pet.Kind), " ")

	local equipButton = Widgets.Button(
		"Equip",
		card,
		UDim2.fromScale(0.9, 0.11),
		UDim2.fromScale(0.05, 0.75),
		if equipped then Color3.fromRGB(150, 90, 90) else Color3.fromRGB(64, 170, 90)
	)
	equipButton.Text = if equipped then Strings.Unequip else Strings.Equip
	equipButton.Activated:Connect(function()
		ClientNet.Fire("PetEquip", petId, not equipped)
	end)

	if not equipped then
		local sellButton = Widgets.Button(
			"Sell",
			card,
			UDim2.fromScale(0.9, 0.1),
			UDim2.fromScale(0.05, 0.88),
			Color3.fromRGB(110, 100, 90)
		)
		local price = PetConfig.SellValue[pet.Rarity] or 0
		sellButton.Text = if confirmPetId == petId
			then Strings.ConfirmSell
			else string.format(Strings.Sell, price)
		sellButton.Activated:Connect(function()
			if confirmPetId == petId then
				confirmPetId = nil
				ClientNet.Fire("PetSell", petId)
				return
			end
			-- First tap only asks to confirm, so a misclick never sells a pet.
			confirmPetId = petId
			sellButton.Text = Strings.ConfirmSell
			confirmToken += 1
			local token = confirmToken
			task.delay(CONFIRM_SECONDS, function()
				if token == confirmToken and confirmPetId == petId then
					confirmPetId = nil
					if sellButton.Parent then
						sellButton.Text = string.format(Strings.Sell, price)
					end
				end
			end)
		end)
	end
end

local function refresh(profile: Types.Profile?)
	if profile == nil or not window.Visible then
		return
	end
	local data = profile :: Types.Profile

	local placed = PetIncome.PlacedPets(data.Incubators :: any)
	local ids = {}
	for petId in data.Pets do
		if placed[petId] == nil then
			table.insert(ids, petId)
		end
	end
	-- Equipped first, then rarest, then newest.
	table.sort(ids, function(a, b)
		local equippedA = table.find(data.Equipped, a) ~= nil
		local equippedB = table.find(data.Equipped, b) ~= nil
		if equippedA ~= equippedB then
			return equippedA
		end
		local petA, petB = data.Pets[a], data.Pets[b]
		if petA.Rarity ~= petB.Rarity then
			return rarityRank(petA.Rarity) > rarityRank(petB.Rarity)
		end
		if petA.ObtainedAt ~= petB.ObtainedAt then
			return petA.ObtainedAt > petB.ObtainedAt
		end
		return a < b
	end)

	local key = table.concat(ids, ",") .. "|" .. table.concat(data.Equipped, ",")
	if key ~= builtKey then
		builtKey = key
		for _, child in list:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		for order, petId in ids do
			buildCard(petId, data.Pets[petId], table.find(data.Equipped, petId) ~= nil, order)
		end
	end

	local eggCount = 0
	for _ in data.Eggs do
		eggCount += 1
	end
	titleLabel.Text = string.format(Strings.PetsTitle, #ids, data.PetCapacity)
		.. "   "
		.. string.format(Strings.EggsCount, eggCount, data.EggCapacity)
	slotsButton.Text = string.format(
		Strings.BuyPetSlots,
		EggConfig.PetSlotsStep,
		Incubation.NextPetSlotsPrice(data.PetCapacity, PetConfig.StartCapacity, EggConfig)
	)
	statsLabel.Text = statsText(data)
	emptyLabel.Visible = #ids == 0
end

local function build()
	gui = Widgets.ScreenGui("Inventory", 3)

	local toggle = Widgets.MenuButton(
		"PetsButton",
		Strings.PetsButton,
		"Index",
		Color3.fromRGB(40, 150, 255),
		2
	)

	window = Widgets.Panel(
		"Window",
		gui,
		UDim2.fromScale(0.72, 0.72),
		UDim2.fromScale(0.5, 0.5),
		Color3.fromRGB(30, 120, 230)
	)
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.Visible = false
	Widgets.AspectRatio(window, 1.6)

	titleLabel =
		Widgets.Label("Title", window, UDim2.fromScale(0.6, 0.08), UDim2.fromScale(0.03, 0.025))
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	local close = Widgets.Button(
		"Close",
		window,
		UDim2.fromScale(0.07, 0.09),
		UDim2.fromScale(0.91, 0.02),
		Color3.fromRGB(200, 70, 70)
	)
	close.Text = "X"
	slotsButton = Widgets.Button(
		"BuySlots",
		window,
		UDim2.fromScale(0.25, 0.08),
		UDim2.fromScale(0.64, 0.025),
		Color3.fromRGB(230, 160, 40)
	)
	slotsButton.Activated:Connect(function()
		ClientNet.Fire("BuyUpgrade", "PetSlots")
	end)
	statsLabel =
		Widgets.Label("Stats", window, UDim2.fromScale(0.94, 0.055), UDim2.fromScale(0.03, 0.12))
	statsLabel.TextXAlignment = Enum.TextXAlignment.Left
	statsLabel.TextColor3 = Color3.fromRGB(200, 220, 255)

	list = Instance.new("ScrollingFrame")
	list.Name = "List"
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Size = UDim2.fromScale(0.94, 0.78)
	list.Position = UDim2.fromScale(0.03, 0.2)
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.ScrollBarThickness = 8
	list.Parent = window
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromScale(0.18, 0)
	grid.CellPadding = UDim2.fromScale(0.02, 0.02)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = list
	local cellRatio = Instance.new("UIAspectRatioConstraint")
	cellRatio.AspectRatio = 0.62
	cellRatio.Parent = grid

	emptyLabel =
		Widgets.Label("Empty", window, UDim2.fromScale(0.8, 0.08), UDim2.fromScale(0.1, 0.45))
	emptyLabel.Text = Strings.NoPets

	toggle.Activated:Connect(function()
		InventoryController:Toggle()
	end)
	close.Activated:Connect(function()
		window.Visible = false
	end)

	gui.Parent = player:WaitForChild("PlayerGui")
end

-- Opens or closes the pets window (PETS button, the pack's Backpack button).
function InventoryController:Toggle()
	window.Visible = not window.Visible
	builtKey = nil
	refresh(DataController:Get())
end

function InventoryController:Init()
	build()
end

function InventoryController:Start()
	DataController.Changed:Connect(refresh)
end

return InventoryController
