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
local AssetModels = require(script.Parent.Parent.UI.AssetModels)
local PetText = require(script.Parent.Parent.UI.PetText)
local Widgets = require(script.Parent.Parent.UI.Widgets)
local ClientNet = require(script.Parent.Parent.Util.ClientNet)
local DataController = require(script.Parent.DataController)
local PackUiController = require(script.Parent.PackUiController)

local WINDOW_NAME = "Pets"
local COLUMNS = 3
-- Width / height of one egg row: the egg on the left, two rows of pets and
-- the progress bar.
local SECTION_RATIO = 2.1
local MAX_BUFFS = 5

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

-- The theme's pets, commonest first.
local function kindsOf(theme: string): { string }
	local kinds = {}
	for kind, entry in PetConfig.Pets do
		if entry.Theme == theme then
			table.insert(kinds, kind)
		end
	end
	table.sort(kinds, function(a, b)
		local rankA = rarityRank(PetConfig.Pets[a].Rarity)
		local rankB = rarityRank(PetConfig.Pets[b].Rarity)
		if rankA ~= rankB then
			return rankA < rankB
		end
		return a < b
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
		else string.format("%.1f%%", share)
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
	incomeLabel.Text = string.format(Strings.IndexIncome, PetText.Number(entry.Income))
	local lines = PetText.BuffLines(kind :: string)
	for index, label in buffLabels do
		label.Text = lines[index] or ""
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

local function buildCard(parent: Frame, kind: string, size: UDim2, position: UDim2)
	local entry = PetConfig.Pets[kind]
	local color = PetStyle.Rarity[entry.Rarity] or WHITE
	local frame, title = Widgets.Card(kind, parent, size, position, color)
	local holder = holderIn(frame, UDim2.fromScale(0.9, 0.74), UDim2.fromScale(0.05, 0.24))
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
end

local function buildSection(list: ScrollingFrame, theme: string, order: number)
	local section = Instance.new("Frame")
	section.Name = theme
	section.BackgroundTransparency = 1
	section.LayoutOrder = order
	section.Parent = list
	-- An aspect constraint cannot size a row inside an auto-sized canvas, so
	-- the height follows the list width.
	local function resize()
		local width = list.AbsoluteSize.X * 0.97
		section.Size = UDim2.new(0.97, 0, 0, width / SECTION_RATIO)
	end
	list:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
	resize()

	local themeColor = PetStyle.Theme[theme] or WHITE
	local egg, eggTitle =
		Widgets.Card("Egg", section, UDim2.fromScale(0.21, 1), UDim2.fromScale(0, 0), themeColor)
	eggTitle.Text = string.format(Strings.EggTheme, theme)
	local holder = holderIn(egg, UDim2.fromScale(0.9, 0.58), UDim2.fromScale(0.05, 0.24))
	AssetModels.Viewport(holder, AssetModels.Egg(theme), themeColor)
	local chance =
		Widgets.Label("Chance", egg, UDim2.fromScale(0.9, 0.12), UDim2.fromScale(0.05, 0.84))
	chance.ZIndex = 30
	chance.Text = chanceText(theme)

	local kinds = kindsOf(theme)
	totalKinds += #kinds
	for index, kind in kinds do
		local column = (index - 1) % COLUMNS
		local row = (index - 1) // COLUMNS
		buildCard(
			section,
			kind,
			UDim2.fromScale(0.245, 0.4),
			UDim2.fromScale(0.225 + column * 0.26, row * 0.42)
		)
	end

	local bar, fill, left, right = Widgets.ProgressBar(
		"Progress",
		section,
		UDim2.fromScale(0.765, 0.13),
		UDim2.fromScale(0.225, 0.86),
		DARK,
		GREEN
	)
	left.Text = ""
	right.Text = ""
	local count = Widgets.Label("Count", bar, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0))
	count.ZIndex = 30
	table.insert(sections, { Kinds = kinds, Fill = fill, Count = count })
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
	for index = 1, MAX_BUFFS do
		local column = (index - 1) % 2
		local row = (index - 1) // 2
		local label = Widgets.Label(
			`Buff{index}`,
			detail,
			UDim2.fromScale(0.45, 0.08),
			UDim2.fromScale(0.04 + column * 0.47, 0.7 + row * 0.095)
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
