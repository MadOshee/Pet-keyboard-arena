--!strict
-- The Settings gear at the top right (the pack's Settings icon, Ivan
-- 2026-10-14) and the pack's Settings window it opens (PackUiController):
-- Background Music, Sound Effects and Visual Effects switches
-- (Util/ClientSettings, saved in the profile through SetSetting) and a
-- Credits row that shows CreditsConfig under it. The gear hides during a
-- match and under the egg screen, like the pack HUD.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CreditsConfig = require(ReplicatedStorage.Shared.Config.CreditsConfig)
local Strings = require(ReplicatedStorage.Shared.Config.Strings)
local PlayerSettings = require(ReplicatedStorage.Shared.Logic.PlayerSettings)
local Types = require(ReplicatedStorage.Shared.Types)
local Widgets = require(script.Parent.Parent.UI.Widgets)
local ClientNet = require(script.Parent.Parent.Util.ClientNet)
local ClientSettings = require(script.Parent.Parent.Util.ClientSettings)
local DataController = require(script.Parent.DataController)
local EggOfferController = require(script.Parent.EggOfferController)
local PackUiController = require(script.Parent.PackUiController)

local player = Players.LocalPlayer

local BUTTON_COLOR = Color3.fromRGB(125, 130, 150)
-- Top right corner, in screen widths; FeedbackController puts its smaller
-- button just left of it.
local BUTTON_POSITION = UDim2.fromScale(0.985, 0.02)
local BUTTON_WIDTH = 0.06
-- The pack's rows are about 9 times wider than tall.
local ROW_ASPECT = 9.3
local CREDITS_TEXT_SIZE = 0.042 -- of the window height
local CREDITS_COLOR = Color3.fromRGB(20, 24, 40)
local FONT = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)

-- The switches in window order: setting name, pack row title, our title.
local SWITCHES: { { Name: string, PackTitle: string, Title: string } } = {
	{ Name = "Music", PackTitle = "Background Music", Title = Strings.SettingsMusic },
	{ Name = "Sfx", PackTitle = "SFX", Title = Strings.SettingsSfx },
	{ Name = "Vfx", PackTitle = "VFX", Title = Strings.SettingsVfx },
}

-- A row button's colors: the pack's green ON and red OFF, and our blue.
type Style = { Background: Color3, Stroke: Color3, Gradient: ColorSequence }

local CREDITS_STYLE: Style = {
	Background = Color3.fromRGB(0, 70, 140),
	Stroke = Color3.fromRGB(0, 25, 55),
	Gradient = ColorSequence.new(Color3.fromRGB(120, 210, 255), Color3.fromRGB(0, 130, 255)),
}

local SettingsController = {}

local buttonGui: ScreenGui
local switchButtons: { [string]: TextButton } = {}
local onStyle: Style? = nil
local offStyle: Style? = nil
local loaded = false

local function styleOf(button: Instance): Style?
	local stroke = button:FindFirstChild("Outer")
	local container = button:FindFirstChild("Container")
	local gradient = container and container:FindFirstChildOfClass("UIGradient")
	if
		not button:IsA("GuiObject")
		or stroke == nil
		or not stroke:IsA("UIStroke")
		or gradient == nil
	then
		return nil
	end
	return {
		Background = (button :: GuiObject).BackgroundColor3,
		Stroke = (stroke :: UIStroke).Color,
		Gradient = (gradient :: UIGradient).Color,
	}
end

local function applyStyle(button: TextButton, style: Style?)
	if style == nil then
		return
	end
	local s = style :: Style
	button.BackgroundColor3 = s.Background
	local stroke = button:FindFirstChild("Outer")
	if stroke and stroke:IsA("UIStroke") then
		stroke.Color = s.Stroke
	end
	local container = button:FindFirstChild("Container")
	local gradient = container and container:FindFirstChildOfClass("UIGradient")
	if gradient then
		gradient.Color = s.Gradient
	end
end

local function setButtonText(button: TextButton, text: string)
	local container = button:FindFirstChild("Container")
	local label = container and container:FindFirstChild("Name")
	if label and label:IsA("TextLabel") then
		Widgets.SetText(label, text)
	else
		button.Text = text
	end
end

local function setRowTitle(row: Instance, text: string)
	local title = row:FindFirstChild("Title")
	if title and title:IsA("TextLabel") then
		Widgets.SetText(title, text)
	end
end

local function showSwitch(name: string)
	local button = switchButtons[name]
	if button then
		local on = ClientSettings.Get(name)
		applyStyle(button, if on then onStyle else offStyle)
		setButtonText(button, if on then Strings.SettingOn else Strings.SettingOff)
	end
end

local function rowButton(row: Instance): TextButton?
	local button = row:FindFirstChild("Button")
	if button and button:IsA("TextButton") then
		button.Active = true
		button.Selectable = true
		return button
	end
	return nil
end

local function fitRow(row: GuiObject, order: number)
	row.LayoutOrder = order
	row.Size = UDim2.fromScale(0.965, 0.2)
	local ratio = row:FindFirstChildOfClass("UIAspectRatioConstraint")
		or Instance.new("UIAspectRatioConstraint")
	ratio.AspectRatio = ROW_ASPECT
	ratio.Parent = row
end

-- RichText needs &, < and > escaped.
local function escape(text: string): string
	return (string.gsub(text, "[&<>]", { ["&"] = "&amp;", ["<"] = "&lt;", [">"] = "&gt;" }))
end

local function creditsText(): string
	local parts = {}
	for _, entry in CreditsConfig do
		table.insert(parts, `<b>{escape(entry.Title)}</b>\n{escape(entry.Text)}`)
	end
	return table.concat(parts, "\n\n")
end

local function buildCredits(list: Instance, template: GuiObject, window: GuiObject)
	local row = template:Clone()
	row.Name = "CreditsRow"
	fitRow(row, #SWITCHES + 1)
	setRowTitle(row, Strings.SettingsCredits)
	row.Parent = list

	local box = Instance.new("Frame")
	box.Name = "Credits"
	box.BackgroundColor3 = CREDITS_COLOR
	box.BackgroundTransparency = 0.15
	box.Size = UDim2.fromScale(0.965, 0)
	box.AutomaticSize = Enum.AutomaticSize.Y
	box.LayoutOrder = #SWITCHES + 2
	box.Visible = false
	box.Parent = list
	Widgets.Corner(box, 0.03)
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0.03, 0)
	padding.PaddingRight = UDim.new(0.03, 0)
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.Parent = box

	local text = Instance.new("TextLabel")
	text.Name = "Text"
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 0)
	text.AutomaticSize = Enum.AutomaticSize.Y
	text.FontFace = FONT
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextWrapped = true
	text.RichText = true
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.TextYAlignment = Enum.TextYAlignment.Top
	text.Text = creditsText()
	text.Parent = box
	local function sizeText()
		text.TextSize = math.max(math.floor(window.AbsoluteSize.Y * CREDITS_TEXT_SIZE), 10)
	end
	window:GetPropertyChangedSignal("AbsoluteSize"):Connect(sizeText)
	sizeText()

	local button = rowButton(row)
	if button then
		local clicked = button :: TextButton
		applyStyle(clicked, CREDITS_STYLE)
		setButtonText(clicked, Strings.CreditsShow)
		Widgets.AnimatePress(clicked)
		clicked.Activated:Connect(function()
			Widgets.PlaySound("Click")
			box.Visible = not box.Visible
			setButtonText(clicked, if box.Visible then Strings.CreditsHide else Strings.CreditsShow)
		end)
	end
	-- Closed credits each time the window opens.
	PackUiController.Opened:Connect(function(name)
		if name == window.Name and box.Visible then
			box.Visible = false
			if button then
				setButtonText(button, Strings.CreditsShow)
			end
		end
	end)
end

-- Rebuilds the pack window's sample rows into our switches and Credits.
local function buildWindow()
	local window = PackUiController:GetWindow("Settings")
	local found = window and window:FindFirstChild("Main")
	if window == nil or found == nil or not found:IsA("ScrollingFrame") then
		return
	end
	local list = found :: ScrollingFrame
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.ScrollingDirection = Enum.ScrollingDirection.Y

	local byTitle: { [string]: GuiObject } = {}
	for _, row in list:GetChildren() do
		local title = row:FindFirstChild("Title")
		if row:IsA("GuiObject") and title and title:IsA("TextLabel") then
			byTitle[title.Text] = row
		end
	end
	local onRow = byTitle["Background Music"]
	local offRow = byTitle["VFX"]
	local onButton = onRow and onRow:FindFirstChild("Button")
	local offButton = offRow and offRow:FindFirstChild("Button")
	onStyle = if onButton then styleOf(onButton) else nil
	offStyle = if offButton then styleOf(offButton) else nil

	for order, switch in SWITCHES do
		local packRow = byTitle[switch.PackTitle]
		if not packRow then
			continue
		end
		local row = packRow :: GuiObject
		row.Name = switch.Name
		fitRow(row, order)
		setRowTitle(row, switch.Title)
		local button = rowButton(row)
		if button then
			switchButtons[switch.Name] = button
			button.Activated:Connect(function()
				local on = not ClientSettings.Get(switch.Name)
				ClientSettings.Set(switch.Name, on)
				ClientNet.Fire("SetSetting", switch.Name, on)
			end)
			showSwitch(switch.Name)
		end
	end
	if onRow then
		buildCredits(list, onRow, window :: GuiObject)
	end
end

-- The pack's square menu button with its Settings gear.
local function buildButton()
	buttonGui = Widgets.ScreenGui("SettingsButton", 1)
	local holder = Instance.new("Frame")
	holder.Name = "TopRight"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(1, 0)
	holder.Position = BUTTON_POSITION
	holder.Size = UDim2.fromScale(BUTTON_WIDTH, BUTTON_WIDTH * 2)
	holder.Parent = buttonGui
	Widgets.AspectRatio(holder, 1)

	local button = Widgets.PackButton(
		"MenuButton",
		"Settings",
		holder,
		UDim2.fromScale(1, 1),
		UDim2.new(),
		BUTTON_COLOR
	)
	Widgets.Paint(button, BUTTON_COLOR)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local ui = assets and assets:FindFirstChild("UI")
	local icons = ui and ui:FindFirstChild("Icons")
	local gear = icons and icons:FindFirstChild("Settings")
	local container = button:FindFirstChild("Container") or button
	for _, child in container:GetChildren() do
		if child:IsA("ImageLabel") and (child.Name == "Icon" or child.Name == "ImageBg") then
			if gear and gear:IsA("ImageLabel") then
				child.Image = gear.Image
			end
		end
	end
	local name = button:FindFirstChild("Name")
	if name and name:IsA("TextLabel") then
		Widgets.SetText(name, Strings.SettingsButton)
	end
	button.Activated:Connect(function()
		PackUiController:Toggle("Settings")
	end)
	buttonGui.Parent = player:WaitForChild("PlayerGui")
end

-- The saved switches arrive with the first profile; after that this
-- client's switches lead and the server only stores them.
local function onProfile(profile: Types.Profile?)
	if profile == nil or loaded then
		return
	end
	loaded = true
	local saved = (profile :: Types.Profile).Settings :: any
	for _, name in PlayerSettings.Names do
		ClientSettings.Set(name, PlayerSettings.Get(saved, name))
	end
end

function SettingsController:Init()
	buildButton()
	buildWindow()
	ClientSettings.Changed:Connect(showSwitch)
end

function SettingsController:Start()
	local function updateVisible()
		buttonGui.Enabled = player:GetAttribute("Team") == nil and not EggOfferController:IsShown()
	end
	player:GetAttributeChangedSignal("Team"):Connect(updateVisible)
	EggOfferController.ShownChanged:Connect(updateVisible)
	updateVisible()
	DataController.Changed:Connect(onProfile)
	onProfile(DataController:Get())
end

return SettingsController
