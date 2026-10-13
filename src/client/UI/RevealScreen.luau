--!strict
-- The "you got it" screen for a picked egg and a hatched pet (Ivan,
-- 2026-10-13: no gray window, just a darkened screen). The model pops in
-- over turning rays and a glow in its color, sways and bobs, sparkles
-- twinkle around it; a heading, the name and up to two lines sit under it.
-- A click anywhere or a few seconds close it.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local AssetModels = require(script.Parent.AssetModels)
local Glow = require(script.Parent.Glow)
local Widgets = require(script.Parent.Widgets)

local DISPLAY_ORDER = 7 -- above the egg screen (5) and the tutorial (6)
local SHOW_SECONDS = 5
local DIM_TRANSPARENCY = 0.35
local FADE = TweenInfo.new(0.2)
local POP = TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local TEXT_POP = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local SWAY_DEGREES = 28
local SWAY_SPEED = 0.9
local BOB = 0.025 -- of the stage height
local BOB_SPEED = 2.2
local SPARKLES = 9
local GOLD = Color3.fromRGB(255, 214, 64)
local WHITE = Color3.new(1, 1, 1)

export type Line = {
	Text: string,
	Color: Color3?,
	-- "Pill": white text on a rounded plate in Color; "Money": gold money text.
	Style: ("Pill" | "Money" | "Text")?,
}

export type Options = {
	Model: Model?,
	Color: Color3,
	Heading: string,
	Title: string,
	Lines: { Line },
	Note: string?,
	Close: string,
}

local RevealScreen = {}

local gui: ScreenGui? = nil
local root: TextButton
local dim: Frame
local stage: Frame
local glow: Glow.Glow
local holder: Frame
local holderScale: UIScale
local heading: TextLabel
local title: TextLabel
local titleScale: UIScale
local lines: Frame
local note: TextLabel
local closeHint: TextLabel
local sparkles: { Frame } = {}
local viewport: ViewportFrame? = nil
local token = 0
local shownAt = 0
local stepConnection: RBXScriptConnection? = nil

local function popLabel(name: string, size: UDim2, position: UDim2): (TextLabel, UIScale)
	local label = Widgets.Label(name, root, size, position)
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.ZIndex = 5
	local scale = Instance.new("UIScale")
	scale.Parent = label
	return label, scale
end

local function build()
	local screen = Widgets.ScreenGui("Reveal", DISPLAY_ORDER)
	screen.IgnoreGuiInset = true
	screen.Enabled = false

	root = Instance.new("TextButton")
	root.Name = "Root"
	root.Text = ""
	root.AutoButtonColor = false
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Parent = screen

	dim = Instance.new("Frame")
	dim.Name = "Dim"
	dim.BackgroundColor3 = Color3.new(0, 0, 0)
	dim.BackgroundTransparency = 1
	dim.BorderSizePixel = 0
	dim.Size = UDim2.fromScale(1, 1)
	dim.Parent = root

	stage = Instance.new("Frame")
	stage.Name = "Stage"
	stage.BackgroundTransparency = 1
	stage.AnchorPoint = Vector2.new(0.5, 0.5)
	stage.Position = UDim2.fromScale(0.5, 0.42)
	stage.Size = UDim2.fromScale(0.5, 0.5)
	stage.SizeConstraint = Enum.SizeConstraint.RelativeYY
	stage.Parent = root
	glow = Glow.new(stage, WHITE, 1.45, true, 1)

	holder = Instance.new("Frame")
	holder.Name = "Model"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromScale(0.82, 0.82)
	holder.ZIndex = 3
	holder.Parent = stage
	holderScale = Instance.new("UIScale")
	holderScale.Parent = holder

	-- Little diamonds that twinkle around the model.
	for index = 1, SPARKLES do
		local sparkle = Instance.new("Frame")
		sparkle.Name = `Sparkle{index}`
		sparkle.AnchorPoint = Vector2.new(0.5, 0.5)
		sparkle.BackgroundColor3 = WHITE
		sparkle.BorderSizePixel = 0
		sparkle.Rotation = 45
		sparkle.SizeConstraint = Enum.SizeConstraint.RelativeYY
		sparkle.ZIndex = 4
		sparkle.Parent = stage
		Widgets.Corner(sparkle, 0.2)
		table.insert(sparkles, sparkle)
	end

	heading = popLabel("Heading", UDim2.fromScale(0.5, 0.055), UDim2.fromScale(0.5, 0.11))
	heading.TextColor3 = GOLD
	title, titleScale = popLabel("Title", UDim2.fromScale(0.7, 0.095), UDim2.fromScale(0.5, 0.715))

	lines = Instance.new("Frame")
	lines.Name = "Lines"
	lines.BackgroundTransparency = 1
	lines.AnchorPoint = Vector2.new(0.5, 0)
	lines.Position = UDim2.fromScale(0.5, 0.775)
	lines.Size = UDim2.fromScale(0.6, 0.11)
	lines.ZIndex = 5
	lines.Parent = root
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0.08, 0)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = lines

	note = popLabel("Note", UDim2.fromScale(0.6, 0.035), UDim2.fromScale(0.5, 0.9))
	note.TextColor3 = Color3.fromRGB(255, 190, 110)
	closeHint = popLabel("Close", UDim2.fromScale(0.4, 0.03), UDim2.fromScale(0.5, 0.95))
	closeHint.TextColor3 = Color3.fromRGB(200, 205, 225)

	root.Activated:Connect(function()
		RevealScreen.Hide()
	end)

	screen.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	gui = screen
end

local function clearLines()
	for _, child in lines:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function addLine(line: Line, order: number)
	local style = line.Style or "Text"
	local color = line.Color or WHITE
	if style == "Pill" then
		local pill = Instance.new("Frame")
		pill.Name = "Pill"
		pill.BackgroundColor3 = color
		pill.BorderSizePixel = 0
		pill.AutomaticSize = Enum.AutomaticSize.X
		pill.Size = UDim2.fromScale(0, 0.42)
		pill.LayoutOrder = order
		pill.ZIndex = 5
		pill.Parent = lines
		Widgets.Corner(pill, 0.5)
		local outline = Widgets.Stroke(pill, Color3.fromRGB(25, 25, 25), 2)
		outline.Transparency = 0.2
		local gradient = Instance.new("UIGradient")
		gradient.Rotation = 90
		gradient.Color = ColorSequence.new(WHITE, Color3.fromRGB(190, 190, 190))
		gradient.Parent = pill
		local padding = Instance.new("UIPadding")
		padding.PaddingLeft = UDim.new(0.6, 0)
		padding.PaddingRight = UDim.new(0.6, 0)
		padding.Parent = pill
		local label = Widgets.Label("Text", pill, UDim2.fromScale(0, 0.8), UDim2.fromScale(0, 0.1))
		label.AutomaticSize = Enum.AutomaticSize.X
		label.TextScaled = false
		label.ZIndex = 6
		label.Text = line.Text
		local function size()
			local height = pill.AbsoluteSize.Y
			label.TextSize = math.max(math.floor(height * 0.72), 8)
			padding.PaddingLeft = UDim.new(0, height * 0.6)
			padding.PaddingRight = UDim.new(0, height * 0.6)
		end
		pill:GetPropertyChangedSignal("AbsoluteSize"):Connect(size)
		size()
	elseif style == "Money" then
		local label = Widgets.MoneyLabel("Money", lines, UDim2.fromScale(1, 0.42), UDim2.new())
		label.LayoutOrder = order
		label.ZIndex = 5
		Widgets.SetText(label, line.Text)
	else
		local label = Widgets.Label("Text", lines, UDim2.fromScale(1, 0.36), UDim2.new())
		label.LayoutOrder = order
		label.ZIndex = 5
		label.TextColor3 = color
		label.Text = line.Text
	end
end

-- Sparkles sit on a ring around the model at random spots, each with its
-- own twinkle rhythm.
local function scatterSparkles()
	for index, sparkle in sparkles do
		local angle = (index / #sparkles) * math.pi * 2 + math.random() * 0.5
		local radius = 0.36 + math.random() * 0.14
		sparkle.Position =
			UDim2.fromScale(0.5 + math.cos(angle) * radius, 0.5 + math.sin(angle) * radius)
		sparkle:SetAttribute("Phase", math.random() * math.pi * 2)
		sparkle:SetAttribute("Speed", 2 + math.random() * 2.5)
		sparkle:SetAttribute("Big", 0.025 + math.random() * 0.03)
	end
end

local function step()
	local t = os.clock() - shownAt
	holder.Position = UDim2.fromScale(0.5, 0.5 + math.sin(t * BOB_SPEED) * BOB)
	local shown = viewport
	if shown and shown.Parent then
		local angle = math.rad(math.sin(t * SWAY_SPEED) * SWAY_DEGREES)
		AssetModels.Frame(shown, Vector3.new(math.sin(angle) + 0.25, 0.2, -math.cos(angle)))
	end
	for _, sparkle in sparkles do
		local phase = (sparkle:GetAttribute("Phase") or 0) :: number
		local speed = (sparkle:GetAttribute("Speed") or 3) :: number
		local big = (sparkle:GetAttribute("Big") or 0.04) :: number
		local wave = math.max(0, math.sin(t * speed + phase))
		sparkle.Size = UDim2.fromScale(big * wave, big * wave)
		sparkle.BackgroundTransparency = 1 - wave * 0.9
	end
end

function RevealScreen.Show(options: Options)
	if gui == nil then
		build()
	end
	token += 1
	local myToken = token
	shownAt = os.clock()

	for _, child in holder:GetChildren() do
		child:Destroy()
	end
	viewport = AssetModels.Viewport(holder, options.Model, options.Color)
	Glow.SetColor(glow, options.Color)
	for _, sparkle in sparkles do
		sparkle.BackgroundColor3 = WHITE:Lerp(options.Color, 0.25)
	end
	scatterSparkles()

	heading.Text = options.Heading
	title.Text = options.Title
	title.TextColor3 = options.Color
	clearLines()
	for order, line in options.Lines do
		addLine(line, order)
	end
	note.Text = options.Note or ""
	note.Visible = options.Note ~= nil and options.Note ~= ""
	closeHint.Text = options.Close

	local screen = gui :: ScreenGui
	screen.Enabled = true
	dim.BackgroundTransparency = 1
	TweenService:Create(dim, FADE, { BackgroundTransparency = DIM_TRANSPARENCY }):Play()
	holderScale.Scale = 0
	TweenService:Create(holderScale, POP, { Scale = 1 }):Play()
	titleScale.Scale = 0.3
	task.delay(0.12, function()
		if myToken == token then
			TweenService:Create(titleScale, TEXT_POP, { Scale = 1 }):Play()
		end
	end)
	if stepConnection == nil then
		stepConnection = RunService.RenderStepped:Connect(step)
	end
	step()

	task.delay(SHOW_SECONDS, function()
		if myToken == token then
			RevealScreen.Hide()
		end
	end)
end

function RevealScreen.Hide()
	if gui == nil or not (gui :: ScreenGui).Enabled then
		return
	end
	local screen = gui :: ScreenGui
	token += 1
	local myToken = token
	TweenService:Create(dim, FADE, { BackgroundTransparency = 1 }):Play()
	TweenService:Create(holderScale, FADE, { Scale = 0 }):Play()
	task.delay(FADE.Time, function()
		if myToken ~= token then
			return
		end
		screen.Enabled = false
		if stepConnection then
			stepConnection:Disconnect()
			stepConnection = nil
		end
		for _, child in holder:GetChildren() do
			child:Destroy()
		end
		viewport = nil
	end)
end

return RevealScreen
