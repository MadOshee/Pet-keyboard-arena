--!strict
-- Client side of plots (docs/design.md 4.3 "Участок"): labels above the
-- platforms (pet name, rarity and income, egg name and timer on every base;
-- price and "Empty" on your own) and the MY PLOT button.
-- Everything here is display; the platform window is PlatformController.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local PetConfig = require(ReplicatedStorage.Shared.Config.PetConfig)
local PetStyle = require(ReplicatedStorage.Shared.Config.PetStyle)
local Strings = require(ReplicatedStorage.Shared.Config.Strings)
local Money = require(ReplicatedStorage.Shared.Util.Money)
local Widgets = require(script.Parent.Parent.UI.Widgets)
local ClientNet = require(script.Parent.Parent.Util.ClientNet)

local player = Players.LocalPlayer

local UPDATE_SECONDS = 0.5
local WHITE = Color3.new(1, 1, 1)
local TIMER_COLOR = Color3.fromRGB(190, 225, 255)
-- Phones and tablets: plot pets on every base without their particles.
local LOW_END = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local PlotController = {}

type Watched = {
	Platform: BasePart,
	Billboard: BillboardGui,
	Title: TextLabel,
	Sub: TextLabel,
	Money: TextLabel,
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

local function stringAttribute(platform: BasePart, name: string): string?
	local value = platform:GetAttribute(name)
	return if type(value) == "string" and value ~= "" then value else nil
end

-- One to three lines over the platform (Ivan): a pet's name, rarity and
-- money per second; an egg's name and hatch timer. Pets and eggs show on
-- every base, the price and "Empty" only on your own.
local function updateLabel(entry: Watched, now: number)
	local platform = entry.Platform
	local state = platform:GetAttribute("State")
	local kind = stringAttribute(platform, "Kind")
	local rarity = stringAttribute(platform, "Rarity")
	local title, sub, money = entry.Title, entry.Sub, entry.Money
	local mine = isMine(entry.Plot)
	title.Visible, sub.Visible, money.Visible = true, false, false

	if state == "Pet" and kind then
		local pet = PetConfig.Pets[kind :: string]
		title.Text = if pet then pet.Name else kind :: string
		title.TextColor3 = WHITE
		sub.Visible = true
		sub.Text = if rarity then (Strings.Rarity :: any)[rarity] or rarity else ""
		sub.TextColor3 = if rarity then PetStyle.Rarity[rarity :: string] or WHITE else WHITE
		local income = platform:GetAttribute("Income")
		money.Visible = true
		Widgets.SetText(
			money,
			string.format(
				Strings.PlatformIncome,
				Money.Format(if type(income) == "number" then income else 0)
			)
		)
	elseif state == "Incubating" and kind then
		title.Text = string.format(Strings.EggTheme, kind :: string)
		title.TextColor3 = PetStyle.Theme[kind :: string] or WHITE
		local hatchAt = platform:GetAttribute("HatchAt")
		local left = if type(hatchAt) == "number" then hatchAt - now else 0
		sub.Visible = true
		sub.Text = if left > 0
			then string.format(Strings.PlatformHatchesIn, formatDuration(left))
			else Strings.PlatformHatching
		sub.TextColor3 = TIMER_COLOR
	elseif not mine then
		title.Visible = false
	elseif state == "Empty" then
		title.Text = Strings.PlatformEmpty
		title.TextColor3 = Color3.fromRGB(200, 200, 210)
	else
		local price = platform:GetAttribute("Price")
		if type(price) == "number" and price > 0 then
			title.Text = string.format(Strings.PlatformPrice, Money.Format(price))
			title.TextColor3 = Color3.fromRGB(255, 214, 64)
		else
			title.Text = Strings.PlatformLocked
			title.TextColor3 = Color3.fromRGB(160, 160, 170)
		end
	end
	entry.Billboard.Enabled = title.Visible
end

local function watchPlatform(platform: BasePart, plot: Model)
	if watched[platform] then
		return
	end
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "PlatformLabel"
	billboard.Size = UDim2.fromScale(11, 4.6)
	billboard.StudsOffset = Vector3.new(0, 6.5, 0)
	billboard.MaxDistance = 90
	billboard.LightInfluence = 0
	billboard.Adornee = platform
	local stack = Instance.new("Frame")
	stack.Name = "Lines"
	stack.BackgroundTransparency = 1
	stack.Size = UDim2.fromScale(1, 1)
	stack.Parent = billboard
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = stack
	local title = Widgets.Label("Title", stack, UDim2.fromScale(1, 0.4), UDim2.new())
	title.LayoutOrder = 1
	local sub = Widgets.Label("Sub", stack, UDim2.fromScale(1, 0.3), UDim2.new())
	sub.LayoutOrder = 2
	local money = Widgets.MoneyLabel("Money", stack, UDim2.fromScale(1, 0.3), UDim2.new())
	money.LayoutOrder = 3
	money.TextXAlignment = Enum.TextXAlignment.Center
	-- Kept on respawn: PlayerGui drops a gui with ResetOnSpawn when the
	-- character spawns, and in a live game this code can run before the
	-- first spawn (Ivan 2026-10-14: no pet names after publishing).
	billboard.ResetOnSpawn = false
	billboard.Parent = player:WaitForChild("PlayerGui")

	local entry: Watched = {
		Platform = platform,
		Billboard = billboard,
		Title = title,
		Sub = sub,
		Money = money,
		Plot = plot,
	}
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
	local button =
		Widgets.MenuButton("MyPlot", Strings.PlotButton, "Pass", Color3.fromRGB(255, 170, 0), 4)
	button.Activated:Connect(function()
		ClientNet.Fire("GoToPlot")
	end)
	local function updateVisible()
		button.Visible = player:GetAttribute("Team") == nil
	end
	player:GetAttributeChangedSignal("Team"):Connect(updateVisible)
	updateVisible()
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
