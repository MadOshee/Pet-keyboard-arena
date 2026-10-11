--!strict
-- Builds the hub world in a blocky "stud" style: the central island with
-- the pond and the portal, a ring of 12 player islands joined to it by
-- bridges, the sea, ships and boats. Pure geometry, no game logic.
--
-- The builder only touches the Roblox types handed in through `rbx`, so the
-- same code runs in Lune (tools/build-world.luau writes world/World.rbxm)
-- and inside Roblox Studio for quick visual checks.
--
-- What the game code reads (everything else is decoration):
--   World.Portal               Model, PrimaryPart "Swirl" (PortalService,
--                              PortalController measure distance to it)
--   World.Islands.IslandN      Model with attribute PlotIndex = N
--     .PlotAnchor              invisible Part on the house floor; PlotService
--                              builds incubators and the showcase on it
--                              (its -Z faces the central island)
--     .ShopStall.Counter.Shop  ProximityPrompt that opens the shop window
--   World.HubSpawn             where players appear and come back after a match

local CELL = 4 -- studs per land tile
local GROUND_Y = 4 -- top of the grass
local DIRT_BOTTOM = -6
local SEA_Y = 0 -- top of the sea

local ISLAND_COUNT = 12
local HUB_RADIUS = 16.5 -- cells
local RING_RADIUS = 128 -- studs from the hub center to an island center
local ISLAND_HALF_W = 7.5 -- cells
local ISLAND_HALF_D = 5.5 -- cells
local BRIDGE_WIDTH = 8

return function(rbx: any): any
	local Instance = rbx.Instance
	local Vector3 = rbx.Vector3
	local CFrame = rbx.CFrame
	local Color3 = rbx.Color3
	local Enum = rbx.Enum
	local UDim2 = rbx.UDim2

	local rgb = Color3.fromRGB
	local C = {
		Grass = rgb(75, 196, 62),
		GrassDark = rgb(52, 160, 52),
		Dirt = rgb(124, 84, 56),
		Foam = rgb(245, 250, 255),
		Sea = rgb(80, 215, 245),
		Pond = rgb(30, 92, 214),
		PondDeep = rgb(22, 70, 180),
		Wood = rgb(124, 80, 50),
		WoodLight = rgb(170, 118, 72),
		WoodDark = rgb(96, 60, 38),
		Rail = rgb(232, 232, 228),
		Leaf = rgb(70, 170, 60),
		LeafLight = rgb(110, 200, 70),
		LeafDark = rgb(46, 130, 48),
		Pine = rgb(120, 190, 80),
		Trunk = rgb(105, 68, 42),
		HouseBlue = rgb(30, 80, 200),
		HouseBlueDark = rgb(22, 58, 150),
		Glass = rgb(150, 205, 255),
		Floor = rgb(210, 220, 235),
		Pad = rgb(120, 220, 90),
		CarRed = rgb(230, 60, 80),
		Stone = rgb(150, 150, 160),
		PortalStone = rgb(90, 60, 170),
		PortalGlow = rgb(170, 90, 255),
		PortalCore = rgb(90, 230, 255),
		Sail = rgb(250, 250, 250),
		Hull = rgb(110, 70, 45),
	}

	-- Deterministic random numbers, the same in Lune and in Studio.
	local seed = 20261011
	local function rand(): number
		seed = (seed * 1103515245 + 12345) % 2147483648
		return seed / 2147483648
	end

	local function part(
		parent: any,
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
		p.Parent = parent
		return p
	end

	local function deco(p: any): any
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		return p
	end

	local function model(parent: any, name: string): any
		local m = Instance.new("Model")
		m.Name = name
		m.Parent = parent
		return m
	end

	local function folder(parent: any, name: string): any
		local f = Instance.new("Folder")
		f.Name = name
		f.Parent = parent
		return f
	end

	local function key(i: number, j: number): string
		return `{i},{j}`
	end

	-- Land: a set of cells, drawn as one grass + dirt slab per row run, with
	-- a white foam rim one cell wider at the water line.
	type Mask = { [string]: boolean }

	local function forRuns(mask: Mask, minI: number, maxI: number, minJ: number, maxJ: number, fn: (number, number, number) -> ())
		for j = minJ, maxJ do
			local start: number? = nil
			for i = minI, maxI + 1 do
				local on = i <= maxI and mask[key(i, j)] == true
				if on and start == nil then
					start = i
				elseif not on and start ~= nil then
					fn(start :: number, i - 1, j)
					start = nil
				end
			end
		end
	end

	local function drawLand(parent: any, origin: any, mask: Mask, holes: Mask, bound: number)
		local grass: Mask = {}
		for k in mask do
			if not holes[k] then
				grass[k] = true
			end
		end
		forRuns(grass, -bound, bound, -bound, bound, function(i0, i1, j)
			local width = (i1 - i0 + 1) * CELL
			local x = (i0 + i1) / 2 * CELL
			part(
				parent,
				"Grass",
				Vector3.new(width, 2, CELL),
				origin * CFrame.new(x, GROUND_Y - 1, j * CELL),
				C.Grass,
				true
			)
		end)
		forRuns(mask, -bound, bound, -bound, bound, function(i0, i1, j)
			local width = (i1 - i0 + 1) * CELL
			local x = (i0 + i1) / 2 * CELL
			local height = GROUND_Y - 2 - DIRT_BOTTOM
			part(
				parent,
				"Dirt",
				Vector3.new(width, height, CELL),
				origin * CFrame.new(x, DIRT_BOTTOM + height / 2, j * CELL),
				C.Dirt
			)
			-- A thin white surf line around the shore.
			deco(
				part(
					parent,
					"Foam",
					Vector3.new(width + 1.6, 0.5, CELL + 1.6),
					origin * CFrame.new(x, SEA_Y + 0.15, j * CELL),
					C.Foam
				)
			)
		end)
	end

	-- Fence along the outline of a mask, skipping edges `skip` rejects.
	local function drawFence(
		parent: any,
		origin: any,
		mask: Mask,
		bound: number,
		skip: (x: number, z: number) -> boolean
	)
		local fence = model(parent, "Fence")
		local inset = 1
		local function segment(a: any, b: any)
			local length = (b - a).Magnitude
			if length < 0.5 then
				return
			end
			local mid = (a + b) / 2
			local frame = origin * CFrame.lookAt(mid, b)
			for _, h in { 1.2, 2.4 } do
				part(fence, "Rail", Vector3.new(0.4, 0.4, length), frame * CFrame.new(0, h, 0), C.Wood)
			end
			local posts = math.max(1, math.floor(length / 6 + 0.5))
			for n = 0, posts do
				local t = n / posts
				local p = a:Lerp(b, t)
				part(
					fence,
					"Post",
					Vector3.new(0.8, 3.2, 0.8),
					origin * CFrame.new(p + Vector3.new(0, 1.6, 0)),
					C.WoodDark
				)
			end
		end
		-- Edges between a land cell and water, merged into straight runs.
		-- dir: the outward side (1 = +X, 2 = -X, 3 = +Z, 4 = -Z).
		for dir = 1, 4 do
			local di = if dir == 1 then 1 elseif dir == 2 then -1 else 0
			local dj = if dir == 3 then 1 elseif dir == 4 then -1 else 0
			local edges: Mask = {}
			for j = -bound, bound do
				for i = -bound, bound do
					if mask[key(i, j)] and not mask[key(i + di, j + dj)] then
						local cx = i * CELL + di * (CELL / 2 - inset)
						local cz = j * CELL + dj * (CELL / 2 - inset)
						if not skip(cx, cz) then
							-- X-facing edges are stored transposed (key(j, i)) so
							-- forRuns merges them along Z.
							if di ~= 0 then
								edges[key(j, i)] = true
							else
								edges[key(i, j)] = true
							end
						end
					end
				end
			end
			forRuns(edges, -bound, bound, -bound, bound, function(a0, a1, line)
				if di ~= 0 then
					-- runs along Z at column `line`
					local x = line * CELL + di * (CELL / 2 - inset)
					segment(
						Vector3.new(x, GROUND_Y, (a0 - 0.5) * CELL + inset),
						Vector3.new(x, GROUND_Y, (a1 + 0.5) * CELL - inset)
					)
				else
					local z = line * CELL + dj * (CELL / 2 - inset)
					segment(
						Vector3.new((a0 - 0.5) * CELL + inset, GROUND_Y, z),
						Vector3.new((a1 + 0.5) * CELL - inset, GROUND_Y, z)
					)
				end
			end)
		end
	end

	local function roundTree(parent: any, at: any, scale: number)
		local m = model(parent, "Tree")
		local s = scale
		part(m, "Trunk", Vector3.new(2, 8, 2) * s, at * CFrame.new(0, 4 * s, 0), C.Trunk)
		part(m, "Leaves", Vector3.new(9, 6, 9) * s, at * CFrame.new(0, 10 * s, 0), C.Leaf, true)
		part(m, "Leaves", Vector3.new(6, 3, 6) * s, at * CFrame.new(0, 14.5 * s, 0), C.LeafLight, true)
		part(m, "Leaves", Vector3.new(4, 4, 4) * s, at * CFrame.new(4.5 * s, 9 * s, 1 * s), C.LeafDark, true)
		part(m, "Leaves", Vector3.new(4, 4, 4) * s, at * CFrame.new(-3 * s, 8.5 * s, -4 * s), C.LeafDark, true)
		return m
	end

	local function pineTree(parent: any, at: any, scale: number)
		local m = model(parent, "Pine")
		local s = scale
		part(m, "Trunk", Vector3.new(1.6, 4, 1.6) * s, at * CFrame.new(0, 2 * s, 0), C.Trunk)
		local y = 4
		for n, w in { 8, 6.5, 5, 3.5, 2 } do
			part(
				m,
				"Leaves",
				Vector3.new(w, 2.6, w) * s,
				at * CFrame.new(0, (y + 1.3) * s, 0),
				if n % 2 == 1 then C.Pine else C.Leaf,
				true
			)
			y += 2.6
		end
		return m
	end

	local function tallTree(parent: any, at: any)
		local m = model(parent, "TallTree")
		part(m, "Trunk", Vector3.new(2.5, 16, 2.5), at * CFrame.new(0, 8, 0), C.Trunk)
		part(m, "Leaves", Vector3.new(11, 7, 11), at * CFrame.new(0, 19, 0), C.LeafDark, true)
		part(m, "Leaves", Vector3.new(8, 4, 8), at * CFrame.new(0, 24.5, 0), C.Leaf, true)
		part(m, "Leaves", Vector3.new(5, 4, 5), at * CFrame.new(5, 17, -2), C.Leaf, true)
		return m
	end

	local world = Instance.new("Model")
	world.Name = "World"

	-- Sea -------------------------------------------------------------------
	local sea = part(world, "Sea", Vector3.new(2048, 8, 2048), CFrame.new(0, SEA_Y - 4, 0), C.Sea)
	sea.Material = Enum.Material.SmoothPlastic
	sea.TopSurface = Enum.SurfaceType.Smooth

	-- Central island ----------------------------------------------------------
	local hub = model(world, "Hub")
	local hubBound = math.ceil(HUB_RADIUS)
	local hubMask: Mask = {}
	for j = -hubBound, hubBound do
		for i = -hubBound, hubBound do
			if (i * i + j * j) <= HUB_RADIUS * HUB_RADIUS then
				hubMask[key(i, j)] = true
			end
		end
	end
	-- Stepped diamond pond, like the reference, north of the portal.
	local pond: Mask = {}
	local pondJ = -4
	for j = -hubBound, hubBound do
		for i = -hubBound, hubBound do
			if math.abs(i) + math.abs(j - pondJ) <= 8 then
				pond[key(i, j)] = true
			end
		end
	end
	drawLand(hub, CFrame.new(0, 0, 0), hubMask, pond, hubBound)
	forRuns(pond, -hubBound, hubBound, -hubBound, hubBound, function(i0, i1, j)
		local deep = math.abs(j - pondJ) <= 3
		local function run(a: number, b: number, color: any, top: number)
			if b < a then
				return
			end
			part(
				hub,
				"Pond",
				Vector3.new((b - a + 1) * CELL, 1, CELL),
				CFrame.new((a + b) / 2 * CELL, top - 0.5, j * CELL),
				color,
				true
			)
		end
		if deep then
			run(i0, math.min(i1, -4), C.Pond, GROUND_Y - 0.6)
			run(math.max(i0, -3), math.min(i1, 3), C.PondDeep, GROUND_Y - 1)
			run(math.max(i0, 4), i1, C.Pond, GROUND_Y - 0.6)
		else
			run(i0, i1, C.Pond, GROUND_Y - 0.6)
		end
	end)
	-- Two white stones by the pond, like in the reference.
	for _, x in { -20, 20 } do
		part(hub, "Stone", Vector3.new(6, 1.4, 4), CFrame.new(x, GROUND_Y + 0.7, 18), C.Foam, true)
	end
	-- Trees on the hub, away from the bridges.
	for n = 0, 5 do
		local angle = math.rad(n * 60 + 15)
		local at = CFrame.new(math.cos(angle) * 54, GROUND_Y, math.sin(angle) * 54)
		if n % 2 == 0 then
			pineTree(hub, at, 0.9)
		else
			roundTree(hub, at, 0.8)
		end
	end

	local spawnPad = part(hub, "SpawnPad", Vector3.new(12, 0.4, 12), CFrame.new(0, GROUND_Y + 0.2, 50), C.Foam, true)
	spawnPad.CanCollide = true
	local hubSpawn = deco(
		part(world, "HubSpawn", Vector3.new(4, 1, 4), CFrame.new(0, GROUND_Y + 3, 46), C.Foam)
	)
	hubSpawn.Transparency = 1

	-- Portal ------------------------------------------------------------------
	local portal = model(world, "Portal")
	local portalBase = CFrame.new(0, GROUND_Y, 28) -- faces +Z (towards the spawn)
	part(portal, "Base", Vector3.new(20, 1, 12), portalBase * CFrame.new(0, 0.5, 0), C.Stone, true)
	part(portal, "Step", Vector3.new(16, 0.6, 3), portalBase * CFrame.new(0, 0.3, 7.5), C.Stone, true)
	for _, x in { -8, 8 } do
		part(portal, "Pillar", Vector3.new(3, 18, 3), portalBase * CFrame.new(x, 10, 0), C.PortalStone, true)
		part(portal, "Cap", Vector3.new(4, 2, 4), portalBase * CFrame.new(x, 20, 0), C.PortalGlow, true)
		part(portal, "Foot", Vector3.new(4, 2, 4), portalBase * CFrame.new(x, 2, 0), C.PortalGlow, true)
	end
	part(portal, "Top", Vector3.new(20, 3, 3), portalBase * CFrame.new(0, 21, 0), C.PortalStone, true)
	part(portal, "Crown", Vector3.new(8, 2, 3), portalBase * CFrame.new(0, 23.5, 0), C.PortalGlow, true)
	local swirl = deco(
		part(portal, "Swirl", Vector3.new(13, 18, 0.6), portalBase * CFrame.new(0, 10, 0), C.PortalGlow)
	)
	swirl.Material = Enum.Material.Neon
	swirl.Transparency = 0.25
	local core = deco(part(portal, "Core", Vector3.new(7, 11, 0.8), portalBase * CFrame.new(0, 9.5, 0), C.PortalCore))
	core.Material = Enum.Material.Neon
	core.Transparency = 0.35
	local ring = deco(part(portal, "Ring", Vector3.new(0.4, 18, 18), portalBase * CFrame.new(0, 1.05, 8) * CFrame.Angles(0, 0, math.rad(90)), C.PortalCore))
	ring.Shape = Enum.PartType.Cylinder
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.75
	portal.PrimaryPart = swirl
	local light = Instance.new("PointLight")
	light.Color = C.PortalGlow
	light.Range = 24
	light.Brightness = 2
	light.Parent = swirl
	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "Sparks"
	sparks.Color = rbx.ColorSequence.new(C.PortalCore, C.PortalGlow)
	sparks.Size = rbx.NumberSequence.new(0.6, 0)
	sparks.Lifetime = rbx.NumberRange.new(1, 1.6)
	sparks.Rate = 25
	sparks.Speed = rbx.NumberRange.new(2, 4)
	sparks.SpreadAngle = rbx.Vector2.new(60, 60)
	sparks.LightEmission = 1
	sparks.Parent = swirl
	local sign = Instance.new("BillboardGui")
	sign.Name = "Sign"
	sign.Size = UDim2.fromScale(14, 4)
	sign.StudsOffset = Vector3.new(0, 15, 0)
	sign.MaxDistance = 220
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

	-- Player islands ----------------------------------------------------------
	local islands = folder(world, "Islands")
	local bridges = folder(world, "Bridges")
	local islandBound = math.ceil(ISLAND_HALF_W) + 1
	local islandMask: Mask = {}
	for j = -islandBound, islandBound do
		for i = -islandBound, islandBound do
			local u = i / ISLAND_HALF_W
			local v = j / ISLAND_HALF_D
			if u * u + v * v <= 1.05 then
				islandMask[key(i, j)] = true
			end
		end
	end

	local function house(parent: any, floor: any)
		local m = model(parent, "House")
		local w, d = 30, 24
		local h1, h2 = 9, 8
		part(m, "Floor", Vector3.new(w, 0.6, d), floor * CFrame.new(0, -0.3, 0), C.Floor, true)
		-- Pillars at the corners and the middle of each long side.
		for _, x in { -w / 2 + 0.8, 0, w / 2 - 0.8 } do
			for _, z in { -d / 2 + 0.8, d / 2 - 0.8 } do
				if x == 0 and z < 0 then
					continue -- keep the entrance free
				end
				part(m, "Pillar", Vector3.new(1.6, h1 + h2 + 1, 1.6), floor * CFrame.new(x, (h1 + h2 + 1) / 2, z), C.HouseBlue)
			end
		end
		-- Upper floor (blue glass) and the roof.
		local mid = part(m, "UpperFloor", Vector3.new(w, 1, d), floor * CFrame.new(0, h1 + 0.5, 0), C.HouseBlue, true)
		mid.Transparency = 0.15
		part(m, "Roof", Vector3.new(w + 2, 1.6, d + 2), floor * CFrame.new(0, h1 + h2 + 1.8, 0), C.HouseBlue, true)
		part(m, "RoofTrim", Vector3.new(w + 2.4, 0.6, d + 2.4), floor * CFrame.new(0, h1 + h2 + 0.9, 0), C.HouseBlueDark)
		-- Glass walls: back and sides on both floors; the front stays open
		-- downstairs and has a low glass rail upstairs.
		local function glass(size: any, cf: any)
			local g = part(m, "Glass", size, floor * cf, C.Glass)
			g.Material = Enum.Material.Glass
			g.Transparency = 0.6
			return g
		end
		local wallH = h1 + h2 + 1
		glass(Vector3.new(w - 1.6, wallH, 0.4), CFrame.new(0, wallH / 2, d / 2 - 0.8))
		glass(Vector3.new(0.4, wallH, d - 1.6), CFrame.new(-w / 2 + 0.8, wallH / 2, 0))
		glass(Vector3.new(0.4, wallH, d - 1.6), CFrame.new(w / 2 - 0.8, wallH / 2, 0))
		glass(Vector3.new(w - 1.6, 3, 0.4), CFrame.new(0, h1 + 2.5, -d / 2 + 0.8))
		-- Upstairs: green pet pads and a red car, like the reference.
		for n = 0, 5 do
			local x = (n % 3 - 1) * 8
			local z = if n < 3 then 4 else -3
			part(m, "Pad", Vector3.new(5, 0.3, 3.5), floor * CFrame.new(x, h1 + 1.15, z), C.Pad, true)
		end
		local car = model(m, "Car")
		part(car, "Body", Vector3.new(7, 1.6, 3.6), floor * CFrame.new(0, h1 + 2, -8), C.CarRed, true)
		part(car, "Cabin", Vector3.new(3.6, 1.2, 3.2), floor * CFrame.new(-0.4, h1 + 3.4, -8), C.CarRed)
		for _, x in { -2.4, 2.4 } do
			for _, z in { -1.9, 1.9 } do
				local wheel = part(car, "Wheel", Vector3.new(0.6, 1.4, 1.4), floor * CFrame.new(x, h1 + 1.5, -8 + z), rgb(30, 30, 35))
				wheel.Shape = Enum.PartType.Cylinder
				wheel.CFrame = floor * CFrame.new(x, h1 + 1.5, -8 + z) * CFrame.Angles(0, math.rad(90), 0)
			end
		end
		return m
	end

	local function shopStall(parent: any, at: any)
		local m = model(parent, "ShopStall")
		local counter = part(m, "Counter", Vector3.new(7, 3, 2.5), at * CFrame.new(0, 1.5, 0), C.WoodLight, true)
		for _, x in { -3.2, 3.2 } do
			part(m, "Post", Vector3.new(0.6, 7, 0.6), at * CFrame.new(x, 3.5, 1), C.WoodDark)
		end
		for n = 0, 5 do
			part(
				m,
				"Awning",
				Vector3.new(8 / 6, 0.4, 4),
				at * CFrame.new(-4 + 8 / 12 + n * 8 / 6, 7.2, 0) * CFrame.Angles(math.rad(-12), 0, 0),
				if n % 2 == 0 then C.CarRed else C.Foam
			)
		end
		local board = Instance.new("BillboardGui")
		board.Name = "Sign"
		board.Size = UDim2.fromScale(7, 2)
		board.StudsOffset = Vector3.new(0, 7.5, 0)
		board.MaxDistance = 90
		board.Parent = counter
		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.TextScaled = true
		text.Font = Enum.Font.FredokaOne
		text.Text = "SHOP"
		text.TextColor3 = rgb(255, 230, 90)
		text.TextStrokeTransparency = 0
		text.Parent = board
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "Shop"
		prompt.ActionText = "Open shop"
		prompt.ObjectText = "Shop"
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.RequiresLineOfSight = false
		prompt.MaxActivationDistance = 9
		prompt.Parent = counter
		return m
	end

	local frontHalfD = ISLAND_HALF_D * CELL
	for index = 1, ISLAND_COUNT do
		-- Island 1 sits right behind the portal; the rest go around the ring.
		local angle = math.rad(-90 + (index - 1) * 360 / ISLAND_COUNT)
		local position = Vector3.new(math.cos(angle) * RING_RADIUS, 0, math.sin(angle) * RING_RADIUS)
		-- -Z of the island faces the hub.
		local origin = CFrame.lookAt(position, Vector3.new(0, 0, 0))
		local island = model(islands, `Island{index}`)
		island:SetAttribute("PlotIndex", index)

		drawLand(island, origin, islandMask, {}, islandBound)
		drawFence(island, origin, islandMask, islandBound, function(x, z)
			-- Gap in front for the bridge.
			return z < 0 and math.abs(x) < BRIDGE_WIDTH / 2 + 1.5
		end)

		local floor = origin * CFrame.new(0, GROUND_Y + 0.3, 2)
		house(island, floor)
		local anchor = deco(part(island, "PlotAnchor", Vector3.new(4, 0.2, 4), floor, C.Floor))
		anchor.Transparency = 1
		anchor:SetAttribute("PlotIndex", index)

		-- Trees in the corners: a big leafy one and pines, varied per island.
		local ground = origin * CFrame.new(0, GROUND_Y, 0)
		local flip = if index % 2 == 0 then -1 else 1
		if rand() < 0.5 then
			tallTree(island, ground * CFrame.new(-21 * flip, 0, 9))
		else
			roundTree(island, ground * CFrame.new(-21 * flip, 0, 9), 1)
		end
		pineTree(island, ground * CFrame.new(21 * flip, 0, 9), 1)
		pineTree(island, ground * CFrame.new(-21 * flip, 0, -8), 0.8)
		roundTree(island, ground * CFrame.new(-24 * flip, 0, 0), 0.6)

		shopStall(island, ground * CFrame.new(14 * flip, 0, -15) * CFrame.Angles(0, math.rad(180), 0))

		-- Bridge from the island's front edge to the hub shore.
		local bridge = model(bridges, `Bridge{index}`)
		local outward = position.Unit
		local fromR = HUB_RADIUS * CELL - 4
		local toR = RING_RADIUS - frontHalfD + 4
		local length = toR - fromR
		local center = outward * ((fromR + toR) / 2)
		local frame = CFrame.lookAt(
			Vector3.new(center.X, GROUND_Y, center.Z),
			Vector3.new(outward.X * toR, GROUND_Y, outward.Z * toR)
		)
		local planks = math.floor(length / 1.5)
		for n = 0, planks - 1 do
			local z = -length / 2 + (n + 0.5) * length / planks
			part(
				bridge,
				"Plank",
				Vector3.new(BRIDGE_WIDTH, 0.6, length / planks - 0.15),
				frame * CFrame.new(0, 0.3, z),
				if n % 2 == 0 then C.WoodLight else C.Wood
			)
		end
		part(bridge, "Beam", Vector3.new(BRIDGE_WIDTH - 1, 1, length), frame * CFrame.new(0, -0.5, 0), C.WoodDark)
		for _, side in { -1, 1 } do
			local x = side * (BRIDGE_WIDTH / 2 - 0.3)
			part(bridge, "Rail", Vector3.new(0.5, 0.5, length), frame * CFrame.new(x, 3, 0), C.Rail)
			local posts = math.floor(length / 5)
			for n = 0, posts do
				local z = -length / 2 + n * length / posts
				part(bridge, "Post", Vector3.new(0.6, 3.2, 0.6), frame * CFrame.new(x, 1.6, z), C.Rail)
			end
		end
	end

	-- Decor: ships far out and rowboats near the hub -------------------------
	local decor = folder(world, "Decor")
	local function ship(at: any)
		local m = model(decor, "Ship")
		part(m, "Hull", Vector3.new(12, 5, 34), at * CFrame.new(0, 1, 0), C.Hull)
		part(m, "Bow", Vector3.new(8, 5, 8), at * CFrame.new(0, 1, -19) * CFrame.Angles(0, math.rad(45), 0), C.Hull)
		part(m, "Deck", Vector3.new(11, 0.6, 33), at * CFrame.new(0, 3.8, 0), C.WoodLight)
		for _, z in { -7, 7 } do
			part(m, "Mast", Vector3.new(1, 26, 1), at * CFrame.new(0, 16, z), C.WoodDark)
			for n, w in { 14, 12, 9 } do
				part(m, "Sail", Vector3.new(w, 5.5, 0.4), at * CFrame.new(0, 7 + n * 6, z), C.Sail)
			end
		end
		return m
	end
	for n, angleDeg in { 200, 250, 290, 340, 60, 120 } do
		local a = math.rad(angleDeg)
		local r = 320 + n * 18
		local at = CFrame.new(math.cos(a) * r, SEA_Y, math.sin(a) * r) * CFrame.Angles(0, a + math.rad(90), 0)
		ship(at)
	end
	local function boat(at: any)
		local m = model(decor, "Boat")
		part(m, "Hull", Vector3.new(3, 1, 7), at * CFrame.new(0, 0.3, 0), C.Hull)
		part(m, "Seat", Vector3.new(3, 0.3, 1), at * CFrame.new(0, 0.9, 0), C.WoodLight)
		return m
	end
	boat(CFrame.new(-82, SEA_Y, 30) * CFrame.Angles(0, math.rad(30), 0))
	boat(CFrame.new(78, SEA_Y, 48) * CFrame.Angles(0, math.rad(-60), 0))
	boat(CFrame.new(10, SEA_Y, -84) * CFrame.Angles(0, math.rad(80), 0))

	return world
end
