--!strict
-- Bat input (docs/design.md 4.3 "Бита"): left click or F on PC, the round
-- see-through Hit button (a picture of the bat and a small "Hit") on any
-- screen. Sends a bare BatSwing request; the server checks the phase, the
-- cooldown and picks the target. During the cooldown a dark shade drains
-- out of the button, so players see when they can swing again.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local BatConfig = require(ReplicatedStorage.Shared.Config.BatConfig)
local Strings = require(ReplicatedStorage.Shared.Config.Strings)
local Widgets = require(script.Parent.Parent.UI.Widgets)
local ClientNet = require(script.Parent.Parent.Util.ClientNet)

local player = Players.LocalPlayer

local FACE = Color3.fromRGB(20, 22, 30)
local FACE_TRANSPARENCY = 0.45
local RING = Color3.fromRGB(255, 255, 255)
local SHADE = Color3.fromRGB(0, 0, 0)
-- The bat lies diagonally across the button, barrel up and to the right.
local ICON_TILT = math.rad(50)

local BatController = {}

local button: TextButton
local shade: Frame
local readyAt = 0

local function canSwing(): boolean
	return player:GetAttribute("Team") ~= nil
		and ReplicatedStorage:GetAttribute("RoundPhase") == "Playing"
end

local function showCooldown()
	shade.Size = UDim2.fromScale(1, 1)
	shade.Visible = true
	local tween = TweenService:Create(
		shade,
		TweenInfo.new(BatConfig.Cooldown, Enum.EasingStyle.Linear),
		{ Size = UDim2.fromScale(1, 0) }
	)
	tween.Completed:Once(function()
		if os.clock() >= readyAt then
			shade.Visible = false
		end
	end)
	tween:Play()
end

local function swing()
	local now = os.clock()
	if not canSwing() or now < readyAt then
		return
	end
	readyAt = now + BatConfig.Cooldown
	ClientNet.Fire("BatSwing")
	showCooldown()
end

local function updateVisible()
	button.Visible = canSwing()
end

-- A 3D picture of the real bat model (Assets.Bat), or nothing without it.
local function batIcon(parent: GuiObject)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local template = assets and assets:FindFirstChild("Bat")
	if template == nil or not template:IsA("Model") then
		return
	end
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "Icon"
	viewport.BackgroundTransparency = 1
	viewport.AnchorPoint = Vector2.new(0.5, 0.5)
	viewport.Position = UDim2.fromScale(0.5, 0.44)
	viewport.Size = UDim2.fromScale(0.86, 0.86)
	viewport.Ambient = Color3.fromRGB(200, 200, 200)
	viewport.LightColor = Color3.fromRGB(255, 255, 255)
	viewport.LightDirection = Vector3.new(-0.4, -1, -0.6)
	viewport.Parent = parent

	local bat = (template :: Model):Clone()
	for _, descendant in bat:GetDescendants() do
		if descendant:IsA("ParticleEmitter") or descendant:IsA("Trail") then
			descendant:Destroy()
		end
	end
	-- Stand the bat on its long axis (X), tilt it, center it on the origin.
	local boxCFrame, size = bat:GetBoundingBox()
	local tilt = CFrame.Angles(0, 0, ICON_TILT)
	for _, part in bat:GetDescendants() do
		if part:IsA("BasePart") then
			part.CFrame = tilt * boxCFrame:ToObjectSpace(part.CFrame)
		end
	end
	bat.Parent = viewport

	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	local distance = (size.X * 0.5) / math.tan(math.rad(camera.FieldOfView / 2)) * 1.05
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 0, distance), Vector3.zero)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
end

function BatController:Init()
	local gui = Widgets.ScreenGui("Bat", 2)
	button = Instance.new("TextButton")
	button.Name = "Swing"
	button.Text = ""
	button.AutoButtonColor = false
	button.BackgroundColor3 = FACE
	button.BackgroundTransparency = FACE_TRANSPARENCY
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.Size = UDim2.fromScale(0.12, 0.12)
	button.Position = UDim2.fromScale(0.91, 0.68)
	button.Visible = false
	button.Parent = gui
	Widgets.AspectRatio(button, 1)
	Widgets.Corner(button, 0.5)
	local ring = Widgets.Stroke(button, RING, 3)
	ring.Transparency = 0.35

	-- Drains from the top during the cooldown; clipped to the circle by
	-- a CanvasGroup.
	local clip = Instance.new("CanvasGroup")
	clip.Name = "Cooldown"
	clip.BackgroundTransparency = 1
	clip.Size = UDim2.fromScale(1, 1)
	clip.GroupTransparency = 0.45
	clip.Parent = button
	Widgets.Corner(clip, 0.5)
	shade = Instance.new("Frame")
	shade.Name = "Shade"
	shade.BorderSizePixel = 0
	shade.BackgroundColor3 = SHADE
	shade.AnchorPoint = Vector2.new(0, 1)
	shade.Position = UDim2.fromScale(0, 1)
	shade.Size = UDim2.fromScale(1, 0)
	shade.Visible = false
	shade.Parent = clip

	batIcon(button)

	local caption =
		Widgets.Label("Hit", button, UDim2.fromScale(0.5, 0.2), UDim2.fromScale(0.25, 0.72))
	caption.Text = Strings.BatButton
	caption.ZIndex = 3

	Widgets.AnimatePress(button)
	gui.Parent = player:WaitForChild("PlayerGui")
end

function BatController:Start()
	button.Activated:Connect(swing)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if
			input.KeyCode == Enum.KeyCode.F
			or input.UserInputType == Enum.UserInputType.MouseButton1
		then
			swing()
		end
	end)
	player:GetAttributeChangedSignal("Team"):Connect(updateVisible)
	ReplicatedStorage:GetAttributeChangedSignal("RoundPhase"):Connect(updateVisible)
	updateVisible()
end

return BatController
