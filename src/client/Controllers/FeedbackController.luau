--!strict
-- The Feedback button at the top right and its window (Ivan 2026-10-13):
-- the player writes what to add or fix and sends it; FeedbackService keeps
-- it for Ivan (docs/feedback.md). Hidden during a match like the pack HUD.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FeedbackConfig = require(ReplicatedStorage.Shared.Config.FeedbackConfig)
local Strings = require(ReplicatedStorage.Shared.Config.Strings)
local Widgets = require(script.Parent.Parent.UI.Widgets)
local ClientNet = require(script.Parent.Parent.Util.ClientNet)
local EggOfferController = require(script.Parent.EggOfferController)

local player = Players.LocalPlayer

local BUTTON_COLOR = Color3.fromRGB(0, 150, 255)
local WINDOW_COLOR = Color3.fromRGB(40, 150, 255)
local CLOSE_COLOR = Color3.fromRGB(220, 60, 60)
local GOOD_COLOR = Color3.fromRGB(120, 255, 120)
local WARN_COLOR = Color3.fromRGB(255, 190, 90)
local MUTED_COLOR = Color3.fromRGB(190, 195, 215)
local ICON = utf8.char(0x1F4DD) -- the memo-with-pencil emoji
local THANKS_SECONDS = 1.5
local FONT = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)

local FeedbackController = {}

local buttonGui: ScreenGui
local windowGui: ScreenGui
local window: Frame
local box: TextBox
local countLabel: TextLabel
local noteLabel: TextLabel
local lastSentAt = -math.huge

local function charCount(text: string): number
	return utf8.len(text) or #text
end

local function setNote(text: string, color: Color3)
	noteLabel.Text = text
	noteLabel.TextColor3 = color
end

local function open()
	setNote("", MUTED_COLOR)
	window.Visible = true
end

local function close()
	box:ReleaseFocus()
	window.Visible = false
end

local function send()
	local left = FeedbackConfig.CooldownSeconds - (os.clock() - lastSentAt)
	if left > 0 then
		setNote(string.format(Strings.FeedbackWait, math.ceil(left)), WARN_COLOR)
		return
	end
	local text = string.match(box.Text, "^%s*(.-)%s*$") or ""
	if charCount(text) < FeedbackConfig.MinChars then
		setNote(Strings.FeedbackTooShort, WARN_COLOR)
		return
	end
	lastSentAt = os.clock()
	ClientNet.Fire("SendFeedback", text)
	box.Text = ""
	setNote(Strings.FeedbackThanks, GOOD_COLOR)
	task.delay(THANKS_SECONDS, function()
		if window.Visible then
			close()
		end
	end)
end

-- The pack's square menu button with the emoji in place of its picture and
-- "Feedback" under it.
local function buildButton()
	buttonGui = Widgets.ScreenGui("FeedbackButton", 1)
	local holder = Instance.new("Frame")
	holder.Name = "TopRight"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(1, 0)
	holder.Position = UDim2.fromScale(0.985, 0.02)
	holder.Size = UDim2.fromScale(0.07, 0.12)
	holder.Parent = buttonGui
	Widgets.AspectRatio(holder, 1)

	local button = Widgets.PackButton(
		"MenuButton",
		"Feedback",
		holder,
		UDim2.fromScale(1, 1),
		UDim2.new(),
		BUTTON_COLOR
	)
	Widgets.Paint(button, BUTTON_COLOR)
	local container = button:FindFirstChild("Container") or button
	for _, child in container:GetChildren() do
		if child:IsA("ImageLabel") and (child.Name == "Icon" or child.Name == "ImageBg") then
			child.Visible = false
		end
	end
	local icon = Instance.new("TextLabel")
	icon.Name = "Emoji"
	icon.BackgroundTransparency = 1
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.42)
	icon.Size = UDim2.fromScale(0.7, 0.7)
	icon.TextScaled = true
	icon.Text = ICON
	icon.ZIndex = 3
	icon.Parent = container
	local name = button:FindFirstChild("Name")
	if name and name:IsA("TextLabel") then
		Widgets.SetText(name, Strings.FeedbackButton)
	end
	button.Activated:Connect(function()
		if window.Visible then
			close()
		else
			open()
		end
	end)
end

local function buildWindow()
	windowGui = Widgets.ScreenGui("Feedback", 6)
	window = Widgets.Panel(
		"Window",
		windowGui,
		UDim2.fromScale(0.46, 0.5),
		UDim2.fromScale(0.5, 0.5),
		WINDOW_COLOR
	)
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.Visible = false
	-- Solid: it opens over the egg offer window.
	window.BackgroundTransparency = 0
	Widgets.AspectRatio(window, 1.5)

	local bar = window:FindFirstChild("Top")
	local title = if bar
		then Widgets.Label("Title", bar, UDim2.fromScale(0.7, 0.7), UDim2.fromScale(0.5, 0.46))
		else Widgets.Label(
			"Title",
			window,
			UDim2.fromScale(0.7, 0.1),
			UDim2.fromScale(0.5, 0.07)
		)
	title.AnchorPoint = Vector2.new(0.5, 0.5)
	title.ZIndex = 2
	title.Text = Strings.FeedbackTitle

	local closeButton = Widgets.Button(
		"Close",
		window,
		UDim2.fromScale(0.07, 0.1),
		UDim2.fromScale(0.915, 0.017),
		CLOSE_COLOR
	)
	closeButton.Text = "X"
	closeButton.Activated:Connect(close)

	local field = Instance.new("Frame")
	field.Name = "Field"
	field.BackgroundColor3 = Color3.fromRGB(20, 24, 40)
	field.BackgroundTransparency = 0
	field.Position = UDim2.fromScale(0.05, 0.19)
	field.Size = UDim2.fromScale(0.9, 0.52)
	field.Parent = window
	Widgets.Corner(field, 0.06)
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0.03, 0)
	padding.PaddingRight = UDim.new(0.03, 0)
	padding.PaddingTop = UDim.new(0.05, 0)
	padding.PaddingBottom = UDim.new(0.05, 0)
	padding.Parent = field

	box = Instance.new("TextBox")
	box.Name = "Text"
	box.BackgroundTransparency = 1
	box.Size = UDim2.fromScale(1, 1)
	box.FontFace = FONT
	box.TextColor3 = Color3.new(1, 1, 1)
	box.PlaceholderText = Strings.FeedbackHint
	box.PlaceholderColor3 = MUTED_COLOR
	box.Text = ""
	box.ClearTextOnFocus = false
	box.MultiLine = true
	box.TextWrapped = true
	box.TextXAlignment = Enum.TextXAlignment.Left
	box.TextYAlignment = Enum.TextYAlignment.Top
	box.Parent = field

	countLabel =
		Widgets.Label("Count", window, UDim2.fromScale(0.3, 0.07), UDim2.fromScale(0.05, 0.73))
	countLabel.TextXAlignment = Enum.TextXAlignment.Left
	countLabel.TextColor3 = MUTED_COLOR
	noteLabel =
		Widgets.Label("Note", window, UDim2.fromScale(0.55, 0.09), UDim2.fromScale(0.05, 0.83))
	noteLabel.TextXAlignment = Enum.TextXAlignment.Left

	local sendButton = Widgets.PackButton(
		"LevelButton",
		"Send",
		window,
		UDim2.fromScale(0.3, 0.15),
		UDim2.fromScale(0.65, 0.78),
		GOOD_COLOR
	)
	local sendContainer = sendButton:FindFirstChild("Container")
	local sendText = sendContainer and sendContainer:FindFirstChild("Text")
	if sendText and sendText:IsA("TextLabel") then
		Widgets.SetText(sendText, Strings.FeedbackSend)
	else
		sendButton.Text = Strings.FeedbackSend
	end
	sendButton.Activated:Connect(send)

	-- Long messages stop at MaxChars; the counter shows how much is left.
	local function onText()
		local text = box.Text
		if charCount(text) > FeedbackConfig.MaxChars then
			local cut = utf8.offset(text, FeedbackConfig.MaxChars + 1)
			if cut then
				box.Text = string.sub(text, 1, cut - 1)
				return
			end
		end
		countLabel.Text =
			string.format(Strings.FeedbackCount, charCount(box.Text), FeedbackConfig.MaxChars)
	end
	box:GetPropertyChangedSignal("Text"):Connect(onText)
	onText()
	local function sizeText()
		box.TextSize = math.max(math.floor(window.AbsoluteSize.Y * 0.05), 10)
	end
	window:GetPropertyChangedSignal("AbsoluteSize"):Connect(sizeText)
	sizeText()

	buttonGui.Parent = player:WaitForChild("PlayerGui")
	windowGui.Parent = buttonGui.Parent
end

function FeedbackController:Init()
	buildButton()
	buildWindow()
end

function FeedbackController:Start()
	-- Like the pack HUD: only in the hub, not during a match or under the
	-- egg screen.
	local function updateVisible()
		local visible = player:GetAttribute("Team") == nil and not EggOfferController:IsShown()
		buttonGui.Enabled = visible
		if not visible then
			close()
		end
	end
	player:GetAttributeChangedSignal("Team"):Connect(updateVisible)
	EggOfferController.ShownChanged:Connect(updateVisible)
	updateVisible()
end

return FeedbackController
