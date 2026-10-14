--!strict
-- Regenerates world/World.rbxm (the hub) and the map's materials
-- from Ivan's map pack world/source/StealMap6.rbxl: the plaza in the middle,
-- six bases with two-storey buildings around it, the sea with ships.
--
--   python3 tools/pack/clean_rbxl.py world/source/StealMap6.rbxl /tmp/map.rbxl
--   lune run tools/build-world /tmp/map.rbxl
--
-- What it changes in the pack:
--   * scripts are removed (the map is decoration only);
--   * the red market buildings are removed;
--   * every pet spot of a building becomes a platform (10 on the ground
--     floor, then 10 on the second floor) that holds an egg or a pet, and its
--     green pad becomes the platform's button;
--   * the plaza center is moved to the origin, the sea tiles that would cover
--     the arena (ArenaConfig.CenterZ) are removed;
--   * the "UPGRADES" NPC of every base becomes the shop keeper;
--   * the portal (tools/world/Portal.luau) stands in the plaza center.
--
-- What the game code reads (everything else is decoration):
--   World.Portal                 see tools/world/Portal.luau
--   World.Islands.IslandN        a base, attribute PlotIndex = N
--     .PlotAnchor                invisible Part on the ground floor of the
--                                building, -Z towards the entrance; PlotService
--                                builds the plot on it (attribute SignHeight)
--     .Platforms.PlatformN       invisible Part on top of spot pad N (attribute
--                                Index; ground floor 1-10, second floor
--                                11-20), -Z towards its button
--     ...PlatformButton          the green pad in front of a spot (attribute
--                                Platform = N): stepping on it opens platform N
--     .Shop.NPC.HumanoidRootPart.Shop   ProximityPrompt that opens the shop
--     .Shop.Shop                 ClickDetector: clicking the stall opens it too

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox") :: any

local ArenaConfig = require("../src/shared/Config/ArenaConfig")
local buildPortal = require("./world/Portal")

local Instance = roblox.Instance
local Vector3 = roblox.Vector3
local CFrame = roblox.CFrame

-- Lune's CFrame.lookAt flips some directions (looking along +Z gives -Z),
-- so level "look at" frames are built by hand.
local function facing(position: any, target: any): any
	local look = Vector3.new(target.X - position.X, 0, target.Z - position.Z).Unit
	local up = Vector3.new(0, 1, 0)
	return CFrame.fromMatrix(position, look:Cross(up).Unit, up, -look)
end

local PLOT_FORWARD = 16 -- studs from the building center towards its entrance
local SIGN_HEIGHT = 40 -- plot sign above the floor, over the roof

local source = process.args[1]
if source == nil then
	error("usage: lune run tools/build-world <cleaned map.rbxl>")
end
local game = roblox.deserializePlace(fs.readFile(source))
local workspace = game:GetService("Workspace")
local map = workspace:FindFirstChild("MAP FOR?")
local layout = map:FindFirstChild("NewMAP2")
local plaza = layout:FindFirstChild("NewPlaza?")

local function parts(root: any): { any }
	local result = {}
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(result, descendant)
		end
	end
	return result
end

-- Axis-aligned bounds, good enough for the unrotated plaza.
local function bounds(root: any): (any, any)
	local minX, minY, minZ = math.huge, math.huge, math.huge
	local maxX, maxY, maxZ = -math.huge, -math.huge, -math.huge
	for _, p in parts(root) do
		local position, half = p.CFrame.Position, p.Size / 2
		minX, maxX = math.min(minX, position.X - half.X), math.max(maxX, position.X + half.X)
		minY, maxY = math.min(minY, position.Y - half.Y), math.max(maxY, position.Y + half.Y)
		minZ, maxZ = math.min(minZ, position.Z - half.Z), math.max(maxZ, position.Z + half.Z)
	end
	return Vector3.new(minX, minY, minZ), Vector3.new(maxX, maxY, maxZ)
end

-- The top of the highest plaza tile right under the plaza center.
local plazaMin, plazaMax = bounds(plaza)
local center = (plazaMin + plazaMax) / 2
local plazaTop = -math.huge
for _, p in parts(plaza) do
	local position, half = p.CFrame.Position, p.Size / 2
	if math.abs(position.X - center.X) < half.X and math.abs(position.Z - center.Z) < half.Z then
		plazaTop = math.max(plazaTop, position.Y + half.Y)
	end
end
local offset = Vector3.new(-center.X, 0, -center.Z)

-- 1. Scripts out, the pack's own spawn out (the project has one).
local doomed = {}
for _, descendant in map:GetDescendants() do
	if descendant:IsA("LuaSourceContainer") or descendant:IsA("SpawnLocation") then
		table.insert(doomed, descendant)
	end
end
for _, instance in doomed do
	instance:Destroy()
end

-- 2. Bases: drop the market, find where the plot goes, turn the upgrades NPC
-- into the shop keeper.
type Base = { Folder: any, Anchor: any, Angle: number }
local bases: { Base } = {}
for _, base in layout:GetChildren() do
	if string.match(base.Name, "^BASE %d+$") == nil then
		continue
	end
	base:FindFirstChild("Market"):Destroy()
	local floor1 = base:FindFirstChild("Floor1")

	-- The stairs start in the middle of the building and go to the back;
	-- the entrance is on the other side.
	local steps = parts(floor1:FindFirstChild("Steps"))
	table.sort(steps, function(a, b)
		return a.CFrame.Position.Y < b.CFrame.Position.Y
	end)
	local low, high = steps[1].CFrame.Position, steps[#steps].CFrame.Position
	local back = Vector3.new(high.X - low.X, 0, high.Z - low.Z).Unit
	local floorTop = low.Y - steps[1].Size.Y / 2
	local spot = Vector3.new(low.X, floorTop, low.Z) - back * PLOT_FORWARD

	local anchor = Instance.new("Part")
	anchor.Name = "PlotAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(4, 0.2, 4)
	anchor.CFrame = facing(spot, spot - back)
	anchor:SetAttribute("SignHeight", SIGN_HEIGHT)
	anchor.Parent = base

	-- Platforms on the spot pads (the 7x7 tiles), facing their green button.
	local platforms = Instance.new("Folder")
	platforms.Name = "Platforms"
	local function addPlatforms(floorName: string, first: number)
		for _, spot in base:FindFirstChild(floorName):FindFirstChild("Spots"):GetChildren() do
			local number = tonumber(string.match(spot.Name, "%d+"))
			local pad = nil
			for _, p in parts(spot:FindFirstChild("Spot")) do
				if
					p.Size.X >= 6
					and p.Size.Z >= 6
					and (pad == nil or p.CFrame.Position.Y > pad.CFrame.Position.Y)
				then
					pad = p
				end
			end
			-- The pack's green "Receive" pad: the highest part of that model.
			local button = nil
			for _, p in parts(spot:FindFirstChild("Receive")) do
				if button == nil or p.CFrame.Position.Y > button.CFrame.Position.Y then
					button = p
				end
			end
			assert(number and pad and button, `no pad in {base.Name}.{floorName}.{spot.Name}`)
			local index = first + number - 1
			button.Name = "PlatformButton"
			button:SetAttribute("Platform", index)

			local top = pad.CFrame.Position + Vector3.new(0, pad.Size.Y / 2, 0)
			local toward = button.CFrame.Position
			local platform = Instance.new("Part")
			platform.Name = `Platform{index}`
			platform.Anchored = true
			platform.CanCollide = false
			platform.CanQuery = false
			platform.CanTouch = false
			platform.Transparency = 1
			platform.Size = Vector3.new(4, 0.2, 4)
			platform.CFrame = facing(top, toward)
			platform:SetAttribute("Index", index)
			platform.Parent = platforms
		end
	end
	addPlatforms("Floor1", 1)
	addPlatforms("Floor2", 11)
	platforms.Parent = base

	local upgrades = base:FindFirstChild("Upgrades")
	upgrades.Name = "Shop"
	for _, descendant in upgrades:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
		elseif descendant:IsA("TextLabel") and descendant.Text == "UPGRADES" then
			descendant.Text = "SHOP"
		end
	end
	local root = upgrades:FindFirstChild("NPC"):FindFirstChild("HumanoidRootPart")
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Shop"
	prompt.ActionText = "Shop"
	prompt.ObjectText = "Shop keeper"
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 12
	prompt.Parent = root
	local click = Instance.new("ClickDetector")
	click.Name = "Shop"
	click.MaxActivationDistance = 60
	click.Parent = upgrades

	local position = anchor.CFrame.Position
	table.insert(bases, {
		Folder = base,
		Anchor = anchor,
		Angle = math.atan2(position.Z - center.Z, position.X - center.X),
	})
end
assert(#bases == 6, `expected 6 bases, found {#bases}`)

-- Plot numbers go around the plaza.
table.sort(bases, function(a, b)
	return a.Angle < b.Angle
end)

-- 3. Assemble the World model.
local world = Instance.new("Model")
world.Name = "World"
local islands = Instance.new("Folder")
islands.Name = "Islands"
islands.Parent = world
for index, base in bases do
	base.Folder.Name = `Island{index}`
	base.Folder:SetAttribute("PlotIndex", index)
	base.Anchor:SetAttribute("PlotIndex", index)
	base.Folder.Parent = islands
end
plaza.Name = "Plaza"
plaza.Parent = world
local ocean = map:FindFirstChild("Ocean")
ocean.Parent = world
local plants = Instance.new("Folder")
plants.Name = "Plants"
plants.Parent = world
for _, child in workspace:GetChildren() do
	if child:IsA("Model") and string.match(child.Name, "^LeafyPlant") then
		child.Parent = plants
	end
end

-- 4. Move everything so the plaza center is the origin.
for _, descendant in world:GetDescendants() do
	if descendant:IsA("BasePart") then
		descendant.CFrame = descendant.CFrame + offset
	elseif descendant:IsA("Model") then
		pcall(function()
			descendant.WorldPivot = descendant.WorldPivot + offset
		end)
	end
end

-- Sea tiles reaching the arena would cover it.
local arenaZ = ArenaConfig.CenterZ
for _, descendant in ocean:GetDescendants() do
	if descendant:IsA("BasePart") and descendant.Name == "Water" then
		local z, half = descendant.CFrame.Position.Z, descendant.Size.Z / 2
		if math.abs(arenaZ - z) < half + 200 then
			descendant.Parent = nil
		end
	end
end

-- 5. The portal in the plaza center, facing +Z (the spawn).
buildPortal(roblox, world, CFrame.new(0, plazaTop, 0))

fs.writeFile("world/World.rbxm", roblox.serializeModel({ world }))
print(`world/World.rbxm: {#parts(world)} parts, plaza top at y={plazaTop}`)

-- Materials (the pack's stud textures) go next to the world. The pack's sky
-- is left out: it washed the whole picture out to white.
if not fs.isDir("world/materials") then
	fs.writeDir("world/materials")
end
for _, variant in game:GetService("MaterialService"):GetChildren() do
	fs.writeFile(`world/materials/{variant.Name}.rbxm`, roblox.serializeModel({ variant }))
end
for index, base in bases do
	local position = base.Anchor.CFrame.Position
	print(
		string.format(
			"Island%d plot at (%.1f, %.2f, %.1f)",
			index,
			position.X,
			position.Y,
			position.Z
		)
	)
end
