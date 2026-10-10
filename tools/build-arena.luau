--!strict
-- Regenerates arena/Arena.rbxm: the keyboard arena built from the asset-pack
-- key model (assets/Key.rbxm) and the key layout in ArenaGrid/ArenaConfig.
-- Run after changing either: `lune run tools/build-arena`
--
-- ArenaService picks up any BasePart tagged "ArenaKey" under Workspace.Arena,
-- so this file needs no server changes. The mesh keys do not collide; players
-- walk on the invisible Arena.Floor at key-top height, and the client sinks
-- keys under characters (KeyPressController).

local fs = require("@lune/fs")
local roblox = require("@lune/roblox") :: any

local ArenaConfig = require("../src/shared/Config/ArenaConfig")
local ArenaGrid = require("../src/shared/Logic/ArenaGrid")

local Instance = roblox.Instance
local Vector3 = roblox.Vector3
local CFrame = roblox.CFrame
local Color3 = roblox.Color3
local Enum = roblox.Enum

local template = roblox.deserializeModel(fs.readFile("assets/Key.rbxm"))[1]

local arena = Instance.new("Folder")
arena.Name = "Arena"
local keysFolder = Instance.new("Folder")
keysFolder.Name = "Keys"
keysFolder.Parent = arena

local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
for index, spec in ArenaGrid.KeyboardLayout(ArenaConfig.KeyUnit, ArenaConfig.KeyGap) do
	local key = template:Clone()
	key.Name = `Key{index}_{spec.Label}`
	key.Anchored = true
	key.CanCollide = false
	key.Color = Color3.fromRGB(248, 240, 222)
	key.Size = Vector3.new(spec.SizeX, ArenaConfig.KeyHeight, spec.SizeZ)
	local x = ArenaConfig.CenterX + spec.CenterX
	local z = ArenaConfig.CenterZ + spec.CenterZ
	key.CFrame = CFrame.new(x, ArenaConfig.KeyHeight / 2, z)

	local gui = key.Top
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 20
	local letter = gui.Letter
	letter.BackgroundTransparency = 1
	letter.Size = roblox.UDim2.fromScale(1, 1)
	letter.Text = spec.Label
	letter.TextScaled = true
	letter.TextTransparency = 0
	letter.Visible = true
	letter.TextColor3 = Color3.fromRGB(40, 40, 48)

	key:AddTag("ArenaKey")
	key.Parent = keysFolder

	minX = math.min(minX, x - spec.SizeX / 2)
	maxX = math.max(maxX, x + spec.SizeX / 2)
	minZ = math.min(minZ, z - spec.SizeZ / 2)
	maxZ = math.max(maxZ, z + spec.SizeZ / 2)
end

local margin = ArenaConfig.KeyGap
local floor = Instance.new("Part")
floor.Name = "Floor"
floor.Anchored = true
floor.Transparency = 1
floor.CanQuery = false
floor.CanTouch = false
floor.Size = Vector3.new(maxX - minX + margin * 2, 1, maxZ - minZ + margin * 2)
floor.CFrame = CFrame.new((minX + maxX) / 2, ArenaConfig.KeyHeight - 0.5, (minZ + maxZ) / 2)
floor.Parent = arena

fs.writeFile("arena/Arena.rbxm", roblox.serializeModel({ arena }))
print(`arena/Arena.rbxm: {#keysFolder:GetChildren()} keys`)
