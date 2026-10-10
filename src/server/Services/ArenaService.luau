--!strict
-- Owns the keyboard arena: builds the keys, runs the server-side paint tick
-- and keeps the score (docs/design.md 4.3 "Покраска", section 8).
-- Clients never report painting: the server reads character positions and
-- paints the keys within the brush radius.
--
-- Keys are any BaseParts tagged "ArenaKey" under Workspace.Arena. If none
-- exist, the keyboard is generated from the key model in
-- ReplicatedStorage.Assets (plain parts if the model is missing).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ArenaConfig = require(ReplicatedStorage.Shared.Config.ArenaConfig)
local TeamColors = require(ReplicatedStorage.Shared.Config.TeamColors)
local ArenaGrid = require(ReplicatedStorage.Shared.Logic.ArenaGrid)
local Types = require(ReplicatedStorage.Shared.Types)

local KEY_TAG = "ArenaKey"

export type RoundScore = {
	Red: number,
	Blue: number,
	KeysPainted: { [Player]: number },
}

local ArenaService = {}

local keyParts: { BasePart } = {}
local keyRects: { ArenaGrid.KeyRect } = {}
local keyTeams: { [number]: Types.TeamId } = {}
local keyTopY = 0
local bounds = { MinX = 0, MaxX = 0, CenterZ = 0 }

local participants: { [Player]: Types.TeamId } = {}
local keysPainted: { [Player]: number } = {}
local scoreRed, scoreBlue = 0, 0
local active = false
local scoreDirty = false

-- The key model from the asset pack (assets/Key.rbxm). Without it the arena
-- falls back to plain parts.
local function findKeyTemplate(): BasePart?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local template = assets and assets:FindFirstChild("Key")
	if template and template:IsA("BasePart") then
		return template
	end
	return nil
end

local function makeKeyPart(template: BasePart?): BasePart
	if template then
		local part = template:Clone()
		-- The mesh key is visual only and sinks when pressed (client side);
		-- players stand on the invisible floor built under the keys.
		part.CanCollide = false
		return part
	end
	local part = Instance.new("Part")
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

local function setKeyLabel(part: BasePart, text: string)
	local surface: SurfaceGui
	local existingGui = part:FindFirstChild("Top")
	if existingGui and existingGui:IsA("SurfaceGui") then
		surface = existingGui
	else
		surface = Instance.new("SurfaceGui")
		surface.Name = "Top"
		surface.Parent = part
	end
	surface.Face = Enum.NormalId.Top
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 20

	local letter: TextLabel
	local existingLabel = surface:FindFirstChild("Letter")
	if existingLabel and existingLabel:IsA("TextLabel") then
		letter = existingLabel
	else
		letter = Instance.new("TextLabel")
		letter.Name = "Letter"
		letter.Parent = surface
	end
	letter.BackgroundTransparency = 1
	letter.Size = UDim2.fromScale(1, 1)
	letter.Text = text
	letter.TextScaled = true
	letter.TextTransparency = 0
	letter.Visible = true
	letter.Font = Enum.Font.FredokaOne
	letter.TextColor3 = TeamColors.KeyLabel
end

local function buildKeyboard(folder: Folder)
	local template = findKeyTemplate()
	local keys = ArenaGrid.KeyboardLayout(ArenaConfig.KeyUnit, ArenaConfig.KeyGap)
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	for index, spec in keys do
		local part = makeKeyPart(template)
		part.Name = `Key{index}_{spec.Label}`
		part.Anchored = true
		part.Size = Vector3.new(spec.SizeX, ArenaConfig.KeyHeight, spec.SizeZ)
		local x = ArenaConfig.CenterX + spec.CenterX
		local z = ArenaConfig.CenterZ + spec.CenterZ
		part.CFrame = CFrame.new(x, ArenaConfig.KeyHeight / 2, z)
		setKeyLabel(part, spec.Label)

		minX = math.min(minX, x - spec.SizeX / 2)
		maxX = math.max(maxX, x + spec.SizeX / 2)
		minZ = math.min(minZ, z - spec.SizeZ / 2)
		maxZ = math.max(maxZ, z + spec.SizeZ / 2)

		CollectionService:AddTag(part, KEY_TAG)
		part.Parent = folder
	end

	if template then
		-- One invisible slab at key-top height that players walk on.
		local margin = ArenaConfig.KeyGap
		local floor = Instance.new("Part")
		floor.Name = "Floor"
		floor.Anchored = true
		floor.Transparency = 1
		floor.CanQuery = false
		floor.CanTouch = false
		floor.Size = Vector3.new(maxX - minX + margin * 2, 1, maxZ - minZ + margin * 2)
		floor.CFrame = CFrame.new((minX + maxX) / 2, ArenaConfig.KeyHeight - 0.5, (minZ + maxZ) / 2)
		floor.Parent = folder.Parent
	end
end

local function collectKeys()
	local arena = workspace:FindFirstChild("Arena")
	if arena == nil then
		arena = Instance.new("Folder")
		arena.Name = "Arena"
		arena.Parent = workspace
	end
	local keysFolder = arena:FindFirstChild("Keys")
	if keysFolder == nil then
		local folder = Instance.new("Folder")
		folder.Name = "Keys"
		folder.Parent = arena
		buildKeyboard(folder)
		keysFolder = folder
	end

	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	for _, instance in CollectionService:GetTagged(KEY_TAG) do
		if instance:IsA("BasePart") and instance:IsDescendantOf(arena) then
			local position = instance.Position
			local half = instance.Size / 2
			table.insert(keyParts, instance)
			table.insert(keyRects, {
				CenterX = position.X,
				CenterZ = position.Z,
				HalfX = half.X,
				HalfZ = half.Z,
			})
			keyTopY = math.max(keyTopY, position.Y + half.Y)
			minX = math.min(minX, position.X - half.X)
			maxX = math.max(maxX, position.X + half.X)
			minZ = math.min(minZ, position.Z - half.Z)
			maxZ = math.max(maxZ, position.Z + half.Z)
		end
	end

	if #keyParts == 0 then
		error("ArenaService: no ArenaKey parts found under Workspace.Arena")
	end
	bounds = { MinX = minX, MaxX = maxX, CenterZ = (minZ + maxZ) / 2 }
end

local function resetKeys()
	table.clear(keyTeams)
	for _, part in keyParts do
		part.Color = TeamColors.Neutral
	end
	scoreRed, scoreBlue = 0, 0
	scoreDirty = true
end

local function paintTick()
	local radius = ArenaConfig.BasePaintRadius
	-- Loop variables are annotated: the type checker widens singleton
	-- string types read from tables otherwise.
	for player: Player, team: Types.TeamId in participants do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root == nil or not root:IsA("BasePart") or humanoid == nil or humanoid.Health <= 0 then
			continue
		end

		local position = (root :: BasePart).Position
		if position.Y - keyTopY > ArenaConfig.MaxPaintHeight then
			continue
		end

		ArenaGrid.ForEachKeyInRadius(keyRects, position.X, position.Z, radius, function(index)
			local previous = keyTeams[index]
			if previous == team then
				return
			end
			if previous == "Red" then
				scoreRed -= 1
			elseif previous == "Blue" then
				scoreBlue -= 1
			end
			if team == "Red" then
				scoreRed += 1
			else
				scoreBlue += 1
			end
			keyTeams[index] = team
			keyParts[index].Color = TeamColors.ForTeam(team)
			keysPainted[player] = (keysPainted[player] or 0) + 1
			scoreDirty = true
		end)
	end
end

local function syncScore()
	ReplicatedStorage:SetAttribute("ScoreRed", scoreRed)
	ReplicatedStorage:SetAttribute("ScoreBlue", scoreBlue)
	scoreDirty = false
end

function ArenaService:Init()
	collectKeys()
	resetKeys()
	syncScore()
end

function ArenaService:Start()
	local paintInterval = 1 / ArenaConfig.PaintTickRate
	local scoreInterval = 1 / ArenaConfig.ScoreSyncRate
	local paintElapsed, scoreElapsed = 0, 0

	RunService.Heartbeat:Connect(function(dt)
		if not active then
			return
		end
		paintElapsed += dt
		if paintElapsed >= paintInterval then
			paintElapsed = 0
			paintTick()
		end
		scoreElapsed += dt
		if scoreDirty and scoreElapsed >= scoreInterval then
			scoreElapsed = 0
			syncScore()
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		participants[player] = nil
	end)
end

-- Clears the board and starts painting for the given participants.
function ArenaService:BeginRound(teams: { [Player]: Types.TeamId })
	resetKeys()
	syncScore()
	table.clear(participants)
	table.clear(keysPainted)
	for player: Player, team: Types.TeamId in teams do
		participants[player] = team
	end
	active = true
end

-- Stops painting and returns the final score. Painted keys keep their
-- colors until the next round so players can see the result.
function ArenaService:EndRound(): RoundScore
	active = false
	syncScore()
	local result: RoundScore = {
		Red = scoreRed,
		Blue = scoreBlue,
		KeysPainted = table.clone(keysPainted),
	}
	table.clear(participants)
	return result
end

function ArenaService:GetTeamSpawn(team: Types.TeamId): CFrame
	local inset = ArenaConfig.KeyUnit
	local x = if team == "Red" then bounds.MinX + inset else bounds.MaxX - inset
	local position = Vector3.new(x, keyTopY + 3, bounds.CenterZ)
	local lookAt = Vector3.new(ArenaConfig.CenterX, position.Y, bounds.CenterZ)
	return CFrame.lookAt(position, lookAt)
end

return ArenaService
