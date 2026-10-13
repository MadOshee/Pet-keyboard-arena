--!strict
-- Pets window (Ivan, 2026-10-12; the pack's Index window renamed). Left: a
-- row per egg with that egg's pets and how many of them the player has;
-- pets the player does not have show as "???" silhouettes. Right: the
-- picked pet with its coins per second on a plot platform, its buffs and an
-- Equip/Unequip button. Sends only pet ids (PetEquip); the server checks
-- ownership, slots, platforms and the round lock.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EggConfig = require(ReplicatedStorage.Shared.Config.EggConfig)
local PetConfig = require(ReplicatedStorage.Shared.Config.PetConfig)
local PetStyle = require(ReplicatedStorage.Shared.Config.PetStyle)
local Strings = require(ReplicatedStorage.Shared.Config.Strings)
local PetIncome = require(ReplicatedStorage.Shared.Logic.PetIncome)
local Types = require(ReplicatedStorage.Shared.Types)
local Money = require(ReplicatedStorage.Shared.Util.Money)
local AssetModels = require(script.Parent.Parent.UI.AssetModels)
local PetText = require(script.Parent.Parent.UI.PetText)
local Widgets = require(script.Parent.Parent.UI.Widgets)
local ClientNet = require(script.Parent.Parent.Util.ClientNet)
local DataController = require(script.Parent.DataController)
local PackUiController = require(script.Parent.PackUiController)

local WINDOW_NAME = "Pets"
-- One egg row, in fractions of the row's width: the egg card on the left,
-- its pets in COLUMNS columns on the right, the progress bar under them.
-- 8 pets per egg: two rows of four (Ivan, 2026-10-13).
local COLUMNS = 4
local EGG_WIDTH = 0.21
local EGG_HEIGHT = 0.39
local PETS_LEFT = 0.225
local CARD_WIDTH = 0.185
local CARD_HEIGHT = 0.16
local CARD_STEP_X = 0.195
local CARD_STEP_Y = 0.17
local BAR_HEIGHT = 0.05
-- A pet has at most three buffs (Ivan).
local MAX_BUFFS = 3

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local DARK = Color3.fromRGB(28, 28, 36)
local GREEN = Color3.fromRGB(64, 170, 90)
local RED = Color3.fromRGB(200, 70, 70)
local GRAY = Color3.fromRGB(110, 110, 120)
local MONEY = Color3.fromRGB(120, 255, 120)

type Card = {
	Frame: Frame,
	Title: TextLabel,
	Preview: ViewportFrame,
}

type Section = {
	Kinds: { string },
	Fill: Frame,
	Count: TextLabel,
}

type Owned = {
	Count: number,
	EquippedId: string?,
	FreeId: string?, -- in the inventory: neither equipped nor on a platform
}

local PetIndexController = {}

local cards: { [string]: Card } = {}
local sections: { Section } = {}
local totalKinds = 0
local selectedKind: string? = nil
local shownKind: string? = nil
local equipAction: (() -> ())? = nil

local unlockedLabel: TextLabel
local detail: Frame
local detailHolder: Frame
local nameLabel: TextLabel
local rarityLabel: TextLabel
local incomeLabel: TextLabel
local buffLabels: { TextLabel } = {}
local ownedLabel: TextLabel
local equipButton: TextButton

local function rarityRank(rarity: string): number
	return table.find(PetConfig.Rarities, rarity) or 0
end

-- The theme's pets, weakest first.
local function kindsOf(theme: string): { string }
	local kinds = {}
	for kind, entry in PetConfig.Pets do
		if entry.Theme == theme then
			table.insert(kinds, kind)
		end
	end
	table.sort(kinds, function(a, b)
		local entryA, entryB = PetConfig.Pets[a], PetConfig.Pets[b]
		if entryA.Order ~= entryB.Order then
			return entryA.Order < entryB.Order
		end
		return rarityRank(entryA.Rarity) < rarityRank(entryB.Rarity)
	end)
	return kinds
end

-- How often an offer slot holds this egg, as text.
local function chanceText(theme: string): string
	local weights = EggConfig.ThemeWeights :: { [string]: number }
	local total = 0
	for _, weight in weights do
		total += weight
	end
	local share = if total > 0 then (weights[theme] or 0) / total * 100 else 0
	local text = if share >= 10
		then string.format("%d%%", math.floor(share + 0.5))
		elseif share >= 1 then string.format("%.1f%%", share)
		else string.format("%.2f%%", share)
	return string.format(Strings.IndexChance, text)
end

local function countKinds(profile: Types.Profile): { [string]: number }
	local counts = {}
	for _, pet in profile.Pets do
		counts[pet.Kind] = (counts[pet.Kind] or 0) + 1
	end
	return counts
end

local function ownership(profile: Types.Profile, kind: string): Owned
	local placed = PetIncome.PlacedPets(profile.Incubators :: any)
	local owned: Owned = { Count = 0, EquippedId = nil, FreeId = nil }
	for id, pet in profile.Pets do
		if pet.Kind == kind then
			owned.Count += 1
			if table.find(profile.Equipped, id) then
				owned.EquippedId = id
			elseif placed[id] == nil then
				owned.FreeId = id
			end
		end
	end
	return owned
end

local function setOutline(frame: Frame, selected: boolean)
	local outer = frame:FindFirstChild("Outer")
	if outer and outer:IsA("UIStroke") then
		outer.Color = if selected then WHITE else BLACK
	end
end

local function holderIn(parent: GuiObject, size: UDim2, position: UDim2): Frame
	local holder = Instance.new("Frame")
	holder.Name = "Holder"
	holder.BackgroundTransparency = 1
	holder.Size = size
	holder.Position = position
	holder.Parent = parent
	return holder
end

local function showDetail(profile: Types.Profile)
	local kind = selectedKind
	if kind == nil then
		return
	end
	local entry = PetConfig.Pets[kind :: string]
	local color = PetStyle.Rarity[entry.Rarity] or WHITE
	local owned = ownership(profile, kind :: string)
	local known = owned.Count > 0

	if shownKind ~= kind then
		shownKind = kind
		Widgets.TintCard(detail, color)
		detailHolder:ClearAllChildren()
		AssetModels.Viewport(detailHolder, AssetModels.Pet(kind :: string), color)
	end
	local preview = detailHolder:FindFirstChildOfClass("ViewportFrame")
	if preview then
		preview.ImageColor3 = if known then WHITE else BLACK
		preview.ImageTransparency = if known then 0 else 0.3
	end
	nameLabel.Text = if known then entry.Name else Strings.IndexUnknown
	rarityLabel.Text = (Strings.Rarity :: any)[entry.Rarity] or entry.Rarity
	incomeLabel.Text = string.format(Strings.IndexIncome, Money.Format(entry.Income))
	local buffs = PetText.Buffs(kind :: string)
	for index, label in buffLabels do
		local buff = buffs[index]
		label.Text = if buff then buff.Text else ""
		label.TextColor3 = if buff then PetStyle.Stat[buff.Stat] or WHITE else WHITE
	end

	ownedLabel.Text = string.format(Strings.IndexOwned, owned.Count)
		.. "  ·  "
		.. string.format(Strings.EquippedCount, #profile.Equipped, PetConfig.MaxEquipped)
	local full = #profile.Equipped >= PetConfig.MaxEquipped
	if owned.EquippedId then
		local id = owned.EquippedId :: string
		equipButton.Text = Strings.Unequip
		equipButton.BackgroundColor3 = RED
		equipAction = function()
			ClientNet.Fire("PetEquip", id, false)
		end
	elseif owned.FreeId and not full then
		local id = owned.FreeId :: string
		equipButton.Text = Strings.Equip
		equipButton.BackgroundColor3 = GREEN
		equipAction = function()
			ClientNet.Fire("PetEquip", id, true)
		end
	else
		equipButton.Text = if owned.FreeId
			then Strings.IndexSlotsFull
			elseif known then Strings.IndexOnPlot
			else Strings.IndexNotOwned
		equipButton.BackgroundColor3 = GRAY
		equipAction = nil
	end
end

local function refresh()
	local loaded = DataController:Get()
	if loaded == nil then
		return
	end
	local profile = loaded :: Types.Profile
	local counts = countKinds(profile)
	local unlocked = 0
	for _, section in sections do
		local have = 0
		for _, kind in section.Kinds do
			local known = (counts[kind] or 0) > 0
			if known then
				have += 1
			end
			local card = cards[kind]
			card.Title.Text = if known then PetConfig.Pets[kind].Name else Strings.IndexUnknown
			card.Preview.ImageColor3 = if known then WHITE else BLACK
			card.Preview.ImageTransparency = if known then 0 else 0.3
		end
		unlocked += have
		section.Count.Text = `{have}/{#section.Kinds}`
		section.Fill.Size = UDim2.fromScale(have / math.max(#section.Kinds, 1), 1)
	end
	unlockedLabel.Text = string.format(Strings.IndexUnlocked, unlocked, totalKinds)
	showDetail(profile)
end

local function selectPet(kind: string)
	local previous = selectedKind
	if previous and cards[previous] then
		setOutline(cards[previous].Frame, false)
	end
	selectedKind = kind
	setOutline(cards[kind].Frame, true)
	local profile = DataController:Get()
	if profile then
		showDetail(profile :: Types.Profile)
	end
end

local function buildCard(parent: Frame, kind: string)
	local entry = PetConfig.Pets[kind]
	local color = PetStyle.Rarity[entry.Rarity] or WHITE
	local frame, title = Widgets.Card(kind, parent, UDim2.new(), UDim2.new(), color)
	local holder = holderIn(frame, UDim2.fromScale(0.9, 0.7), UDim2.fromScale(0.05, 0.25))
	local preview = AssetModels.Viewport(holder, AssetModels.Pet(kind), color)
	local hit = Instance.new("TextButton")
	hit.Name = "Hit"
	hit.BackgroundTransparency = 1
	hit.Text = ""
	hit.Size = UDim2.fromScale(1, 1)
	hit.ZIndex = 50
	hit.Parent = frame
	hit.Activated:Connect(function()
		Widgets.PlaySound("Click")
		selectPet(kind)
	end)
	cards[kind] = { Frame = frame, Title = title, Preview = preview }
	return frame
end

local function buildSection(list: ScrollingFrame, theme: string, order: number)
	local section = Instance.new("Frame")
	section.Name = theme
	section.BackgroundTransparency = 1
	section.LayoutOrder = order
	section.Parent = list

	local themeColor = PetStyle.Theme[theme] or WHITE
	local egg, eggTitle = Widgets.Card("Egg", section, UDim2.new(), UDim2.new(), themeColor)
	eggTitle.Text = string.format(Strings.EggTheme, theme)
	local holder = holderIn(egg, UDim2.fromScale(0.9, 0.58), UDim2.fromScale(0.05, 0.24))
	AssetModels.Viewport(holder, AssetModels.Egg(theme), themeColor)
	local chance =
		Widgets.Label("Chance", egg, UDim2.fromScale(0.9, 0.12), UDim2.fromScale(0.05, 0.84))
	chance.ZIndex = 30
	chance.Text = chanceText(theme)

	local kinds = kindsOf(theme)
	totalKinds += #kinds
	local petFrames = {}
	for _, kind in kinds do
		table.insert(petFrames, buildCard(section, kind))
	end

	local bar, fill, left, right =
		Widgets.ProgressBar("Progress", section, UDim2.new(), UDim2.new(), DARK, GREEN)
	left.Text = ""
	right.Text = ""
	local count = Widgets.Label("Count", bar, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0))
	count.ZIndex = 30
	table.insert(sections, { Kinds = kinds, Fill = fill, Count = count })

	-- An aspect constraint cannot size a row inside an auto-sized canvas:
	-- everything is placed in pixels from the list width.
	local rows = math.max(math.ceil(#kinds / COLUMNS), 1)
	local function resize()
		local width = list.AbsoluteSize.X * 0.97
		local petsHeight = (rows - 1) * CARD_STEP_Y + CARD_HEIGHT
		local height = math.max(EGG_HEIGHT, petsHeight + 0.01 + BAR_HEIGHT)
		local function px(x: number, y: number): UDim2
			return UDim2.fromOffset(math.floor(x * width + 0.5), math.floor(y * width + 0.5))
		end
		section.Size = UDim2.new(0.97, 0, 0, math.floor(height * width + 0.5))
		egg.Size = px(EGG_WIDTH, EGG_HEIGHT)
		for index, frame in petFrames do
			local column = (index - 1) % COLUMNS
			local row = (index - 1) // COLUMNS
			frame.Size = px(CARD_WIDTH, CARD_HEIGHT)
			frame.Position = px(PETS_LEFT + column * CARD_STEP_X, row * CARD_STEP_Y)
		end
		bar.Size = px(COLUMNS * CARD_STEP_X - (CARD_STEP_X - CARD_WIDTH), BAR_HEIGHT)
		bar.Position = px(PETS_LEFT, height - BAR_HEIGHT)
	end
	list:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
	resize()
end

local function darkPanel(name: string, parent: Instance, size: UDim2, position: UDim2): Frame
	local panel = Instance.new("Frame")
	panel.Name = name
	panel.BackgroundColor3 = BLACK
	panel.BackgroundTransparency = 0.45
	panel.Size = size
	panel.Position = position
	panel.Parent = parent
	Widgets.Corner(panel, 0.03)
	Widgets.Stroke(panel, BLACK, 2)
	return panel
end

local function build(window: GuiObject)
	local main = window:FindFirstChild("Main") or window

	local back = darkPanel("List", main, UDim2.fromScale(0.66, 0.66), UDim2.fromScale(0.015, 0.2))
	local list = Instance.new("ScrollingFrame")
	list.Name = "Scroll"
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Size = UDim2.fromScale(0.97, 0.94)
	list.Position = UDim2.fromScale(0.015, 0.03)
	list.CanvasSize = UDim2.fromScale(0, 0)
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.ScrollBarThickness = 8
	list.Parent = back
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	for order, theme in EggConfig.OfferThemes do
		buildSection(list, theme, order)
	end

	local unlocked =
		darkPanel("Unlocked", main, UDim2.fromScale(0.66, 0.095), UDim2.fromScale(0.015, 0.885))
	local icons = ReplicatedStorage:FindFirstChild("Assets")
	icons = icons and icons:FindFirstChild("UI")
	icons = icons and icons:FindFirstChild("Icons")
	local book = icons and icons:FindFirstChild("Index")
	if book and book:IsA("ImageLabel") then
		local icon = Instance.new("ImageLabel")
		icon.Name = "Icon"
		icon.BackgroundTransparency = 1
		icon.Image = book.Image
		icon.Size = UDim2.fromScale(0.12, 1.5)
		icon.Position = UDim2.fromScale(-0.03, -0.3)
		icon.ZIndex = 5
		icon.Parent = unlocked
		Widgets.AspectRatio(icon, 1)
	end
	unlockedLabel =
		Widgets.Label("Text", unlocked, UDim2.fromScale(0.8, 0.8), UDim2.fromScale(0.12, 0.1))

	local detailTitle: TextLabel
	detail, detailTitle =
		Widgets.Card("Detail", main, UDim2.fromScale(0.295, 0.5), UDim2.fromScale(0.69, 0.2), GRAY)
	detailTitle.Visible = false
	detailHolder = holderIn(detail, UDim2.fromScale(0.7, 0.38), UDim2.fromScale(0.15, 0.02))
	nameLabel =
		Widgets.Label("PetName", detail, UDim2.fromScale(0.9, 0.1), UDim2.fromScale(0.05, 0.41))
	rarityLabel =
		Widgets.Label("Rarity", detail, UDim2.fromScale(0.9, 0.075), UDim2.fromScale(0.05, 0.515))
	incomeLabel =
		Widgets.Label("Income", detail, UDim2.fromScale(0.9, 0.09), UDim2.fromScale(0.05, 0.595))
	incomeLabel.TextColor3 = MONEY
	-- Buffs in a column, each in its stat's color (Ivan's picture).
	for index = 1, MAX_BUFFS do
		local label = Widgets.Label(
			`Buff{index}`,
			detail,
			UDim2.fromScale(0.9, 0.085),
			UDim2.fromScale(0.05, 0.695 + (index - 1) * 0.095)
		)
		label.ZIndex = 30
		table.insert(buffLabels, label)
	end
	for _, label in { nameLabel, rarityLabel, incomeLabel } do
		label.ZIndex = 30
	end

	local equipPanel = Instance.new("Frame")
	equipPanel.Name = "EquipPanel"
	equipPanel.BackgroundColor3 = Color3.fromRGB(22, 64, 34)
	equipPanel.Size = UDim2.fromScale(0.295, 0.26)
	equipPanel.Position = UDim2.fromScale(0.69, 0.72)
	equipPanel.Parent = main
	Widgets.Corner(equipPanel, 0.05)
	Widgets.Stroke(equipPanel, Color3.fromRGB(40, 150, 60), 3)
	ownedLabel =
		Widgets.Label("Owned", equipPanel, UDim2.fromScale(0.9, 0.2), UDim2.fromScale(0.05, 0.08))
	equipButton = Widgets.Button(
		"Equip",
		equipPanel,
		UDim2.fromScale(0.8, 0.45),
		UDim2.fromScale(0.1, 0.4),
		GRAY
	)
	equipButton.Activated:Connect(function()
		if equipAction then
			(equipAction :: () -> ())()
		end
	end)

	local first = sections[1] and sections[1].Kinds[1]
	if first then
		selectPet(first)
	end
end

function PetIndexController:Init() end

function PetIndexController:Start()
	local window = PackUiController:GetWindow(WINDOW_NAME)
	if window == nil then
		return
	end
	build(window :: GuiObject)
	DataController.Changed:Connect(refresh)
	PackUiController.Opened:Connect(function(name)
		if name == WINDOW_NAME then
			refresh()
		end
	end)
	refresh()
end

return PetIndexController
