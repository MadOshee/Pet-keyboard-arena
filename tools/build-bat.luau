--!strict
-- Regenerates assets/Bat.rbxm (ReplicatedStorage.Assets.Bat): a cartoon
-- baseball bat made of cylinders. Run after changing it: `lune run tools/build-bat`
--
-- The bat lies along its +X axis, knob at x = 0. BatService welds the
-- Handle's "Grip" attachment into the right hand; EffectsController uses
-- Barrel.HitPoint.HitBurst (sparks on a hit) and Barrel.SwingTrail.

local fs = require("@lune/fs")
local roblox = require("@lune/roblox") :: any

local Instance = roblox.Instance
local Vector3 = roblox.Vector3
local CFrame = roblox.CFrame
local Color3 = roblox.Color3
local Enum = roblox.Enum
local ColorSequence = roblox.ColorSequence
local ColorSequenceKeypoint = roblox.ColorSequenceKeypoint
local NumberSequence = roblox.NumberSequence
local NumberSequenceKeypoint = roblox.NumberSequenceKeypoint
local NumberRange = roblox.NumberRange
local Vector2 = roblox.Vector2

local WOOD = Color3.fromRGB(226, 172, 108)
local WOOD_DARK = Color3.fromRGB(150, 96, 52)
local TAPE = Color3.fromRGB(205, 36, 36)
local TAPE_DARK = Color3.fromRGB(120, 16, 16)
local GOLD = Color3.fromRGB(255, 198, 52)
local BLACK = Color3.fromRGB(28, 26, 30)

local bat = Instance.new("Model")
bat.Name = "Bat"

local function part(
	name: string,
	shape: any,
	x: number,
	length: number,
	diameter: number,
	color: any,
	material: any
): any
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape
	p.Size = if shape == Enum.PartType.Ball
		then Vector3.new(diameter, diameter, diameter)
		else Vector3.new(length, diameter, diameter)
	p.CFrame = CFrame.new(x, 0, 0)
	p.Color = color
	p.Material = material
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = bat
	return p
end

local cylinder = Enum.PartType.Cylinder

-- Grip wrapped in red tape; the fist holds it just above the knob.
local handle = part("Handle", cylinder, 0.615, 0.95, 0.27, TAPE, Enum.Material.Fabric)
local grip = Instance.new("Attachment")
grip.Name = "Grip"
grip.CFrame = CFrame.new(-0.13, 0, 0)
grip.Parent = handle
bat.PrimaryPart = handle

local pieces = {
	part("Knob", cylinder, 0.07, 0.14, 0.52, BLACK, Enum.Material.SmoothPlastic),
}
for i, x in { 0.3, 0.5, 0.7, 0.9 } do
	table.insert(pieces, part(`Tape{i}`, cylinder, x, 0.05, 0.29, TAPE_DARK, Enum.Material.Fabric))
end
-- The handle widens into the barrel in a few steps.
for i, diameter in { 0.3, 0.36, 0.43, 0.51 } do
	table.insert(
		pieces,
		part(`Taper{i}`, cylinder, 1.09 + (i - 0.5) * 0.3, 0.3, diameter, WOOD, Enum.Material.Wood)
	)
end
local barrel = part("Barrel", cylinder, 2.965, 1.35, 0.6, WOOD, Enum.Material.Wood)
table.insert(pieces, barrel)
table.insert(pieces, part("Cap", Enum.PartType.Ball, 3.64, 0.6, 0.6, WOOD, Enum.Material.Wood))
table.insert(pieces, part("GoldBand", cylinder, 2.42, 0.08, 0.62, GOLD, Enum.Material.Metal))
table.insert(pieces, part("DarkBand", cylinder, 3.45, 0.1, 0.62, WOOD_DARK, Enum.Material.Wood))
table.insert(pieces, part("TopBand", cylinder, 3.3, 0.05, 0.62, GOLD, Enum.Material.Metal))

-- Plain Welds with explicit offsets: a WeldConstraint only remembers the
-- offset Roblox computes when it first becomes active, which is wrong for
-- a model that is cloned and moved before it reaches the workspace.
for _, piece in pieces do
	local weld = Instance.new("Weld")
	weld.Part0 = handle
	weld.Part1 = piece
	weld.C0 = handle.CFrame:Inverse() * piece.CFrame
	weld.Parent = piece
end

-- Effects on the barrel (positions relative to the barrel's center).
local hitPoint = Instance.new("Attachment")
hitPoint.Name = "HitPoint"
hitPoint.CFrame = CFrame.new(0.4, 0, 0)
hitPoint.Parent = barrel

local burst = Instance.new("ParticleEmitter")
burst.Name = "HitBurst"
burst.Enabled = false
burst.Texture = "rbxasset://textures/particles/sparkles_main.dds"
burst.Color = ColorSequence.new(Color3.fromRGB(255, 240, 120))
burst.LightEmission = 1
burst.Lifetime = NumberRange.new(0.25, 0.45)
burst.Speed = NumberRange.new(18, 28)
burst.SpreadAngle = Vector2.new(180, 180)
burst.Size = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1.2),
	NumberSequenceKeypoint.new(1, 0.2),
})
burst.Rate = 20
burst.Parent = hitPoint

local trail0 = Instance.new("Attachment")
trail0.Name = "Trail0"
trail0.CFrame = CFrame.new(-0.9, 0, 0)
trail0.Parent = barrel
local trail1 = Instance.new("Attachment")
trail1.Name = "Trail1"
trail1.CFrame = CFrame.new(0.95, 0, 0)
trail1.Parent = barrel

local trail = Instance.new("Trail")
trail.Name = "SwingTrail"
trail.Enabled = false
trail.Attachment0 = trail0
trail.Attachment1 = trail1
trail.Lifetime = 0.22
trail.LightEmission = 0.6
trail.FaceCamera = false
trail.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(170, 225, 255)),
})
trail.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.2),
	NumberSequenceKeypoint.new(1, 1),
})
trail.Parent = barrel

fs.writeFile("assets/Bat.rbxm", roblox.serializeModel({ bat }))
print("assets/Bat.rbxm written")
