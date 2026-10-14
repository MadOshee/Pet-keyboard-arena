--!strict
-- The whole Studs UI Pack screen (Assets.UI.GameUI), added as is so Ivan can
-- see every piece in the game and pick what stays. HUD buttons open the pack
-- window with the same name (Shop, Rebirth, Pets, Backpack, Daily,
-- Upgrades); one window is open at a time. Some HUD pieces are hidden until
-- the release update (HIDDEN_HUD), Rebirth is dimmed with "Soon" and does
-- nothing (SOON_BUTTONS); the level bar shows the real level. Real so far: coins in the cash
-- counter, MY BASE takes you to your plot, PETS (PetIndexController) and
-- BACKPACK (BackpackController) are filled by their controllers, PARTY (the
-- pack's top-left stock shop button) opens our party window. The SHOP stall
-- on every base opens the pack's Shop window too (click or its prompt).
-- Other windows
-- still show the pack's samples. Hidden during a match. Replaces the pack's
-- own LocalScript, which is not imported.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local RoundConfig = require(ReplicatedStorage.Shared.Config.RoundConfig)
local Strings = require(ReplicatedStorage.Shared.Config.Strings)
local Levels = require(ReplicatedStorage.Shared.Logic.Levels)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local Types = require(ReplicatedStorage.Shared.Types)
local Money = require(ReplicatedStorage.Shared.Util.Money)
local Widgets = require(script.Parent.Parent.UI.Widgets)
local ClientNet = require(script.Parent.Parent.Util.ClientNet)
local DataController = require(script.Parent.DataController)
local EggOfferController = require(script.Parent.EggOfferController)
local PartyController = require(script.Parent.PartyController)

local player = Players.LocalPlayer

local OPEN_TWEEN = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local CLOSE_TWEEN = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local HIDDEN_POSITION = UDim2.fromScale(0.5, 1.5)
-- Pack HUD pieces hidden until the release update (Ivan 2026-10-13): the
-- level shop buttons, Daily Rewards, Party, Upgrades, the boost icons at the
-- bottom right and the X2 Money / X2 Luck buttons; then the x3 Multiplier
-- label, Friend Boost, the rebirth counter and the Starter Pack.
local HIDDEN_HUD: { { string } } = {
	{ "Bottom", "Products" },
	{ "Left", "Daily" },
	{ "Top", "Party" },
	{ "Top", "Upgrades" },
	{ "BottomRight" },
	{ "Right", "X2Money" },
	{ "Right", "X2Luck" },
	{ "Right", "StarterPack" },
	{ "Bottom", "MultFrame" },
	{ "BottomLeft", "Boost" },
	{ "BottomLeft", "RebirthFrame" },
}
-- HUD buttons for features of a later update: dimmed, "Soon", not pressable.
local SOON_BUTTONS: { [string]: true } = { Rebirth = true }
local DIM = 0.55 -- share of black mixed into every colour
local SOON_COLOR = Color3.fromRGB(255, 220, 60)
local BLACK = Color3.new(0, 0, 0)
-- Above the egg screen (EggOffer, 5) while only the money counter shows.
local OFFER_DISPLAY_ORDER = 6
-- My Base made smaller (Ivan), about the size Party and Upgrades had.
local BASE_SIZE = UDim2.fromScale(0.33, 0.7)

local PackUiController = {}

-- (window name) when a window starts opening, so its contents can refresh.
PackUiController.Opened = Signal.new() :: Signal.Signal<string>

local gui: ScreenGui? = nil
local windowsGui: ScreenGui? = nil
local cashLabel: TextLabel? = nil
local levelBar: Frame? = nil
-- The HUD corner holding the money counter, and the counter's "+" button.
local cashCorner: GuiObject? = nil
local cashPlus: GuiObject? = nil
-- HUD pieces hidden under the egg screen, with how visible they were.
local hiddenForOffer: { [GuiObject]: boolean } = {}
local openPositions: { [GuiObject]: UDim2 } = {}
local current: GuiObject? = nil
local animating = false

local function close()
	if current == nil or animating then
		return
	end
	local window = current :: GuiObject
	animating = true
	local tween = TweenService:Create(window, CLOSE_TWEEN, { Position = HIDDEN_POSITION })
	tween:Play()
	tween.Completed:Wait()
	window.Visible = false
	current = nil
	animating = false
end

local function closeNow()
	local window = current
	if window then
		window.Visible = false
		window.Position = openPositions[window] or window.Position
		current = nil
	end
end

-- Pressing the button of the open window closes it; another button swaps.
local function toggle(window: GuiObject)
	if animating then
		return
	end
	if current == window then
		close()
		return
	end
	closeNow()
	animating = true
	window.Position = HIDDEN_POSITION
	window.Visible = true
	current = window
	PackUiController.Opened:Fire(window.Name)
	local tween = TweenService:Create(window, OPEN_TWEEN, { Position = openPositions[window] })
	tween:Play()
	tween.Completed:Wait()
	animating = false
end

local function dimSequence(sequence: ColorSequence): ColorSequence
	local points = {}
	for _, point in sequence.Keypoints do
		table.insert(points, ColorSequenceKeypoint.new(point.Time, point.Value:Lerp(BLACK, DIM)))
	end
	return ColorSequence.new(points)
end

-- Dims `object` and everything in it, turns its buttons off and writes a
-- tilted "Soon" over it; `soonSize` is the label's size in parts of it.
local function dim(object: GuiObject, soonSize: UDim2)
	if object:IsA("GuiButton") then
		object.Interactable = false
		object.AutoButtonColor = false
	end
	object.BackgroundColor3 = object.BackgroundColor3:Lerp(BLACK, DIM)
	-- A gradient already tints its parent, so a part with one is dimmed once.
	for _, part in object:GetDescendants() do
		if part:IsA("GuiButton") then
			part.Interactable = false
			part.AutoButtonColor = false
		end
		if part:IsA("UIGradient") then
			part.Color = dimSequence(part.Color)
		elseif part:IsA("UIStroke") then
			part.Color = part.Color:Lerp(BLACK, DIM)
		elseif part:FindFirstChildOfClass("UIGradient") then
			continue
		elseif part:IsA("ImageLabel") then
			part.ImageColor3 = part.ImageColor3:Lerp(BLACK, DIM)
		elseif part:IsA("ImageButton") then
			part.ImageColor3 = part.ImageColor3:Lerp(BLACK, DIM)
		elseif part:IsA("TextLabel") then
			part.TextColor3 = part.TextColor3:Lerp(BLACK, DIM)
		end
	end
	-- Above every piece inside: pack blocks hold parts up to ZIndex 50.
	local top = 30
	for _, part in object:GetDescendants() do
		if part:IsA("GuiObject") then
			top = math.max(top, part.ZIndex + 1)
		end
	end
	local holder: GuiObject = object
	if not object:IsA("GuiButton") then
		-- A whole block (a Shop offer): a dark veil over it under the label.
		local veil = Instance.new("Frame")
		veil.Name = "SoonVeil"
		veil.Size = UDim2.fromScale(1, 1)
		veil.BackgroundColor3 = BLACK
		veil.BackgroundTransparency = 0.45
		veil.BorderSizePixel = 0
		veil.Active = true -- swallows clicks meant for the block
		veil.ZIndex = top
		veil.Parent = object
		holder = veil
	end
	local soon = Widgets.Label("Soon", holder, soonSize, UDim2.fromScale(0.5, 0.45))
	soon.AnchorPoint = Vector2.new(0.5, 0.5)
	soon.Rotation = -12
	soon.ZIndex = top + 1
	soon.TextColor3 = SOON_COLOR
	soon.Text = Strings.Soon
end

local function wireButton(button: GuiButton, windows: Instance, hud: Instance)
	if SOON_BUTTONS[button.Name] and button:IsDescendantOf(hud) then
		dim(button, UDim2.fromScale(1.2, 0.42))
		return
	end
	Widgets.AnimatePress(button)
	button.MouseButton1Down:Connect(function()
		Widgets.PlaySound("Click")
	end)
	if button.Name == "Close" then
		button.MouseButton1Click:Connect(function()
			task.spawn(close)
		end)
		return
	end
	if not button:IsDescendantOf(hud) then
		return
	end
	if button.Name == "Base" then
		button.MouseButton1Click:Connect(function()
			ClientNet.Fire("GoToPlot")
		end)
		return
	end
	if button.Name == "Party" then
		button.MouseButton1Click:Connect(function()
			PartyController:Toggle()
		end)
		return
	end
	local window = windows:FindFirstChild(button.Name)
	if window and window:IsA("GuiObject") then
		button.MouseButton1Click:Connect(function()
			task.spawn(toggle, window)
		end)
	end
end

local function updateCash(profile: Types.Profile?)
	local label = cashLabel
	if label and profile then
		label.Text = Money.Format(profile.Coins)
		local top = label:FindFirstChild("Color")
		if top and top:IsA("TextLabel") then
			top.Text = label.Text
		end
	end
end

local function setPackText(label: Instance?, text: string)
	if label and label:IsA("TextLabel") then
		Widgets.SetText(label, text)
	end
end

-- The pack's level bar shows the real level and XP (Logic/Levels).
local function updateLevel(profile: Types.Profile?)
	if levelBar == nil or profile == nil then
		return
	end
	local bar = levelBar :: Frame
	local progress = Levels.FromXP((profile :: Types.Profile).XP or 0, RoundConfig.Levels)
	-- The level's bonus to every stat shows next to it from level 2 (Ivan).
	local bonus = math.floor(Levels.Bonus(progress.Level, RoundConfig.Levels) * 100 + 0.5)
	setPackText(
		bar:FindFirstChild("Level"),
		if bonus > 0
			then string.format(Strings.LevelWithBonus, progress.Level, bonus)
			else string.format(Strings.Level, progress.Level)
	)
	setPackText(
		bar:FindFirstChild("XP"),
		string.format(Strings.XPProgress, progress.Into, progress.Need)
	)
	local fill = bar:FindFirstChild("Effect")
	if fill and fill:IsA("GuiObject") then
		fill.Size = UDim2.fromScale(progress.Into / progress.Need, 1)
	end
end

local function trimHud(hud: Instance)
	for _, path in HIDDEN_HUD do
		local node: Instance? = hud
		for _, name in path do
			node = node and node:FindFirstChild(name)
		end
		if node and node:IsA("GuiObject") then
			node.Visible = false
		end
	end
	local top = hud:FindFirstChild("Top")
	local base = top and top:FindFirstChild("Base")
	if base and base:IsA("GuiObject") then
		base.Size = BASE_SIZE
	end
	local bottom = hud:FindFirstChild("Bottom")
	local barFrame = bottom and bottom:FindFirstChild("BarFrame")
	local bar = barFrame and barFrame:FindFirstChild("Bar")
	if bar and bar:IsA("Frame") then
		levelBar = bar
	end
end

-- Hides every HUD piece but the money counter (and its "+" shop button),
-- or brings them back as they were.
local function setCashOnly(screen: ScreenGui, on: boolean)
	local hud = screen:FindFirstChild("HUD")
	if on == (next(hiddenForOffer) ~= nil) or hud == nil then
		return
	end
	if on then
		local hide: { GuiObject } = {}
		for _, child in (hud :: Instance):GetChildren() do
			if child:IsA("GuiObject") and child ~= cashCorner then
				table.insert(hide, child)
			end
		end
		if cashPlus then
			table.insert(hide, cashPlus :: GuiObject)
		end
		for _, object in hide do
			hiddenForOffer[object] = object.Visible
			object.Visible = false
		end
		screen.DisplayOrder = OFFER_DISPLAY_ORDER
	else
		for object, visible in hiddenForOffer do
			object.Visible = visible
		end
		table.clear(hiddenForOffer)
		screen.DisplayOrder = 0
	end
end

function PackUiController:Init()
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local ui = assets and assets:FindFirstChild("UI")
	local source = ui and ui:FindFirstChild("GameUI")
	if not (source and source:IsA("ScreenGui")) then
		return
	end
	local screen = source:Clone()
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 0
	local hud = screen:WaitForChild("HUD")
	local windows = screen:WaitForChild("Main")
	trimHud(hud)
	-- Windows get their own layer above our menu column (DisplayOrder 2).
	local layer = Widgets.ScreenGui("GameUIWindows", 3)
	layer.ScreenInsets = screen.ScreenInsets
	layer.IgnoreGuiInset = screen.IgnoreGuiInset
	windows.Parent = layer
	for _, window in windows:GetChildren() do
		if window:IsA("GuiObject") then
			openPositions[window] = window.Position
			window.Visible = false
		end
	end
	for _, root in { screen, layer } do
		for _, descendant in root:GetDescendants() do
			if descendant:IsA("GuiButton") then
				wireButton(descendant, windows, hud)
			end
		end
	end
	local cashFrame = hud:FindFirstChild("CashFrame", true)
	local amount = cashFrame and cashFrame:FindFirstChild("Amount")
	if amount and amount:IsA("TextLabel") then
		cashLabel = amount
	end
	local corner: Instance? = cashFrame
	while corner and corner.Parent ~= hud do
		corner = corner.Parent
	end
	if corner and corner:IsA("GuiObject") then
		cashCorner = corner
	end
	local plus = cashFrame and cashFrame:FindFirstChild("Shop")
	if plus and plus:IsA("GuiObject") then
		cashPlus = plus
	end
	screen.Parent = player:WaitForChild("PlayerGui")
	layer.Parent = screen.Parent
	gui = screen
	windowsGui = layer
end

-- A pack window (in Main) by name, for the controllers that fill it.
function PackUiController:GetWindow(name: string): GuiObject?
	local layer = windowsGui
	local windows = layer and layer:FindFirstChild("Main")
	local window = windows and windows:FindFirstChild(name)
	return if window and window:IsA("GuiObject") then window else nil
end

-- Opens the pack window `name` unless it is already open.
-- A pack piece for a later update (Ivan): dimmed, "Soon", not pressable.
function PackUiController:SetSoon(object: GuiObject, soonSize: UDim2)
	if object:FindFirstChild("Soon") == nil and object:FindFirstChild("SoonVeil") == nil then
		dim(object, soonSize)
	end
end

function PackUiController:Open(name: string)
	local window = PackUiController:GetWindow(name)
	if window and current ~= window and gui and (gui :: ScreenGui).Enabled then
		task.spawn(toggle, window)
	end
end

-- Opens the pack window `name`, or closes it when it is the open one (the
-- Settings gear, SettingsController).
function PackUiController:Toggle(name: string)
	local window = PackUiController:GetWindow(name)
	if window and gui and (gui :: ScreenGui).Enabled then
		task.spawn(toggle, window)
	end
end

-- The SHOP stall on each base (tools/build-world: Islands.*.Shop, with a
-- ClickDetector and a ProximityPrompt named "Shop") opens the Shop window.
local function wireShopStalls()
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt.Name == "Shop" then
			PackUiController:Open("Shop")
		end
	end)
	task.spawn(function()
		local islands = workspace:WaitForChild("World"):WaitForChild("Islands")
		for _, descendant in islands:GetDescendants() do
			if descendant:IsA("ClickDetector") and descendant.Name == "Shop" then
				descendant.MouseClick:Connect(function()
					PackUiController:Open("Shop")
				end)
			end
		end
	end)
end

function PackUiController:IsOpen(name: string): boolean
	return current ~= nil and (current :: GuiObject).Name == name
end

-- Ivan dropped our own button column (Widgets.MenuButton) for the pack's:
-- Backpack, My Base and Party cover pets, plot and party.
local function hideMenuColumn()
	local menu = player:WaitForChild("PlayerGui"):FindFirstChild("Menu")
	if menu and menu:IsA("ScreenGui") then
		menu.Enabled = false
	end
end

function PackUiController:Start()
	if gui == nil then
		return
	end
	local screen = gui :: ScreenGui
	local function updateVisible()
		-- Hidden during a match. Under the egg screen only the money counter
		-- stays, drawn above the screen's dimming (Ivan).
		local inLobby = player:GetAttribute("Team") == nil
		local offer = EggOfferController:IsShown()
		if not inLobby or offer then
			closeNow()
		end
		screen.Enabled = inLobby
		setCashOnly(screen, inLobby and offer)
		if windowsGui then
			windowsGui.Enabled = inLobby and not offer
		end
	end
	player:GetAttributeChangedSignal("Team"):Connect(updateVisible)
	EggOfferController.ShownChanged:Connect(updateVisible)
	updateVisible()
	DataController.Changed:Connect(function(profile)
		updateCash(profile)
		updateLevel(profile)
	end)
	updateCash(DataController:Get())
	updateLevel(DataController:Get())
	hideMenuColumn()
	wireShopStalls()
end

return PackUiController
