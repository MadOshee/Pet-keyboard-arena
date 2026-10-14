--!strict
-- Regenerates arena/Arena.rbxm: a floor made entirely of keyboard keys
-- (the Free Ocean Keyboard key model, assets/Key.rbxm), like the reference
-- Ivan picked. Run after changing the numbers below: `lune run tools/build-arena`
--
-- Workspace.Arena.Keys  - every key, tagged "ArenaKey"; ArenaService paints
--                         them all. Each key keeps its gray color in the
--                         "BaseColor" attribute.
-- Workspace.Arena.Floor - one invisible slab under the keys, exactly as big
--                         as the keys, that players walk on, as in the pack.
--                         Keys do not collide; the keys under a character
--                         sink to the floor (KeyPressController), so players
--                         walk "in" the keyboard with the other keys raised
--                         around them. Past the last key there is nothing:
--                         a player who flies over the edge falls
--                         (ArenaService puts them back above the arena).

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
-- The arena in keys, centered on ArenaConfig.CenterX/CenterZ: it floats far
-- away from the hub islands, players are teleported there. Ivan doubled
-- both sides on 2026-10-13 (was 57 x 35), then asked for 30% less (x0.7).
local ARENA_COLS = 80
local ARENA_ROWS = 49
local OX, OZ = ArenaConfig.CenterX, ArenaConfig.CenterZ

local LETTERS = string.split("ABCDEFGHIJKLMNOPQRSTUVWXYZ", "")
-- Grays in several shades (like the pack's warm palette), light enough for
-- the black letters; red and blue stand out on them.
local GRAYS = {
	Color3.fromRGB(196, 197, 202),
	Color3.fromRGB(184, 185, 190),
	Color3.fromRGB(172, 173, 178),
	Color3.fromRGB(160, 162, 168),
	Color3.fromRGB(148, 150, 156),
	Color3.fromRGB(136, 138, 144),
	Color3.fromRGB(190, 186, 180),
	Color3.fromRGB(128, 130, 136),
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

local minX = -(ARENA_COLS - 1) / 2 * PITCH
local minZ = -(ARENA_ROWS - 1) / 2 * PITCH
local count = 0
for row = 0, ARENA_ROWS - 1 do
	for col = 0, ARENA_COLS - 1 do
		count += 1
		local key = makeKey(
			`Key{count}`,
			minX + col * PITCH,
			minZ + row * PITCH,
			GRAYS[math.random(1, #GRAYS)]
		)
		key:AddTag("ArenaKey")
		key.Parent = keys
	end
end

local floor = Instance.new("Part")
floor.Name = "Floor"
floor.Anchored = true
floor.Transparency = 1
floor.CanQuery = false
floor.CanTouch = false
floor.Size = Vector3.new(ARENA_COLS * PITCH, 1, ARENA_ROWS * PITCH)
floor.CFrame = CFrame.new(OX, -0.5, OZ)
floor.Parent = arena

fs.writeFile("arena/Arena.rbxm", roblox.serializeModel({ arena }))
print(`arena/Arena.rbxm: {count} keys`)
