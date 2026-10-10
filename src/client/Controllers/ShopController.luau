--!strict
-- Coin shop (docs/design.md 4.5, stage 7): buy the next incubator and more
-- pet slots. Prices come from the same Incubation math the server uses; the
-- server re-checks coins and limits on every purchase. Robux items arrive in
-- stage 9, so the window only mentions them.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EggConfig = require(ReplicatedStorage.Shared.Config.EggConfig)
local PetConfig = require(ReplicatedStorage.Shared.Config.PetConfig)
local Strings = require(ReplicatedStorage.Shared.Config.Strings)
local Incubation = require(ReplicatedStorage.Shared.Logic.Incubation)
local Types = require(ReplicatedStorage.Shared.Types)
local Widgets = require(script.Parent.Parent.UI.Widgets)
local ClientNet = require(script.Parent.Parent.Util.ClientNet)
local DataController = require(script.Parent.DataController)

local player = Players.LocalPlayer

local ShopController = {}

type Row = {
	Label: TextLabel,
	Button: TextButton,
}

local window: Frame
local lastIncubators: number? = nil
local lastCapacity: number? = nil
local incubatorRow: Row
local slotsRow: Row

local function makeRow(name: string, parent: Instance, y: number, upgradeId: string): Row
	local row = Instance.new("Frame")
	row.Name = name
	row.Size = UDim2.fromScale(0.92, 0.18)
	row.Position = UDim2.fromScale(0.04, y)
	row.BackgroundColor3 = Color3.fromRGB(52, 56, 80)
	row.Parent = parent
	Widgets.Corner(row, 0.2)
	local label = Widgets.Label("Text", row, UDim2.fromScale(0.6, 0.8), UDim2.fromScale(0.03, 0.1))
	label.TextXAlignment = Enum.TextXAlignment.Left
	local button = Widgets.Button(
		"Buy",
		row,
		UDim2.fromScale(0.32, 0.7),
		UDim2.fromScale(0.65, 0.15),
		Color3.fromRGB(64, 170, 90)
	)
	button.Activated:Connect(function()
		ClientNet.Fire("BuyUpgrade", upgradeId)
	end)
	return { Label = label, Button = button }
end

local function setPrice(row: Row, price: number?, coins: number)
	if price then
		row.Button.Text = string.format(Strings.ShopBuy, price)
		row.Button.Active = true
		row.Button.AutoButtonColor = true
		row.Button.BackgroundColor3 = if coins >= price
			then Color3.fromRGB(64, 170, 90)
			else Color3.fromRGB(120, 120, 130)
	else
		row.Button.Text = Strings.ShopMaxed
		row.Button.Active = false
		row.Button.AutoButtonColor = false
		row.Button.BackgroundColor3 = Color3.fromRGB(90, 90, 100)
	end
end

local function refresh(profile: Types.Profile?)
	if profile == nil then
		return
	end
	local data = profile :: Types.Profile
	local owned = #data.Incubators
	-- A purchase went through: more incubators or pet slots than before.
	if
		(lastIncubators ~= nil and owned > (lastIncubators :: number))
		or (lastCapacity ~= nil and data.PetCapacity > (lastCapacity :: number))
	then
		Widgets.PlaySound("Purchase")
	end
	lastIncubators, lastCapacity = owned, data.PetCapacity
	local incubatorPrice = Incubation.NextIncubatorPrice(owned, EggConfig :: any)
	incubatorRow.Label.Text = if incubatorPrice
		then string.format(Strings.ShopIncubator, owned + 1, EggConfig.MaxIncubators)
		else Strings.ShopIncubatorMax
	setPrice(incubatorRow, incubatorPrice, data.Coins)

	slotsRow.Label.Text =
		string.format(Strings.ShopPetSlots, EggConfig.PetSlotsStep, data.PetCapacity)
	setPrice(
		slotsRow,
		Incubation.NextPetSlotsPrice(data.PetCapacity, PetConfig.StartCapacity, EggConfig :: any),
		data.Coins
	)
end

function ShopController:Init()
	local gui = Widgets.ScreenGui("Shop", 3)

	local toggle = Widgets.Button(
		"ShopButton",
		gui,
		UDim2.fromScale(0.1, 0.08),
		UDim2.fromScale(0.015, 0.65),
		Color3.fromRGB(230, 170, 50)
	)
	toggle.Text = Strings.ShopButton
	Widgets.AspectRatio(toggle, 2.2)

	window = Widgets.Panel("Window", gui, UDim2.fromScale(0.42, 0.5), UDim2.fromScale(0.5, 0.5))
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.Visible = false
	Widgets.AspectRatio(window, 1.4)

	local title =
		Widgets.Label("Title", window, UDim2.fromScale(0.7, 0.12), UDim2.fromScale(0.04, 0.04))
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = Strings.ShopTitle
	local close = Widgets.Button(
		"Close",
		window,
		UDim2.fromScale(0.09, 0.12),
		UDim2.fromScale(0.88, 0.04),
		Color3.fromRGB(200, 70, 70)
	)
	close.Text = "X"

	incubatorRow = makeRow("Incubator", window, 0.22, "Incubator")
	slotsRow = makeRow("PetSlots", window, 0.44, "PetSlots")

	local robux =
		Widgets.Label("Robux", window, UDim2.fromScale(0.92, 0.1), UDim2.fromScale(0.04, 0.72))
	robux.Text = Strings.ShopRobuxSoon
	robux.TextColor3 = Color3.fromRGB(180, 200, 255)

	toggle.Activated:Connect(function()
		window.Visible = not window.Visible
		if window.Visible then
			refresh(DataController:Get())
		end
	end)
	close.Activated:Connect(function()
		window.Visible = false
	end)
	-- The shop works only in the lobby, like the other plot buttons.
	local function updateVisible()
		local inLobby = player:GetAttribute("Team") == nil
		toggle.Visible = inLobby
		if not inLobby then
			window.Visible = false
		end
	end
	player:GetAttributeChangedSignal("Team"):Connect(updateVisible)
	updateVisible()

	gui.Parent = player:WaitForChild("PlayerGui")
end

function ShopController:Start()
	DataController.Changed:Connect(refresh)
	refresh(DataController:Get())
end

return ShopController
