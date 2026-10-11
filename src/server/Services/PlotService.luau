--!strict
-- Player plots (docs/design.md 4.3 "Участок", D3): each player gets a free
-- island around the hub with incubators and a showcase of their best pets.
-- The islands and houses are part of the map (World.Islands, built by
-- tools/world); the plot contents are built in code under Workspace.Plots,
-- on each island's PlotAnchor.
--
-- Incubators are used through ProximityPrompts: "Main" (place, collect or
-- buy) and "SpeedUp". The server checks that the player owns the plot and
-- lets EggService decide; the plot only mirrors the profile. Prompts carry
-- an "Active" attribute, and PlotController shows them only to the owner.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EggConfig = require(ReplicatedStorage.Shared.Config.EggConfig)
local PetConfig = require(ReplicatedStorage.Shared.Config.PetConfig)
local PetStyle = require(ReplicatedStorage.Shared.Config.PetStyle)
local Strings = require(ReplicatedStorage.Shared.Config.Strings)
local Types = require(ReplicatedStorage.Shared.Types)
local EggService = require(script.Parent.EggService)
local MovementGuard = require(script.Parent.MovementGuard)
local NetService = require(script.Parent.NetService)
local PlayerDataService = require(script.Parent.PlayerDataService)

local PLOT_COUNT = 12
local PLOT_SIZE = 22
local SHOWCASE_SIZE = 6
local PET_HEIGHT = 3
local REFRESH_SECONDS = 1
local BASE_COLOR = Color3.fromRGB(126, 196, 120)
local INCUBATOR_COLOR = Color3.fromRGB(235, 235, 245)

type Plot = {
	Index: number,
	Model: Model,
	Base: BasePart,
	SignLabel: TextLabel,
	Incubators: { BasePart },
	Pedestals: { BasePart },
	Owner: Player?,
	ShowcaseKey: string,
}

local PlotService = {}

local plots: { Plot } = {}
local onIslands = false -- plots sit in the island houses of the map
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

local function makePrompt(name: string, parent: Instance, key: Enum.KeyCode): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = name
	prompt.ObjectText = Strings.PromptObject
	prompt.KeyboardKeyCode = key
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 10
	prompt:SetAttribute("Active", false)
	prompt.Parent = parent
	return prompt
end

-- Plot positions: the house floor of every island (World.Islands.*.PlotAnchor,
-- -Z towards the hub), in PlotIndex order.
local function islandCFrames(): { CFrame }?
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
	local result = {}
	for _, anchor in anchors do
		table.insert(result, anchor.CFrame)
	end
	return result
end

-- Fallback without the map: six plots on each side of the arena floor.
local function plotCFrames(): { CFrame }
	local fromIslands = islandCFrames()
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
			table.insert(result, CFrame.lookAt(position, lookAt))
		end
	end
	return result
end

local function buildPlot(index: number, cframe: CFrame, folder: Folder): Plot
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
		-- The island house is the visible floor; the base only marks the spot.
		base.Transparency = 1
		base.CanCollide = false
		base.CanQuery = false
		base.CanTouch = false
	end

	local sign = Instance.new("BillboardGui")
	sign.Name = "Sign"
	sign.Size = UDim2.fromScale(10, 2)
	sign.StudsOffset = Vector3.new(0, if onIslands then 22 else 9, 0) -- above the house roof
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

	-- Incubators in two rows of three on the far half; -Z of the plot faces the arena.
	local incubators: { BasePart } = {}
	for slot = 1, EggConfig.MaxIncubators do
		local column = (slot - 1) % 3 - 1
		local row = (slot - 1) // 3
		local offset = CFrame.new(column * 6, 1, 3 + row * 5.5)
		local incubator = anchoredPart(
			`Incubator{slot}`,
			Vector3.new(2, 4, 4),
			cframe * offset * CFrame.Angles(0, 0, math.rad(90)),
			INCUBATOR_COLOR,
			model
		)
		incubator.Shape = Enum.PartType.Cylinder
		incubator:SetAttribute("Index", slot)
		incubator:SetAttribute("State", "Locked")
		makePrompt("Main", incubator, Enum.KeyCode.E)
		makePrompt("SpeedUp", incubator, Enum.KeyCode.R)
		table.insert(incubators, incubator)
	end

	-- Showcase pedestals on the half next to the arena.
	local pedestals: { BasePart } = {}
	for slot = 1, SHOWCASE_SIZE do
		local column = (slot - 1) % 3 - 1
		local row = (slot - 1) // 3
		local offset = CFrame.new(column * 6, 0.5, -4 - row * 5)
		table.insert(
			pedestals,
			anchoredPart(
				`Pedestal{slot}`,
				Vector3.new(3, 1, 3),
				cframe * offset,
				Color3.fromRGB(90, 90, 110),
				model
			)
		)
	end

	model.Parent = folder
	return {
		Index = index,
		Model = model,
		Base = base,
		SignLabel = signLabel,
		Incubators = incubators,
		Pedestals = pedestals,
		Owner = nil,
		ShowcaseKey = "",
	}
end

local function setPrompt(incubator: BasePart, name: string, active: boolean, text: string?)
	local prompt = incubator:FindFirstChild(name)
	if prompt and prompt:IsA("ProximityPrompt") then
		if text and prompt.ActionText ~= text then
			prompt.ActionText = text
		end
		if prompt:GetAttribute("Active") ~= active then
			prompt:SetAttribute("Active", active)
		end
	end
end

local function setEggModel(incubator: BasePart, theme: string?)
	local current = incubator:FindFirstChild("Egg")
	if current and current:GetAttribute("Theme") == theme then
		return
	end
	if current then
		current:Destroy()
	end
	if theme == nil then
		return
	end
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local eggs = assets and assets:FindFirstChild("Eggs")
	local template = eggs and eggs:FindFirstChild(EggConfig.ModelName(theme :: string))
	local model: Model
	if template and template:IsA("Model") then
		model = template:Clone()
	else
		model = Instance.new("Model")
		local ball = Instance.new("Part")
		ball.Shape = Enum.PartType.Ball
		ball.Size = Vector3.new(2.5, 2.5, 2.5)
		ball.Color = PetStyle.Theme[theme :: string] or Color3.new(1, 1, 1)
		ball.Parent = model
	end
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
		end
	end
	model.Name = "Egg"
	model:SetAttribute("Theme", theme)
	local size = model:GetExtentsSize()
	if size.Y > 0 then
		model:ScaleTo(model:GetScale() * 3 / size.Y)
	end
	local top = incubator.Position + Vector3.new(0, incubator.Size.X / 2 + 1.5, 0)
	model:PivotTo(CFrame.new(top))
	model.Parent = incubator
end

local function refreshIncubators(plot: Plot, data: Types.Profile?)
	local now = os.time()
	local owned = if data then #data.Incubators else 0
	for slot, incubator in plot.Incubators do
		local state = "Locked"
		local hatchAt = 0
		local theme: string? = nil
		local rarity = ""
		if data and slot <= owned then
			local entry = data.Incubators[slot]
			local egg = entry.Egg
			if egg then
				theme = egg.Theme
				rarity = egg.Rarity
				hatchAt = entry.HatchAt or now
				state = if now >= hatchAt then "Ready" else "Incubating"
			else
				state = "Empty"
			end
		end

		incubator:SetAttribute("State", state)
		incubator:SetAttribute("HatchAt", hatchAt)
		incubator:SetAttribute("Rarity", rarity)
		incubator.Transparency = if state == "Locked" then 0.6 else 0
		setEggModel(incubator, theme)

		if state == "Locked" then
			local price = if data and slot == owned + 1
				then EggService:NextIncubatorPrice(data :: Types.Profile)
				else nil
			setPrompt(
				incubator,
				"Main",
				price ~= nil,
				if price then string.format(Strings.PromptBuyIncubator, price) else nil
			)
			setPrompt(incubator, "SpeedUp", false)
		elseif state == "Empty" then
			setPrompt(incubator, "Main", next(data and data.Eggs or {}) ~= nil, Strings.PromptPlace)
			setPrompt(incubator, "SpeedUp", false)
		elseif state == "Incubating" then
			setPrompt(incubator, "Main", false)
			-- PlotController keeps the cost in the text up to date.
			setPrompt(incubator, "SpeedUp", true, Strings.PromptSpeedUp)
		else
			setPrompt(incubator, "Main", true, Strings.PromptCollect)
			setPrompt(incubator, "SpeedUp", false)
		end
	end
end

local function rarityRank(rarity: string): number
	return table.find(PetConfig.Rarities, rarity) or 0
end

local function refreshShowcase(plot: Plot, data: Types.Profile?)
	local best: { { Id: string, Pet: Types.PetInstance } } = {}
	if data then
		for id, pet in data.Pets do
			table.insert(best, { Id = id, Pet = pet })
		end
	end
	table.sort(best, function(a, b)
		local rankA, rankB = rarityRank(a.Pet.Rarity), rarityRank(b.Pet.Rarity)
		if rankA ~= rankB then
			return rankA > rankB
		end
		return a.Id < b.Id
	end)

	local keyParts = {}
	for slot = 1, math.min(#best, SHOWCASE_SIZE) do
		table.insert(keyParts, best[slot].Id)
	end
	local key = table.concat(keyParts, ",")
	if key == plot.ShowcaseKey then
		return
	end
	plot.ShowcaseKey = key

	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local petsFolder = assets and assets:FindFirstChild("Pets")
	for slot, pedestal in plot.Pedestals do
		local old = pedestal:FindFirstChild("Pet")
		if old then
			old:Destroy()
		end
		local entry = best[slot]
		local kind = entry and PetConfig.Pets[entry.Pet.Kind]
		local template = kind and petsFolder and petsFolder:FindFirstChild(kind.Model)
		if template and template:IsA("Model") then
			local model = template:Clone()
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
			model.Name = "Pet"
			local size = model:GetExtentsSize()
			if size.Y > 0 then
				model:ScaleTo(model:GetScale() * PET_HEIGHT / size.Y)
			end
			local center = model:GetBoundingBox()
			local lift = pedestal.Position.Y + pedestal.Size.Y / 2 + PET_HEIGHT / 2
			model:PivotTo(
				model:GetPivot()
					+ Vector3.new(pedestal.Position.X, lift, pedestal.Position.Z)
					- center.Position
			)
			model.Parent = pedestal
		end
	end
end

local function refresh(plot: Plot)
	local owner = plot.Owner
	local data = if owner then PlayerDataService:Get(owner :: Player) else nil
	refreshIncubators(plot, data)
	refreshShowcase(plot, data)
end

local function assign(player: Player)
	if plotOf[player] then
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

local function onPrompt(plot: Plot, slot: number, promptName: string, player: Player)
	if plot.Owner ~= player then
		NetService:FireClient("ActionResult", player, "Incubator", "NotYourPlot")
		return
	end
	local data = PlayerDataService:Get(player)
	if data == nil then
		return
	end
	local owned = #(data :: Types.Profile).Incubators
	if promptName == "SpeedUp" then
		EggService:SpeedUp(player, slot)
	elseif slot > owned then
		if slot == owned + 1 then
			EggService:BuyIncubator(player)
		end
	elseif (data :: Types.Profile).Incubators[slot].Egg == nil then
		EggService:PlaceStored(player, slot)
	else
		EggService:Collect(player, slot)
	end
end

function PlotService:Init()
	local folder = Instance.new("Folder")
	folder.Name = "Plots"
	folder.Parent = workspace
	for index, cframe in plotCFrames() do
		local plot = buildPlot(index, cframe, folder)
		table.insert(plots, plot)
		for slot, incubator in plot.Incubators do
			for _, child in incubator:GetChildren() do
				if child:IsA("ProximityPrompt") then
					local name = child.Name
					child.Triggered:Connect(function(player)
						onPrompt(plot, slot, name, player)
					end)
				end
			end
		end
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

	-- Flip incubators to Ready when their time comes.
	task.spawn(function()
		while true do
			task.wait(REFRESH_SECONDS)
			for _, plot in plots do
				local owner = plot.Owner
				if owner then
					refreshIncubators(plot, PlayerDataService:Get(owner :: Player))
				end
			end
		end
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
