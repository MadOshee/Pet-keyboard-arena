--!strict
-- Clones pet and egg models from ReplicatedStorage.Assets (the asset packs)
-- for client-only display. Returns nil when a model is missing, and callers
-- then draw a simple placeholder, so the game runs without the packs too.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EggConfig = require(ReplicatedStorage.Shared.Config.EggConfig)
local PetConfig = require(ReplicatedStorage.Shared.Config.PetConfig)

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

-- The direction a model faces, in its pivot's space and flattened to the
-- ground plane. Pack pets mark their front with a "FaceDecal" decal.
function AssetModels.LocalFront(model: Model): Vector3
	local pivot = model:GetPivot()
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Decal") and descendant.Name == "FaceDecal" then
			local part = descendant.Parent
			if part and part:IsA("BasePart") then
				local world = part.CFrame:VectorToWorldSpace(Vector3.FromNormalId(descendant.Face))
				local flat = pivot:VectorToObjectSpace(world) * Vector3.new(1, 0, 1)
				if flat.Magnitude > 0.01 then
					return flat.Unit
				end
			end
		end
	end
	return Vector3.new(0, 0, -1)
end

-- Rotation that turns a model's own front into -Z (CFrame.LookVector).
function AssetModels.FrontCorrection(model: Model): CFrame
	return CFrame.lookAt(Vector3.zero, AssetModels.LocalFront(model)):Inverse()
end

-- Scales a model so its height is about `height` studs.
function AssetModels.FitHeight(model: Model, height: number)
	local size = model:GetExtentsSize()
	if size.Y > 0 then
		model:ScaleTo(model:GetScale() * height / size.Y)
	end
end

-- Shows `model` (or a colored ball when nil) inside a ViewportFrame that
-- fills `parent`, seen from the model's front.
function AssetModels.Viewport(
	parent: GuiObject,
	model: Model?,
	fallbackColor: Color3
): ViewportFrame
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "Preview"
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.BackgroundTransparency = 1
	viewport.Ambient = Color3.fromRGB(200, 200, 200)
	viewport.LightColor = Color3.new(1, 1, 1)

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

	local center, size = shown:GetBoundingBox()
	local distance = math.max(size.X, size.Y, size.Z) * 1.4
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	camera.CFrame =
		CFrame.lookAt(center.Position + Vector3.new(0.35, 0.3, -1).Unit * distance, center.Position)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	viewport.Parent = parent
	return viewport
end

return AssetModels
