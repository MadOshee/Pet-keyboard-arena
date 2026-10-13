--!strict
-- First-time tips (docs/design.md 12, stage 7). Five steps, each advanced by
-- something the player actually did: got ready, played a round, picked an
-- egg, put it on a platform and it hatched; the last tip about pet income
-- closes by itself. Steps only move forward. SKIP or the last
-- step tells the server, which stores Tutorial.Done so the tips never return.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Strings = require(ReplicatedStorage.Shared.Config.Strings)
local Types = require(ReplicatedStorage.Shared.Types)
local Widgets = require(script.Parent.Parent.UI.Widgets)
local ClientNet = require(script.Parent.Parent.Util.ClientNet)
local DataController = require(script.Parent.DataController)

local player = Players.LocalPlayer

local LAST_TIP_SECONDS = 10
-- The "pick an egg" tip sits at the bottom, under the egg offer's buttons
-- and odds; the others at the top.
local PICK_EGG_STEP = 3
local TOP = {
	Size = UDim2.fromScale(0.5, 0.12),
	Position = UDim2.fromScale(0.5, 0.13),
	Anchor = Vector2.new(0.5, 0),
}
local BOTTOM = {
	Size = UDim2.fromScale(0.36, 0.1),
	Position = UDim2.fromScale(0.5, 0.99),
	Anchor = Vector2.new(0.5, 1),
}

local TutorialController = {}

local panel: Frame
local stepLabel: TextLabel
local textLabel: TextLabel

local step = 0 -- 0 = not started (waiting for data), > #steps = finished
local finished = false

local function stepCount(): number
	return #Strings.TutorialSteps
end

local function finish()
	if finished then
		return
	end
	finished = true
	panel.Visible = false
	ClientNet.Fire("TutorialDone")
end

local function show()
	if finished then
		return
	end
	if step > stepCount() then
		finish()
		return
	end
	stepLabel.Text = `{step}/{stepCount()}`
	textLabel.Text = Strings.TutorialSteps[step]
	local place = if step == PICK_EGG_STEP then BOTTOM else TOP
	panel.Size = place.Size
	panel.Position = place.Position
	panel.AnchorPoint = place.Anchor
	panel.Visible = true
end

-- Moves to `target` only if it is ahead of the current step.
local function advanceTo(target: number)
	if finished or step == 0 or target <= step then
		return
	end
	step = target
	show()
end

local function onProfile(profile: Types.Profile)
	if finished then
		return
	end
	if step == 0 then
		if profile.Tutorial.Done then
			finished = true
			return
		end
		step = 1
		show()
	end
	if profile.PendingOffer ~= nil then
		advanceTo(3)
	end
end

function TutorialController:Init()
	-- Above the egg offer (5), so its dimming does not cover the tip.
	local gui = Widgets.ScreenGui("Tutorial", 6)
	panel = Widgets.Panel("Tip", gui, TOP.Size, TOP.Position)
	panel.AnchorPoint = TOP.Anchor
	panel.Visible = false
	Widgets.AspectRatio(panel, 6)
	Widgets.Stroke(panel, Color3.fromRGB(255, 220, 90), 2)

	stepLabel = Widgets.Label("Step", panel, UDim2.fromScale(0.1, 0.8), UDim2.fromScale(0.02, 0.1))
	stepLabel.TextColor3 = Color3.fromRGB(255, 220, 90)
	textLabel = Widgets.Label("Text", panel, UDim2.fromScale(0.68, 0.8), UDim2.fromScale(0.13, 0.1))
	textLabel.TextWrapped = true
	local skip = Widgets.Button(
		"Skip",
		panel,
		UDim2.fromScale(0.15, 0.6),
		UDim2.fromScale(0.83, 0.2),
		Color3.fromRGB(120, 120, 140)
	)
	skip.Text = Strings.TutorialSkip
	skip.Activated:Connect(finish)

	gui.Parent = player:WaitForChild("PlayerGui")
end

function TutorialController:Start()
	player:GetAttributeChangedSignal("Ready"):Connect(function()
		if player:GetAttribute("Ready") == true then
			advanceTo(2)
		end
	end)
	player:GetAttributeChangedSignal("Team"):Connect(function()
		if player:GetAttribute("Team") ~= nil then
			advanceTo(2)
		end
	end)
	ClientNet.On("EggPicked", function()
		advanceTo(4)
	end)
	ClientNet.On("PetHatched", function()
		advanceTo(5)
		task.delay(LAST_TIP_SECONDS, function()
			advanceTo(6)
		end)
	end)
	DataController.Changed:Connect(onProfile)
	local profile = DataController:Get()
	if profile then
		onProfile(profile)
	end
	-- Joining already ready (a rejoin) skips the first tip.
	if player:GetAttribute("Ready") == true then
		advanceTo(2)
	end
end

return TutorialController
