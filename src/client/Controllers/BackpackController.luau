--!strict
-- Backpack window (Ivan, 2026-10-12): a pack window with three tabs on its
-- right. Bats: the bat every player swings in a round and the knockback
-- their equipped pets add (Power). Eggs: eggs in storage, which the player
-- puts on plot platforms. Traits: not made yet. Read-only: nothing here
-- talks to the server.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EggConfig = require(ReplicatedStorage.Shared.Config.EggConfig)
local PetConfig = require(ReplicatedStorage.Shared.Config.PetConfig)
local PetStyle = require(ReplicatedStorage.Shared.Config.PetStyle)
local Strings = require(ReplicatedStorage.Shared.Config.Strings)
local StatCalculator = require(ReplicatedStorage.Shared.Logic.StatCalculator)
local Types = require(ReplicatedStorage.Shared.Types)
local AssetModels = require(script.Parent.Parent.UI.AssetModels)
local Widgets = require(script.Parent.Parent.UI.Widgets)
local DataController = require(script.Parent.DataController)
local PackUiController = require(script.Parent.PackUiController)

local WINDOW_NAME = "Backpack"
local TABS = { "Bats", "Eggs", "Traits" }
local CELL_WIDTH = 0.18
local CELL_RATIO = 0.85 -- width / height

local WHITE = Color3.new(1, 1, 1)
local TAB_OUTLINE = Color3.fromRGB(39, 34, 0)
local BAT_COLOR = Color3.fromRGB(200, 140, 70)

local BackpackController = {}

local list: ScrollingFrame
local infoLabel: TextLabel
local tabButtons: { [string]: GuiButton } = {}
local tab = "Bats"
-- What the cards were last built from, so coin updates do not rebuild them.
local builtKey: string? = nil

local function cardHolder(card: Frame): Frame
	local holder = Instance.new("Frame")
	holder.Name = "Holder"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(0.9, 0.56)
	holder.Position = UDim2.fromScale(0.05, 0.22)
	holder.Parent = card
	return holder
end

local function footer(card: Frame, text: string, color: Color3)
	local label =
		Widgets.Label("Footer", card, UDim2.fromScale(0.9, 0.15), UDim2.fromScale(0.05, 0.8))
	label.ZIndex = 30
	label.Text = text
	label.TextColor3 = color
end

local function clear()
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function batModel(): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local bat = assets and assets:FindFirstChild("Bat")
	if bat and bat:IsA("Model") then
		local copy = bat:Clone()
		for _, part in copy:GetDescendants() do
			if part:IsA("BasePart") then
				part.Anchored = true
			end
		end
		return copy
	end
	return nil
end

local function showBats(profile: Types.Profile)
	local equipped = {}
	for _, petId in profile.Equipped do
		local pet = profile.Pets[petId]
		if pet then
			table.insert(equipped, pet)
		end
	end
	local power = StatCalculator.Totals(equipped :: any, PetConfig :: any).Power
	infoLabel.Text = string.format(Strings.BackpackBatInfo, math.floor(power * 100 + 0.5))
	if builtKey == "Bats" then
		return
	end
	builtKey = "Bats"
	clear()
	local card, title = Widgets.Card("Bat", list, UDim2.new(), UDim2.new(), BAT_COLOR)
	title.Text = Strings.BackpackBat
	local viewport = AssetModels.Viewport(cardHolder(card), batModel(), BAT_COLOR)
	-- The bat is long and thin: show it diagonally, straight from the front.
	local model = viewport:FindFirstChildOfClass("Model")
	if model then
		model:PivotTo(CFrame.Angles(0, 0, math.rad(45)))
		AssetModels.Frame(viewport, -Vector3.zAxis)
	end
	footer(card, Strings.PlatformEquipped, Color3.fromRGB(120, 255, 120))
end

local function showEggs(profile: Types.Profile)
	local ids = {}
	for id in profile.Eggs do
		table.insert(ids, id)
	end
	local function themeRank(theme: string): number
		return table.find(EggConfig.OfferThemes, theme) or 0
	end
	local function rarityRank(rarity: string): number
		return table.find(PetConfig.Rarities, rarity) or 0
	end
	-- Rarest eggs first.
	table.sort(ids, function(a, b)
		local eggA, eggB = profile.Eggs[a], profile.Eggs[b]
		if eggA.Theme ~= eggB.Theme then
			return themeRank(eggA.Theme) > themeRank(eggB.Theme)
		end
		if eggA.Rarity ~= eggB.Rarity then
			return rarityRank(eggA.Rarity) > rarityRank(eggB.Rarity)
		end
		return a < b
	end)
	infoLabel.Text = if #ids > 0
		then string.format(Strings.BackpackEggs, #ids, profile.EggCapacity)
		else Strings.BackpackNoEggs
	local key = "Eggs:" .. table.concat(ids, ",")
	if builtKey == key then
		return
	end
	builtKey = key
	clear()
	for order, id in ids do
		local egg = profile.Eggs[id]
		-- The egg's own rarity, not the pet's inside (Ivan 2026-10-16).
		local eggRarity = EggConfig.EggRarity[egg.Theme] or "Common"
		local color = PetStyle.EggRarity[eggRarity] or WHITE
		local card, title = Widgets.Card(id, list, UDim2.new(), UDim2.new(), color)
		card.LayoutOrder = order
		title.Text = string.format(Strings.EggTheme, egg.Theme)
		AssetModels.Viewport(cardHolder(card), AssetModels.Egg(egg.Theme), color)
		footer(card, (Strings.EggRarity :: any)[eggRarity] or eggRarity, color)
	end
end

local function refresh()
	local loaded = DataController:Get()
	if loaded == nil then
		return
	end
	local profile = loaded :: Types.Profile
	for name, button in tabButtons do
		local outer = button:FindFirstChild("Outer")
		if outer and outer:IsA("UIStroke") then
			outer.Color = if name == tab then WHITE else TAB_OUTLINE
		end
	end
	if tab == "Bats" then
		showBats(profile)
	elseif tab == "Eggs" then
		showEggs(profile)
	else
		infoLabel.Text = Strings.BackpackTraits
		if builtKey ~= "Traits" then
			builtKey = "Traits"
			clear()
		end
	end
end

local function build(window: GuiObject)
	local main = window:FindFirstChild("Main") or window
	local scroll = main:FindFirstChild("Scrolling")
	if not (scroll and scroll:IsA("ScrollingFrame")) then
		return false
	end
	list = scroll :: ScrollingFrame
	list.Size = UDim2.fromScale(0.985, 0.72)
	list.CanvasSize = UDim2.fromScale(0, 0)
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	local oldLayout = list:FindFirstChildOfClass("UIListLayout")
	if oldLayout then
		oldLayout:Destroy()
	end
	local grid = Instance.new("UIGridLayout")
	grid.CellPadding = UDim2.new(0.025, 0, 0, 10)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = list
	-- Cell height follows the list width (an aspect constraint gives 0 here).
	local function resize()
		local width = list.AbsoluteSize.X * CELL_WIDTH
		grid.CellSize = UDim2.new(CELL_WIDTH, 0, 0, width / CELL_RATIO)
	end
	list:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
	resize()

	infoLabel =
		Widgets.Label("Info", main, UDim2.fromScale(0.94, 0.07), UDim2.fromScale(0.03, 0.195))
	infoLabel.TextXAlignment = Enum.TextXAlignment.Left

	local buttons = window:FindFirstChild("Buttons")
	local container = buttons and buttons:FindFirstChild("Container")
	for _, name in TABS do
		local button = container and container:FindFirstChild(name)
		if button and button:IsA("GuiButton") then
			tabButtons[name] = button
			button.MouseButton1Click:Connect(function()
				tab = name
				refresh()
			end)
		end
	end
	return true
end

function BackpackController:Init() end

function BackpackController:Start()
	local window = PackUiController:GetWindow(WINDOW_NAME)
	if window == nil or not build(window :: GuiObject) then
		return
	end
	DataController.Changed:Connect(refresh)
	PackUiController.Opened:Connect(function(name)
		if name == WINDOW_NAME then
			refresh()
		end
	end)
	refresh()
end

return BackpackController
