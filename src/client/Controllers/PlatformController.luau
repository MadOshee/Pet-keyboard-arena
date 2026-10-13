--!strict
-- Plot platforms on the client (docs/design.md 4.3 "Участок"). Every green
-- button in front of a platform sinks with a click while a character stands
-- on it. On your own plot it also opens the platform window: pick an egg or
-- a pet to put there, or see what stands there (hatch timer, income) and
-- take it back, hatch it now or buy a locked platform. The window closes
-- when you step off. Only ids and intents go to the server
-- (PlatformAction); PlatformService checks everything.
-- Also shows what pets earned while the player was away (OfflineIncome).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local EggConfig = require(ReplicatedStorage.Shared.Config.EggConfig)
local PetConfig = require(ReplicatedStorage.Shared.Config.PetConfig)
local PetStyle = require(ReplicatedStorage.Shared.Config.PetStyle)
local Strings = require(ReplicatedStorage.Shared.Config.Strings)
local Incubation = require(ReplicatedStorage.Shared.Logic.Incubation)
local PetIncome = require(ReplicatedStorage.Shared.Logic.PetIncome)
local Types = require(ReplicatedStorage.Shared.Types)
local Money = require(ReplicatedStorage.Shared.Util.Money)
local AssetModels = require(script.Parent.Parent.UI.AssetModels)
local Glow = require(script.Parent.Parent.UI.Glow)
local Widgets = require(script.Parent.Parent.UI.Widgets)
local ClientNet = require(script.Parent.Parent.Util.ClientNet)
local DataController = require(script.Parent.DataController)

local player = Players.LocalPlayer

local PRESS_DEPTH = 0.3
local PRESS_TWEEN = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local RELEASE_TWEEN = TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local STAND_MARGIN = 0.6 -- studs around the pad that still count as on it
local STAND_HEIGHT = 7 -- the character root is at most this far above the pad
local OFFLINE_NOTICE_SECONDS = 7
local WHITE = Color3.new(1, 1, 1)
local NAVY = Color3.fromRGB(20, 24, 54)
local GOLD = Color3.fromRGB(255, 214, 64)
local HINT_COLOR = Color3.fromRGB(190, 210, 255)
local CARD_STROKE = 2.5
local CARD_STROKE_HOVER = 4
local COUNT_COLOR = Color3.fromRGB(235, 70, 90)
-- Where the hint line and the buttons go (in parts of the window).
local INFO_TOP = {
	Position = UDim2.fromScale(0.04, 0.17),
	Size = UDim2.fromScale(0.92, 0.075),
	Align = Enum.TextXAlignment.Left,
}
local INFO_SIDE = {
	Position = UDim2.fromScale(0.4, 0.36),
	Size = UDim2.fromScale(0.56, 0.08),
	Align = Enum.TextXAlignment.Center,
}
local SIDE_FIRST = UDim2.fromScale(0.43, 0.5)
local SIDE_SECOND = UDim2.fromScale(0.43, 0.73)
local BUY_POSITION = UDim2.fromScale(0.25, 0.42)
local BUTTON_SIZE = UDim2.fromScale(0.5, 0.19)
local EQUIPPED_COLOR = Color3.fromRGB(60, 180, 90)

local PlatformController = {}

type Button = {
	Part: BasePart,
	Rest: CFrame,
	Color: Color3,
	Pressed: boolean,
	-- Platforms this pad opens (on the bare-plot fallback a pad is its platform).
	Platforms: { BasePart },
}

local buttons: { [BasePart]: Button } = {}
local openPlatform: BasePart? = nil
local builtKey: string? = nil

local gui: ScreenGui
local window: Frame
local titleLabel: TextLabel
local infoLabel: TextLabel
local nameLabel: TextLabel
local previewGlow: Glow.Glow
local list: ScrollingFrame
local preview: Frame
local actionButton: TextButton
local takeButton: TextButton
local noticeLabel: TextLabel
local noticeToken = 0

local function formatDuration(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	if seconds >= 3600 then
		return string.format("%d:%02d:%02d", seconds // 3600, seconds // 60 % 60, seconds % 60)
	end
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function rarityRank(rarity: string): number
	return table.find(PetConfig.Rarities, rarity) or 0
end

local function platformIndex(platform: BasePart): number
	local index = platform:GetAttribute("Index")
	return if type(index) == "number" then index else 0
end

local function isMine(platform: BasePart): boolean
	local plot = platform.Parent
	return plot ~= nil and plot:GetAttribute("OwnerUserId") == player.UserId
end

local function send(action: Types.PlatformActionKind, id: string?)
	local platform = openPlatform
	if platform then
		ClientNet.Fire("PlatformAction", platformIndex(platform), action, id)
	end
end

local function clearList()
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function clearPreview()
	local holder = preview:FindFirstChild("Model")
	if holder then
		holder:Destroy()
	end
end

-- A color for a card's face: the rarity color sunk into the window's navy.
local function cardFace(color: Color3): (Color3, Color3)
	return NAVY:Lerp(color, 0.55), NAVY:Lerp(color, 0.2)
end

-- A small rounded tag in a card's top corner ("x2", "Equipped").
local function addTag(card: GuiObject, text: string, color: Color3, right: boolean)
	local tag = Instance.new("Frame")
	tag.Name = "Tag"
	tag.BackgroundColor3 = color
	tag.BorderSizePixel = 0
	tag.AnchorPoint = Vector2.new(if right then 1 else 0, 0)
	tag.Position = UDim2.fromScale(if right then 0.95 else 0.05, 0.04)
	tag.Size = UDim2.fromScale(0, 0.12)
	tag.AutomaticSize = Enum.AutomaticSize.X
	tag.ZIndex = 6
	tag.Parent = card
	Widgets.Corner(tag, 0.5)
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 6)
	padding.PaddingRight = UDim.new(0, 6)
	padding.Parent = tag
	local label = Widgets.Label("Text", tag, UDim2.fromScale(0, 0.86), UDim2.fromScale(0, 0.07))
	label.AutomaticSize = Enum.AutomaticSize.X
	label.TextScaled = false
	label.ZIndex = 7
	label.Text = text
	local function size()
		label.TextSize = math.max(math.floor(tag.AbsoluteSize.Y * 0.78), 8)
	end
	tag:GetPropertyChangedSignal("AbsoluteSize"):Connect(size)
	size()
end

-- One egg or pet in the picker (Ivan: smaller models, no gray tile): a
-- face in the rarity's color with a soft glow behind the model, the name,
-- the rarity and, for a pet, its money per second.
local function addCard(
	order: number,
	model: Model?,
	color: Color3,
	title: string,
	rarity: string,
	money: string?,
	tags: { { Text: string, Color: Color3, Right: boolean } },
	onPick: () -> ()
)
	local card = Instance.new("TextButton")
	card.Name = `Card{order}`
	card.Text = ""
	card.AutoButtonColor = false
	card.BackgroundColor3 = WHITE
	card.BorderSizePixel = 0
	card.LayoutOrder = order
	card.Parent = list
	Widgets.Corner(card, 0.12)
	local top, bottom = cardFace(color)
	local face = Instance.new("UIGradient")
	face.Rotation = 90
	face.Color = ColorSequence.new(top, bottom)
	face.Parent = card
	local stroke = Widgets.Stroke(card, color, CARD_STROKE)
	Widgets.AnimatePress(card)
	card.MouseEnter:Connect(function()
		stroke.Thickness = CARD_STROKE_HOVER
	end)
	card.MouseLeave:Connect(function()
		stroke.Thickness = CARD_STROKE
	end)

	local stage = Instance.new("Frame")
	stage.Name = "Stage"
	stage.BackgroundTransparency = 1
	stage.AnchorPoint = Vector2.new(0.5, 0)
	stage.Position = UDim2.fromScale(0.5, 0.06)
	stage.Size = UDim2.fromScale(0.9, 0.5)
	stage.ZIndex = 2
	stage.Parent = card
	Glow.new(stage, color, 1.1, false, 2)
	local holder = Instance.new("Frame")
	holder.Name = "Model"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromScale(0.78, 0.78)
	holder.ZIndex = 3
	holder.Parent = stage
	AssetModels.Viewport(holder, model, color)

	local name = Widgets.Label("Name", card, UDim2.fromScale(0.9, 0.13), UDim2.fromScale(0.05, 0.6))
	name.ZIndex = 4
	name.Text = title
	local sub =
		Widgets.Label("Rarity", card, UDim2.fromScale(0.86, 0.1), UDim2.fromScale(0.07, 0.74))
	sub.ZIndex = 4
	sub.Text = rarity
	sub.TextColor3 = color
	if money then
		local income = Widgets.MoneyLabel(
			"Money",
			card,
			UDim2.fromScale(0.86, 0.1),
			UDim2.fromScale(0.07, 0.855)
		)
		income.ZIndex = 4
		income.TextXAlignment = Enum.TextXAlignment.Center
		Widgets.SetText(income, money)
	else
		sub.Position = UDim2.fromScale(0.07, 0.78)
	end
	for _, tag in tags do
		addTag(card, tag.Text, tag.Color, tag.Right)
	end
	card.Activated:Connect(function()
		Widgets.PlaySound("Click")
		onPick()
	end)
end

-- The picker: stored eggs (one card per theme and rarity) and inventory pets.
local function buildPicker(data: Types.Profile)
	list.Visible = true
	clearList()
	local order = 0

	type EggGroup = { Id: string, Theme: string, Rarity: string, Count: number }
	local groups: { [string]: EggGroup } = {}
	for id, egg in data.Eggs do
		local key = egg.Theme .. "|" .. egg.Rarity
		local group = groups[key]
		if group then
			group.Count += 1
		else
			groups[key] = { Id = id, Theme = egg.Theme, Rarity = egg.Rarity, Count = 1 }
		end
	end
	local eggs: { EggGroup } = {}
	for _, group in groups do
		table.insert(eggs, group)
	end
	table.sort(eggs, function(a, b)
		if a.Rarity ~= b.Rarity then
			return rarityRank(a.Rarity) > rarityRank(b.Rarity)
		end
		return a.Theme < b.Theme
	end)
	for _, group in eggs do
		order += 1
		local rarityName = (Strings.Rarity :: any)[group.Rarity] or group.Rarity
		addCard(
			order,
			AssetModels.Egg(group.Theme),
			PetStyle.Rarity[group.Rarity] or WHITE,
			string.format(Strings.EggTheme, group.Theme),
			rarityName,
			nil,
			if group.Count > 1
				then { { Text = `x{group.Count}`, Color = COUNT_COLOR, Right = true } }
				else {},
			function()
				send("PlaceEgg", group.Id)
			end
		)
	end

	local placed = PetIncome.PlacedPets(data.Incubators :: any)
	local pets: { string } = {}
	for id in data.Pets do
		if placed[id] == nil then
			table.insert(pets, id)
		end
	end
	table.sort(pets, function(a, b)
		local petA, petB = data.Pets[a], data.Pets[b]
		if petA.Rarity ~= petB.Rarity then
			return rarityRank(petA.Rarity) > rarityRank(petB.Rarity)
		end
		return a < b
	end)
	for _, id in pets do
		order += 1
		local pet = data.Pets[id]
		local entry = PetConfig.Pets[pet.Kind]
		local income = string.format(
			Strings.PlatformIncome,
			Money.Format(PetIncome.Rate(pet.Kind, PetConfig :: any))
		)
		addCard(
			order,
			AssetModels.Pet(pet.Kind),
			PetStyle.Rarity[pet.Rarity] or WHITE,
			if entry then entry.Name else pet.Kind,
			(Strings.Rarity :: any)[pet.Rarity] or pet.Rarity,
			income,
			if table.find(data.Equipped, id)
				then { { Text = Strings.PlatformEquipped, Color = EQUIPPED_COLOR, Right = false } }
				else {},
			function()
				send("PlacePet", id)
			end
		)
	end

	infoLabel.Text = if order == 0 then Strings.PlatformNothing else Strings.PlatformHint
end

local function showPreview(model: Model?, color: Color3)
	clearPreview()
	preview.Visible = true
	Glow.SetColor(previewGlow, color)
	local holder = Instance.new("Frame")
	holder.Name = "Model"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromScale(0.8, 0.8)
	holder.ZIndex = 3
	holder.Parent = preview
	AssetModels.Viewport(holder, model, color)
end

-- The hint line: across the top under the title, or beside the preview.
local function placeInfo(place: { Position: UDim2, Size: UDim2, Align: Enum.TextXAlignment })
	infoLabel.Position = place.Position
	infoLabel.Size = place.Size
	infoLabel.TextXAlignment = place.Align
end

local function showName(text: string, color: Color3)
	nameLabel.Visible = true
	nameLabel.Text = text
	nameLabel.TextColor3 = color
end

-- Rebuilds the window for the open platform when what it shows changed;
-- timers and prices are refreshed every frame by updateLive.
local function render()
	local current = openPlatform
	local data = DataController:Get()
	if current == nil or data == nil then
		return
	end
	local platform = current :: BasePart
	local profile = data :: Types.Profile
	local index = platformIndex(platform)
	local owned = #profile.Incubators
	local slot = profile.Incubators[index]
	local state = if index > owned
		then "Locked"
		elseif slot.PetId ~= nil then "Pet"
		elseif slot.Egg ~= nil then "Egg"
		else "Empty"

	local eggIds, petIds = {}, {}
	for id in profile.Eggs do
		table.insert(eggIds, id)
	end
	for id in profile.Pets do
		table.insert(petIds, id)
	end
	table.sort(eggIds)
	table.sort(petIds)
	local key = table.concat({
		tostring(index),
		state,
		tostring(owned),
		if slot then tostring(slot.PetId) .. tostring(slot.Egg and slot.Egg.Theme) else "",
		if state == "Empty"
			then table.concat(eggIds, ",") .. "|" .. table.concat(petIds, ",")
			else "",
		if state == "Empty" then table.concat(profile.Equipped, ",") else "",
	}, "/")
	if key == builtKey then
		return
	end
	builtKey = key

	titleLabel.Text = string.format(Strings.PlatformTitle, index)
	list.Visible = false
	preview.Visible = false
	nameLabel.Visible = false
	actionButton.Visible = false
	takeButton.Visible = false
	clearList()
	clearPreview()
	placeInfo(INFO_TOP)

	if state == "Locked" then
		local price = platform:GetAttribute("Price")
		if type(price) == "number" and price > 0 then
			infoLabel.Text = Strings.PlatformBuyHint
			actionButton.Visible = true
			actionButton.Position = BUY_POSITION
		else
			infoLabel.Text = if owned < EggConfig.MaxIncubators
				then string.format(Strings.PlatformBuyFirst, index - 1)
				else Strings.PlatformLocked
		end
	elseif state == "Empty" then
		buildPicker(profile)
	elseif state == "Egg" then
		local egg = slot.Egg :: Types.EggInstance
		local color = PetStyle.Rarity[egg.Rarity] or WHITE
		showPreview(AssetModels.Egg(egg.Theme), color)
		showName(string.format(Strings.EggTheme, egg.Theme), color)
		placeInfo(INFO_SIDE)
		actionButton.Visible = true
		actionButton.Position = SIDE_FIRST
		takeButton.Visible = true
		takeButton.Position = SIDE_SECOND
	else
		local pet = profile.Pets[slot.PetId :: string]
		if pet then
			local color = PetStyle.Rarity[pet.Rarity] or WHITE
			local entry = PetConfig.Pets[pet.Kind]
			showPreview(AssetModels.Pet(pet.Kind), color)
			showName(if entry then entry.Name else pet.Kind, color)
			placeInfo(INFO_SIDE)
			infoLabel.Text = string.format(
				Strings.PlatformEarns,
				Money.Format(PetIncome.Rate(pet.Kind, PetConfig :: any))
			)
		end
		takeButton.Visible = true
		takeButton.Position = SIDE_FIRST
	end
end

-- Texts that change by the second: the hatch timer and the speed-up cost.
local function updateLive()
	local current = openPlatform
	local data = DataController:Get()
	if current == nil or data == nil then
		return
	end
	local platform = current :: BasePart
	local profile = data :: Types.Profile
	local slot = profile.Incubators[platformIndex(platform)]
	if slot == nil then
		local price = platform:GetAttribute("Price")
		if type(price) == "number" and price > 0 then
			actionButton.Text = string.format(Strings.PlatformBuy, Money.Format(price))
		end
		return
	end
	if slot.Egg ~= nil and slot.PetId == nil then
		local now = workspace:GetServerTimeNow()
		local hatchAt = slot.HatchAt or now
		infoLabel.Text = string.format(Strings.PlatformHatchesIn, formatDuration(hatchAt - now))
		actionButton.Text = if profile.FreeSpeedUps > 0
			then Strings.PlatformSpeedUpFree
			else string.format(
				Strings.PlatformSpeedUp,
				Money.Format(Incubation.SpeedUpCost(hatchAt, now, EggConfig))
			)
	end
end

local function open(platform: BasePart)
	openPlatform = platform
	builtKey = nil
	window.Visible = true
	render()
	updateLive()
end

local function close(platform: BasePart)
	if openPlatform == platform then
		openPlatform = nil
		builtKey = nil
		window.Visible = false
		clearList()
		clearPreview()
	end
end

local function press(button: Button)
	button.Pressed = true
	Widgets.PlaySound("Click")
	TweenService:Create(button.Part, PRESS_TWEEN, {
		CFrame = button.Rest * CFrame.new(0, -PRESS_DEPTH, 0),
		Color = button.Color:Lerp(Color3.new(1, 1, 1), 0.35),
	}):Play()
	for _, platform in button.Platforms do
		if isMine(platform) then
			open(platform)
			break
		end
	end
end

local function release(button: Button)
	button.Pressed = false
	TweenService:Create(button.Part, RELEASE_TWEEN, { CFrame = button.Rest, Color = button.Color })
		:Play()
	for _, platform in button.Platforms do
		close(platform)
	end
end

local function standsOn(button: Button, position: Vector3): boolean
	local part = button.Part
	local localPosition = button.Rest:PointToObjectSpace(position)
	return math.abs(localPosition.X) <= part.Size.X / 2 + STAND_MARGIN
		and math.abs(localPosition.Z) <= part.Size.Z / 2 + STAND_MARGIN
		and localPosition.Y >= 0
		and localPosition.Y <= STAND_HEIGHT
end

local function watchPlatform(platform: BasePart)
	local link = platform:WaitForChild("Button", 10)
	if not (link and link:IsA("ObjectValue")) then
		return
	end
	local value = (link :: ObjectValue).Value
	if not (value and value:IsA("BasePart")) then
		return
	end
	local part = value :: BasePart
	local entry = buttons[part]
	if entry == nil then
		entry = {
			Part = part,
			Rest = part.CFrame,
			Color = part.Color,
			Pressed = false,
			Platforms = {},
		}
		buttons[part] = entry
	end
	table.insert((entry :: Button).Platforms, platform)
end

local function watchPlot(plot: Instance)
	local function scan(child: Instance)
		if child:IsA("BasePart") and child:GetAttribute("Index") ~= nil then
			watchPlatform(child)
		end
	end
	plot.ChildAdded:Connect(scan)
	for _, child in plot:GetChildren() do
		task.spawn(scan, child)
	end
end

local function update()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local position = if root and root:IsA("BasePart") then root.Position else nil
	for _, button in buttons do
		local on = position ~= nil and standsOn(button, position :: Vector3)
		if on and not button.Pressed then
			press(button)
		elseif not on and button.Pressed then
			release(button)
		end
	end
end

local function onOfflineIncome(result: Types.OfflineIncomePayload)
	noticeLabel.Text = string.format(Strings.OfflineIncome, Money.Format(result.Coins))
	noticeLabel.Visible = true
	Widgets.PlaySound("Success")
	noticeToken += 1
	local token = noticeToken
	task.delay(OFFLINE_NOTICE_SECONDS, function()
		if token == noticeToken then
			noticeLabel.Visible = false
		end
	end)
end

local function build()
	-- Above the HUD windows, so a pack window left open never covers it.
	gui = Widgets.ScreenGui("Platform", 6)

	-- A dark navy window with a soft light edge (Ivan: no gray), above the
	-- level bar.
	window = Instance.new("Frame")
	window.Name = "Window"
	window.AnchorPoint = Vector2.new(0.5, 1)
	window.Position = UDim2.fromScale(0.5, 0.885)
	window.Size = UDim2.fromScale(0.56, 0.4)
	window.BackgroundColor3 = WHITE
	window.BorderSizePixel = 0
	window.Visible = false
	window.Parent = gui
	Widgets.AspectRatio(window, 2.3)
	Widgets.Corner(window, 0.08)
	local windowFace = Instance.new("UIGradient")
	windowFace.Rotation = 90
	windowFace.Color = ColorSequence.new(Color3.fromRGB(44, 52, 112), Color3.fromRGB(16, 18, 42))
	windowFace.Transparency = NumberSequence.new(0.06, 0.12)
	windowFace.Parent = window
	local edge = Widgets.Stroke(window, Color3.fromRGB(150, 175, 255), 3)
	edge.Transparency = 0.35

	titleLabel =
		Widgets.Label("Title", window, UDim2.fromScale(0.5, 0.12), UDim2.fromScale(0.04, 0.045))
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.TextColor3 = GOLD
	infoLabel = Widgets.Label("Info", window, INFO_TOP.Size, INFO_TOP.Position)
	infoLabel.TextColor3 = HINT_COLOR
	nameLabel =
		Widgets.Label("Name", window, UDim2.fromScale(0.56, 0.14), UDim2.fromScale(0.4, 0.18))
	nameLabel.Visible = false

	list = Instance.new("ScrollingFrame")
	list.Name = "List"
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Size = UDim2.fromScale(0.94, 0.68)
	list.Position = UDim2.fromScale(0.03, 0.28)
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.X
	list.ScrollingDirection = Enum.ScrollingDirection.X
	list.ScrollBarThickness = 6
	list.ScrollBarImageColor3 = Color3.fromRGB(150, 200, 255)
	list.ScrollBarImageTransparency = 0.3
	list.Parent = window
	local row = Instance.new("UIListLayout")
	row.FillDirection = Enum.FillDirection.Horizontal
	row.Padding = UDim.new(0, 10)
	row.VerticalAlignment = Enum.VerticalAlignment.Center
	local inset = Instance.new("UIPadding")
	inset.PaddingLeft = UDim.new(0, 6)
	inset.PaddingRight = UDim.new(0, 6)
	inset.Parent = list
	row.SortOrder = Enum.SortOrder.LayoutOrder
	row.Parent = list
	-- Cards are as tall as the list and a bit narrower than tall. Sized in
	-- pixels: scale sizes inside a scrolling list follow its canvas, not the
	-- visible frame, and collapsed to nothing in Play.
	local function sizeCard(card: GuiObject)
		local height = list.AbsoluteSize.Y * 0.86
		card.Size = UDim2.fromOffset(height * 0.78, height)
	end
	list.ChildAdded:Connect(function(child)
		if child:IsA("GuiObject") then
			sizeCard(child)
		end
	end)
	list:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		for _, child in list:GetChildren() do
			if child:IsA("GuiObject") then
				sizeCard(child)
			end
		end
	end)

	preview = Instance.new("Frame")
	preview.Name = "Preview"
	preview.BackgroundTransparency = 1
	preview.Size = UDim2.fromScale(0.3, 0.7)
	preview.Position = UDim2.fromScale(0.05, 0.22)
	preview.Visible = false
	preview.Parent = window
	previewGlow = Glow.new(preview, WHITE, 1, true, 1)

	actionButton =
		Widgets.Button("Action", window, BUTTON_SIZE, SIDE_FIRST, Color3.fromRGB(64, 170, 90))
	actionButton.Visible = false
	actionButton.Activated:Connect(function()
		local platform = openPlatform
		local data = DataController:Get()
		if platform == nil or data == nil then
			return
		end
		local slot = (data :: Types.Profile).Incubators[platformIndex(platform :: BasePart)]
		send(if slot == nil then "Buy" else "SpeedUp")
	end)
	takeButton =
		Widgets.Button("Take", window, BUTTON_SIZE, SIDE_SECOND, Color3.fromRGB(150, 90, 90))
	takeButton.Text = Strings.PlatformTake
	takeButton.Visible = false
	takeButton.Activated:Connect(function()
		send("Take")
	end)

	noticeLabel =
		Widgets.Label("Notice", gui, UDim2.fromScale(0.6, 0.07), UDim2.fromScale(0.2, 0.22))
	noticeLabel.TextColor3 = Color3.fromRGB(255, 214, 64)
	noticeLabel.Visible = false

	gui.Parent = player:WaitForChild("PlayerGui")
end

function PlatformController:Init()
	build()
end

function PlatformController:Start()
	task.spawn(function()
		local folder = workspace:WaitForChild("Plots")
		folder.ChildAdded:Connect(watchPlot)
		for _, plot in folder:GetChildren() do
			watchPlot(plot)
		end
	end)
	DataController.Changed:Connect(function()
		render()
		updateLive()
	end)
	ClientNet.On("OfflineIncome", onOfflineIncome)
	RunService.Heartbeat:Connect(function()
		update()
		if openPlatform then
			updateLive()
		end
	end)
end

return PlatformController
