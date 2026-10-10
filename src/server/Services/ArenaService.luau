--!strict
-- Owns the keyboard arena: builds the keys, runs the server-side paint tick
-- and keeps the score (docs/design.md 4.3 "Покраска", section 8).
-- Clients never report painting: the server reads character positions and
-- paints the keys within the brush radius (base radius plus pet PaintRadius
-- from StatsService).
--
-- Keys are any BaseParts tagged "ArenaKey" under Workspace.Arena. If none
-- exist, a placeholder keyboard is generated, so an art model from the asset
-- packs can replace it later just by tagging its keys.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ArenaConfig = require(ReplicatedStorage.Shared.Config.ArenaConfig)
local TeamColors = require(ReplicatedStorage.Shared.Config.TeamColors)
local ArenaGrid = require(ReplicatedStorage.Shared.Logic.ArenaGrid)
local Types = require(ReplicatedStorage.Shared.Types)
local MovementGuard = require(script.Parent.MovementGuard)
local StatsService = require(script.Parent.StatsService)

local KEY_TAG = "ArenaKey"

export type RoundScore = {
	Red: number,
	Blue: number,
	KeysPainted: { [Player]: number },
}

local ArenaService = {}

local keyParts: { BasePart } = {}
local keyRects: { ArenaGrid.KeyRect } = {}
local keyBaseColors: { Color3 } = {}
local keyIndex: ArenaGrid.KeyIndex
local keyTeams: { [number]: Types.TeamId } = {}
local keyMaterials: { Enum.Material } = {}
local keyLockedUntil: { [number]: number } = {} -- locked keys keep their team
local keyTopY = 0
local bounds = { MinX = 0, MaxX = 0, CenterZ = 0 }

local participants: { [Player]: Types.TeamId } = {}
local paintRadius: { [Player]: number } = {}
local paintBlockedUntil: { [Player]: number } = {}
local keysPainted: { [Player]: number } = {}
local scoreRed, scoreBlue = 0, 0
local active = false
local scoreDirty = false

local function buildPlaceholderKeyboard(folder: Folder)
	local keys = ArenaGrid.KeyboardLayout(ArenaConfig.KeyUnit, ArenaConfig.KeyGap)
	for index, spec in keys do
		local part = Instance.new("Part")
		part.Name = `Key{index}_{spec.Label}`
		part.Anchored = true
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Size = Vector3.new(spec.SizeX, ArenaConfig.KeyHeight, spec.SizeZ)
		part.Position = Vector3.new(
			ArenaConfig.CenterX + spec.CenterX,
			ArenaConfig.KeyHeight / 2,
			ArenaConfig.CenterZ + spec.CenterZ
		)

		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Top
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 20
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Text = spec.Label
		label.TextScaled = true
		label.Font = Enum.Font.FredokaOne
		label.TextColor3 = TeamColors.KeyLabel
		label.Parent = gui
		gui.Parent = part

		CollectionService:AddTag(part, KEY_TAG)
		part.Parent = folder
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
		buildPlaceholderKeyboard(folder)
		keysFolder = folder
	end

	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	for _, instance in CollectionService:GetTagged(KEY_TAG) do
		if instance:IsA("BasePart") and instance:IsDescendantOf(arena) then
			local position = instance.Position
			local half = instance.Size / 2
			table.insert(keyParts, instance)
			table.insert(keyMaterials, instance.Material)
			-- Art keys keep their own color between rounds via a "BaseColor" attribute.
			local baseColor = instance:GetAttribute("BaseColor")
			table.insert(
				keyBaseColors,
				if typeof(baseColor) == "Color3" then baseColor else TeamColors.Neutral
			)
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
	keyIndex = ArenaGrid.BuildIndex(keyRects, ArenaConfig.IndexCellSize)
end

local function unlockKey(index: number)
	keyLockedUntil[index] = nil
	keyParts[index].Material = keyMaterials[index]
end

local function resetKeys()
	table.clear(keyTeams)
	for index in keyLockedUntil do
		unlockKey(index)
	end
	for index, part in keyParts do
		part.Color = keyBaseColors[index]
	end
	scoreRed, scoreBlue = 0, 0
	scoreDirty = true
end

-- Paints one key for `team`. Locked keys of the other team stay as they
-- are. Returns true when the key changed hands.
local function paintKey(index: number, team: Types.TeamId, player: Player?): boolean
	local previous = keyTeams[index]
	if previous == team then
		return false
	end
	if previous ~= nil and keyLockedUntil[index] then
		return false
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
	if player then
		keysPainted[player] = (keysPainted[player] or 0) + 1
	end
	scoreDirty = true
	return true
end

local function getRoot(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if root == nil or not root:IsA("BasePart") or humanoid == nil or humanoid.Health <= 0 then
		return nil
	end
	return root :: BasePart
end

local function returnToSpawn(player: Player, team: Types.TeamId)
	local character = player.Character
	if character then
		character:PivotTo(ArenaService:GetTeamSpawn(team))
		MovementGuard:Reset(player)
	end
end

local function paintTick()
	local now = os.clock()
	for index, untilTime in keyLockedUntil do
		if now >= untilTime then
			unlockKey(index)
		end
	end

	-- Loop variables are annotated: the type checker widens singleton
	-- string types read from tables otherwise.
	for player: Player, team: Types.TeamId in participants do
		local root = getRoot(player)
		if root == nil or now < (paintBlockedUntil[player] or 0) then
			continue
		end
		local rootPart = root :: BasePart
		local position = rootPart.Position
		local humanoid = (player.Character :: Model):FindFirstChildOfClass("Humanoid") :: Humanoid
		local verdict = MovementGuard:Check(player, position, humanoid.WalkSpeed)
		if verdict == "Return" then
			returnToSpawn(player, team)
			continue
		elseif verdict == "Skip" then
			continue
		end
		if position.Y - keyTopY > ArenaConfig.MaxPaintHeight then
			continue
		end

		local radius = paintRadius[player] or ArenaConfig.BasePaintRadius
		ArenaGrid.ForEachKeyInRadiusIndexed(
			keyIndex,
			position.X,
			position.Z,
			radius,
			function(index)
				paintKey(index, team, player)
			end
		)
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
		paintRadius[player] = nil
		paintBlockedUntil[player] = nil
	end)
end

-- Clears the board and starts painting for the given participants.
function ArenaService:BeginRound(teams: { [Player]: Types.TeamId })
	resetKeys()
	syncScore()
	table.clear(participants)
	table.clear(keysPainted)
	table.clear(paintRadius)
	table.clear(paintBlockedUntil)
	for player: Player, team: Types.TeamId in teams do
		participants[player] = team
		-- Pets cannot change during a round, so the radius is fixed here.
		paintRadius[player] = StatsService:GetPaintRadius(player)
		MovementGuard:Reset(player)
	end
	active = true
end

-- Stops painting and returns the final score. Painted keys keep their
-- colors until the next round so players can see the result.
function ArenaService:EndRound(): RoundScore
	active = false
	for index in keyLockedUntil do
		unlockKey(index)
	end
	syncScore()
	local result: RoundScore = {
		Red = scoreRed,
		Blue = scoreBlue,
		KeysPainted = table.clone(keysPainted),
	}
	table.clear(participants)
	return result
end

-- Paints every key within `radius` of (x, z) for `team` (paint bomb).
-- Keys count toward `player`'s contribution when given.
function ArenaService:PaintArea(
	team: Types.TeamId,
	x: number,
	z: number,
	radius: number,
	player: Player?
)
	if not active then
		return
	end
	ArenaGrid.ForEachKeyInRadiusIndexed(keyIndex, x, z, radius, function(index)
		paintKey(index, team, player)
	end)
end

-- Locks `team`'s keys within `radius` of (x, z): the other team cannot
-- repaint them for `seconds`. Locked keys glow.
function ArenaService:LockArea(
	team: Types.TeamId,
	x: number,
	z: number,
	radius: number,
	seconds: number
)
	if not active then
		return
	end
	local untilTime = os.clock() + seconds
	ArenaGrid.ForEachKeyInRadiusIndexed(keyIndex, x, z, radius, function(index)
		if keyTeams[index] == team then
			keyLockedUntil[index] = math.max(keyLockedUntil[index] or 0, untilTime)
			keyParts[index].Material = Enum.Material.Neon
		end
	end)
end

-- A blocked participant (knocked out by a bat) paints nothing until then.
function ArenaService:BlockPainting(player: Player, untilTime: number)
	paintBlockedUntil[player] = untilTime
end

function ArenaService:IsPaintBlocked(player: Player): boolean
	return os.clock() < (paintBlockedUntil[player] or 0)
end

-- Top of a random key, for spawning power-ups.
function ArenaService:GetRandomKeyTop(random: Random): Vector3
	local part = keyParts[random:NextInteger(1, #keyParts)]
	return Vector3.new(part.Position.X, keyTopY, part.Position.Z)
end

function ArenaService:GetTeamSpawn(team: Types.TeamId): CFrame
	local inset = ArenaConfig.KeyUnit
	local x = if team == "Red" then bounds.MinX + inset else bounds.MaxX - inset
	local position = Vector3.new(x, keyTopY + 3, bounds.CenterZ)
	local lookAt = Vector3.new(ArenaConfig.CenterX, position.Y, bounds.CenterZ)
	return CFrame.lookAt(position, lookAt)
end

return ArenaService
