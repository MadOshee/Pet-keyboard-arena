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
--
-- A participant who leaves the arena (knocked over the edge by a bat or
-- walked off) keeps flying for FallSeconds, then drops in again from above
-- their team's side (Respawned signal, ArenaRespawn to the player).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ArenaConfig = require(ReplicatedStorage.Shared.Config.ArenaConfig)
local TeamColors = require(ReplicatedStorage.Shared.Config.TeamColors)
local ArenaGrid = require(ReplicatedStorage.Shared.Logic.ArenaGrid)
local SpawnSlots = require(ReplicatedStorage.Shared.Logic.SpawnSlots)
local Types = require(ReplicatedStorage.Shared.Types)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local Participant = require(script.Parent.Parent.Util.Participant)
local MovementGuard = require(script.Parent.MovementGuard)
local NetService = require(script.Parent.NetService)
local StatsService = require(script.Parent.StatsService)

local KEY_TAG = "ArenaKey"

export type RoundScore = {
	Red: number,
	Blue: number,
	KeysPainted: { [Participant.Participant]: number },
}

local ArenaService = {}

-- (participant) put back above the arena after falling off it.
ArenaService.Respawned = Signal.new() :: Signal.Signal<Participant.Participant>

local keyParts: { BasePart } = {}
local keyRects: { ArenaGrid.KeyRect } = {}
local keyBaseColors: { Color3 } = {}
local keyIndex: ArenaGrid.KeyIndex
local keyTeams: { [number]: Types.TeamId } = {}
local keyMaterials: { Enum.Material } = {}
local keyLockedUntil: { [number]: number } = {} -- locked keys keep their team
local keyTopY = 0
local bounds = { MinX = 0, MaxX = 0, MinZ = 0, MaxZ = 0, CenterZ = 0 }
local respawnRandom = Random.new()

local participants: { [Participant.Participant]: Types.TeamId } = {}
local paintRadius: { [Participant.Participant]: number } = {}
local paintBlockedUntil: { [Participant.Participant]: number } = {}
local keysPainted: { [Participant.Participant]: number } = {}
local offArenaSince: { [Participant.Participant]: number } = {}
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
	bounds = { MinX = minX, MaxX = maxX, MinZ = minZ, MaxZ = maxZ, CenterZ = (minZ + maxZ) / 2 }
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
local function paintKey(
	index: number,
	team: Types.TeamId,
	painter: Participant.Participant?
): boolean
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
	if painter then
		keysPainted[painter] = (keysPainted[painter] or 0) + 1
	end
	scoreDirty = true
	return true
end

local function returnToSpawn(participant: Participant.Participant, team: Types.TeamId)
	local character = Participant.Character(participant)
	if character then
		character:PivotTo(ArenaService:GetTeamSpawn(team))
	end
	local player = Participant.AsPlayer(participant)
	if player then
		MovementGuard:Reset(player)
	end
end

local function isOffArena(position: Vector3): boolean
	local margin = ArenaConfig.EdgeMargin
	return position.X < bounds.MinX - margin
		or position.X > bounds.MaxX + margin
		or position.Z < bounds.MinZ - margin
		or position.Z > bounds.MaxZ + margin
		or position.Y < keyTopY - ArenaConfig.FallDepth
end

-- Drops a participant who fell off back in from above their team's side.
local function respawnAbove(participant: Participant.Participant, team: Types.TeamId)
	local character = Participant.Character(participant)
	local root = Participant.Root(participant)
	if character == nil or root == nil then
		return
	end
	local spread = (bounds.MaxZ - bounds.MinZ) * 0.6
	local offset =
		Vector3.new(0, ArenaConfig.RespawnHeight, (respawnRandom:NextNumber() - 0.5) * spread)
	local rootPart = root :: BasePart
	local model = character :: Model
	model:PivotTo(ArenaService:GetTeamSpawn(team) + offset)
	-- Bots are simulated here; a player's own client stops its fall.
	rootPart.AssemblyLinearVelocity = Vector3.zero
	local player = Participant.AsPlayer(participant)
	if player then
		MovementGuard:Reset(player)
		NetService:FireClient("ArenaRespawn", player)
	end
	ArenaService.Respawned:Fire(participant)
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
	for participant: Participant.Participant, team: Types.TeamId in participants do
		local root = Participant.Root(participant)
		if root == nil then
			continue
		end
		local position = (root :: BasePart).Position
		if isOffArena(position) then
			local since = offArenaSince[participant]
			if since == nil then
				offArenaSince[participant] = now
				local fallen = Participant.AsPlayer(participant)
				if fallen then
					NetService:FireClient("ArenaFell", fallen)
				end
			elseif now - since >= ArenaConfig.FallSeconds then
				offArenaSince[participant] = nil
				respawnAbove(participant, team)
			end
			continue
		end
		offArenaSince[participant] = nil
		if now < (paintBlockedUntil[participant] or 0) then
			continue
		end
		-- Bots move on the server, so only players need the speed check.
		local player = Participant.AsPlayer(participant)
		local humanoid = Participant.Humanoid(participant)
		if player and humanoid then
			local verdict = MovementGuard:Check(player, position, humanoid.WalkSpeed)
			if verdict == "Return" then
				returnToSpawn(participant, team)
				continue
			elseif verdict == "Skip" then
				continue
			end
		end
		if position.Y - keyTopY > ArenaConfig.MaxPaintHeight then
			continue
		end

		local radius = paintRadius[participant] or ArenaConfig.BasePaintRadius
		ArenaGrid.ForEachKeyInRadiusIndexed(
			keyIndex,
			position.X,
			position.Z,
			radius,
			function(index)
				paintKey(index, team, participant)
			end
		)
	end
end

local function syncScore()
	ReplicatedStorage:SetAttribute("ScoreRed", scoreRed)
	ReplicatedStorage:SetAttribute("ScoreBlue", scoreBlue)
	-- The HUD shows each team's share of the whole arena.
	ReplicatedStorage:SetAttribute("ScoreTotal", #keyParts)
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
		offArenaSince[player] = nil
	end)
end

-- Back to the unpainted gray board, with the score at 0.
function ArenaService:ClearBoard()
	resetKeys()
	syncScore()
end

-- Clears the board and starts painting for the given participants.
-- `teams` holds players and bots.
function ArenaService:BeginRound(teams: { [Participant.Participant]: Types.TeamId })
	resetKeys()
	syncScore()
	table.clear(participants)
	table.clear(keysPainted)
	table.clear(paintRadius)
	table.clear(paintBlockedUntil)
	table.clear(offArenaSince)
	for participant: Participant.Participant, team: Types.TeamId in teams do
		participants[participant] = team
		local player = Participant.AsPlayer(participant)
		if player then
			-- Pets cannot change during a round, so the radius is fixed here.
			paintRadius[participant] = StatsService:GetPaintRadius(player)
			MovementGuard:Reset(player)
		end
	end
	active = true
end

-- Stops painting and returns the final score. Painted keys keep their
-- colors through Results so players can see the result.
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
-- Keys count toward `painter`'s contribution when given.
function ArenaService:PaintArea(
	team: Types.TeamId,
	x: number,
	z: number,
	radius: number,
	painter: Participant.Participant?
)
	if not active then
		return
	end
	ArenaGrid.ForEachKeyInRadiusIndexed(keyIndex, x, z, radius, function(index)
		paintKey(index, team, painter)
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
function ArenaService:BlockPainting(participant: Participant.Participant, untilTime: number)
	paintBlockedUntil[participant] = untilTime
	-- The flight is faster than walking; the speed check starts over after it.
	local player = Participant.AsPlayer(participant)
	if player then
		MovementGuard:Reset(player)
	end
end

function ArenaService:IsPaintBlocked(participant: Participant.Participant): boolean
	return os.clock() < (paintBlockedUntil[participant] or 0)
end

-- Picks a key for a bot to walk to: the nearest of a few random keys that
-- `team` does not own yet (any key when all sampled ones are owned).
function ArenaService:FindKeyToPaint(
	team: Types.TeamId,
	from: Vector3,
	random: Random,
	samples: number
): Vector3
	local bestIndex = random:NextInteger(1, #keyParts)
	local bestDistance = math.huge
	for _ = 1, samples do
		local index = random:NextInteger(1, #keyParts)
		if keyTeams[index] ~= team then
			local rect = keyRects[index]
			local dx, dz = rect.CenterX - from.X, rect.CenterZ - from.Z
			local distance = dx * dx + dz * dz
			if distance < bestDistance then
				bestIndex, bestDistance = index, distance
			end
		end
	end
	local rect = keyRects[bestIndex]
	return Vector3.new(rect.CenterX, keyTopY, rect.CenterZ)
end

-- Top of a random key, for spawning power-ups.
function ArenaService:GetRandomKeyTop(random: Random): Vector3
	local part = keyParts[random:NextInteger(1, #keyParts)]
	return Vector3.new(part.Position.X, keyTopY, part.Position.Z)
end

-- Middle of the board: where arena-server players wait for their match.
function ArenaService:GetWaitingSpot(): CFrame
	return CFrame.new((bounds.MinX + bounds.MaxX) / 2, keyTopY + 3, bounds.CenterZ)
end

function ArenaService:GetTeamSpawn(team: Types.TeamId): CFrame
	local inset = ArenaConfig.KeyUnit
	local x = if team == "Red" then bounds.MinX + inset else bounds.MaxX - inset
	local position = Vector3.new(x, keyTopY + 3, bounds.CenterZ)
	local lookAt = Vector3.new((bounds.MinX + bounds.MaxX) / 2, position.Y, bounds.CenterZ)
	return CFrame.lookAt(position, lookAt)
end

-- Spot `index` of `count` teammates at the start of a match, spread over
-- the team's side (Logic/SpawnSlots), facing the middle.
function ArenaService:GetTeamSpawnSlot(team: Types.TeamId, index: number, count: number): CFrame
	local slot = SpawnSlots.Get(index, count, bounds.MaxZ - bounds.MinZ)
	local x = if team == "Red" then bounds.MinX + slot.Inward else bounds.MaxX - slot.Inward
	local position = Vector3.new(x, keyTopY + 3, bounds.CenterZ + slot.Along)
	local lookAt = Vector3.new((bounds.MinX + bounds.MaxX) / 2, position.Y, position.Z)
	return CFrame.lookAt(position, lookAt)
end

return ArenaService
