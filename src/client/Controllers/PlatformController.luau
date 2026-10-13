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
	for _, child in preview:GetChildren() do
		child:Destroy()
	end
end

local function addCard(
	order: number,
	model: Model?,
	color: Color3,
	title: string,
	subtitle: string,
	onPick: () -> ()
)
	local card =
		Widgets.Button(`Card{order}`, list, UDim2.new(), UDim2.new(), Color3.fromRGB(52, 56, 80))
	card.LayoutOrder = order
	Widgets.Stroke(card, color, 2)
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(0.9, 0.55)
	holder.Position = UDim2.fromScale(0.05, 0.04)
	holder.Parent = card
	AssetModels.Viewport(holder, model, color)
	local name = Widgets.Label("Name", card, UDim2.fromScale(0.9, 0.18), UDim2.fromScale(0.05, 0.6))
	name.Text = title
	local sub = Widgets.Label("Sub", card, UDim2.fromScale(0.9, 0.16), UDim2.fromScale(0.05, 0.8))
	sub.Text = subtitle
	sub.TextColor3 = color
	card.Activated:Connect(onPick)
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
			PetStyle.Rarity[group.Rarity] or Color3.new(1, 1, 1),
			string.format(Strings.EggTheme, group.Theme)
				.. (if group.Count > 1 then ` x{group.Count}` else ""),
			rarityName,
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
			PetStyle.Rarity[pet.Rarity] or Color3.new(1, 1, 1),
			if entry then entry.Name else pet.Kind,
			if table.find(data.Equipped, id)
				then `{income} · {Strings.PlatformEquipped}`
				else income,
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
	AssetModels.Viewport(preview, model, color)
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
	actionButton.Visible = false
	takeButton.Visible = false
	clearList()
	clearPreview()

	if state == "Locked" then
		local price = platform:GetAttribute("Price")
		if type(price) == "number" and price > 0 then
			infoLabel.Text = ""
			actionButton.Visible = true
		else
			infoLabel.Text = if owned < EggConfig.MaxIncubators
				then string.format(Strings.PlatformBuyFirst, index - 1)
				else Strings.PlatformLocked
		end
	elseif state == "Empty" then
		buildPicker(profile)
	elseif state == "Egg" then
		local egg = slot.Egg :: Types.EggInstance
		showPreview(AssetModels.Egg(egg.Theme), PetStyle.Rarity[egg.Rarity] or Color3.new(1, 1, 1))
		actionButton.Visible = true
		takeButton.Visible = true
	else
		local pet = profile.Pets[slot.PetId :: string]
		if pet then
			showPreview(
				AssetModels.Pet(pet.Kind),
				PetStyle.Rarity[pet.Rarity] or Color3.new(1, 1, 1)
			)
			infoLabel.Text = string.format(
				Strings.PlatformEarns,
				Money.Format(PetIncome.Rate(pet.Kind, PetConfig :: any))
			)
		end
		takeButton.Visible = true
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

	window = Widgets.Panel("Window", gui, UDim2.fromScale(0.5, 0.42), UDim2.fromScale(0.5, 0.97))
	window.AnchorPoint = Vector2.new(0.5, 1)
	window.Visible = false
	window.BackgroundTransparency = math.min(window.BackgroundTransparency, 0.15)
	Widgets.AspectRatio(window, 2.1)

	titleLabel =
		Widgets.Label("Title", window, UDim2.fromScale(0.5, 0.12), UDim2.fromScale(0.03, 0.03))
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	infoLabel =
		Widgets.Label("Info", window, UDim2.fromScale(0.9, 0.09), UDim2.fromScale(0.05, 0.17))
	infoLabel.TextColor3 = Color3.fromRGB(200, 220, 255)

	list = Instance.new("ScrollingFrame")
	list.Name = "List"
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Size = UDim2.fromScale(0.94, 0.68)
	list.Position = UDim2.fromScale(0.03, 0.29)
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.X
	list.ScrollingDirection = Enum.ScrollingDirection.X
	list.ScrollBarThickness = 8
	list.Parent = window
	local row = Instance.new("UIListLayout")
	row.FillDirection = Enum.FillDirection.Horizontal
	row.Padding = UDim.new(0, 8)
	row.SortOrder = Enum.SortOrder.LayoutOrder
	row.Parent = list
	-- Cards are as tall as the list and a bit narrower than tall. Sized in
	-- pixels: scale sizes inside a scrolling list follow its canvas, not the
	-- visible frame, and collapsed to nothing in Play.
	local function sizeCard(card: GuiObject)
		local height = list.AbsoluteSize.Y * 0.9
		card.Size = UDim2.fromOffset(height * 0.8, height)
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
	preview.Size = UDim2.fromScale(0.3, 0.62)
	preview.Position = UDim2.fromScale(0.05, 0.3)
	preview.Visible = false
	preview.Parent = window

	actionButton = Widgets.Button(
		"Action",
		window,
		UDim2.fromScale(0.5, 0.2),
		UDim2.fromScale(0.42, 0.36),
		Color3.fromRGB(64, 170, 90)
	)
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
	takeButton = Widgets.Button(
		"Take",
		window,
		UDim2.fromScale(0.5, 0.2),
		UDim2.fromScale(0.42, 0.66),
		Color3.fromRGB(150, 90, 90)
	)
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
