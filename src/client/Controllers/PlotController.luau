--!strict
-- Client side of plots (docs/design.md 4.3 "Участок"): timers above
-- incubators, prompts shown only on your own plot, the speed-up price kept
-- current, and the MY PLOT button. Everything here is display; the server
-- re-checks every prompt.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EggConfig = require(ReplicatedStorage.Shared.Config.EggConfig)
local PetStyle = require(ReplicatedStorage.Shared.Config.PetStyle)
local Strings = require(ReplicatedStorage.Shared.Config.Strings)
local Incubation = require(ReplicatedStorage.Shared.Logic.Incubation)
local Types = require(ReplicatedStorage.Shared.Types)
local Widgets = require(script.Parent.Parent.UI.Widgets)
local ClientNet = require(script.Parent.Parent.Util.ClientNet)
local DataController = require(script.Parent.DataController)

local player = Players.LocalPlayer

local UPDATE_SECONDS = 0.5

local PlotController = {}

type Watched = {
	Incubator: BasePart,
	Billboard: BillboardGui,
	Label: TextLabel,
	Plot: Model,
}

local watched: { [BasePart]: Watched } = {}
local plotButton: TextButton

local function isMine(plot: Model): boolean
	return plot:GetAttribute("OwnerUserId") == player.UserId
end

local function formatDuration(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	if seconds >= 3600 then
		return string.format("%d:%02d:%02d", seconds // 3600, seconds // 60 % 60, seconds % 60)
	end
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

-- A prompt is usable only on your own plot and when the server marks it active.
local function updatePrompts(entry: Watched)
	local mine = isMine(entry.Plot)
	for _, child in entry.Incubator:GetChildren() do
		if child:IsA("ProximityPrompt") then
			child.Enabled = mine and child:GetAttribute("Active") == true
		end
	end
end

local function updateLabel(entry: Watched, now: number)
	local incubator = entry.Incubator
	local state = incubator:GetAttribute("State")
	local label = entry.Label
	-- Timers show on your own plot only.
	entry.Billboard.Enabled = isMine(entry.Plot)
	local rarity = incubator:GetAttribute("Rarity")
	label.TextColor3 = if type(rarity) == "string" and PetStyle.Rarity[rarity]
		then PetStyle.Rarity[rarity]
		else Color3.new(1, 1, 1)

	if state == "Incubating" then
		local hatchAt = incubator:GetAttribute("HatchAt")
		local left = if type(hatchAt) == "number" then hatchAt - now else 0
		label.Text = formatDuration(left)
		local speedUp = incubator:FindFirstChild("SpeedUp")
		if speedUp and speedUp:IsA("ProximityPrompt") and type(hatchAt) == "number" then
			speedUp.ActionText = string.format(
				Strings.PromptSpeedUp,
				Incubation.SpeedUpCost(hatchAt, now, EggConfig)
			)
		end
	elseif state == "Ready" then
		label.Text = Strings.IncubatorReady
	elseif state == "Empty" then
		label.Text = Strings.IncubatorEmpty
		label.TextColor3 = Color3.fromRGB(200, 200, 210)
	else
		label.Text = Strings.IncubatorLocked
		label.TextColor3 = Color3.fromRGB(160, 160, 170)
	end
end

-- The MY PLOT button shows "!" while any of your eggs is ready to collect.
local function updateReadyBadge(now: number)
	local profile = DataController:Get()
	local ready = false
	if profile then
		for _, slot: Types.Incubator in (profile :: Types.Profile).Incubators do
			if slot.Egg ~= nil and slot.HatchAt ~= nil and (slot.HatchAt :: number) <= now then
				ready = true
				break
			end
		end
	end
	plotButton.Text = if ready then Strings.PlotReady else Strings.PlotButton
end

local function watchIncubator(incubator: BasePart, plot: Model)
	if watched[incubator] then
		return
	end
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Timer"
	billboard.Size = UDim2.fromScale(5, 1.2)
	billboard.StudsOffset = Vector3.new(0, 5.5, 0)
	billboard.MaxDistance = 60
	billboard.Adornee = incubator
	local label = Widgets.Label("Text", billboard, UDim2.fromScale(1, 1), UDim2.new())
	billboard.Parent = player:WaitForChild("PlayerGui")

	local entry: Watched =
		{ Incubator = incubator, Billboard = billboard, Label = label, Plot = plot }
	watched[incubator] = entry
	for _, child in incubator:GetChildren() do
		if child:IsA("ProximityPrompt") then
			child:GetAttributeChangedSignal("Active"):Connect(function()
				updatePrompts(entry)
			end)
		end
	end
	plot:GetAttributeChangedSignal("OwnerUserId"):Connect(function()
		updatePrompts(entry)
	end)
	updatePrompts(entry)
	updateLabel(entry, workspace:GetServerTimeNow())
end

local function watchPlot(plot: Instance)
	if not plot:IsA("Model") then
		return
	end
	local function scan(child: Instance)
		if child:IsA("BasePart") and child:GetAttribute("Index") ~= nil then
			-- Prompts are created before the incubator replicates, but wait briefly to be safe.
			child:WaitForChild("Main", 5)
			child:WaitForChild("SpeedUp", 5)
			watchIncubator(child, plot :: Model)
		end
	end
	plot.ChildAdded:Connect(scan)
	for _, child in plot:GetChildren() do
		task.spawn(scan, child)
	end
end

function PlotController:Init()
	local gui = Widgets.ScreenGui("PlotButton", 2)
	local button = Widgets.Button(
		"MyPlot",
		gui,
		UDim2.fromScale(0.1, 0.08),
		UDim2.fromScale(0.015, 0.55),
		Color3.fromRGB(90, 170, 90)
	)
	button.Text = Strings.PlotButton
	plotButton = button
	Widgets.AspectRatio(button, 2.2)
	button.Activated:Connect(function()
		ClientNet.Fire("GoToPlot")
	end)
	local function updateVisible()
		button.Visible = player:GetAttribute("Team") == nil
	end
	player:GetAttributeChangedSignal("Team"):Connect(updateVisible)
	updateVisible()
	gui.Parent = player:WaitForChild("PlayerGui")
end

function PlotController:Start()
	task.spawn(function()
		local folder = workspace:WaitForChild("Plots")
		folder.ChildAdded:Connect(watchPlot)
		for _, plot in folder:GetChildren() do
			watchPlot(plot)
		end
	end)

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < UPDATE_SECONDS then
			return
		end
		elapsed = 0
		local now = workspace:GetServerTimeNow()
		for _, entry in watched do
			updateLabel(entry, now)
		end
		updateReadyBadge(now)
	end)
end

return PlotController
