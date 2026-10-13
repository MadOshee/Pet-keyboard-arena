--!strict
-- The egg offer (pick 1 of 4, reroll) and the reveals (UI/RevealScreen) for a picked
-- egg and a hatched pet (docs/design.md 4.3 "Яйца"). It only shows what the server put in the
-- profile's PendingOffer and sends the offer id plus a slot number; the
-- server decides everything else.
--
-- Ivan's layout (Figma, 2026-10-13): no window; the world blurs and dims,
-- the winner and the round's money and XP sit on top, then the four eggs
-- with their name and main buff, the two reroll buttons and the odds. A
-- reroll spins the eggs like a slot machine's reels for about 1.3 s.

local Lighting = game:GetService("Lighting")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local EggConfig = require(ReplicatedStorage.Shared.Config.EggConfig)
local PetConfig = require(ReplicatedStorage.Shared.Config.PetConfig)
local PetStyle = require(ReplicatedStorage.Shared.Config.PetStyle)
local ShopConfig = require(ReplicatedStorage.Shared.Config.ShopConfig)
local Strings = require(ReplicatedStorage.Shared.Config.Strings)
local EggRoller = require(ReplicatedStorage.Shared.Logic.EggRoller)
local PetIncome = require(ReplicatedStorage.Shared.Logic.PetIncome)
local Types = require(ReplicatedStorage.Shared.Types)
local Money = require(ReplicatedStorage.Shared.Util.Money)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local AssetModels = require(script.Parent.Parent.UI.AssetModels)
local RevealScreen = require(script.Parent.Parent.UI.RevealScreen)
local Widgets = require(script.Parent.Parent.UI.Widgets)
local ClientNet = require(script.Parent.Parent.Util.ClientNet)
local DataController = require(script.Parent.DataController)

local player = Players.LocalPlayer

local NOTE_SECONDS = 2.5
local CASH_IMAGE = "rbxassetid://82091418744362"
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local CASH_COLOR = Color3.fromRGB(7, 138, 0)
local ROBUX_COLOR = Color3.fromRGB(60, 180, 90)
local XP_COLOR = Color3.fromRGB(120, 200, 255)
local TEAM_COLORS: { [string]: Color3 } = {
	Red = Color3.fromRGB(255, 80, 80),
	Blue = Color3.fromRGB(80, 160, 255),
	Draw = Color3.fromRGB(255, 255, 255),
}
-- The money button's face when there is no reroll to buy.
local DISABLED_FACE =
	ColorSequence.new(Color3.fromRGB(170, 170, 180), Color3.fromRGB(100, 100, 110))

-- Layout in parts of the content frame, which keeps the Figma frame's shape.
local CONTENT_ASPECT = 1.85
local EGG_CENTERS = { 0.24, 0.413, 0.587, 0.76 }
local EGG_WIDTH = 0.165
local REROLL_BUTTON_SIZE = UDim2.fromScale(0.159, 0.089)
local BLUR_SIZE = 16
local DIM_TRANSPARENCY = 0.45
local FADE = TweenInfo.new(0.25)

-- The reroll reels: eggs run down at SPIN_SPEED eggs a second until the new
-- offer is known, then each reel slows down and stops on its new egg, left
-- to right, with a small bounce.
local SPIN_SPEED = 16
local STOP_SECONDS = 0.55 -- the first reel's slow-down
local STOP_STAGGER = 0.15 -- each next reel stops this much later
local MIN_FREE_SPIN = 0.3 -- spin at least this long before slowing down
local SPIN_TIMEOUT = 3 -- no answer: stop on the eggs we have
local BOUNCE = 1.2 -- ease-out-back overshoot
local BOUNCE_SPEED = BOUNCE + 3 -- that easing's slope at the start
local LABEL_POP = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
-- A refused reroll shakes its button.
local SHAKE_STEPS = 6
local SHAKE_OFFSET = 0.008 -- of the content width
local SHAKE_TWEEN = TweenInfo.new(0.05, Enum.EasingStyle.Sine)

local EggOfferController = {}

-- Fires when the egg screen opens or closes; the hub HUD hides under it so
-- only the blurred world shows behind the eggs (Ivan's Figma).
EggOfferController.ShownChanged = Signal.new() :: Signal.Signal<boolean>

-- One egg column. Its reel clips the eggs that run through it; each theme
-- the reel has shown keeps its own viewport (Frames), so a spin only moves
-- and shows them.
type Card = {
	Button: TextButton,
	Reel: Frame,
	Frames: { [string]: Frame },
	Name: TextLabel,
	Buff: TextLabel,
	NameScale: UIScale,
	BuffScale: UIScale,
	Theme: string?, -- the egg shown when not spinning
}

-- A spinning reel. Egg Sequence[k] is in the middle when Position == k;
-- with Stop set it slows down and lands on Sequence[Stop.Target].
type Spin = {
	Sequence: { string },
	Position: number,
	StopTheme: string?, -- where to stop, once the new offer is known
	StopAt: number, -- os.clock() when slowing down may begin
	Stop: {
		From: number,
		Target: number,
		Started: number,
		Seconds: number,
	}?,
}

-- A reroll button's caption row: the word, an optional icon and the price
-- side by side ("Reroll [cash] $50", "Reroll ⬢10").
type Caption = {
	Row: Frame,
	Word: TextLabel,
	Icon: ImageLabel?,
	Price: TextLabel,
	Scale: UIScale?, -- the button's hover and press scale
}

local gui: ScreenGui
local root: Frame -- the whole screen while an offer is shown
local dim: Frame
local blur: BlurEffect
local cards: { Card } = {}
local spins: { [number]: Spin } = {}
local spinStarted = 0
local rerollButton: TextButton
local rerollCaption: Caption
local captions: { Caption } = {}
local rerollFace: UIGradient? = nil -- the money button's lime face
local rerollFaceColor: ColorSequence? = nil
local robuxRerollButton: TextButton
local robuxCaption: Caption? = nil
local robuxPrice: string? = nil
local oddsLabel: TextLabel
local winnerLabel: TextLabel
local rewardsRow: Frame
local rewardMoney: TextLabel
local rewardXp: TextLabel
-- The last round's result, shown with the offer it brought.
local pendingResult: Types.RoundResultPayload? = nil
local shownResult: Types.RoundResultPayload? = nil
local warningLabel: TextLabel
local noteToken = 0
local noteShowing = false

local shownOfferId: string? = nil
local shownRerollCount = 0
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

-- The egg's viewport in this reel, made the first time the reel shows it.
local function themeFrame(card: Card, theme: string): Frame
	local found = card.Frames[theme]
	if found then
		return found
	end
	local frame = Instance.new("Frame")
	frame.Name = theme
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromScale(1, 1)
	frame.Visible = false
	frame.Parent = card.Reel
	AssetModels.Viewport(frame, AssetModels.Egg(theme), PetStyle.Theme[theme] or WHITE)
	card.Frames[theme] = frame
	return frame
end

-- `theme` moved down by `offset` reel heights, with `above` right over it.
local function placeReel(card: Card, theme: string, offset: number, above: string?)
	local frame = themeFrame(card, theme)
	local aboveFrame = if above and above ~= theme then themeFrame(card, above) else nil
	for _, other in card.Frames do
		other.Visible = other == frame or other == aboveFrame
	end
	frame.Position = UDim2.fromScale(0, offset)
	if aboveFrame then
		aboveFrame.Position = UDim2.fromScale(0, offset - 1)
	end
end

local function setLabelsVisible(card: Card, visible: boolean, pop: boolean)
	card.Name.Visible = visible
	card.Buff.Visible = visible
	if visible and pop then
		for _, scale in { card.NameScale, card.BuffScale } do
			scale.Scale = 0.5
			TweenService:Create(scale, LABEL_POP, { Scale = 1 }):Play()
		end
	end
end

-- A reel shows `theme` standing still.
local function land(card: Card, theme: string, pop: boolean)
	card.Theme = theme
	placeReel(card, theme, 0, nil)
	setLabelsVisible(card, true, pop)
end

local function randomTheme(not1: string?, not2: string?): string
	local themes = EggConfig.OfferThemes
	for _ = 1, 10 do
		local theme = themes[math.random(1, #themes)]
		if theme ~= not1 and theme ~= not2 then
			return theme
		end
	end
	return themes[1]
end

-- Random eggs on the reel up to `index`, never the same egg twice in a row.
local function extend(sequence: { string }, index: number)
	for k = #sequence + 1, index do
		sequence[k] = randomTheme(sequence[k - 1])
	end
end

local function isSpinning(): boolean
	return next(spins) ~= nil
end

-- Every reel starts running down from the egg it shows.
local function startSpin()
	if isSpinning() then
		return
	end
	spinStarted = os.clock()
	for slot, card in cards do
		spins[slot] = {
			Sequence = { card.Theme or randomTheme() },
			Position = 1,
			StopTheme = nil,
			StopAt = 0,
			Stop = nil,
		}
		setLabelsVisible(card, false, false)
	end
end

-- The reels stop on `themes`, left to right.
local function stopSpin(themes: { string })
	local earliest = math.max(os.clock(), spinStarted + MIN_FREE_SPIN)
	for slot, spin in spins do
		if spin.StopTheme == nil and themes[slot] then
			spin.StopTheme = themes[slot]
			spin.StopAt = earliest
		end
	end
end

-- From full speed, the reel slows down onto its new egg: it lands a few
-- eggs further on, so it keeps its speed at first and bounces at the end.
local function beginStop(slot: number, spin: Spin, now: number)
	local target = spin.StopTheme :: string
	local seconds = STOP_SECONDS + STOP_STAGGER * (slot - 1)
	local index = math.max(
		math.floor(spin.Position) + 2,
		math.ceil(spin.Position + SPIN_SPEED * seconds / BOUNCE_SPEED)
	)
	extend(spin.Sequence, index - 1)
	-- The egg before the target must differ from it (the egg above may show).
	while spin.Sequence[index - 1] == target do
		index += 1
		extend(spin.Sequence, index - 1)
	end
	for k = #spin.Sequence, index, -1 do
		spin.Sequence[k] = nil
	end
	spin.Sequence[index] = target
	spin.Sequence[index + 1] = randomTheme(target)
	spin.Stop = {
		From = spin.Position,
		Target = index,
		Started = now,
		Seconds = (index - spin.Position) * BOUNCE_SPEED / SPIN_SPEED,
	}
end

local function stepSpins(dt: number)
	local now = os.clock()
	for slot, spin in spins do
		local card = cards[slot]
		local stop = spin.Stop
		if stop == nil and spin.StopTheme == nil and now - spinStarted > SPIN_TIMEOUT then
			-- No new offer came (the request was dropped): stop where we were.
			spin.StopTheme = card.Theme or spin.Sequence[1]
			spin.StopAt = now
		end
		if stop == nil and spin.StopTheme and now >= spin.StopAt then
			beginStop(slot, spin, now)
			stop = spin.Stop
		end
		if stop then
			local x = math.min((now - stop.Started) / stop.Seconds, 1)
			local eased = 1 + (BOUNCE + 1) * (x - 1) ^ 3 + BOUNCE * (x - 1) ^ 2
			spin.Position = stop.From + (stop.Target - stop.From) * eased
			if x >= 1 then
				spins[slot] = nil
				land(card, spin.Sequence[stop.Target], true)
				continue
			end
		else
			spin.Position += SPIN_SPEED * dt
		end
		local k = math.floor(spin.Position)
		extend(spin.Sequence, k + 1)
		placeReel(card, spin.Sequence[k], spin.Position - k, spin.Sequence[k + 1])
	end
end

-- A label with a UIScale for its pop when the reel stops.
local function poppingLabel(name: string, parent: Instance, size: UDim2, position: UDim2)
	local label = Widgets.Label(name, parent, size, position)
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.ZIndex = 3
	local scale = Instance.new("UIScale")
	scale.Parent = label
	return label, scale
end

-- One egg column: the egg on its reel, its name and its main buff. The
-- whole column is the pick button.
local function buildCard(parent: Instance, slot: number): Card
	local button = Instance.new("TextButton")
	button.Name = `Egg{slot}`
	button.Text = ""
	button.BackgroundTransparency = 1
	button.AutoButtonColor = false
	button.AnchorPoint = Vector2.new(0.5, 0)
	button.Size = UDim2.fromScale(EGG_WIDTH, 0.37)
	button.Position = UDim2.fromScale(EGG_CENTERS[slot], 0.25)
	button.Parent = parent
	Widgets.AnimatePress(button)

	local reel = Instance.new("Frame")
	reel.Name = "Reel"
	reel.BackgroundTransparency = 1
	reel.ClipsDescendants = true
	reel.Size = UDim2.fromScale(1, 0.69)
	reel.ZIndex = 2
	reel.Parent = button

	local name, nameScale =
		poppingLabel("EggName", button, UDim2.fromScale(1.05, 0.15), UDim2.fromScale(0.5, 0.8))
	local buff, buffScale =
		poppingLabel("Buff", button, UDim2.fromScale(1, 0.095), UDim2.fromScale(0.5, 0.93))

	button.Activated:Connect(function()
		if waiting or shownOfferId == nil or isSpinning() then
			return
		end
		Widgets.PlaySound("Click")
		startWaiting()
		ClientNet.Fire("EggPick", shownOfferId, slot)
	end)

	return {
		Button = button,
		Reel = reel,
		Frames = {},
		Name = name,
		Buff = buff,
		NameScale = nameScale,
		BuffScale = buffScale,
		Theme = nil,
	}
end

-- Text height of a pack label and of its white top layer.
local function setTextSize(label: TextLabel, size: number)
	label.TextSize = size
	label.TextWrapped = false
	local top = label:FindFirstChild("Color")
	if top and top:IsA("TextLabel") then
		top.TextScaled = false
		top.TextWrapped = false
		top.TextSize = size
	end
end

-- A label in the caption row: as wide as its text.
local function rowLabel(label: TextLabel, row: Frame, order: number)
	label.TextScaled = false
	label.AutomaticSize = Enum.AutomaticSize.X
	label.AnchorPoint = Vector2.zero
	label.Size = UDim2.fromScale(0, 1)
	label.LayoutOrder = order
	label.Parent = row
end

-- Both buttons' captions share one text size (Ivan): as tall as the rows,
-- smaller when a long caption ("NO REROLLS LEFT") would not fit its button.
local function setCaptionSize(size: number)
	for _, caption in captions do
		setTextSize(caption.Word, size)
		setTextSize(caption.Price, size)
	end
end

-- Sized from the rows without the hover or press scale, so the text does
-- not jump while a button grows (Ivan).
local function fitCaptions()
	local height = math.huge
	for _, caption in captions do
		local scale = caption.Scale
		local factor = if scale and scale.Scale > 0 then scale.Scale else 1
		height = math.min(height, caption.Row.AbsoluteSize.Y / factor)
	end
	setCaptionSize(math.max(math.floor(height * 0.95 + 0.01), 8))
end

local function buildCaption(
	button: TextButton,
	container: Instance,
	word: TextLabel,
	price: TextLabel,
	icon: ImageLabel?
): Caption
	local row = Instance.new("Frame")
	row.Name = "Caption"
	row.BackgroundTransparency = 1
	row.AnchorPoint = Vector2.new(0.5, 0.5)
	row.Position = UDim2.fromScale(0.5, 0.52)
	row.Size = UDim2.fromScale(0.92, 0.62)
	row.ZIndex = 5
	row.Parent = container
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0.03, 0)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = row

	rowLabel(word, row, 1)
	rowLabel(price, row, 3)
	if icon then
		icon.LayoutOrder = 2
		icon.Parent = row
	end

	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		local width = layout.AbsoluteContentSize.X
		local room = row.AbsoluteSize.X
		if width > room and room > 0 and word.TextSize > 8 then
			setCaptionSize(math.max(math.floor(word.TextSize * room / width * 0.97), 8))
		end
	end)
	local caption = {
		Row = row,
		Word = word,
		Icon = icon,
		Price = price,
		Scale = button:FindFirstChildOfClass("UIScale"),
	}
	table.insert(captions, caption)
	return caption
end

-- "Reroll", the pack's cash icon and the price in the lime button's orange
-- text (Ivan's pictures: the "+5 Levels" button).
local function buildRerollCaption(button: TextButton): Caption
	local container = button:FindFirstChild("Container") or button
	-- The template's own two-layer text is the word; a copy is the price.
	local source = container:FindFirstChild("Text")
	local word = if source and source:IsA("TextLabel")
		then source
		else Widgets.Label("Text", container, UDim2.new(), UDim2.new())
	local price = word:Clone()
	word.Name = "Word"
	price.Name = "Price"

	local icon = Instance.new("ImageLabel")
	icon.Name = "Cash"
	icon.BackgroundTransparency = 1
	icon.Image = CASH_IMAGE
	icon.Size = UDim2.fromScale(1, 1.2)
	icon.ZIndex = 5
	local square = Instance.new("UIAspectRatioConstraint")
	square.AspectRatio = 1
	square.DominantAxis = Enum.DominantAxis.Height
	square.Parent = icon

	local face = container:FindFirstChildOfClass("UIGradient")
	if face and container ~= button then
		rerollFace = face
		rerollFaceColor = face.Color
	end
	return buildCaption(button, container, word, price, icon)
end

-- "Reroll" in the rainbow button's white text with the pack's green Robux
-- price to its right, like the money button (Ivan).
local function buildRobuxCaption(button: TextButton): Caption
	local container = button:FindFirstChild("Container") or button
	local name = container:FindFirstChild("Name")
	local word = if name and name:IsA("TextLabel")
		then name
		else Widgets.Label("Name", container, UDim2.new(), UDim2.new())
	local found = button:FindFirstChild("Price")
	local price = if found and found:IsA("TextLabel") then found else word:Clone()
	word.Name = "Word"
	price.Name = "Price"
	Widgets.SetText(word, Strings.Reroll)
	return buildCaption(button, container, word, price, nil)
end

-- The Robux price on the rainbow button, as the pack writes it.
local function showRobuxPrice(price: string)
	local caption = robuxCaption
	if caption then
		Widgets.SetText(caption.Price, string.format(Strings.RobuxPrice, price))
		fitCaptions()
	end
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
			showRobuxPrice(robuxPrice :: string)
		end
	end)
end

-- Why the money reroll cannot run now, or nil when it can.
local function rerollRefusal(): string?
	local found = DataController:Get()
	if found == nil or (found :: Types.Profile).PendingOffer == nil then
		return nil
	end
	local profile = found :: Types.Profile
	local offer = profile.PendingOffer :: Types.EggOffer
	local cost = EggConfig.RerollCosts[offer.RerollCount + 1]
	if cost == nil then
		return Strings.Errors.RerollLimit
	end
	if profile.FreeRerolls <= 0 and profile.Coins < cost then
		return Strings.Errors.NotEnoughCoins
	end
	return nil
end

-- A quick left-right shake of a button whose action was refused.
local shakeHomes: { [GuiObject]: UDim2 } = {}
local shakeTokens: { [GuiObject]: number } = {}
local function shake(button: GuiObject)
	local token = (shakeTokens[button] or 0) + 1
	shakeTokens[button] = token
	local home = shakeHomes[button] or button.Position
	shakeHomes[button] = home
	task.spawn(function()
		for step = 1, SHAKE_STEPS do
			if shakeTokens[button] ~= token then
				return
			end
			local side = if step % 2 == 1 then 1 else -1
			local push = SHAKE_OFFSET * (1 - (step - 1) / SHAKE_STEPS)
			TweenService:Create(button, SHAKE_TWEEN, {
				Position = home + UDim2.fromScale(side * push, 0),
			}):Play()
			task.wait(SHAKE_TWEEN.Time)
		end
		if shakeTokens[button] == token then
			button.Position = home
		end
	end)
end

local function build()
	gui = Widgets.ScreenGui("EggOffer", 5)
	gui.IgnoreGuiInset = true

	root = Instance.new("Frame")
	root.Name = "Offer"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Visible = false
	root.Parent = gui
	-- Darkens the screen (the world behind is blurred too); clicks still go
	-- through to the HUD.
	dim = Instance.new("Frame")
	dim.Name = "Dim"
	dim.BackgroundColor3 = BLACK
	dim.BackgroundTransparency = 1
	dim.BorderSizePixel = 0
	dim.Size = UDim2.fromScale(1, 1)
	dim.Parent = root

	-- Everything else keeps the shape of Ivan's Figma frame.
	local content = Instance.new("Frame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.AnchorPoint = Vector2.new(0.5, 0.5)
	content.Position = UDim2.fromScale(0.5, 0.5)
	content.Size = UDim2.fromScale(1, 1)
	content.Parent = root
	Widgets.AspectRatio(content, CONTENT_ASPECT)

	-- On top: which team won, then the money and XP the round gave (Ivan).
	winnerLabel =
		Widgets.Label("Winner", content, UDim2.fromScale(0.6, 0.075), UDim2.fromScale(0.5, 0.108))
	winnerLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	winnerLabel.Visible = false
	rewardsRow = Instance.new("Frame")
	rewardsRow.Name = "Rewards"
	rewardsRow.BackgroundTransparency = 1
	rewardsRow.AnchorPoint = Vector2.new(0.5, 0.5)
	rewardsRow.Position = UDim2.fromScale(0.5, 0.175)
	rewardsRow.Size = UDim2.fromScale(0.3, 0.05)
	rewardsRow.Visible = false
	rewardsRow.Parent = content
	local rewardsLayout = Instance.new("UIListLayout")
	rewardsLayout.FillDirection = Enum.FillDirection.Horizontal
	rewardsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	rewardsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	rewardsLayout.Padding = UDim.new(0.04, 0)
	rewardsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rewardsLayout.Parent = rewardsRow
	local cash = Instance.new("ImageLabel")
	cash.Name = "Cash"
	cash.BackgroundTransparency = 1
	cash.Image = CASH_IMAGE
	cash.Size = UDim2.fromScale(1, 1.1)
	cash.LayoutOrder = 1
	cash.Parent = rewardsRow
	local cashSquare = Instance.new("UIAspectRatioConstraint")
	cashSquare.AspectRatio = 1
	cashSquare.DominantAxis = Enum.DominantAxis.Height
	cashSquare.Parent = cash
	rewardMoney = Widgets.MoneyLabel("Money", rewardsRow, UDim2.fromScale(0.36, 1), UDim2.new())
	rewardMoney.LayoutOrder = 2
	rewardXp = Widgets.Label("XP", rewardsRow, UDim2.fromScale(0.36, 1), UDim2.new())
	rewardXp.LayoutOrder = 3
	rewardXp.TextColor3 = XP_COLOR

	for slot = 1, EggConfig.EggsPerOffer do
		cards[slot] = buildCard(content, slot)
	end

	-- Two reroll buttons of one size side by side (Ivan).
	rerollButton = Widgets.PackButton(
		"LevelButton",
		"Reroll",
		content,
		REROLL_BUTTON_SIZE,
		UDim2.fromScale(0.411, 0.754),
		CASH_COLOR
	)
	-- Centred so a hover or press grows the button evenly around its middle,
	-- like the pack's buttons.
	rerollButton.AnchorPoint = Vector2.new(0.5, 0.5)
	rerollCaption = buildRerollCaption(rerollButton)
	rerollButton.Activated:Connect(function()
		if waiting or shownOfferId == nil or isSpinning() then
			return
		end
		-- No spin without money or rerolls (Ivan): the button shakes and the
		-- note says why. The server checks again anyway.
		local refusal = rerollRefusal()
		if refusal then
			Widgets.PlaySound("Error")
			shake(rerollButton)
			flashNote(refusal)
			return
		end
		startWaiting()
		startSpin()
		ClientNet.Fire("EggReroll", shownOfferId)
	end)

	-- Robux reroll next to it, the rainbow "X2 Money" button with the green
	-- Robux price (Ivan's pictures). Until Ivan creates the product it shows
	-- the planned price and only says so when clicked.
	robuxRerollButton = Widgets.PackButton(
		"RobuxButton",
		"RobuxReroll",
		content,
		REROLL_BUTTON_SIZE,
		UDim2.fromScale(0.588, 0.754),
		ROBUX_COLOR
	)
	robuxRerollButton.AnchorPoint = Vector2.new(0.5, 0.5)
	robuxCaption = buildRobuxCaption(robuxRerollButton)
	content:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		task.defer(fitCaptions)
	end)
	task.defer(fitCaptions)
	local planned = ShopConfig.Products.Reroll.Robux
	showRobuxPrice(if planned then tostring(planned) else "")
	robuxRerollButton.Activated:Connect(function()
		if isSpinning() then
			return
		end
		local id = ShopConfig.Products.Reroll.Id
		if id ~= 0 then
			MarketplaceService:PromptProductPurchase(player, id)
		else
			flashNote(Strings.ShopRobuxSoon)
		end
	end)
	loadRobuxPrice()

	-- Odds per rarity on one line on a small dark plate that hugs the text,
	-- each rarity in its color (Ivan).
	local oddsBack = Instance.new("Frame")
	oddsBack.Name = "OddsBack"
	oddsBack.AnchorPoint = Vector2.new(0.5, 0.5)
	oddsBack.Position = UDim2.fromScale(0.5, 0.845)
	oddsBack.BackgroundColor3 = Color3.fromRGB(20, 24, 60)
	oddsBack.BackgroundTransparency = 0.3
	oddsBack.BorderSizePixel = 0
	oddsBack.Parent = content
	Widgets.Corner(oddsBack, 0.3)
	oddsLabel = Widgets.Label("Odds", oddsBack, UDim2.fromScale(1, 1), UDim2.fromScale(0.5, 0.5))
	oddsLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	oddsLabel.TextColor3 = Color3.fromRGB(200, 200, 215)
	oddsLabel.RichText = true
	oddsLabel.TextScaled = false
	oddsLabel.TextWrapped = false
	local function sizeOdds()
		local textSize = math.max(math.floor(content.AbsoluteSize.Y * 0.017), 8)
		oddsLabel.TextSize = textSize
		local bounds = oddsLabel.TextBounds
		oddsBack.Size = UDim2.fromOffset(bounds.X + textSize * 1.6, textSize * 2)
	end
	content:GetPropertyChangedSignal("AbsoluteSize"):Connect(sizeOdds)
	oddsLabel:GetPropertyChangedSignal("TextBounds"):Connect(sizeOdds)
	sizeOdds()

	warningLabel =
		Widgets.Label("Warning", content, UDim2.fromScale(0.6, 0.03), UDim2.fromScale(0.5, 0.89))
	warningLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	warningLabel.TextColor3 = Color3.fromRGB(255, 170, 80)
	warningLabel.Text = Strings.EggStorageFullWarning

	gui.Parent = player:WaitForChild("PlayerGui")
end

-- Rich text: each rarity and its chance in the rarity's color.
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
		table.insert(parts, `<font color="#{color}">{name} {shown}%</font>`)
	end
	return string.format(Strings.Odds, table.concat(parts, " · "))
end

-- The money button's caption; without a price it shows only `word`. Lime
-- green even when money is short (Ivan); gray only with no reroll left.
local function setRerollCaption(word: string, price: string?, enabled: boolean)
	Widgets.SetText(rerollCaption.Word, word)
	Widgets.SetText(rerollCaption.Price, price or "")
	local icon = rerollCaption.Icon
	if icon then
		icon.Visible = price ~= nil
	end
	rerollCaption.Price.Visible = price ~= nil
	fitCaptions()
	local face = rerollFace
	if face then
		face.Color = if enabled then rerollFaceColor or face.Color else DISABLED_FACE
	else
		rerollButton.BackgroundColor3 = if enabled then CASH_COLOR else Color3.fromRGB(90, 90, 110)
	end
end

-- Blurs and dims the world behind the offer, or clears it again.
local function setShown(shown: boolean)
	if root.Visible == shown then
		return
	end
	root.Visible = shown
	EggOfferController.ShownChanged:Fire(shown)
	TweenService:Create(blur, FADE, { Size = if shown then BLUR_SIZE else 0 }):Play()
	dim.BackgroundTransparency = 1
	if shown then
		TweenService:Create(dim, FADE, { BackgroundTransparency = DIM_TRANSPARENCY }):Play()
	end
end

local function showOffer(profile: Types.Profile, offer: Types.EggOffer)
	if offer.OfferId ~= shownOfferId then
		-- A reroll of the offer on screen spins the reels; a new offer just
		-- appears.
		local rerolled = root.Visible
			and shownOfferId ~= nil
			and offer.RerollCount > shownRerollCount
		shownOfferId = offer.OfferId
		shownRerollCount = offer.RerollCount
		-- The egg's rarity stays a surprise (Ivan): only its theme and its
		-- main buff show.
		local themes = {}
		for slot, card in cards do
			local egg = offer.Eggs[slot]
			local theme = PetConfig.Themes[egg.Theme]
			themes[slot] = egg.Theme
			card.Name.Text = string.format(Strings.EggTheme, egg.Theme)
			local stat = if theme then theme.Stat else nil
			card.Buff.Text = if stat
				then string.format(Strings.EggMainBuff, (Strings.StatName :: any)[stat] or stat)
				else ""
			card.Buff.TextColor3 = if stat then PetStyle.Stat[stat] or WHITE else WHITE
		end
		if rerolled then
			startSpin()
			stopSpin(themes)
		else
			table.clear(spins)
			for slot, card in cards do
				land(card, themes[slot], false)
			end
		end
		oddsLabel.Text = oddsText(offer)
	end

	local cost = EggConfig.RerollCosts[offer.RerollCount + 1]
	robuxRerollButton.Visible = cost ~= nil
	if cost and profile.FreeRerolls > 0 then
		setRerollCaption(string.format(Strings.RerollFree, profile.FreeRerolls), nil, true)
	elseif cost then
		setRerollCaption(Strings.Reroll, Money.Format(cost), true)
	else
		setRerollCaption(Strings.RerollLimit, nil, false)
	end
	if not noteShowing then
		warningLabel.Visible = eggWouldBeLost(profile)
	end
	setShown(true)
end

-- The winner and the round's rewards around the offer that round brought.
local function showResult()
	local result = shownResult
	local visible = result ~= nil and root.Visible
	winnerLabel.Visible = visible
	rewardsRow.Visible = visible
	if result == nil then
		return
	end
	local shown = result :: Types.RoundResultPayload
	winnerLabel.Text = Strings.TeamWins[shown.Winner]
	winnerLabel.TextColor3 = TEAM_COLORS[shown.Winner] or WHITE
	Widgets.SetText(rewardMoney, string.format(Strings.CoinsGained, Money.Format(shown.Coins)))
	rewardXp.Text = string.format(Strings.XPGained, shown.XP)
end

local function onProfile(profile: Types.Profile)
	waiting = false
	local offer = profile.PendingOffer
	if offer then
		local isNew = offer.OfferId ~= shownOfferId
		showOffer(profile, offer)
		if isNew and pendingResult then
			shownResult = pendingResult
			pendingResult = nil
		end
	else
		shownOfferId = nil
		shownResult = nil
		table.clear(spins)
		setShown(false)
	end
	showResult()
end

-- The server makes the offer before it sends the result, so the result
-- usually finds the window open; otherwise it waits for the next offer.
local function onRoundResult(result: Types.RoundResultPayload)
	if not result.Rewarded then
		return
	end
	if root.Visible then
		shownResult = result
		showResult()
	else
		pendingResult = result
	end
end

local function onEggPicked(result: Types.EggPickedPayload)
	-- No rarity here either: the pet's rarity shows when it hatches.
	local info = if result.Where ~= "Coins"
		then Strings.EggStored
		else string.format(Strings.ConvertedToCoins, Money.Format(result.Coins))
	RevealScreen.Show({
		Model = AssetModels.Egg(result.Theme),
		Color = PetStyle.Theme[result.Theme] or WHITE,
		Heading = Strings.RevealNewEgg,
		Title = string.format(Strings.EggTheme, result.Theme),
		Lines = { { Text = info } },
		Note = if result.AutoPicked then Strings.AutoPicked else nil,
		Close = Strings.TapToClose,
	})
end

local function onHatched(result: Types.PetHatchedPayload)
	local entry = PetConfig.Pets[result.Kind]
	local color = PetStyle.Rarity[result.Rarity] or WHITE
	local rarityName = (Strings.Rarity :: any)[result.Rarity] or result.Rarity
	RevealScreen.Show({
		Model = AssetModels.Pet(result.Kind),
		Color = color,
		Heading = Strings.RevealNewPet,
		Title = if entry then entry.Name else result.Kind,
		Lines = {
			{ Text = rarityName, Color = color, Style = "Pill" },
			{
				Text = string.format(
					Strings.PlatformIncome,
					Money.Format(PetIncome.Rate(result.Kind, PetConfig :: any))
				),
				Style = "Money",
			},
		},
		Close = Strings.TapToClose,
	})
end

function EggOfferController:IsShown(): boolean
	local frame: Frame? = root
	return frame ~= nil and frame.Visible
end

function EggOfferController:Init()
	blur = Instance.new("BlurEffect")
	blur.Name = "EggOfferBlur"
	blur.Size = 0
	blur.Parent = Lighting
	build()
end

function EggOfferController:Start()
	DataController.Changed:Connect(onProfile)
	ClientNet.On("EggPicked", onEggPicked)
	ClientNet.On("PetHatched", onHatched)
	ClientNet.On("RoundResult", onRoundResult)
	-- A refused request (for example not enough coins) unlocks the buttons;
	-- a refused reroll stops the reels on the eggs they had.
	ClientNet.On("ActionResult", function(action: string)
		waiting = false
		if action == "EggReroll" and isSpinning() then
			local themes = {}
			for slot, card in cards do
				themes[slot] = card.Theme or ""
			end
			stopSpin(themes)
		end
	end)

	-- No timer: the offer stays until the player picks (Ivan, 2026-10-13).
	RunService.RenderStepped:Connect(function(dt)
		if isSpinning() then
			stepSpins(dt)
		end
	end)

	local profile = DataController:Get()
	if profile then
		onProfile(profile)
	end
end

return EggOfferController
