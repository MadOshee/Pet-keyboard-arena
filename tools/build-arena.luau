--!strict
-- Regenerates arena/Arena.rbxm: a floor made entirely of keyboard keys
-- (the Free Ocean Keyboard key model, assets/Key.rbxm), like the reference
-- Ivan picked. Run after changing the numbers below: `lune run tools/build-arena`
--
-- Workspace.Arena.Keys  - the playable keys, tagged "ArenaKey"; ArenaService
--                         paints them. Each key keeps its pack color in the
--                         "BaseColor" attribute.
-- Workspace.Arena.Decor - the same keys around the arena and under the lobby;
--                         never painted.
-- Workspace.Arena.Floor - one invisible slab at key-bottom height that
--                         players walk on, as in the pack. Keys do not collide;
--                         the keys under a character sink to the floor
--                         (KeyPressController), so players walk "in" the
--                         keyboard with the other keys raised around them.

local fs = require("@lune/fs")
local roblox = require("@lune/roblox") :: any

local Instance = roblox.Instance
local Vector3 = roblox.Vector3
local CFrame = roblox.CFrame
local Color3 = roblox.Color3

local ArenaConfig = require("../src/shared/Config/ArenaConfig")

-- Same as the keys in Free Ocean Keyboard: 2.2 x 1.4 x 2.2, touching.
local KEY_SIZE = 2.2
local KEY_HEIGHT = 1.4
local PITCH = 2.2
-- Playable area in keys, centered on ArenaConfig.CenterX/CenterZ: the
-- arena floats far away from the hub islands, players are teleported there.
local ARENA_COLS = 57
local ARENA_ROWS = 35
local OX, OZ = ArenaConfig.CenterX, ArenaConfig.CenterZ
-- The decorative floor around the playable keys (studs, relative to the center).
local FLOOR_MIN_X, FLOOR_MAX_X = -80, 80
local FLOOR_MIN_Z, FLOOR_MAX_Z = -50, 50

local LETTERS = string.split("ABCDEFGHIJKLMNOPQRSTUVWXYZ", "")
local WARM = {
	Color3.fromRGB(238, 214, 175),
	Color3.fromRGB(240, 230, 140),
	Color3.fromRGB(255, 190, 100),
	Color3.fromRGB(255, 245, 180),
	Color3.fromRGB(248, 217, 109),
	Color3.fromRGB(255, 170, 80),
	Color3.fromRGB(255, 230, 150),
	Color3.fromRGB(240, 210, 120),
}

math.randomseed(20261010)
local template = roblox.deserializeModel(fs.readFile("assets/Key.rbxm"))[1]

local function makeKey(name: string, x: number, z: number, color: any): any
	local key = template:Clone()
	key.Name = name
	key.Anchored = true
	key.CanCollide = false
	key.Color = color
	key.Size = Vector3.new(KEY_SIZE, KEY_HEIGHT, KEY_SIZE)
	key.CFrame = CFrame.new(OX + x, KEY_HEIGHT / 2, OZ + z)
	-- The pack's SurfaceGui is kept as is; like its key script, pick a random
	-- letter (solid black, as in Ivan's reference screenshot).
	local letter = key.Top.Letter
	letter.Text = LETTERS[math.random(1, #LETTERS)]
	letter.TextTransparency = 0
	letter.Visible = true
	key:SetAttribute("BaseColor", color)
	return key
end

local arena = Instance.new("Folder")
arena.Name = "Arena"
local keys = Instance.new("Folder")
keys.Name = "Keys"
keys.Parent = arena
local decor = Instance.new("Folder")
decor.Name = "Decor"
decor.Parent = arena

-- The playable grid sits on the same lattice as the decorative floor.
local arenaMinX = -(ARENA_COLS - 1) / 2 * PITCH
local arenaMinZ = -(ARENA_ROWS - 1) / 2 * PITCH
local arenaCount, decorCount = 0, 0

local z = arenaMinZ - math.floor((arenaMinZ - FLOOR_MIN_Z) / PITCH) * PITCH
while z <= FLOOR_MAX_Z do
	local x = arenaMinX - math.floor((arenaMinX - FLOOR_MIN_X) / PITCH) * PITCH
	while x <= FLOOR_MAX_X do
		local inArena = x >= arenaMinX - 0.01
			and x <= -arenaMinX + 0.01
			and z >= arenaMinZ - 0.01
			and z <= -arenaMinZ + 0.01
		if inArena then
			arenaCount += 1
			local key = makeKey(`Key{arenaCount}`, x, z, WARM[math.random(1, #WARM)])
			key:AddTag("ArenaKey")
			key.Parent = keys
		else
			decorCount += 1
			makeKey(`Decor{decorCount}`, x, z, WARM[math.random(1, #WARM)]).Parent = decor
		end
		x += PITCH
	end
	z += PITCH
end

local floor = Instance.new("Part")
floor.Name = "Floor"
floor.Anchored = true
floor.Transparency = 1
floor.CanQuery = false
floor.CanTouch = false
floor.Size = Vector3.new(FLOOR_MAX_X - FLOOR_MIN_X + PITCH, 1, FLOOR_MAX_Z - FLOOR_MIN_Z + PITCH)
floor.CFrame =
	CFrame.new(OX + (FLOOR_MIN_X + FLOOR_MAX_X) / 2, -0.5, OZ + (FLOOR_MIN_Z + FLOOR_MAX_Z) / 2)
floor.Parent = arena

fs.writeFile("arena/Arena.rbxm", roblox.serializeModel({ arena }))
print(`arena/Arena.rbxm: {arenaCount} arena keys, {decorCount} decor keys`)
