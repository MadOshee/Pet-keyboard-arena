--!strict
-- Regenerates world/World.rbxm: the hub world (central island, portal,
-- 12 player islands with houses and bridges, sea and decor) built by
-- tools/world/Builder.luau. Run after changing the builder:
-- `lune run tools/build-world`

local fs = require("@lune/fs")
local roblox = require("@lune/roblox") :: any

local build = require("./world/Builder")

local world = build(roblox)
fs.writeFile("world/World.rbxm", roblox.serializeModel({ world }))

local parts = 0
for _, descendant in world:GetDescendants() do
	if descendant:IsA("BasePart") then
		parts += 1
	end
end
print(`world/World.rbxm: {parts} parts`)
