--!strict
-- The egg offer window (pick 1 of 4, reroll) and the reveals for a picked
-- egg and a hatched pet (docs/design.md 4.3 "Яйца"). It only shows what the server put in the
-- profile's PendingOffer and sends the offer id plus a slot number; the
-- server decides everything else.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EggConfig = require(ReplicatedStorage.Shared.Config.EggConfig)
local PetConfig = require(ReplicatedStorage.Shared.Config.PetConfig)
local PetStyle = require(ReplicatedStorage.Shared.Config.PetStyle)
local ShopConfig = require(ReplicatedStorage.Shared.Config.ShopConfig)
local Strings = require(ReplicatedStorage.Shared.Config.Strings)
local EggRoller = require(ReplicatedStorage.Shared.Logic.EggRoller)
local PetIncome = require(ReplicatedStorage.Shared.Logic.PetIncome)
local Types = require(ReplicatedStorage.Shared.Types)
local Money = require(ReplicatedStorage.Shared.Util.Money)
local AssetModels = require(script.Parent.Parent.UI.AssetModels)
local Widgets = require(script.Parent.Parent.UI.Widgets)
local ClientNet = require(script.Parent.Parent.Util.ClientNet)
local DataController = require(script.Parent.DataController)

local player = Players.LocalPlayer

local REVEAL_SECONDS = 5
local NOTE_SECONDS = 2.5
local CASH_IMAGE = "rbxassetid://82091418744362"
-- Behind each egg: the pack's shine as slowly turning rays and a soft round
-- glow in the egg's theme color (Ivan, 2026-10-13).
local RAYS_IMAGE = "rbxassetid://98508264222687"
local RAYS_DEGREES_PER_SECOND = 25
local GLOW_RINGS = {
	{ Size = 0.95, Transparency = 0.88 },
	{ Size = 0.72, Transparency = 0.78 },
	{ Size = 0.5, Transparency = 0.6 },
}
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local CASH_COLOR = Color3.fromRGB(230, 160, 40)
local ROBUX_COLOR = Color3.fromRGB(60, 180, 90)

local EggOfferController = {}

type Card = {
	Button: TextButton,
	Preview: Frame,
	Theme: TextLabel,
	Buff: TextLabel,
	Stroke: UIStroke,
	Rays: ImageLabel,
	Rings: { Frame },
}

-- The cash reroll button's caption: "Reroll", the cash icon and the price.
type RerollCaption = {
	Word: TextLabel,
	Icon: ImageLabel,
	Price: TextLabel,
}

local gui: ScreenGui
local window: Frame
local cards: { Card } = {}
local rerollButton: TextButton
local rerollCaption: RerollCaption
local robuxRerollButton: TextButton
local robuxPrice: string? = nil
local oddsLabel: TextLabel
local warningLabel: TextLabel
local noteToken = 0
local noteShowing = false
local reveal: TextButton
local revealPreview: Frame
local revealTitle: TextLabel
local revealInfo: TextLabel
local revealNote: TextLabel

local shownOfferId: string? = nil
local waiting = false -- a request is in flight; ignore extra clicks
local waitToken = 0
local WAIT_TIMEOUT = 3

-- Blocks double clicks until the server answers. A dropped request (rate
-- limit, profile not loaded) gets no answer, so unlock after a timeout too.
local function startWaiting()
	waiting = true
	waitToken += 1
	local token = waitToken
	task.delay(WAIT_TIMEOUT, function()
		if token == waitToken then
			waiting = false
		end
	end)
end
local revealToken = 0

-- True when a picked egg would turn into coins: egg storage is full.
local function eggWouldBeLost(profile: Types.Profile): boolean
	local count = 0
	for _ in profile.Eggs do
		count += 1
	end
	return count >= profile.EggCapacity
end

-- Shows `text` in the warning line for a moment, then puts the storage
-- warning back.
local function flashNote(text: string)
	noteToken += 1
	local token = noteToken
	noteShowing = true
	warningLabel.Text = text
	warningLabel.Visible = true
	task.delay(NOTE_SECONDS, function()
		if token == noteToken then
			noteShowing = false
			warningLabel.Text = Strings.EggStorageFullWarning
			local profile = DataController:Get()
			warningLabel.Visible = profile ~= nil and eggWouldBeLost(profile :: Types.Profile)
		end
	end)
end

local function buildCard(parent: Instance, slot: number): Card
	local button = Widgets.Button(
		`Egg{slot}`,
		parent,
		UDim2.fromScale(0.23, 1),
		UDim2.new(),
		Color3.fromRGB(52, 56, 80)
	)
	button.LayoutOrder = slot
	button.AutoButtonColor = true

	-- A CanvasGroup clips the turning rays (rotated images ignore
	-- ClipsDescendants).
	local back = Instance.new("CanvasGroup")
	back.Name = "Glow"
	back.BackgroundTransparency = 1
	back.Size = UDim2.fromScale(0.9, 0.6)
	back.Position = UDim2.fromScale(0.05, 0.03)
	back.ZIndex = 2
	back.Parent = button
	local rays = Instance.new("ImageLabel")
	rays.Name = "Rays"
	rays.BackgroundTransparency = 1
	rays.Image = RAYS_IMAGE
	rays.ImageTransparency = 0.15
	rays.AnchorPoint = Vector2.new(0.5, 0.5)
	rays.Position = UDim2.fromScale(0.5, 0.5)
	rays.Size = UDim2.fromScale(1.4, 1.4)
	rays.Parent = back
	Widgets.AspectRatio(rays, 1)
	local rings = {}
	for _, ring in GLOW_RINGS do
		local circle = Instance.new("Frame")
		circle.Name = "Ring"
		circle.AnchorPoint = Vector2.new(0.5, 0.5)
		circle.Position = UDim2.fromScale(0.5, 0.5)
		circle.Size = UDim2.fromScale(ring.Size, ring.Size)
		circle.BackgroundTransparency = ring.Transparency
		circle.BorderSizePixel = 0
		circle.Parent = back
		Widgets.AspectRatio(circle, 1)
		Widgets.Corner(circle, 0.5)
		table.insert(rings, circle)
	end

	local preview = Instance.new("Frame")
	preview.Name = "PreviewHolder"
	preview.BackgroundTransparency = 1
	preview.Size = UDim2.fromScale(0.9, 0.56)
	preview.Position = UDim2.fromScale(0.05, 0.05)
	preview.ZIndex = 3
	preview.Parent = button

	local theme =
		Widgets.Label("Theme", button, UDim2.fromScale(0.9, 0.14), UDim2.fromScale(0.05, 0.65))
	local buff =
		Widgets.Label("Buff", button, UDim2.fromScale(0.9, 0.11), UDim2.fromScale(0.05, 0.81))
	theme.ZIndex = 4
	buff.ZIndex = 4

	button.Activated:Connect(function()
		if waiting or shownOfferId == nil then
			return
		end
		startWaiting()
		ClientNet.Fire("EggPick", shownOfferId, slot)
	end)

	return {
		Button = button,
		Preview = preview,
		Theme = theme,
		Buff = buff,
		Stroke = Widgets.Stroke(button, WHITE, 3),
		Rays = rays,
		Rings = rings,
	}
end

-- A label sized to its text inside a row; resize() sets the text height.
local function rowLabel(name: string, parent: Instance, order: number): TextLabel
	local label = Widgets.Label(name, parent, UDim2.fromScale(0, 1), UDim2.new())
	label.TextScaled = false
	label.AutomaticSize = Enum.AutomaticSize.X
	label.LayoutOrder = order
	label.ZIndex = 5
	return label
end

-- "Reroll", the pack's cash icon and the price, centered on the button
-- (Ivan's picture 1).
local function buildRerollCaption(button: TextButton): RerollCaption
	local row = Instance.new("Frame")
	row.Name = "Caption"
	row.BackgroundTransparency = 1
	row.AnchorPoint = Vector2.new(0.5, 0.5)
	row.Position = UDim2.fromScale(0.5, 0.45)
	row.Size = UDim2.fromScale(0.92, 0.6)
	row.ZIndex = 5
	row.Parent = button
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0.03, 0)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = row

	local word = rowLabel("Word", row, 1)
	local icon = Instance.new("ImageLabel")
	icon.Name = "Cash"
	icon.BackgroundTransparency = 1
	icon.Image = CASH_IMAGE
	icon.Size = UDim2.fromScale(1, 1.3)
	icon.LayoutOrder = 2
	icon.ZIndex = 5
	icon.Parent = row
	local square = Instance.new("UIAspectRatioConstraint")
	square.AspectRatio = 1
	square.DominantAxis = Enum.DominantAxis.Height
	square.Parent = icon
	local price = rowLabel("Price", row, 3)
	price.TextColor3 = Color3.fromRGB(150, 255, 120)

	local function resize()
		local size = math.max(math.floor(row.AbsoluteSize.Y * 0.95), 8)
		word.TextSize = size
		price.TextSize = size
	end
	row:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
	resize()
	return { Word = word, Icon = icon, Price = price }
end

-- The Robux price of the reroll product, once (shown on the green button).
local function loadRobuxPrice()
	local id = ShopConfig.Products.Reroll.Id
	if id == 0 then
		return
	end
	task.spawn(function()
		local ok, info = pcall(function()
			return MarketplaceService:GetProductInfo(id, Enum.InfoType.Product)
		end)
		local price = ok and type(info) == "table" and (info :: any).PriceInRobux
		if type(price) == "number" then
			robuxPrice = tostring(price)
			robuxRerollButton.Text = string.format(Strings.RerollRobux, robuxPrice)
		end
	end)
end

local function build()
	gui = Widgets.ScreenGui("EggOffer", 5)

	window = Widgets.Panel(
		"Window",
		gui,
		UDim2.fromScale(0.8, 0.62),
		UDim2.fromScale(0.5, 0.5),
		Color3.fromRGB(255, 140, 0)
	)
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.Visible = false
	Widgets.AspectRatio(window, 1.9)

	local title =
		Widgets.Label("Title", window, UDim2.fromScale(0.7, 0.1), UDim2.fromScale(0.03, 0.03))
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = Strings.EggOfferTitle

	local row = Instance.new("Frame")
	row.Name = "Eggs"
	row.BackgroundTransparency = 1
	row.Size = UDim2.fromScale(0.94, 0.56)
	row.Position = UDim2.fromScale(0.03, 0.16)
	row.Parent = window
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0.02, 0)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = row
	for slot = 1, EggConfig.EggsPerOffer do
		cards[slot] = buildCard(row, slot)
	end

	warningLabel =
		Widgets.Label("Warning", window, UDim2.fromScale(0.94, 0.06), UDim2.fromScale(0.03, 0.73))
	warningLabel.TextColor3 = Color3.fromRGB(255, 170, 80)
	warningLabel.Text = Strings.EggStorageFullWarning

	-- Odds per rarity on two lines, a bit smaller than before, each rarity
	-- name in its color (Ivan).
	oddsLabel =
		Widgets.Label("Odds", window, UDim2.fromScale(0.45, 0.12), UDim2.fromScale(0.03, 0.83))
	oddsLabel.TextXAlignment = Enum.TextXAlignment.Left
	oddsLabel.TextColor3 = Color3.fromRGB(200, 200, 215)
	oddsLabel.RichText = true
	oddsLabel.TextScaled = false
	oddsLabel.TextWrapped = true
	local function sizeOdds()
		oddsLabel.TextSize = math.max(math.floor(window.AbsoluteSize.Y * 0.032), 8)
	end
	window:GetPropertyChangedSignal("AbsoluteSize"):Connect(sizeOdds)
	sizeOdds()

	rerollButton = Widgets.Button(
		"Reroll",
		window,
		UDim2.fromScale(0.27, 0.12),
		UDim2.fromScale(0.5, 0.83),
		CASH_COLOR
	)
	rerollCaption = buildRerollCaption(rerollButton)
	rerollButton.Activated:Connect(function()
		if waiting or shownOfferId == nil then
			return
		end
		startWaiting()
		ClientNet.Fire("EggReroll", shownOfferId)
	end)

	-- Robux reroll next to it (Ivan's picture 2); the odds stay visible
	-- before the purchase. Until Ivan creates the product it only says so.
	robuxRerollButton = Widgets.Button(
		"RobuxReroll",
		window,
		UDim2.fromScale(0.18, 0.12),
		UDim2.fromScale(0.79, 0.83),
		ROBUX_COLOR
	)
	robuxRerollButton.Text = string.format(Strings.RerollRobux, "")
	robuxRerollButton.Activated:Connect(function()
		local id = ShopConfig.Products.Reroll.Id
		if id ~= 0 then
			MarketplaceService:PromptProductPurchase(player, id)
		else
			flashNote(Strings.ShopRobuxSoon)
		end
	end)
	loadRobuxPrice()

	reveal = Widgets.Button(
		"Reveal",
		gui,
		UDim2.fromScale(0.36, 0.5),
		UDim2.fromScale(0.5, 0.5),
		Color3.fromRGB(34, 36, 52)
	)
	reveal.AnchorPoint = Vector2.new(0.5, 0.5)
	reveal.AutoButtonColor = false
	reveal.Visible = false
	Widgets.AspectRatio(reveal, 0.9)
	revealPreview = Instance.new("Frame")
	revealPreview.Name = "PreviewHolder"
	revealPreview.BackgroundTransparency = 1
	revealPreview.Size = UDim2.fromScale(0.8, 0.5)
	revealPreview.Position = UDim2.fromScale(0.1, 0.04)
	revealPreview.Parent = reveal
	revealTitle =
		Widgets.Label("Title", reveal, UDim2.fromScale(0.9, 0.13), UDim2.fromScale(0.05, 0.56))
	revealInfo =
		Widgets.Label("Info", reveal, UDim2.fromScale(0.9, 0.1), UDim2.fromScale(0.05, 0.7))
	revealNote =
		Widgets.Label("Note", reveal, UDim2.fromScale(0.9, 0.07), UDim2.fromScale(0.05, 0.82))
	revealNote.TextColor3 = Color3.fromRGB(255, 200, 120)
	local close =
		Widgets.Label("Close", reveal, UDim2.fromScale(0.9, 0.05), UDim2.fromScale(0.05, 0.92))
	close.TextColor3 = Color3.fromRGB(170, 170, 190)
	close.Text = Strings.TapToClose
	reveal.Activated:Connect(function()
		reveal.Visible = false
	end)

	gui.Parent = player:WaitForChild("PlayerGui")
end

local function setPreview(holder: Frame, model: Model?, color: Color3)
	holder:ClearAllChildren()
	AssetModels.Viewport(holder, model, color)
end

-- Rich text: each rarity name in its color.
local function oddsText(offer: Types.EggOffer): string
	local odds = EggRoller.Odds(EggRoller.Weights(offer.Context :: any, EggConfig))
	local parts = {}
	for index, rarity in PetConfig.Rarities do
		local chance = odds[index] * 100
		local shown = if chance < 10
			then string.format("%.1f", chance)
			else tostring(math.floor(chance + 0.5))
		local color = (PetStyle.Rarity[rarity] or WHITE):ToHex()
		local name = (Strings.Rarity :: any)[rarity] or rarity
		table.insert(parts, `<font color="#{color}">{name}</font> {shown}%`)
	end
	return string.format(Strings.Odds, table.concat(parts, " · "))
end

local function setRerollCaption(word: string, price: string?)
	rerollCaption.Word.Text = word
	rerollCaption.Icon.Visible = price ~= nil
	rerollCaption.Price.Visible = price ~= nil
	rerollCaption.Price.Text = price or ""
end

local function showOffer(profile: Types.Profile, offer: Types.EggOffer)
	if offer.OfferId ~= shownOfferId then
		shownOfferId = offer.OfferId
		-- The egg's rarity stays a surprise (Ivan): the card shows only its
		-- theme, its main buff and the theme's colors.
		for slot, card in cards do
			local egg = offer.Eggs[slot]
			local theme = PetConfig.Themes[egg.Theme]
			local themeColor = PetStyle.Theme[egg.Theme] or WHITE
			local glowColor = themeColor:Lerp(WHITE, 0.35)
			setPreview(card.Preview, AssetModels.Egg(egg.Theme), themeColor)
			card.Button.BackgroundColor3 = themeColor:Lerp(BLACK, 0.65)
			card.Rays.ImageColor3 = glowColor
			for _, ring in card.Rings do
				ring.BackgroundColor3 = glowColor
			end
			card.Theme.Text = string.format(Strings.EggTheme, egg.Theme)
			card.Theme.TextColor3 = themeColor:Lerp(WHITE, 0.2)
			local stat = if theme then theme.Stat else nil
			card.Buff.Text = if stat
				then string.format(Strings.EggMainBuff, (Strings.StatName :: any)[stat] or stat)
				else ""
			card.Buff.TextColor3 = if stat then PetStyle.Stat[stat] or WHITE else WHITE
			card.Stroke.Color = glowColor
		end
		oddsLabel.Text = oddsText(offer)
	end

	local cost = EggConfig.RerollCosts[offer.RerollCount + 1]
	robuxRerollButton.Visible = cost ~= nil
	if cost and profile.FreeRerolls > 0 then
		setRerollCaption(string.format(Strings.RerollFree, profile.FreeRerolls), nil)
		rerollButton.BackgroundColor3 = ROBUX_COLOR
	elseif cost then
		setRerollCaption(Strings.Reroll, Money.Format(cost))
		rerollButton.BackgroundColor3 = if profile.Coins >= cost
			then CASH_COLOR
			else Color3.fromRGB(110, 100, 90)
	else
		setRerollCaption(Strings.RerollLimit, nil)
		rerollButton.BackgroundColor3 = Color3.fromRGB(90, 90, 110)
	end
	if not noteShowing then
		warningLabel.Visible = eggWouldBeLost(profile)
	end
	window.Visible = true
end

local function onProfile(profile: Types.Profile)
	waiting = false
	local offer = profile.PendingOffer
	if offer then
		showOffer(profile, offer)
	else
		shownOfferId = nil
		window.Visible = false
	end
end

local function showReveal(model: Model?, color: Color3, title: string, info: string, note: string)
	setPreview(revealPreview, model, color)
	revealTitle.Text = title
	revealTitle.TextColor3 = color
	revealInfo.Text = info
	revealNote.Text = note
	reveal.Visible = true

	revealToken += 1
	local token = revealToken
	task.delay(REVEAL_SECONDS, function()
		if token == revealToken then
			reveal.Visible = false
		end
	end)
end

local function onEggPicked(result: Types.EggPickedPayload)
	-- No rarity here either: the pet's rarity shows when it hatches.
	local color = PetStyle.Theme[result.Theme] or WHITE
	local title = string.format(Strings.EggTheme, result.Theme)
	local info: string
	if result.Where ~= "Coins" then
		info = Strings.EggStored
	else
		info = string.format(Strings.ConvertedToCoins, Money.Format(result.Coins))
	end
	showReveal(
		AssetModels.Egg(result.Theme),
		color,
		title,
		info,
		if result.AutoPicked then Strings.AutoPicked else ""
	)
end

local function onHatched(result: Types.PetHatchedPayload)
	local entry = PetConfig.Pets[result.Kind]
	local color = PetStyle.Rarity[result.Rarity] or Color3.new(1, 1, 1)
	local rarityName = (Strings.Rarity :: any)[result.Rarity] or result.Rarity
	showReveal(
		AssetModels.Pet(result.Kind),
		color,
		string.format(Strings.Hatched, if entry then entry.Name else result.Kind),
		`{rarityName} · {string.format(
			Strings.PlatformIncome,
			Money.Format(PetIncome.Rate(result.Kind, PetConfig :: any))
		)}`,
		""
	)
end

function EggOfferController:Init()
	build()
end

function EggOfferController:Start()
	DataController.Changed:Connect(onProfile)
	ClientNet.On("EggPicked", onEggPicked)
	ClientNet.On("PetHatched", onHatched)
	-- A refused request (for example not enough coins) unlocks the buttons.
	ClientNet.On("ActionResult", function()
		waiting = false
	end)

	-- No timer: the window stays until the player picks (Ivan, 2026-10-13).
	RunService.RenderStepped:Connect(function()
		if not window.Visible then
			return
		end
		local angle = (os.clock() * RAYS_DEGREES_PER_SECOND) % 360
		for _, card in cards do
			card.Rays.Rotation = angle
		end
	end)

	local profile = DataController:Get()
	if profile then
		onProfile(profile)
	end
end

return EggOfferController
