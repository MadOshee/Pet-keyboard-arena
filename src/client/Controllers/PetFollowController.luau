--!strict
-- Draws every player's equipped pets following them (docs/design.md 4.3
-- "Питомцы"). Purely visual and local: each client reads the replicated
-- "EquippedPets" Player attribute and moves its own copies of the models.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PetConfig = require(ReplicatedStorage.Shared.Config.PetConfig)
local PetStyle = require(ReplicatedStorage.Shared.Config.PetStyle)
local AssetModels = require(script.Parent.Parent.UI.AssetModels)

local PET_HEIGHT = 2.2 -- studs
local FOLLOW_DISTANCE = 4.5 -- behind the player
local SPREAD = 3.5 -- sideways gap between pets
local FOLLOW_SPEED = 10 -- higher catches up faster
local BOB_HEIGHT = 0.25
local BOB_SPEED = 4

local PetFollowController = {}

type Pet = {
	Model: Model,
	Correction: CFrame, -- turns the model's front to face forward
	Current: CFrame?,
}

local folder: Folder
local petsByPlayer: { [Player]: { Pet } } = {}

local function placeholder(kind: string): Model
	local entry = PetConfig.Pets[kind]
	local model = Instance.new("Model")
	model.Name = kind
	local ball = Instance.new("Part")
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.new(PET_HEIGHT, PET_HEIGHT, PET_HEIGHT)
	ball.Material = Enum.Material.SmoothPlastic
	ball.Color = entry and PetStyle.Rarity[entry.Rarity] or Color3.new(1, 1, 1)
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanQuery = false
	ball.CanTouch = false
	ball.Parent = model
	model.PrimaryPart = ball
	return model
end

local function clearPets(owner: Player)
	local pets = petsByPlayer[owner]
	if pets then
		for _, pet in pets do
			pet.Model:Destroy()
		end
	end
	petsByPlayer[owner] = nil
end

local function rebuild(owner: Player)
	clearPets(owner)
	local value = owner:GetAttribute("EquippedPets")
	if type(value) ~= "string" or value == "" then
		return
	end
	local pets: { Pet } = {}
	for _, kind in string.split(value :: string, ",") do
		if PetConfig.Pets[kind] == nil then
			continue
		end
		local model = AssetModels.Pet(kind)
		if model then
			AssetModels.FitHeight(model, PET_HEIGHT)
		else
			model = placeholder(kind)
		end
		local shown = model :: Model
		local correction = AssetModels.FrontCorrection(shown)
		shown.Parent = folder
		table.insert(pets, { Model = shown, Correction = correction, Current = nil })
	end
	petsByPlayer[owner] = pets
end

local function watch(owner: Player)
	owner:GetAttributeChangedSignal("EquippedPets"):Connect(function()
		rebuild(owner)
	end)
	rebuild(owner)
end

local function step(dt: number)
	local now = os.clock()
	local alpha = 1 - math.exp(-FOLLOW_SPEED * dt)
	for owner, pets in petsByPlayer do
		local character = owner.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root == nil or not root:IsA("BasePart") then
			continue
		end
		local rootPart = root :: BasePart
		-- Ground level under the character, from the humanoid's hip height.
		local hip = if humanoid then humanoid.HipHeight else 2
		local groundY = rootPart.Position.Y - rootPart.Size.Y / 2 - hip
		local look = rootPart.CFrame.LookVector * Vector3.new(1, 0, 1)
		local forward = if look.Magnitude > 0.01 then look.Unit else Vector3.new(0, 0, -1)
		local right = forward:Cross(Vector3.yAxis)

		for index, pet in pets do
			local side = (index - (#pets + 1) / 2) * SPREAD
			local bob = math.sin(now * BOB_SPEED + index) * BOB_HEIGHT
			local position = rootPart.Position - forward * FOLLOW_DISTANCE + right * side
			position = Vector3.new(position.X, groundY + PET_HEIGHT / 2 + bob, position.Z)
			local target = CFrame.lookAt(position, position + forward)
			local current = pet.Current
			local nextCFrame = if current and (current.Position - position).Magnitude < 40
				then current:Lerp(target, alpha)
				else target
			pet.Current = nextCFrame
			pet.Model:PivotTo(nextCFrame * pet.Correction)
		end
	end
end

function PetFollowController:Init()
	folder = Instance.new("Folder")
	folder.Name = "FollowPets"
	folder.Parent = workspace
end

function PetFollowController:Start()
	Players.PlayerAdded:Connect(watch)
	for _, owner in Players:GetPlayers() do
		watch(owner)
	end
	Players.PlayerRemoving:Connect(clearPets)
	RunService.RenderStepped:Connect(step)
end

return PetFollowController
