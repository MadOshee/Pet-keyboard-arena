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
local Types = require(ReplicatedStorage.Shared.Types)
local AssetModels = require(script.Parent.Parent.UI.AssetModels)
local Widgets = require(script.Parent.Parent.UI.Widgets)
local ClientNet = require(script.Parent.Parent.Util.ClientNet)
local DataController = require(script.Parent.DataController)

local player = Players.LocalPlayer

local REVEAL_SECONDS = 5

local EggOfferController = {}

type Card = {
	Button: TextButton,
	Preview: Frame,
	Theme: TextLabel,
	Rarity: TextLabel,
	Bonus: TextLabel,
	Stroke: UIStroke,
}

local gui: ScreenGui
local window: Frame
local timerLabel: TextLabel
local cards: { Card } = {}
local rerollButton: TextButton
local robuxRerollButton: TextButton
local oddsLabel: TextLabel
local warningLabel: TextLabel
local reveal: TextButton
local revealPreview: Frame
local revealTitle: TextLabel
local revealInfo: TextLabel
local revealNote: TextLabel

local shownOfferId: string? = nil
local expiresAt = 0
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

local function percent(value: number): number
	return math.floor(value * 100 + 0.5)
end

local function bonusText(stat: string, rarity: string): string
	local value = PetConfig.Bonus[stat] and PetConfig.Bonus[stat][rarity] or 0
	return string.format(Strings.Bonus, percent(value), (Strings.StatName :: any)[stat] or stat)
end

-- True when a picked egg would turn into coins: no empty incubator and
-- egg storage full.
local function eggWouldBeLost(profile: Types.Profile): boolean
	for _, incubator in profile.Incubators do
		if incubator.Egg == nil then
			return false
		end
	end
	local count = 0
	for _ in profile.Eggs do
		count += 1
	end
	return count >= profile.EggCapacity
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

	local preview = Instance.new("Frame")
	preview.Name = "PreviewHolder"
	preview.BackgroundTransparency = 1
	preview.Size = UDim2.fromScale(0.9, 0.5)
	preview.Position = UDim2.fromScale(0.05, 0.03)
	preview.Parent = button

	local theme =
		Widgets.Label("Theme", button, UDim2.fromScale(0.9, 0.13), UDim2.fromScale(0.05, 0.54))
	local rarity =
		Widgets.Label("Rarity", button, UDim2.fromScale(0.9, 0.14), UDim2.fromScale(0.05, 0.68))
	local bonus =
		Widgets.Label("Bonus", button, UDim2.fromScale(0.9, 0.12), UDim2.fromScale(0.05, 0.84))

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
		Rarity = rarity,
		Bonus = bonus,
		Stroke = Widgets.Stroke(button, Color3.new(1, 1, 1), 3),
	}
end

local function build()
	gui = Widgets.ScreenGui("EggOffer", 5)

	window = Widgets.Panel("Window", gui, UDim2.fromScale(0.8, 0.62), UDim2.fromScale(0.5, 0.5))
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.Visible = false
	Widgets.AspectRatio(window, 1.9)

	local title =
		Widgets.Label("Title", window, UDim2.fromScale(0.7, 0.1), UDim2.fromScale(0.03, 0.03))
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = Strings.EggOfferTitle
	timerLabel =
		Widgets.Label("Timer", window, UDim2.fromScale(0.22, 0.1), UDim2.fromScale(0.75, 0.03))
	timerLabel.TextXAlignment = Enum.TextXAlignment.Right

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

	oddsLabel =
		Widgets.Label("Odds", window, UDim2.fromScale(0.47, 0.07), UDim2.fromScale(0.03, 0.85))
	oddsLabel.TextXAlignment = Enum.TextXAlignment.Left
	oddsLabel.TextColor3 = Color3.fromRGB(200, 200, 215)

	rerollButton = Widgets.Button(
		"Reroll",
		window,
		UDim2.fromScale(0.3, 0.12),
		UDim2.fromScale(0.67, 0.83),
		Color3.fromRGB(230, 160, 40)
	)
	rerollButton.Activated:Connect(function()
		if waiting or shownOfferId == nil then
			return
		end
		startWaiting()
		ClientNet.Fire("EggReroll", shownOfferId)
	end)

	-- Robux reroll; the odds above stay visible before the purchase.
	robuxRerollButton = Widgets.Button(
		"RobuxReroll",
		window,
		UDim2.fromScale(0.15, 0.12),
		UDim2.fromScale(0.51, 0.83),
		Color3.fromRGB(60, 180, 90)
	)
	robuxRerollButton.Text = Strings.RerollRobux
	robuxRerollButton.Visible = false
	robuxRerollButton.Activated:Connect(function()
		local id = ShopConfig.Products.Reroll.Id
		if id ~= 0 then
			MarketplaceService:PromptProductPurchase(player, id)
		end
	end)

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

local function oddsText(offer: Types.EggOffer): string
	local odds = EggRoller.Odds(EggRoller.Weights(offer.Context :: any, EggConfig))
	local parts = {}
	for index, rarity in PetConfig.Rarities do
		local chance = odds[index] * 100
		local shown = if chance < 10
			then string.format("%.1f", chance)
			else tostring(math.floor(chance + 0.5))
		table.insert(parts, `{(Strings.Rarity :: any)[rarity]} {shown}%`)
	end
	return string.format(Strings.Odds, table.concat(parts, " · "))
end

local function showOffer(profile: Types.Profile, offer: Types.EggOffer)
	if offer.OfferId ~= shownOfferId then
		shownOfferId = offer.OfferId
		for slot, card in cards do
			local egg = offer.Eggs[slot]
			local theme = PetConfig.Themes[egg.Theme]
			local themeColor = PetStyle.Theme[egg.Theme] or Color3.new(1, 1, 1)
			setPreview(card.Preview, AssetModels.Egg(egg.Theme), themeColor)
			card.Theme.Text = string.format(Strings.EggTheme, egg.Theme)
			card.Theme.TextColor3 = themeColor
			card.Rarity.Text = (Strings.Rarity :: any)[egg.Rarity] or egg.Rarity
			card.Rarity.TextColor3 = PetStyle.Rarity[egg.Rarity] or Color3.new(1, 1, 1)
			card.Bonus.Text = if theme then bonusText(theme.Stat, egg.Rarity) else ""
			card.Stroke.Color = PetStyle.Rarity[egg.Rarity] or Color3.new(1, 1, 1)
		end
		oddsLabel.Text = oddsText(offer)
	end

	expiresAt = offer.ExpiresAt
	local cost = EggConfig.RerollCosts[offer.RerollCount + 1]
	robuxRerollButton.Visible = cost ~= nil and ShopConfig.Products.Reroll.Id ~= 0
	if cost and profile.FreeRerolls > 0 then
		rerollButton.Text = string.format(Strings.RerollFree, profile.FreeRerolls)
		rerollButton.BackgroundColor3 = Color3.fromRGB(60, 180, 90)
	elseif cost then
		rerollButton.Text = string.format(Strings.Reroll, cost)
		rerollButton.BackgroundColor3 = if profile.Coins >= cost
			then Color3.fromRGB(230, 160, 40)
			else Color3.fromRGB(110, 100, 90)
	else
		rerollButton.Text = Strings.RerollLimit
		rerollButton.BackgroundColor3 = Color3.fromRGB(90, 90, 110)
	end
	warningLabel.Visible = eggWouldBeLost(profile)
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

local function formatDuration(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function onEggPicked(result: Types.EggPickedPayload)
	local color = PetStyle.Rarity[result.Rarity] or Color3.new(1, 1, 1)
	local rarityName = (Strings.Rarity :: any)[result.Rarity] or result.Rarity
	local title = string.format(Strings.EggTheme, result.Theme) .. " · " .. rarityName
	local info: string
	if result.Where == "Incubator" then
		local left = (result.HatchAt or 0) - workspace:GetServerTimeNow()
		info = string.format(Strings.EggInIncubator, formatDuration(left))
	elseif result.Where == "Storage" then
		info = Strings.EggStored
	else
		info = string.format(Strings.ConvertedToCoins, result.Coins)
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
	local theme = entry and PetConfig.Themes[entry.Theme]
	local rarityName = (Strings.Rarity :: any)[result.Rarity] or result.Rarity
	showReveal(
		AssetModels.Pet(result.Kind),
		color,
		string.format(Strings.Hatched, if entry then entry.Name else result.Kind),
		if theme then `{rarityName} · {bonusText(theme.Stat, result.Rarity)}` else rarityName,
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

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.25 or not window.Visible then
			return
		end
		elapsed = 0
		local secondsLeft = math.max(0, math.ceil(expiresAt - workspace:GetServerTimeNow()))
		timerLabel.Text = string.format(Strings.EggOfferTimer, secondsLeft)
	end)

	local profile = DataController:Get()
	if profile then
		onProfile(profile)
	end
end

return EggOfferController
