--!strict
-- The portal in the middle of the hub plaza: a round stone stage with a
-- glowing ring gate, a swirling core, floating crystals and sparkles.
-- Pure geometry; PortalController spins the "Spin" parts on the client.
--
-- What the game code reads:
--   Portal               Model, PrimaryPart "Swirl" (PortalService and
--                        PortalController measure the distance to it)
--   Portal.Spin.*        parts PortalController turns around the gate axis
--   Portal.Float.*       crystals PortalController bobs up and down
--
-- `rbx` carries the Roblox types (Lune or Studio), `base` is the CFrame of
-- the ground under the stage center; the gate faces its +Z (the spawn).

local RING_RADIUS = 9 -- studs from the gate center to the middle of the ring
local RING_SEGMENTS = 28
local GATE_HEIGHT = 12.5 -- gate center above the stage top
local STAGE_RADIUS = 15

return function(rbx: any, parent: any, base: any): any
	local Instance = rbx.Instance
	local Vector3 = rbx.Vector3
	local CFrame = rbx.CFrame
	local Color3 = rbx.Color3
	local Enum = rbx.Enum
	local UDim2 = rbx.UDim2

	local rgb = Color3.fromRGB
	local C = {
		Stone = rgb(232, 236, 245),
		StoneDark = rgb(150, 160, 185),
		Frame = rgb(70, 50, 160),
		FrameLight = rgb(110, 80, 220),
		Glow = rgb(190, 110, 255),
		Core = rgb(90, 235, 255),
		Gold = rgb(255, 205, 70),
		Crystal = rgb(120, 240, 255),
	}

	local function part(
		parentInstance: any,
		name: string,
		size: any,
		cframe: any,
		color: any,
		studs: boolean?
	): any
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.Size = size
		p.CFrame = cframe
		p.Color = color
		p.Material = Enum.Material.Plastic
		p.TopSurface = if studs then Enum.SurfaceType.Studs else Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
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

	-- Stage: two low round stone tiers with a glowing rim and a front step.
	cylinder(portal, "Stage", STAGE_RADIUS * 2, 0.8, base * CFrame.new(0, 0.4, 0), C.StoneDark)
	cylinder(portal, "StageTop", STAGE_RADIUS * 2 - 5, 0.8, base * CFrame.new(0, 1.2, 0), C.Stone)
	neon(
		cylinder(portal, "Rim", STAGE_RADIUS * 2 - 4.4, 0.3, base * CFrame.new(0, 0.95, 0), C.Glow),
		0.1
	)
	part(
		portal,
		"Step",
		Vector3.new(12, 0.4, 2.5),
		base * CFrame.new(0, 0.2, STAGE_RADIUS + 1),
		C.Stone,
		true
	)

	local stageTop = 1.6
	local gate = base * CFrame.new(0, stageTop + GATE_HEIGHT, 0)

	-- Gate feet: two stepped plinths the ring stands on.
	for _, x in { -1, 1 } do
		local foot = base * CFrame.new(x * 6.5, stageTop, 0)
		part(portal, "Plinth", Vector3.new(6, 2, 5), foot * CFrame.new(0, 1, 0), C.Frame, true)
		part(
			portal,
			"PlinthTop",
			Vector3.new(4.5, 1.5, 4),
			foot * CFrame.new(0, 2.75, 0),
			C.FrameLight,
			true
		)
		neon(
			part(
				portal,
				"PlinthGlow",
				Vector3.new(6.2, 0.3, 5.2),
				foot * CFrame.new(0, 2.05, 0),
				C.Glow
			),
			0
		)
	end

	-- The ring: an outer frame of blocks with a neon band and gold studs.
	local ringFolder = Instance.new("Model")
	ringFolder.Name = "Ring"
	ringFolder.Parent = portal
	local segmentLength = 2 * math.pi * (RING_RADIUS + 1) / RING_SEGMENTS + 0.35
	for i = 0, RING_SEGMENTS - 1 do
		local angle = (i / RING_SEGMENTS) * 2 * math.pi
		local at = gate * CFrame.Angles(0, 0, angle)
		part(
			ringFolder,
			"Frame",
			Vector3.new(segmentLength, 2.6, 2.4),
			at * CFrame.new(0, RING_RADIUS + 1.3, 0),
			C.Frame
		)
		neon(
			part(
				ringFolder,
				"Band",
				Vector3.new(segmentLength * 0.88, 0.8, 2.8),
				at * CFrame.new(0, RING_RADIUS - 0.2, 0),
				C.Glow
			),
			0
		)
		if i % 4 == 0 then
			local stud = part(
				ringFolder,
				"Gem",
				Vector3.new(1.6, 1.6, 3.2),
				at * CFrame.new(0, RING_RADIUS + 2.7, 0) * CFrame.Angles(0, 0, math.rad(45)),
				C.Gold
			)
			stud.Material = Enum.Material.Neon
		end
	end
	-- Crown on top of the ring.
	local crown = gate * CFrame.new(0, RING_RADIUS + 3.4, 0)
	part(ringFolder, "Crown", Vector3.new(6, 1.6, 3), crown, C.FrameLight, true)
	neon(
		part(
			ringFolder,
			"CrownGem",
			Vector3.new(2.4, 2.4, 2.4),
			crown * CFrame.new(0, 2.2, 0) * CFrame.Angles(0, 0, math.rad(45)),
			C.Gold
		),
		0
	)

	-- The swirl: a glowing disc filling the ring, with a brighter core.
	local swirl = neon(
		cylinder(
			portal,
			"Swirl",
			RING_RADIUS * 2,
			0.4,
			gate * CFrame.Angles(math.rad(90), 0, 0),
			C.Glow
		),
		0.35
	)
	portal.PrimaryPart = swirl
	light(swirl, C.Glow, 30, 3)
	sparkles(swirl, "Sparks", C.Core, C.Glow, 30, 4, 70, 0.8)

	local spin = Instance.new("Model")
	spin.Name = "Spin"
	spin.Parent = portal
	local core = neon(
		cylinder(
			spin,
			"Core",
			RING_RADIUS * 1.2,
			0.6,
			gate * CFrame.Angles(math.rad(90), 0, 0),
			C.Core
		),
		0.3
	)
	-- Swirl arms: thin neon blades around the core; the client turns them.
	for i = 0, 5 do
		local at = gate * CFrame.Angles(0, 0, i * math.pi / 3)
		neon(
			part(
				spin,
				"Arm",
				Vector3.new(1.2, RING_RADIUS * 0.85, 0.7),
				at * CFrame.new(1.6, RING_RADIUS * 0.45, 0) * CFrame.Angles(0, 0, math.rad(-25)),
				C.Core
			),
			0.45
		)
	end
	sparkles(core, "Glow", C.Core, Color3.new(1, 1, 1), 15, 1, 180, 1.2)

	-- Floating crystals around the stage.
	local float = Instance.new("Model")
	float.Name = "Float"
	float.Parent = portal
	for i = 0, 3 do
		local angle = math.rad(45 + i * 90)
		local at = base
			* CFrame.new(
				math.cos(angle) * (STAGE_RADIUS - 3),
				stageTop,
				math.sin(angle) * (STAGE_RADIUS - 3)
			)
		part(
			portal,
			"Pedestal",
			Vector3.new(2.4, 1.6, 2.4),
			at * CFrame.new(0, 0.8, 0),
			C.Frame,
			true
		)
		local crystal = neon(
			part(
				float,
				"Crystal",
				Vector3.new(1.6, 3.2, 1.6),
				at * CFrame.new(0, 4.2, 0) * CFrame.Angles(0, math.rad(45), 0),
				C.Crystal
			),
			0.1
		)
		light(crystal, C.Crystal, 12, 1.5)
	end

	-- Sparkles rising from the stage rim.
	local riser = deco(
		part(
			portal,
			"Riser",
			Vector3.new(STAGE_RADIUS * 2 - 6, 0.2, STAGE_RADIUS * 2 - 6),
			base * CFrame.new(0, stageTop + 0.1, 0),
			C.Stone
		)
	)
	riser.Transparency = 1
	local rise = sparkles(riser, "Rise", C.Glow, C.Core, 12, 5, 8, 0.5)
	rise.Acceleration = Vector3.new(0, 2, 0)

	-- Sign above the gate.
	local sign = Instance.new("BillboardGui")
	sign.Name = "Sign"
	sign.Size = UDim2.fromScale(16, 4.5)
	sign.StudsOffset = Vector3.new(0, RING_RADIUS + 9, 0)
	sign.MaxDistance = 260
	sign.Parent = swirl
	local signText = Instance.new("TextLabel")
	signText.Size = UDim2.fromScale(1, 1)
	signText.BackgroundTransparency = 1
	signText.TextScaled = true
	signText.Font = Enum.Font.FredokaOne
	signText.Text = "PLAY"
	signText.TextColor3 = Color3.new(1, 1, 1)
	signText.TextStrokeColor3 = rgb(70, 30, 140)
	signText.TextStrokeTransparency = 0
	signText.Parent = sign

	return portal
end
