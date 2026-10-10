--!strict
-- Small builders for code-made UI. Sizes use Scale so the same layout fits
-- phones, tablets and PC. Stage 7 restyles these with art from the packs.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Widgets = {}

local FONT = Enum.Font.FredokaOne

-- Plays a UI sound from Assets.Sounds (Click, Success, Error, ...) if the
-- asset pack is present.
function Widgets.PlaySound(name: string)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local sounds = assets and assets:FindFirstChild("Sounds")
	local sound = sounds and sounds:FindFirstChild(name)
	if sound and sound:IsA("Sound") then
		SoundService:PlayLocalSound(sound)
	end
end

function Widgets.Corner(parent: GuiObject, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(radius, 0)
	corner.Parent = parent
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

function Widgets.Label(name: string, parent: Instance, size: UDim2, position: UDim2): TextLabel
	local text = Instance.new("TextLabel")
	text.Name = name
	text.Size = size
	text.Position = position
	text.BackgroundTransparency = 1
	text.TextScaled = true
	text.Font = FONT
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextStrokeTransparency = 0.4
	text.Text = ""
	text.Parent = parent
	return text
end

function Widgets.Button(
	name: string,
	parent: Instance,
	size: UDim2,
	position: UDim2,
	color: Color3
): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = size
	button.Position = position
	button.BackgroundColor3 = color
	button.TextScaled = true
	button.Font = FONT
	button.TextColor3 = Color3.new(1, 1, 1)
	button.TextStrokeTransparency = 0.5
	button.AutoButtonColor = true
	button.Text = ""
	button.Parent = parent
	Widgets.Corner(button, 0.25)
	button.Activated:Connect(function()
		Widgets.PlaySound("Click")
	end)
	return button
end

function Widgets.Panel(name: string, parent: Instance, size: UDim2, position: UDim2): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = size
	frame.Position = position
	frame.BackgroundColor3 = Color3.fromRGB(34, 36, 52)
	frame.BackgroundTransparency = 0.05
	frame.Parent = parent
	Widgets.Corner(frame, 0.06)
	return frame
end

function Widgets.ScreenGui(name: string, displayOrder: number): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = displayOrder
	return gui
end

return Widgets
