--!strict
-- Bat input (docs/design.md 4.3 "Бита"): left click or F on PC, the BAT
-- button on touch screens. Sends a bare BatSwing request; the server checks
-- the phase, the cooldown and picks the target. The button greys out for
-- the cooldown so players see when they can swing again.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local BatConfig = require(ReplicatedStorage.Shared.Config.BatConfig)
local Strings = require(ReplicatedStorage.Shared.Config.Strings)
local Widgets = require(script.Parent.Parent.UI.Widgets)
local ClientNet = require(script.Parent.Parent.Util.ClientNet)

local player = Players.LocalPlayer

local READY_COLOR = Color3.fromRGB(220, 120, 50)
local COOLDOWN_COLOR = Color3.fromRGB(100, 90, 90)

local BatController = {}

local button: TextButton
local readyAt = 0

local function canSwing(): boolean
	return player:GetAttribute("Team") ~= nil
		and ReplicatedStorage:GetAttribute("RoundPhase") == "Playing"
end

local function swing()
	local now = os.clock()
	if not canSwing() or now < readyAt then
		return
	end
	readyAt = now + BatConfig.Cooldown
	ClientNet.Fire("BatSwing")
	button.BackgroundColor3 = COOLDOWN_COLOR
	task.delay(BatConfig.Cooldown, function()
		if os.clock() >= readyAt then
			button.BackgroundColor3 = READY_COLOR
		end
	end)
end

local function updateVisible()
	button.Visible = canSwing()
end

function BatController:Init()
	local gui = Widgets.ScreenGui("Bat", 2)
	button = Widgets.Button(
		"Swing",
		gui,
		UDim2.fromScale(0.13, 0.13),
		UDim2.fromScale(0.85, 0.62),
		READY_COLOR
	)
	button.Text = Strings.BatButton
	button.Visible = false
	Widgets.AspectRatio(button, 1)
	Widgets.Corner(button, 0.5)
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
