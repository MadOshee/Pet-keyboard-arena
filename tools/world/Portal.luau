--!strict
-- The portal in the middle of the hub plaza, after Ivan's reference: a
-- stone arch with vines on a round three-step stage, a glowing gate between
-- the pillars, and a "Play" sign with a sword icon above. Built from studded
-- blocks like the rest of the pack's map. Pure geometry; PortalController
-- turns the "Spin" parts and bobs the "Float" ones on the client.
--
-- What the game code reads:
--   Portal               Model, PrimaryPart "Swirl" (PortalService and
--                        PortalController measure the distance to it; its
--                        X axis is the gate axis)
--   Portal.Spin.*        parts PortalController turns around the gate axis
--   Portal.Float.*       crystals PortalController bobs up and down
--
-- `rbx` carries the Roblox types (Lune or Studio), `base` is the CFrame of
-- the ground under the stage center; the gate faces its +Z (the spawn).

local IconConfig = require("../../src/shared/Config/IconConfig")

local TIERS = { -- outer radius and band width of each stage step, bottom up
	{ Radius = 18, Band = 3 },
	{ Radius = 15, Band = 3 },
	{ Radius = 12, Band = 2.5 },
}
local TIER_HEIGHT = 1.2
local TILES = 36 -- paving tiles around each step
local GATE_WIDTH = 10 -- the glowing opening between the pillars
local GATE_HEIGHT = 13
local PILLAR_X = GATE_WIDTH / 2 + 2

return function(rbx: any, parent: any, base: any): any
	local Instance = rbx.Instance
	local Vector3 = rbx.Vector3
	local CFrame = rbx.CFrame
	local Color3 = rbx.Color3
	local Enum = rbx.Enum
	local UDim2 = rbx.UDim2

	local rgb = Color3.fromRGB
	local C = {
		Step = rgb(108, 102, 128),
		StepDark = rgb(78, 74, 96),
		Grout = rgb(55, 52, 70),
		Stone = rgb(226, 222, 214),
		StoneShade = rgb(196, 190, 182),
		Rock = rgb(120, 120, 128),
		RockDark = rgb(92, 92, 100),
		Band = rgb(64, 66, 82),
		Vine = rgb(122, 186, 62),
		Leaf = rgb(150, 214, 70),
		Slate = rgb(52, 74, 96),
		Gold = rgb(240, 196, 60),
		Gate = rgb(90, 230, 220),
		GateCore = rgb(235, 255, 252),
		Crystal = rgb(110, 235, 225),
	}

	-- A block studded on every face, like the pack's map.
	local function part(parentInstance: any, name: string, size: any, cframe: any, color: any): any
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.Size = size
		p.CFrame = cframe
		p.Color = color
		p.Material = Enum.Material.Plastic
		for _, face in { "Top", "Bottom", "Front", "Back", "Left", "Right" } do
			p[face .. "Surface"] = Enum.SurfaceType.Studs
		end
		p.Parent = parentInstance
		return p
	end

	local function deco(p: any): any
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		return p
	end

	local function neon(p: any, transparency: number): any
		p.Material = Enum.Material.Neon
		p.Transparency = transparency
		for _, face in { "Top", "Bottom", "Front", "Back", "Left", "Right" } do
			p[face .. "Surface"] = Enum.SurfaceType.Smooth
		end
		return deco(p)
	end

	local function cylinder(
		parentInstance: any,
		name: string,
		diameter: number,
		height: number,
		cframe: any,
		color: any
	): any
		-- A cylinder's axis is its X; turn it upright.
		local p = part(
			parentInstance,
			name,
			Vector3.new(height, diameter, diameter),
			cframe * CFrame.Angles(0, 0, math.rad(90)),
			color
		)
		p.Shape = Enum.PartType.Cylinder
		return p
	end

	local function light(parentInstance: any, color: any, range: number, brightness: number)
		local l = Instance.new("PointLight")
		l.Color = color
		l.Range = range
		l.Brightness = brightness
		l.Parent = parentInstance
	end

	local function sparkles(
		parentInstance: any,
		name: string,
		colorA: any,
		colorB: any,
		rate: number,
		speed: number,
		spread: number,
		size: number
	)
		local e = Instance.new("ParticleEmitter")
		e.Name = name
		e.Color = rbx.ColorSequence.new(colorA, colorB)
		e.Size = rbx.NumberSequence.new(size, 0)
		e.Transparency = rbx.NumberSequence.new(0.1, 1)
		e.Lifetime = rbx.NumberRange.new(1.2, 2)
		e.Rate = rate
		e.Speed = rbx.NumberRange.new(speed * 0.5, speed)
		e.SpreadAngle = rbx.Vector2.new(spread, spread)
		e.RotSpeed = rbx.NumberRange.new(-90, 90)
		e.LightEmission = 1
		e.Parent = parentInstance
		return e
	end

	local portal = Instance.new("Model")
	portal.Name = "Portal"
	portal.Parent = parent

	-- Stage: three round steps. Each step is a dark core (the grout) with a
	-- ring of studded paving tiles on its rim; the top step is paved inside
	-- with square tiles too.
	local stage = Instance.new("Model")
	stage.Name = "Stage"
	stage.Parent = portal
	for index, tier in TIERS do
		local top = index * TIER_HEIGHT
		local core = cylinder(
			stage,
			"Core",
			tier.Radius * 2 - 0.6,
			TIER_HEIGHT - 0.1,
			base * CFrame.new(0, top - TIER_HEIGHT / 2 - 0.05, 0),
			C.Grout
		)
		core.Material = Enum.Material.SmoothPlastic
		local inner = tier.Radius - tier.Band
		local tileLength = 2 * inner * math.sin(math.pi / TILES) + 0.05
		for i = 0, TILES - 1 do
			local angle = (i + (index % 2) * 0.5) / TILES * 2 * math.pi
			part(
				stage,
				"Tile",
				Vector3.new(tileLength, TIER_HEIGHT, tier.Band),
				base
					* CFrame.Angles(0, angle, 0)
					* CFrame.new(0, top - TIER_HEIGHT / 2, inner + tier.Band / 2),
				if i % 3 == 0 then C.StepDark else C.Step
			)
		end
	end
	local stageTop = #TIERS * TIER_HEIGHT
	local floorRadius = TIERS[#TIERS].Radius - TIERS[#TIERS].Band - 0.3
	local floorTile = 3
	for gx = -4, 3 do
		for gz = -4, 3 do
			local x0, z0 = gx * floorTile, gz * floorTile
			local far = math.max(
				Vector3.new(x0, 0, z0).Magnitude,
				Vector3.new(x0 + floorTile, 0, z0).Magnitude,
				Vector3.new(x0, 0, z0 + floorTile).Magnitude,
				Vector3.new(x0 + floorTile, 0, z0 + floorTile).Magnitude
			)
			if far <= floorRadius then
				part(
					stage,
					"Floor",
					Vector3.new(floorTile - 0.15, 0.4, floorTile - 0.15),
					base * CFrame.new(x0 + floorTile / 2, stageTop - 0.2, z0 + floorTile / 2),
					if (gx + gz) % 2 == 0 then C.Step else C.StepDark
				)
			end
		end
	end
	-- The arch: two pillars on rough rocks, a stone lintel across them.
	local arch = Instance.new("Model")
	arch.Name = "Arch"
	arch.Parent = portal
	local columnBottom = stageTop + 5.5
	local columnTop = stageTop + GATE_HEIGHT + 0.5
	for _, side in { -1, 1 } do
		local foot = base * CFrame.new(side * PILLAR_X, stageTop, 0)
		part(
			arch,
			"Rock",
			Vector3.new(5, 3, 5),
			foot * CFrame.new(0, 1.5, 0) * CFrame.Angles(0, math.rad(side * 8), math.rad(side * 3)),
			C.RockDark
		)
		part(
			arch,
			"Rock",
			Vector3.new(4.4, 2.6, 4.4),
			foot
				* CFrame.new(side * 0.2, 4.1, 0)
				* CFrame.Angles(0, math.rad(-side * 10), math.rad(-side * 2)),
			C.Rock
		)
		local columnHeight = columnTop - columnBottom
		part(
			arch,
			"Column",
			Vector3.new(3, columnHeight, 3),
			base * CFrame.new(side * PILLAR_X, columnBottom + columnHeight / 2, 0),
			C.Stone
		)
		part(
			arch,
			"Ring",
			Vector3.new(3.6, 0.8, 3.6),
			base * CFrame.new(side * PILLAR_X, columnTop - 0.6, 0),
			C.Band
		)
		part(
			arch,
			"Capital",
			Vector3.new(4.4, 1.2, 4.4),
			base * CFrame.new(side * PILLAR_X, columnTop + 0.4, 0),
			C.StoneShade
		)
	end
	local lintelY = columnTop + 1 + 1.8
	local lintel = base * CFrame.new(0, lintelY, 0)
	local lintelLength = PILLAR_X * 2 + 6
	part(arch, "Lintel", Vector3.new(lintelLength, 3.6, 4.6), lintel, C.Stone)
	for _, side in { -1, 1 } do
		part(
			arch,
			"LintelEnd",
			Vector3.new(1.6, 4, 5),
			lintel
				* CFrame.new(side * (lintelLength / 2 - 0.4), 0.1, 0)
				* CFrame.Angles(0, 0, math.rad(side * 4)),
			C.StoneShade
		)
	end

	-- Emblem on the lintel front: a slate diamond with a gold disc.
	local emblem = lintel * CFrame.new(0, 0.6, 2.6)
	part(
		arch,
		"Emblem",
		Vector3.new(4.4, 4.4, 1.2),
		emblem * CFrame.Angles(0, 0, math.rad(45)),
		C.Slate
	)
	part(arch, "EmblemTip", Vector3.new(1.2, 2.2, 1), emblem * CFrame.new(0, 3.6, -0.1), C.Slate)
	local disc = cylinder(
		arch,
		"EmblemDisc",
		2.4,
		0.6,
		emblem * CFrame.new(0, 0, 0.7) * CFrame.Angles(math.rad(90), 0, 0),
		C.Gold
	)
	disc.Material = Enum.Material.SmoothPlastic

	-- Vines: chains of small green blocks over the lintel and down the pillars.
	local vines = Instance.new("Model")
	vines.Name = "Vines"
	vines.Parent = portal
	-- A CFrame at `position` whose -Z points along `look` (CFrame.lookAt
	-- turns some directions wrong under Lune).
	local function along(position: any, look: any): any
		local up = if math.abs(look.Y) > 0.95 then Vector3.new(1, 0, 0) else Vector3.new(0, 1, 0)
		local right = look:Cross(up).Unit
		return CFrame.fromMatrix(position, right, right:Cross(look), -look)
	end
	local function vine(from: any, to: any, wobble: number)
		local steps = math.max(2, math.floor((to - from).Magnitude / 1.2))
		local previous = from
		for i = 1, steps do
			local t = i / steps
			local point = from
				+ (to - from) * t
				+ Vector3.new(math.sin(t * 9) * wobble, 0, math.cos(t * 7) * wobble * 0.4)
			local length = (point - previous).Magnitude
			deco(
				part(
					vines,
					"Vine",
					Vector3.new(0.35, 0.35, length + 0.2),
					along((previous + point) / 2, (point - previous).Unit),
					C.Vine
				)
			)
			if i % 3 == 0 then
				deco(
					part(
						vines,
						"Leaf",
						Vector3.new(0.9, 0.3, 0.9),
						CFrame.new(point) * CFrame.Angles(0.4, t * 5, 0.3),
						C.Leaf
					)
				)
			end
			previous = point
		end
	end
	local front = 2.45
	vine(
		(lintel * CFrame.new(-lintelLength / 2 + 1.5, 1.9, front)).Position,
		(lintel * CFrame.new(-3, 1.2, front)).Position,
		0.4
	)
	vine(
		(lintel * CFrame.new(-lintelLength / 2 + 2.5, 1.8, front)).Position,
		(base * CFrame.new(-PILLAR_X - 1.55, stageTop + 7, 0.8)).Position,
		0.5
	)
	vine(
		(lintel * CFrame.new(3, 1.9, front)).Position,
		(lintel * CFrame.new(lintelLength / 2 - 1, 1, front)).Position,
		0.4
	)
	vine(
		(lintel * CFrame.new(lintelLength / 2 - 2.8, 1.8, front)).Position,
		(base * CFrame.new(PILLAR_X + 1.55, stageTop + 9, 0.6)).Position,
		0.5
	)
	vine(
		(lintel * CFrame.new(PILLAR_X - 1, -1.8, front)).Position,
		(base * CFrame.new(PILLAR_X - 1.55, stageTop + 10.5, 1.6)).Position,
		0.3
	)

	-- The gate: a glowing slab between the pillars with a bright core.
	local gate = base * CFrame.new(0, stageTop + 0.4 + GATE_HEIGHT / 2, 0)
	local swirl = neon(
		part(
			portal,
			"Swirl",
			Vector3.new(0.6, GATE_HEIGHT, GATE_WIDTH),
			gate * CFrame.Angles(0, math.rad(90), 0),
			C.Gate
		),
		0.45
	)
	portal.PrimaryPart = swirl
	light(swirl, C.Gate, 16, 1)
	sparkles(swirl, "Sparks", C.GateCore, C.Gate, 30, 3, 70, 0.7)

	local spin = Instance.new("Model")
	spin.Name = "Spin"
	spin.Parent = portal
	-- Swirl arms: faint blades turning inside the gate.
	for i = 0, 5 do
		local at = gate * CFrame.Angles(0, 0, i * math.pi / 3)
		neon(
			part(
				spin,
				"Arm",
				Vector3.new(0.9, 3.6, 0.8),
				at * CFrame.new(1.2, 2.2, 0) * CFrame.Angles(0, 0, math.rad(-25)),
				C.GateCore
			),
			0.7
		)
	end
	local core = neon(
		part(
			spin,
			"Core",
			Vector3.new(3, 3, 0.9),
			gate * CFrame.Angles(0, 0, math.rad(45)),
			C.GateCore
		),
		0.55
	)
	sparkles(core, "Glow", C.GateCore, Color3.new(1, 1, 1), 12, 1, 180, 1)

	-- Two crystals hovering by the gate.
	local float = Instance.new("Model")
	float.Name = "Float"
	float.Parent = portal
	for _, side in { -1, 1 } do
		local crystal = neon(
			part(
				float,
				"Crystal",
				Vector3.new(1.2, 2.4, 1.2),
				base
					* CFrame.new(side * (PILLAR_X + 4.5), stageTop + 4, 3)
					* CFrame.Angles(0, math.rad(45), 0),
				C.Crystal
			),
			0.1
		)
		light(crystal, C.Crystal, 8, 0.6)
	end

	-- Sign above the arch: the sword icon and "Play".
	local sign = Instance.new("BillboardGui")
	sign.Name = "Sign"
	sign.Size = UDim2.fromScale(16, 5)
	sign.StudsOffset = Vector3.new(0, lintelY - (stageTop + 0.4 + GATE_HEIGHT / 2) + 9, 0)
	sign.MaxDistance = 260
	sign.Parent = swirl
	local icon = Instance.new("ImageLabel")
	icon.Name = "Sword"
	icon.Size = UDim2.fromScale(0.3, 1)
	icon.BackgroundTransparency = 1
	icon.Image = IconConfig.Sword
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Parent = sign
	local signText = Instance.new("TextLabel")
	signText.Name = "Text"
	signText.Position = UDim2.fromScale(0.3, 0)
	signText.Size = UDim2.fromScale(0.7, 1)
	signText.BackgroundTransparency = 1
	signText.TextScaled = true
	signText.Font = Enum.Font.FredokaOne
	signText.Text = "Play"
	signText.TextColor3 = Color3.new(1, 1, 1)
	signText.TextStrokeColor3 = rgb(30, 40, 60)
	signText.TextStrokeTransparency = 0
	signText.Parent = sign

	return portal
end
