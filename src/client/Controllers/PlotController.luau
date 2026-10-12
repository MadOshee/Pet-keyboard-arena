--!strict
-- Client side of plots (docs/design.md 4.3 "Участок"): labels above the
-- platforms of your own plot (price, timer, income) and the MY PLOT button.
-- Everything here is display; the platform window is PlatformController.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local PetStyle = require(ReplicatedStorage.Shared.Config.PetStyle)
local Strings = require(ReplicatedStorage.Shared.Config.Strings)
local Widgets = require(script.Parent.Parent.UI.Widgets)
local ClientNet = require(script.Parent.Parent.Util.ClientNet)

local player = Players.LocalPlayer

local UPDATE_SECONDS = 0.5
-- Phones and tablets: plot pets on every base without their particles.
local LOW_END = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local PlotController = {}

type Watched = {
	Platform: BasePart,
	Billboard: BillboardGui,
	Label: TextLabel,
	Plot: Model,
}

local watched: { [BasePart]: Watched } = {}

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

-- 1500000 -> "1,500,000"
local function formatNumber(value: number): string
	local text = tostring(math.floor(value))
	local result = string.reverse(text):gsub("(%d%d%d)", "%1,")
	return (string.reverse(result):gsub("^,", ""))
end

local function updateLabel(entry: Watched, now: number)
	local platform = entry.Platform
	local state = platform:GetAttribute("State")
	local label = entry.Label
	-- Labels show on your own plot only.
	entry.Billboard.Enabled = isMine(entry.Plot)
	local rarity = platform:GetAttribute("Rarity")
	label.TextColor3 = if type(rarity) == "string" and PetStyle.Rarity[rarity]
		then PetStyle.Rarity[rarity]
		else Color3.new(1, 1, 1)

	if state == "Incubating" then
		local hatchAt = platform:GetAttribute("HatchAt")
		local left = if type(hatchAt) == "number" then hatchAt - now else 0
		label.Text = formatDuration(left)
	elseif state == "Pet" then
		local income = platform:GetAttribute("Income")
		label.Text = string.format(
			Strings.PlatformIncome,
			formatNumber(if type(income) == "number" then income else 0)
		)
	elseif state == "Empty" then
		label.Text = Strings.PlatformEmpty
		label.TextColor3 = Color3.fromRGB(200, 200, 210)
	else
		local price = platform:GetAttribute("Price")
		if type(price) == "number" and price > 0 then
			label.Text = string.format(Strings.PlatformPrice, formatNumber(price))
			label.TextColor3 = Color3.fromRGB(255, 214, 64)
		else
			label.Text = Strings.PlatformLocked
			label.TextColor3 = Color3.fromRGB(160, 160, 170)
		end
	end
end

local function watchPlatform(platform: BasePart, plot: Model)
	if watched[platform] then
		return
	end
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "PlatformLabel"
	billboard.Size = UDim2.fromScale(5, 1.2)
	billboard.StudsOffset = Vector3.new(0, 4.5, 0)
	billboard.MaxDistance = 60
	billboard.Adornee = platform
	local label = Widgets.Label("Text", billboard, UDim2.fromScale(1, 1), UDim2.new())
	billboard.Parent = player:WaitForChild("PlayerGui")

	local entry: Watched =
		{ Platform = platform, Billboard = billboard, Label = label, Plot = plot }
	watched[platform] = entry
	updateLabel(entry, workspace:GetServerTimeNow())
end

local function watchPlot(plot: Instance)
	if not plot:IsA("Model") then
		return
	end
	if LOW_END then
		local function quiet(descendant: Instance)
			if descendant:IsA("ParticleEmitter") then
				descendant.Enabled = false
			end
		end
		plot.DescendantAdded:Connect(quiet)
		for _, descendant in plot:GetDescendants() do
			quiet(descendant)
		end
	end
	local function scan(child: Instance)
		if child:IsA("BasePart") and child:GetAttribute("Index") ~= nil then
			watchPlatform(child, plot :: Model)
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
	end)
end

return PlotController
