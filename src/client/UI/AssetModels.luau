--!strict
-- Clones pet and egg models from ReplicatedStorage.Assets (the asset packs)
-- for client-only display. Returns nil when a model is missing, and callers
-- then draw a simple placeholder, so the game runs without the packs too.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EggConfig = require(ReplicatedStorage.Shared.Config.EggConfig)
local PetConfig = require(ReplicatedStorage.Shared.Config.PetConfig)
local ModelFront = require(ReplicatedStorage.Shared.Util.ModelFront)

local AssetModels = {}

local function findTemplate(folderName: string, modelName: string): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild(folderName)
	local model = folder and folder:FindFirstChild(modelName)
	if model and model:IsA("Model") then
		return model
	end
	return nil
end

-- Display copies never collide, fall or block clicks and raycasts, and
-- pivot around their center so placing them is predictable.
local function prepare(model: Model): Model
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.CastShadow = false
		elseif descendant:IsA("Script") or descendant:IsA("LocalScript") then
			descendant:Destroy()
		end
	end
	model.PrimaryPart = nil
	model.WorldPivot = model:GetBoundingBox()
	return model
end

function AssetModels.Pet(kind: string): Model?
	local entry = PetConfig.Pets[kind]
	local template = entry and findTemplate("Pets", entry.Model)
	return if template then prepare(template:Clone()) else nil
end

function AssetModels.Egg(theme: string): Model?
	local template = findTemplate("Eggs", EggConfig.ModelName(theme))
	return if template then prepare(template:Clone()) else nil
end

-- The direction a model faces (see Shared/Util/ModelFront).
function AssetModels.LocalFront(model: Model): Vector3
	return ModelFront.LocalFront(model)
end

-- Rotation that turns a model's own front into -Z (CFrame.LookVector).
function AssetModels.FrontCorrection(model: Model): CFrame
	return ModelFront.Correction(model)
end

-- Scales a model so its height is about `height` studs.
function AssetModels.FitHeight(model: Model, height: number)
	local size = model:GetExtentsSize()
	if size.Y > 0 then
		model:ScaleTo(model:GetScale() * height / size.Y)
	end
end

-- Where the camera looks from, relative to the model's center: front,
-- slightly right and above.
local VIEW_DIRECTION = Vector3.new(0.25, 0.2, -1).Unit
local FIELD_OF_VIEW = 40
-- Room around the model, so it never touches the frame's edge.
local MARGIN = 1.04

local directions: { [ViewportFrame]: Vector3 } = setmetatable({}, { __mode = "k" }) :: any

-- Moves the camera so every corner of every part of the model fits the
-- viewport at its current width / height (the parts' boxes hug the model
-- tighter than the model's own box).
local function fit(viewport: ViewportFrame)
	local camera = viewport.CurrentCamera
	local found = viewport:FindFirstChildOfClass("Model")
	if not (camera and found) then
		return
	end
	local model = found :: Model
	local pixels = viewport.AbsoluteSize
	local aspect = if pixels.X > 0 and pixels.Y > 0 then pixels.X / pixels.Y else 1
	-- Corners of the visible parts (an invisible root or hitbox is left out).
	local corners: { Vector3 } = {}
	local function addBox(box: CFrame, size: Vector3)
		for _, x in { -0.5, 0.5 } do
			for _, y in { -0.5, 0.5 } do
				for _, z in { -0.5, 0.5 } do
					table.insert(corners, box:PointToWorldSpace(size * Vector3.new(x, y, z)))
				end
			end
		end
	end
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part.Transparency < 1 then
			addBox(part.CFrame, part.Size)
		end
	end
	if #corners == 0 then
		local box, size = model:GetBoundingBox()
		addBox(box, size)
	end
	local low, high = corners[1], corners[1]
	for _, corner in corners do
		low, high = low:Min(corner), high:Max(corner)
	end
	local center = (low + high) / 2

	local back = directions[viewport] or VIEW_DIRECTION
	local view = CFrame.lookAt(Vector3.zero, -back)
	local tanY = math.tan(math.rad(camera.FieldOfView / 2))
	local tanX = tanY * aspect
	local need = 0
	for _, corner in corners do
		local offset = corner - center
		local depth = offset:Dot(back)
		need = math.max(
			need,
			depth + math.abs(offset:Dot(view.RightVector)) / tanX,
			depth + math.abs(offset:Dot(view.UpVector)) / tanY
		)
	end
	camera.CFrame = CFrame.lookAt(center + back * need * MARGIN, center)
end

-- Frames the viewport's model again, for example after turning it.
-- `direction` points from the model to the camera (default: the front).
function AssetModels.Frame(viewport: ViewportFrame, direction: Vector3?)
	if direction then
		directions[viewport] = direction.Unit
	end
	fit(viewport)
end

-- Shows `model` (or a colored ball when nil) inside a ViewportFrame that
-- fills `parent`, seen from the model's front and fitted inside it.
function AssetModels.Viewport(
	parent: GuiObject,
	model: Model?,
	fallbackColor: Color3
): ViewportFrame
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "Preview"
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.BackgroundTransparency = 1
	-- Light from the camera's side and less flat ambient: clearer shapes.
	viewport.Ambient = Color3.fromRGB(165, 165, 165)
	viewport.LightColor = Color3.new(1, 1, 1)
	viewport.LightDirection = Vector3.new(-0.3, -1, 0.6).Unit

	local shown: Model = model or Instance.new("Model")
	if model == nil then
		local ball = Instance.new("Part")
		ball.Shape = Enum.PartType.Ball
		ball.Size = Vector3.new(3, 3, 3)
		ball.Color = fallbackColor
		ball.Material = Enum.Material.SmoothPlastic
		ball.Anchored = true
		ball.Parent = shown
	end
	shown:PivotTo(CFrame.new() * AssetModels.FrontCorrection(shown))
	shown.Parent = viewport

	local camera = Instance.new("Camera")
	camera.FieldOfView = FIELD_OF_VIEW
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	viewport.Parent = parent
	viewport:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		fit(viewport)
	end)
	fit(viewport)
	return viewport
end

return AssetModels
