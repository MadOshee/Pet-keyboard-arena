--!strict
-- Player plots (docs/design.md 4.3 "Участок", D3): each player gets a free
-- base around the hub plaza. The bases and buildings are part of the map
-- (World.Islands, built by tools/build-world); the plot contents are built
-- in code under Workspace.Plots: one invisible part per platform of the
-- building (10 on the ground floor, 10 on the second), with the egg or pet
-- that stands there.
--
-- The plot only mirrors the profile: platform parts carry State ("Locked",
-- "Empty", "Incubating", "Pet"), HatchAt, Rarity, Kind, Income and Price
-- attributes for PlotController, and an ObjectValue "Button" pointing at the
-- green pad in front. Stepping on it opens the platform window on the client
-- (PlatformController), which asks PlatformService to change the profile.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EggConfig = require(ReplicatedStorage.Shared.Config.EggConfig)
local PetConfig = require(ReplicatedStorage.Shared.Config.PetConfig)
local PetStyle = require(ReplicatedStorage.Shared.Config.PetStyle)
local Strings = require(ReplicatedStorage.Shared.Config.Strings)
local PetIncome = require(ReplicatedStorage.Shared.Logic.PetIncome)
local Types = require(ReplicatedStorage.Shared.Types)
local ModelFront = require(ReplicatedStorage.Shared.Util.ModelFront)
local MatchMode = require(script.Parent.Parent.Match.MatchMode)
local EggService = require(script.Parent.EggService)
local MovementGuard = require(script.Parent.MovementGuard)
local NetService = require(script.Parent.NetService)
local PlayerDataService = require(script.Parent.PlayerDataService)

local PLOT_COUNT = 12
local PLOT_SIZE = 22
local PET_HEIGHT = 3
local EGG_HEIGHT = 3
local BASE_COLOR = Color3.fromRGB(126, 196, 120)
local BUTTON_COLOR = Color3.fromRGB(42, 255, 38)

type Plot = {
	Index: number,
	Model: Model,
	Base: BasePart,
	SignLabel: TextLabel,
	Platforms: { BasePart },
	Owner: Player?,
}

-- Where a platform goes and the green pad that opens it.
type PlatformSpot = {
	CFrame: CFrame, -- on top of the pad, -Z towards the button
	Button: BasePart?,
}

-- Where a plot's pieces go. Without platforms from the map they are built
-- in a grid on a bare plot.
type Layout = {
	Center: CFrame,
	Platforms: { PlatformSpot }?,
}

local PlotService = {}

local plots: { Plot } = {}
local onIslands = false -- plots sit in the buildings of the map
local signHeight = 9 -- plot sign above the plot floor
local plotOf: { [Player]: Plot } = {}

local function anchoredPart(
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	parent: Instance
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- Platforms of a base (World.Islands.*.Platforms) in Index order, each with
-- its green pad (a "PlatformButton" with the same Platform number).
local function islandPlatforms(island: Instance): { PlatformSpot }?
	local folder = island:FindFirstChild("Platforms")
	if folder == nil then
		return nil
	end
	local buttons: { [number]: BasePart } = {}
	for _, descendant in island:GetDescendants() do
		local number = descendant:GetAttribute("Platform")
		if descendant:IsA("BasePart") and type(number) == "number" then
			buttons[number] = descendant
		end
	end
	local parts: { BasePart } = {}
	for _, child in (folder :: Instance):GetChildren() do
		if child:IsA("BasePart") and type(child:GetAttribute("Index")) == "number" then
			table.insert(parts, child)
		end
	end
	if #parts == 0 then
		return nil
	end
	table.sort(parts, function(a, b)
		return (a:GetAttribute("Index") :: number) < (b:GetAttribute("Index") :: number)
	end)
	local result: { PlatformSpot } = {}
	for _, part in parts do
		table.insert(
			result,
			{ CFrame = part.CFrame, Button = buttons[part:GetAttribute("Index") :: number] }
		)
	end
	return result
end

-- Plot layouts from the map: the building floor of every base
-- (World.Islands.*.PlotAnchor) with its platforms, in PlotIndex order.
local function islandLayouts(): { Layout }?
	local world = workspace:FindFirstChild("World")
	local islands = world and world:FindFirstChild("Islands")
	if islands == nil then
		return nil
	end
	local anchors: { BasePart } = {}
	for _, island in islands:GetChildren() do
		local anchor = island:FindFirstChild("PlotAnchor")
		if anchor and anchor:IsA("BasePart") and anchor:GetAttribute("PlotIndex") then
			table.insert(anchors, anchor)
		end
	end
	if #anchors == 0 then
		return nil
	end
	table.sort(anchors, function(a, b)
		return (a:GetAttribute("PlotIndex") :: number) < (b:GetAttribute("PlotIndex") :: number)
	end)
	local result: { Layout } = {}
	for _, anchor in anchors do
		table.insert(result, {
			Center = anchor.CFrame,
			Platforms = islandPlatforms(anchor.Parent :: Instance),
		})
	end
	local height = anchors[1]:GetAttribute("SignHeight")
	signHeight = if type(height) == "number" then height else 22
	return result
end

-- Fallback without the map: six plots on each side of the arena floor.
local function plotLayouts(): { Layout }
	local fromIslands = islandLayouts()
	if fromIslands then
		onIslands = true
		return fromIslands
	end
	local arena = workspace:FindFirstChild("Arena")
	local floor = arena and arena:FindFirstChild("Floor")
	local minX, maxX, minZ, maxZ, topY = -80, 80, -50, 95, 0
	if floor and floor:IsA("BasePart") then
		local half = floor.Size / 2
		minX, maxX = floor.Position.X - half.X, floor.Position.X + half.X
		minZ, maxZ = floor.Position.Z - half.Z, floor.Position.Z + half.Z
		topY = floor.Position.Y + half.Y
	end
	local perSide = PLOT_COUNT // 2
	local step = (maxZ - minZ) / perSide
	local result = {}
	for side = 0, 1 do
		local x = if side == 0 then minX - PLOT_SIZE / 2 else maxX + PLOT_SIZE / 2
		for row = 1, perSide do
			local position = Vector3.new(x, topY, minZ + step * (row - 0.5))
			local lookAt = Vector3.new(0, topY, position.Z)
			table.insert(result, { Center = CFrame.lookAt(position, lookAt) })
		end
	end
	return result
end

local function buildPlot(index: number, layout: Layout, folder: Folder): Plot
	local cframe = layout.Center
	local model = Instance.new("Model")
	model.Name = `Plot{index}`
	model:SetAttribute("PlotIndex", index)
	model:SetAttribute("OwnerUserId", 0)

	local base = anchoredPart(
		"Base",
		Vector3.new(PLOT_SIZE, 1, PLOT_SIZE),
		cframe * CFrame.new(0, -0.5, 0),
		BASE_COLOR,
		model
	)
	model.PrimaryPart = base
	if onIslands then
		-- The building is the visible floor; the base only marks the spot.
		base.Transparency = 1
		base.CanCollide = false
		base.CanQuery = false
		base.CanTouch = false
	end

	local sign = Instance.new("BillboardGui")
	sign.Name = "Sign"
	sign.Size = UDim2.fromScale(10, 2)
	sign.StudsOffset = Vector3.new(0, signHeight, 0) -- above the building roof
	sign.MaxDistance = 150
	local signLabel = Instance.new("TextLabel")
	signLabel.Size = UDim2.fromScale(1, 1)
	signLabel.BackgroundTransparency = 1
	signLabel.TextScaled = true
	signLabel.Font = Enum.Font.FredokaOne
	signLabel.TextColor3 = Color3.new(1, 1, 1)
	signLabel.TextStrokeTransparency = 0.3
	signLabel.Text = Strings.PlotFree
	signLabel.Parent = sign
	sign.Parent = base

	-- Platforms: invisible parts on the building's pads, or a 5 x 4 grid of
	-- visible pads on a bare plot, where the pad is its own button.
	local platforms: { BasePart } = {}
	local spots = layout.Platforms
	for slot = 1, EggConfig.MaxIncubators do
		local platform: Part
		local button: BasePart
		if spots then
			local spot = spots[slot]
			if spot == nil then
				break
			end
			platform = anchoredPart(
				`Platform{slot}`,
				Vector3.new(4, 0.2, 4),
				spot.CFrame * CFrame.new(0, -0.1, 0),
				BASE_COLOR,
				model
			)
			platform.Transparency = 1
			platform.CanCollide = false
			platform.CanQuery = false
			platform.CanTouch = false
			button = spot.Button or platform
		else
			local column = (slot - 1) % 5 - 2
			local row = (slot - 1) // 5
			platform = anchoredPart(
				`Platform{slot}`,
				Vector3.new(3.6, 0.4, 3.6),
				cframe * CFrame.new(column * 4.2, 0.2, -6 + row * 4.2),
				BUTTON_COLOR,
				model
			)
			button = platform
		end
		platform:SetAttribute("Index", slot)
		platform:SetAttribute("State", "Locked")
		local link = Instance.new("ObjectValue")
		link.Name = "Button"
		link.Value = button
		link.Parent = platform
		table.insert(platforms, platform)
	end

	model.Parent = folder
	return {
		Index = index,
		Model = model,
		Base = base,
		SignLabel = signLabel,
		Platforms = platforms,
		Owner = nil,
	}
end

-- Display copies never collide, block clicks or run scripts.
local function prepareModel(model: Model, height: number)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
		elseif descendant:IsA("Script") or descendant:IsA("LocalScript") then
			descendant:Destroy()
		end
	end
	local size = model:GetExtentsSize()
	if size.Y > 0 then
		model:ScaleTo(model:GetScale() * height / size.Y)
	end
end

-- Stands `model` on the platform, centred on its geometry (pack pivots are
-- often far from the model itself) and facing the platform's button.
local function standOn(model: Model, platform: BasePart, height: number, turn: CFrame)
	local surface = platform.Position.Y + platform.Size.Y / 2
	local rotation = platform.CFrame.Rotation * turn
	model:PivotTo(CFrame.new(model:GetPivot().Position) * rotation)
	local center = model:GetBoundingBox()
	local target = Vector3.new(platform.Position.X, surface + height / 2, platform.Position.Z)
	model:PivotTo(model:GetPivot() + (target - center.Position))
end

local function findTemplate(folderName: string, name: string): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild(folderName)
	local template = folder and folder:FindFirstChild(name)
	return if template and template:IsA("Model") then template else nil
end

local function ball(color: Color3): Model
	local model = Instance.new("Model")
	local part = Instance.new("Part")
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(2.5, 2.5, 2.5)
	part.Color = color
	part.Parent = model
	return model
end

-- Shows what stands on a platform: "Egg:<theme>", "Pet:<pet id>" or nothing.
-- The model is rebuilt only when that key changes.
local function setShown(platform: BasePart, key: string?, build: (() -> (Model, number, boolean))?)
	local current = platform:FindFirstChild("Shown")
	if current and current:GetAttribute("Key") == key then
		return
	end
	if current then
		current:Destroy()
	end
	if key == nil or build == nil then
		return
	end
	local model, height, turnToFront = (build :: () -> (Model, number, boolean))()
	prepareModel(model, height)
	local turn = if turnToFront then ModelFront.Correction(model) else CFrame.identity
	standOn(model, platform, height, turn)
	model.Name = "Shown"
	model:SetAttribute("Key", key)
	model.Parent = platform
end

local function refreshPlatforms(plot: Plot, data: Types.Profile?)
	local now = os.time()
	local owned = if data then #data.Incubators else 0
	local nextPrice = if data then EggService:NextIncubatorPrice(data :: Types.Profile) else nil
	for slot, platform in plot.Platforms do
		local state = "Locked"
		local hatchAt = 0
		local rarity = ""
		local kind = ""
		local income = 0
		local key: string? = nil
		local build: (() -> (Model, number, boolean))? = nil
		if data and slot <= owned then
			local entry = data.Incubators[slot]
			local egg = entry.Egg
			local pet = if entry.PetId then data.Pets[entry.PetId :: string] else nil
			if pet then
				local placed = pet :: Types.PetInstance
				state = "Pet"
				rarity = placed.Rarity
				kind = placed.Kind
				income = PetIncome.Rate(placed.Kind, PetConfig :: any)
				key = "Pet:" .. (entry.PetId :: string)
				build = function()
					local config = PetConfig.Pets[placed.Kind]
					local template = config and findTemplate("Pets", config.Model)
					local model = if template
						then template:Clone()
						else ball(PetStyle.Rarity[placed.Rarity] or Color3.new(1, 1, 1))
					return model, PET_HEIGHT, true
				end
			elseif egg then
				local placed = egg :: Types.EggInstance
				state = "Incubating"
				rarity = placed.Rarity
				kind = placed.Theme
				hatchAt = entry.HatchAt or now
				key = "Egg:" .. placed.Theme
				build = function()
					local template = findTemplate("Eggs", EggConfig.ModelName(placed.Theme))
					local model = if template
						then template:Clone()
						else ball(PetStyle.Theme[placed.Theme] or Color3.new(1, 1, 1))
					return model, EGG_HEIGHT, false
				end
			else
				state = "Empty"
			end
		end

		platform:SetAttribute("State", state)
		platform:SetAttribute("HatchAt", hatchAt)
		platform:SetAttribute("Rarity", rarity)
		platform:SetAttribute("Kind", kind)
		platform:SetAttribute("Income", income)
		platform:SetAttribute(
			"Price",
			if state == "Locked" and slot == owned + 1 and nextPrice then nextPrice else 0
		)
		setShown(platform, key, build)
	end
end

local function refresh(plot: Plot)
	local owner = plot.Owner
	local data = if owner then PlayerDataService:Get(owner :: Player) else nil
	-- Pets earn nothing while the egg pick screen is open (PlatformService);
	-- PlotPetController shows no money popups then.
	plot.Model:SetAttribute("IncomePaused", data ~= nil and data.PendingOffer ~= nil)
	refreshPlatforms(plot, data)
end

local function assign(player: Player)
	-- Arena servers hold only the match; plots live on the hub.
	if plotOf[player] or MatchMode.IsArena() then
		return
	end
	for _, plot in plots do
		if plot.Owner == nil then
			plot.Owner = player
			plotOf[player] = plot
			plot.Model:SetAttribute("OwnerUserId", player.UserId)
			plot.SignLabel.Text = string.format(Strings.PlotSign, player.DisplayName)
			player:SetAttribute("Plot", plot.Index)
			refresh(plot)
			return
		end
	end
end

local function release(player: Player)
	local plot = plotOf[player]
	if plot == nil then
		return
	end
	plotOf[player] = nil
	plot.Owner = nil
	plot.Model:SetAttribute("OwnerUserId", 0)
	plot.SignLabel.Text = Strings.PlotFree
	refresh(plot)
end

function PlotService:Init()
	local folder = Instance.new("Folder")
	folder.Name = "Plots"
	folder.Parent = workspace
	for index, layout in plotLayouts() do
		table.insert(plots, buildPlot(index, layout, folder))
	end
end

function PlotService:Start()
	PlayerDataService.ProfileLoaded:Connect(assign)
	for _, player in Players:GetPlayers() do
		if PlayerDataService:IsLoaded(player) then
			assign(player)
		end
	end
	Players.PlayerRemoving:Connect(release)

	PlayerDataService.Changed:Connect(function(player)
		local plot = plotOf[player]
		if plot then
			refresh(plot)
		end
	end)

	NetService:On("GoToPlot", { PerSecond = 1, Burst = 2 }, function(player)
		PlotService:Teleport(player)
	end)
end

-- Puts the player on their plot, except during a round they play in.
function PlotService:Teleport(player: Player)
	local plot = plotOf[player]
	local character = player.Character
	if plot == nil or character == nil or player:GetAttribute("Team") ~= nil then
		return
	end
	(character :: Model):PivotTo(plot.Base.CFrame * CFrame.new(0, 4, 0))
	MovementGuard:Reset(player)
end

return PlotService
