--!strict
-- The whole Studs UI Pack screen (Assets.UI.GameUI), added as is so Ivan can
-- see every piece in the game and pick what stays. HUD buttons open the pack
-- window with the same name (Shop, Pass, Rebirth, Index, Daily, StockShop,
-- Upgrades); window contents are the pack's own samples. Real data so far:
-- coins in the cash counter, and BASE takes you to your plot. Hidden during a
-- match. Replaces the pack's own LocalScript, which is not imported.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Types = require(ReplicatedStorage.Shared.Types)
local Widgets = require(script.Parent.Parent.UI.Widgets)
local ClientNet = require(script.Parent.Parent.Util.ClientNet)
local DataController = require(script.Parent.DataController)

local player = Players.LocalPlayer

local OPEN_TWEEN = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local CLOSE_TWEEN = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local HIDDEN_POSITION = UDim2.fromScale(0.5, 1.5)

local PackUiController = {}

local gui: ScreenGui? = nil
local windowsGui: ScreenGui? = nil
local packLeft: GuiObject? = nil
local cashLabel: TextLabel? = nil
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
	local tween = TweenService:Create(window, OPEN_TWEEN, { Position = openPositions[window] })
	tween:Play()
	tween.Completed:Wait()
	animating = false
end

local function wireButton(button: GuiButton, windows: Instance, hud: Instance)
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
		label.Text = tostring(profile.Coins)
		local top = label:FindFirstChild("Color")
		if top and top:IsA("TextLabel") then
			top.Text = label.Text
		end
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
	local left = hud:FindFirstChild("Left")
	if left and left:IsA("GuiObject") then
		packLeft = left
	end
	screen.Parent = player:WaitForChild("PlayerGui")
	layer.Parent = screen.Parent
	gui = screen
	windowsGui = layer
end

-- Our menu column (Widgets.MenuButton) sits on the left edge too; keep it
-- just right of the pack's column so the two don't overlap.
local function followPackColumn()
	local found = packLeft
	local menu = player:WaitForChild("PlayerGui"):FindFirstChild("Menu")
	local column = menu and menu:FindFirstChild("Left")
	if found == nil or not (column and column:IsA("GuiObject")) then
		return
	end
	local left = found :: GuiObject
	local function place()
		column.Position = UDim2.new(
			0,
			left.AbsolutePosition.X + left.AbsoluteSize.X + 12,
			column.Position.Y.Scale,
			0
		)
	end
	left:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)
	left:GetPropertyChangedSignal("AbsolutePosition"):Connect(place)
	place()
end

function PackUiController:Start()
	if gui == nil then
		return
	end
	local screen = gui :: ScreenGui
	local function updateVisible()
		local inLobby = player:GetAttribute("Team") == nil
		if not inLobby then
			closeNow()
		end
		screen.Enabled = inLobby
		if windowsGui then
			windowsGui.Enabled = inLobby
		end
	end
	player:GetAttributeChangedSignal("Team"):Connect(updateVisible)
	updateVisible()
	DataController.Changed:Connect(updateCash)
	updateCash(DataController:Get())
	followPackColumn()
end

return PackUiController
