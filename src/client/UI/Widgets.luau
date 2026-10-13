--!strict
-- Small builders for code-made UI. Sizes use Scale so the same layout fits
-- phones, tablets and PC. The look comes from the Studs UI Pack templates in
-- ReplicatedStorage.Assets.UI (see docs/assets.md): striped buttons with a
-- dark lip, outlined two-layer text, see-through windows with a title bar
-- and the square menu buttons on the left. Without the templates (unit
-- tests, a broken asset) every builder falls back to plain instances.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Widgets = {}

local FONT = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy)
local OUTLINE = Color3.fromRGB(25, 25, 25)
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)

local HOVER_SCALE = 1.05
local PRESS_SCALE = 0.95
local SCALE_TWEEN = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
-- Window titles and close buttons sit in the top ~12% of every window.
local BAR_HEIGHT = 0.135

local function template(name: string): Instance?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local ui = assets and assets:FindFirstChild("UI")
	return ui and ui:FindFirstChild(name)
end

-- Plays a UI sound: the UI pack's sounds first, then Assets.Sounds.
function Widgets.PlaySound(name: string)
	local packSounds = template("Sounds")
	local sound = packSounds and packSounds:FindFirstChild(name)
	if sound == nil then
		local assets = ReplicatedStorage:FindFirstChild("Assets")
		local sounds = assets and assets:FindFirstChild("Sounds")
		sound = sounds and sounds:FindFirstChild(name)
	end
	if sound and sound:IsA("Sound") then
		SoundService:PlayLocalSound(sound)
	end
end

-- Pack strokes are sized relative to the object (StrokeSizingMode.ScaledSize).
-- Older Studio builds without it get a fixed 2 px outline instead.
local function scaledStroke(stroke: UIStroke, thickness: number)
	local ok = pcall(function()
		(stroke :: any).StrokeSizingMode = (Enum :: any).StrokeSizingMode.ScaledSize
	end)
	stroke.Thickness = if ok then thickness else 2
end

-- Colors of a pack block (button, menu button, title bar) from one base color:
-- a light-to-base gradient on top, a darker lip under it, a near-black edge.
local function lighter(color: Color3): Color3
	return color:Lerp(WHITE, 0.45)
end

local function darker(color: Color3): Color3
	return color:Lerp(BLACK, 0.45)
end

local function edge(color: Color3): Color3
	return color:Lerp(BLACK, 0.82)
end

local function paintBlock(block: GuiObject, base: Color3, lip: Color3)
	block.BackgroundColor3 = lip
	local container = block:FindFirstChild("Container")
	local gradient = container and container:FindFirstChildOfClass("UIGradient")
	if gradient then
		gradient.Color = ColorSequence.new(lighter(base), base)
	end
	local outer = block:FindFirstChild("Outer")
	if outer and outer:IsA("UIStroke") then
		outer.Color = edge(base)
	end
	local shadow = block:FindFirstChild("UIShadow")
	if shadow then
		pcall(function()
			(shadow :: any).Color = lighter(base)
		end)
	end
end

-- Pack texts are two labels: a dark one and a white copy shifted up a bit.
-- Returns the setter that keeps both in sync.
local function twoLayerText(label: Instance): (string) -> ()
	local top = label:FindFirstChild("Color")
	return function(text: string)
		if label:IsA("TextLabel") then
			label.Text = text
		end
		if top and top:IsA("TextLabel") then
			top.Text = text
		end
	end
end

-- Keeps the white top layer of a two-layer pack text in sync with the label
-- callers write to.
local function mirrorTopLayer(label: TextLabel)
	local found = label:FindFirstChild("Color")
	if found == nil or not found:IsA("TextLabel") then
		return
	end
	local top = found :: TextLabel
	label:GetPropertyChangedSignal("Text"):Connect(function()
		top.Text = label.Text
	end)
	label:GetPropertyChangedSignal("TextXAlignment"):Connect(function()
		top.TextXAlignment = label.TextXAlignment
	end)
end

-- The pack's stud texture is tiled for wide buttons (a tile as tall as the
-- face). On a tall button, such as an egg card, that stretches the studs
-- down the face, so the tiles are kept no taller than they are wide.
local function squareTiles(container: Instance?)
	if container == nil or not container:IsA("GuiObject") then
		return
	end
	local face = container :: GuiObject
	local textures = face:FindFirstChild("Textures")
	if textures == nil then
		return
	end
	for _, child in (textures :: Instance):GetChildren() do
		if child:IsA("ImageLabel") and child.ScaleType == Enum.ScaleType.Tile then
			local image = child :: ImageLabel
			local tile = image.TileSize
			local function fit()
				local size = image.AbsoluteSize
				if size.Y <= 0 then
					return
				end
				local height = math.min(tile.Y.Scale, tile.X.Scale * size.X / size.Y)
				image.TileSize = UDim2.fromScale(tile.X.Scale, height)
			end
			image:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
			fit()
		end
	end
end

-- Hover grows a button a little (with the Hover sound on PC), a press shrinks it.
function Widgets.AnimatePress(button: GuiButton)
	local scale = button:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Parent = button
	local function tweenTo(value: number)
		TweenService:Create(scale, SCALE_TWEEN, { Scale = value }):Play()
	end
	button.MouseEnter:Connect(function()
		if UserInputService.MouseEnabled then
			Widgets.PlaySound("Hover")
			tweenTo(HOVER_SCALE)
		end
	end)
	button.MouseLeave:Connect(function()
		tweenTo(1)
	end)
	button.MouseButton1Down:Connect(function()
		tweenTo(PRESS_SCALE)
	end)
	button.MouseButton1Up:Connect(function()
		tweenTo(if UserInputService.MouseEnabled then HOVER_SCALE else 1)
	end)
end

function Widgets.Corner(parent: GuiObject, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(radius, 0)
	corner.Parent = parent
	-- A pack button draws its face in Container, which needs the same shape.
	local container = parent:FindFirstChild("Container")
	if container and container:IsA("GuiObject") then
		local inner = container:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
		inner.CornerRadius = UDim.new(radius, 0)
		inner.Parent = container
	end
end

function Widgets.Stroke(parent: GuiObject, color: Color3, thickness: number): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.Parent = parent
	return stroke
end

function Widgets.AspectRatio(parent: GuiObject, ratio: number)
	local constraint = Instance.new("UIAspectRatioConstraint")
	constraint.AspectRatio = ratio
	constraint.Parent = parent
end

-- White text with the pack font and a dark outline.
function Widgets.Label(name: string, parent: Instance, size: UDim2, position: UDim2): TextLabel
	local text = Instance.new("TextLabel")
	text.Name = name
	text.Size = size
	text.Position = position
	text.BackgroundTransparency = 1
	text.TextScaled = true
	text.FontFace = FONT
	text.TextColor3 = WHITE
	text.TextStrokeTransparency = 1
	text.Text = ""
	local stroke = Instance.new("UIStroke")
	stroke.Name = "Outer"
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Color = OUTLINE
	scaledStroke(stroke, 0.06)
	stroke.Parent = text
	text.Parent = parent
	return text
end

local function plainButton(name: string, size: UDim2, position: UDim2, color: Color3): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = size
	button.Position = position
	button.BackgroundColor3 = color
	button.TextScaled = true
	button.FontFace = FONT
	button.TextColor3 = WHITE
	button.TextStrokeTransparency = 0.5
	button.AutoButtonColor = true
	button.Text = ""
	Widgets.Corner(button, 0.25)
	return button
end

-- A pack button. Callers use it like a plain TextButton: Text, TextColor3 and
-- BackgroundColor3 (the button's base color) are mirrored onto the pack art.
function Widgets.Button(
	name: string,
	parent: Instance,
	size: UDim2,
	position: UDim2,
	color: Color3
): TextButton
	local source = template("Button")
	local button: TextButton
	if source and source:IsA("TextButton") then
		button = source:Clone()
		button.Name = name
		button.AnchorPoint = Vector2.zero
		button.Size = size
		button.Position = position
		button.AutoButtonColor = false
		-- The pack ships its buttons inactive; Activated only fires when Active.
		button.Active = true
		button.Selectable = true
		button.TextTransparency = 1
		button.TextColor3 = WHITE
		button.Text = ""

		local container = button:FindFirstChild("Container")
		squareTiles(container)
		local caption = container and container:FindFirstChild("Name")
		local setText: (string) -> () = if caption
			then twoLayerText(caption)
			else function(_: string) end
		local top = caption and caption:FindFirstChild("Color")
		setText("")
		button:GetPropertyChangedSignal("Text"):Connect(function()
			setText(button.Text)
		end)
		button:GetPropertyChangedSignal("TextColor3"):Connect(function()
			if top and top:IsA("TextLabel") then
				top.TextColor3 = button.TextColor3
			end
		end)

		-- BackgroundColor3 is the caller's base color; the lip we draw is
		-- written back to it, so remember it to ignore our own write.
		local lip: Color3? = nil
		local function repaint()
			local base = button.BackgroundColor3
			if lip ~= nil and base == lip then
				return
			end
			lip = darker(base)
			paintBlock(button, base, lip :: Color3)
		end
		button.BackgroundColor3 = color
		repaint()
		button:GetPropertyChangedSignal("BackgroundColor3"):Connect(repaint)
		Widgets.AnimatePress(button)
	else
		button = plainButton(name, size, position, color)
	end
	button.Activated:Connect(function()
		Widgets.PlaySound("Click")
	end)
	button.Parent = parent
	return button
end

-- Sets the text of a two-layer pack label (the dark label and its white
-- "Color" copy).
function Widgets.SetText(label: TextLabel, text: string)
	twoLayerText(label)(text)
end

-- A copy of one of the pack's own buttons kept in Assets.UI (LevelButton:
-- the lime "+5 Levels" button; RobuxButton: the rainbow "X2 Money" button
-- with its green Robux price under it). Without the template it is a plain
-- Widgets.Button in `color`. Callers fill the template's own labels.
function Widgets.PackButton(
	templateName: string,
	name: string,
	parent: Instance,
	size: UDim2,
	position: UDim2,
	color: Color3
): TextButton
	local found = template(templateName)
	if found == nil or not found:IsA("TextButton") then
		return Widgets.Button(name, parent, size, position, color)
	end
	local button = (found :: TextButton):Clone()
	button.Name = name
	button.AnchorPoint = Vector2.zero
	button.Size = size
	button.Position = position
	button.AutoButtonColor = false
	-- The pack ships its buttons inactive; Activated only fires when Active.
	button.Active = true
	button.Selectable = true
	button.Text = ""
	Widgets.AnimatePress(button)
	button.Activated:Connect(function()
		Widgets.PlaySound("Click")
	end)
	button.Parent = parent
	return button
end

-- A see-through pack window. With barColor it gets the pack title bar across
-- its top BAR_HEIGHT, where callers put their Title label and close button.
function Widgets.Panel(
	name: string,
	parent: Instance,
	size: UDim2,
	position: UDim2,
	barColor: Color3?
): Frame
	local source = template("Window")
	local frame: Frame
	if source and source:IsA("Frame") then
		frame = source:Clone()
		frame.AnchorPoint = Vector2.zero
		local bar = frame:FindFirstChild("Top")
		if bar and bar:IsA("Frame") then
			if barColor then
				bar.Size = UDim2.fromScale(1, BAR_HEIGHT)
				paintBlock(bar, barColor, darker(barColor))
			else
				bar:Destroy()
			end
		end
	else
		frame = Instance.new("Frame")
		frame.BackgroundColor3 = Color3.fromRGB(34, 36, 52)
		frame.BackgroundTransparency = 0.05
		Widgets.Corner(frame, 0.06)
	end
	frame.Name = name
	frame.Size = size
	frame.Position = position
	frame.Parent = parent
	return frame
end

-- A tile of the pack's index: tinted face with a shine and a dark outline
-- (its UIStroke "Outer"), and a two-layer title across the top. Returns the
-- card and the title; Widgets.TintCard recolors it.
function Widgets.Card(
	name: string,
	parent: Instance,
	size: UDim2,
	position: UDim2,
	color: Color3
): (Frame, TextLabel)
	local source = template("Item")
	local found = source and source:FindFirstChild("Name")
	local card: Frame
	local title: TextLabel
	if source and source:IsA("Frame") and found and found:IsA("TextLabel") then
		card = source:Clone()
		card.AnchorPoint = Vector2.zero
		-- The pack's shine goes behind the contents, softer.
		local shine = card:FindFirstChild("Effect")
		if shine and shine:IsA("ImageLabel") then
			shine.ZIndex = 0
			shine.ImageTransparency = 0.6
		end
		title = card:FindFirstChild("Name") :: TextLabel
		title.Name = "Title"
		title.Position = UDim2.fromScale(0.5, 0.13)
		title.Size = UDim2.fromScale(0.92, 0.2)
		mirrorTopLayer(title)
	else
		card = Instance.new("Frame")
		Widgets.Corner(card, 0.06)
		local outline = Widgets.Stroke(card, OUTLINE, 2)
		outline.Name = "Outer"
		title =
			Widgets.Label("Title", card, UDim2.fromScale(0.92, 0.2), UDim2.fromScale(0.04, 0.03))
	end
	title.ZIndex = 25
	title.Text = ""
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Parent = card
	card.Name = name
	card.Size = size
	card.Position = position
	card.BackgroundTransparency = 0
	Widgets.TintCard(card, color)
	card.Parent = parent
	return card, title
end

function Widgets.TintCard(card: GuiObject, color: Color3)
	card.BackgroundColor3 = WHITE
	local gradient = card:FindFirstChildOfClass("UIGradient")
	if gradient then
		gradient.Color = ColorSequence.new(lighter(color), darker(color))
	else
		card.BackgroundColor3 = color
	end
end

-- Gold money text from the pack (two layers with a gradient).
function Widgets.MoneyLabel(name: string, parent: Instance, size: UDim2, position: UDim2): TextLabel
	local source = template("CashText")
	local label: TextLabel
	if source and source:IsA("TextLabel") then
		label = source:Clone()
		label.AnchorPoint = Vector2.zero
		mirrorTopLayer(label)
	else
		label = Widgets.Label(name, parent, size, position)
		label.TextColor3 = Color3.fromRGB(255, 214, 64)
	end
	label.Name = name
	label.Size = size
	label.Position = position
	label.Text = ""
	label.Parent = parent
	return label
end

-- The pack's striped progress bar: back color behind, fillColor from the left.
-- Returns the bar, the fill (set its Size X scale) and the left and right
-- texts on top.
function Widgets.ProgressBar(
	name: string,
	parent: Instance,
	size: UDim2,
	position: UDim2,
	backColor: Color3,
	fillColor: Color3
): (Frame, Frame, TextLabel, TextLabel)
	local source = template("Bar")
	local bar: Frame
	local fill: Frame
	local left: TextLabel
	local right: TextLabel
	local effect = source and source:FindFirstChild("Effect")
	local level = source and source:FindFirstChild("Level")
	local xp = source and source:FindFirstChild("XP")
	if
		source
		and source:IsA("Frame")
		and effect
		and effect:IsA("Frame")
		and level
		and level:IsA("TextLabel")
		and xp
		and xp:IsA("TextLabel")
	then
		bar = source:Clone()
		bar.AnchorPoint = Vector2.zero
		fill = bar:FindFirstChild("Effect") :: Frame
		left = bar:FindFirstChild("Level") :: TextLabel
		right = bar:FindFirstChild("XP") :: TextLabel
		bar.BackgroundColor3 = WHITE
		local backGradient = bar:FindFirstChildOfClass("UIGradient")
		if backGradient then
			backGradient.Color = ColorSequence.new(lighter(backColor), backColor)
		end
		local fillGradient = fill:FindFirstChildOfClass("UIGradient")
		if fillGradient then
			fillGradient.Color = ColorSequence.new(lighter(fillColor), fillColor)
		end
		mirrorTopLayer(left)
		mirrorTopLayer(right)
		-- The pack's sample texts ("Level 5") go from both layers.
		left.Text = " "
		right.Text = " "
		left.Text = ""
		right.Text = ""
		right.TextXAlignment = Enum.TextXAlignment.Right
		local rightTop = right:FindFirstChild("Color")
		if rightTop and rightTop:IsA("TextLabel") then
			rightTop.TextXAlignment = Enum.TextXAlignment.Right
		end
	else
		bar = Instance.new("Frame")
		bar.BackgroundColor3 = backColor
		Widgets.Corner(bar, 0.5)
		fill = Instance.new("Frame")
		fill.Name = "Fill"
		fill.Size = UDim2.fromScale(0.5, 1)
		fill.BackgroundColor3 = fillColor
		fill.Parent = bar
		Widgets.Corner(fill, 0.5)
		left = Widgets.Label("Left", bar, UDim2.fromScale(0.3, 1), UDim2.fromScale(0.02, 0))
		right = Widgets.Label("Right", bar, UDim2.fromScale(0.3, 1), UDim2.fromScale(0.68, 0))
		right.TextXAlignment = Enum.TextXAlignment.Right
	end
	left.TextXAlignment = Enum.TextXAlignment.Left
	fill.Size = UDim2.fromScale(0.5, 1)
	bar.Name = name
	bar.Size = size
	bar.Position = position
	bar.Parent = parent
	return bar, fill, left, right
end

function Widgets.ScreenGui(name: string, displayOrder: number): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = displayOrder
	return gui
end

-- The square buttons on the left edge (shop, pets, party, plot). They share
-- one column, two per row, in LayoutOrder.
local menuColumn: Frame? = nil

local function getMenuColumn(): Frame
	if menuColumn then
		return menuColumn
	end
	local gui = Widgets.ScreenGui("Menu", 2)
	local column = Instance.new("Frame")
	column.Name = "Left"
	column.AnchorPoint = Vector2.new(0, 0.5)
	column.Position = UDim2.fromScale(0.012, 0.52)
	column.Size = UDim2.fromScale(0.2, 0.38)
	column.BackgroundTransparency = 1
	column.Parent = gui
	Widgets.AspectRatio(column, 1)
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromScale(0.46, 0.46)
	grid.CellPadding = UDim2.fromScale(0.06, 0.08)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = column
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	menuColumn = column
	return column
end

-- icon is a name in Assets.UI.Icons (Shop, Index, Pass, Rebirth, Settings).
-- Text on the returned button is mirrored onto its caption.
function Widgets.MenuButton(
	name: string,
	text: string,
	icon: string,
	color: Color3,
	order: number
): TextButton
	local column = getMenuColumn()
	local source = template("MenuButton")
	local button: TextButton
	if source and source:IsA("TextButton") then
		button = source:Clone()
		button.AnchorPoint = Vector2.zero
		button.TextTransparency = 1
		button.AutoButtonColor = false
		button.Active = true
		button.Selectable = true
		paintBlock(button, color, darker(color))

		local caption = button:FindFirstChild("Name")
		local setText: (string) -> () = if caption
			then twoLayerText(caption)
			else function(_: string) end
		button:GetPropertyChangedSignal("Text"):Connect(function()
			setText(button.Text)
		end)
		local icons = template("Icons")
		local iconSource = icons and icons:FindFirstChild(icon)
		local container = button:FindFirstChild("Container")
		if iconSource and iconSource:IsA("ImageLabel") and container then
			for _, child in container:GetChildren() do
				if
					child:IsA("ImageLabel") and (child.Name == "Icon" or child.Name == "ImageBg")
				then
					child.Image = iconSource.Image
				end
			end
		end
		Widgets.AnimatePress(button)
	else
		button = plainButton(name, UDim2.new(), UDim2.new(), color)
	end
	button.Name = name
	button.LayoutOrder = order
	button.Text = text
	button.Activated:Connect(function()
		Widgets.PlaySound("Click")
	end)
	button.Parent = column
	return button
end

return Widgets
