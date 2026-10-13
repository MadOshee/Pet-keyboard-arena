--!strict
-- Arena power-ups (docs/design.md 4.3 "Бонусы на арене"): one appears on a
-- random key every few seconds during Playing, at most MaxActive at once.
-- The server decides pickups by distance; clients never ask to pick up.
-- Knocked-out participants cannot pick anything up. Bots can.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PowerUpConfig = require(ReplicatedStorage.Shared.Config.PowerUpConfig)
local ArenaConfig = require(ReplicatedStorage.Shared.Config.ArenaConfig)
local Types = require(ReplicatedStorage.Shared.Types)
local Participant = require(script.Parent.Parent.Util.Participant)
local ArenaService = require(script.Parent.ArenaService)
local NetService = require(script.Parent.NetService)
local StatsService = require(script.Parent.StatsService)

local CHECK_INTERVAL = 0.1
local FLOAT_HEIGHT = 2.5
local SIZE = 2.5
local ICON_STUDS = 4.5

type Active = {
	Kind: string,
	Part: BasePart,
}

local PowerUpService = {}

local random = Random.new()
local folder: Folder
local participants: { [Participant.Participant]: Types.TeamId } = {}
local botBoostEnds: { [Participant.Participant]: number } = {}
local active: { Active } = {}
local running = false
local roundToken = 0
local spawnElapsed = 0

-- Ivan's icons (bomb, shoe, lock) float above the key, always facing the
-- camera. The part itself is invisible and only marks the spot.
local function makePart(kind: string, position: Vector3): BasePart
	local part = Instance.new("Part")
	part.Name = kind
	part.Size = Vector3.new(SIZE, SIZE, SIZE)
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Position = position
	part:SetAttribute("PowerUp", kind)

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Icon"
	billboard.Size = UDim2.fromScale(ICON_STUDS, ICON_STUDS)
	billboard.LightInfluence = 0
	billboard.MaxDistance = 150
	local iconId = PowerUpConfig.Icons[kind] or 0
	if iconId ~= 0 then
		local image = Instance.new("ImageLabel")
		image.Size = UDim2.fromScale(1, 1)
		image.BackgroundTransparency = 1
		image.Image = `rbxassetid://{iconId}`
		image.Parent = billboard
	else
		-- Until the icon is uploaded: the power-up's name.
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 0.3)
		label.Position = UDim2.fromScale(0, 0.35)
		label.BackgroundTransparency = 1
		label.TextScaled = true
		label.Font = Enum.Font.FredokaOne
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextStrokeTransparency = 0.2
		label.Text = kind
		label.Parent = billboard
	end
	billboard.Parent = part

	part.Parent = folder
	return part
end

local function spawnOne()
	if #active >= PowerUpConfig.MaxActive then
		return
	end
	local kind = PowerUpConfig.Kinds[random:NextInteger(1, #PowerUpConfig.Kinds)]
	local position = ArenaService:GetRandomKeyTop(random) + Vector3.new(0, FLOAT_HEIGHT, 0)
	table.insert(active, { Kind = kind, Part = makePart(kind, position) })
end

-- Players get pets plus the boost from StatsService; bots run at base speed.
local function walkSpeedOf(participant: Participant.Participant): number
	local player = Participant.AsPlayer(participant)
	if player then
		return StatsService:GetWalkSpeed(player)
	end
	local boosted = os.clock() < (botBoostEnds[participant] or 0)
	return ArenaConfig.BaseWalkSpeed * (if boosted then PowerUpConfig.SpeedMultiplier else 1)
end

local function applyWalkSpeed(participant: Participant.Participant)
	local humanoid = Participant.Humanoid(participant)
	if humanoid then
		humanoid.WalkSpeed = walkSpeedOf(participant)
	end
end

local function applySpeed(participant: Participant.Participant, token: number)
	local player = Participant.AsPlayer(participant)
	if player then
		StatsService:SetSpeedBoost(
			player,
			PowerUpConfig.SpeedMultiplier,
			PowerUpConfig.SpeedSeconds
		)
	else
		botBoostEnds[participant] = os.clock() + PowerUpConfig.SpeedSeconds
	end
	applyWalkSpeed(participant)
	task.delay(PowerUpConfig.SpeedSeconds, function()
		-- walkSpeedOf still includes a newer boost that has not ended.
		if token == roundToken and participants[participant] ~= nil then
			applyWalkSpeed(participant)
		end
	end)
end

local function apply(
	participant: Participant.Participant,
	team: Types.TeamId,
	kind: string,
	position: Vector3
)
	if kind == "Speed" then
		applySpeed(participant, roundToken)
	elseif kind == "PaintBomb" then
		ArenaService:PaintArea(team, position.X, position.Z, PowerUpConfig.BombRadius, participant)
	elseif kind == "Lock" then
		ArenaService:LockArea(
			team,
			position.X,
			position.Z,
			PowerUpConfig.LockRadius,
			PowerUpConfig.LockSeconds
		)
	end
	NetService:FireAllClients("PowerUpEvent", kind, Participant.UserId(participant), position)
end

local function checkPickups()
	local radiusSquared = PowerUpConfig.PickupRadius * PowerUpConfig.PickupRadius
	for participant: Participant.Participant, team: Types.TeamId in participants do
		local root = Participant.Root(participant)
		if root == nil or ArenaService:IsPaintBlocked(participant) then
			continue
		end
		local rootPosition = (root :: BasePart).Position
		for index = #active, 1, -1 do
			local powerUp = active[index]
			local offset = powerUp.Part.Position - rootPosition
			if offset:Dot(offset) <= radiusSquared then
				table.remove(active, index)
				local position = powerUp.Part.Position
				powerUp.Part:Destroy()
				apply(participant, team, powerUp.Kind, position)
			end
		end
	end
end

local function clearActive()
	for _, powerUp in active do
		powerUp.Part:Destroy()
	end
	table.clear(active)
end

function PowerUpService:Init()
	folder = Instance.new("Folder")
	folder.Name = "ActivePowerUps"
	folder.Parent = workspace
end

function PowerUpService:Start()
	local checkElapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		if not running then
			return
		end
		spawnElapsed += dt
		if spawnElapsed >= PowerUpConfig.SpawnInterval then
			spawnElapsed = 0
			spawnOne()
		end
		checkElapsed += dt
		if checkElapsed >= CHECK_INTERVAL then
			checkElapsed = 0
			checkPickups()
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		participants[player] = nil
	end)
end

-- `teams` holds players and bots.
function PowerUpService:BeginRound(teams: { [Participant.Participant]: Types.TeamId })
	roundToken += 1
	spawnElapsed = 0
	clearActive()
	table.clear(participants)
	table.clear(botBoostEnds)
	for participant: Participant.Participant, team: Types.TeamId in teams do
		participants[participant] = team
	end
	running = true
end

function PowerUpService:EndRound()
	roundToken += 1
	running = false
	clearActive()
	for participant in participants do
		local player = Participant.AsPlayer(participant)
		if player then
			StatsService:ClearSpeedBoost(player)
		end
	end
	table.clear(participants)
	table.clear(botBoostEnds)
end

-- Positions of power-ups on the arena (bots sometimes go for them).
function PowerUpService:GetActivePositions(): { Vector3 }
	local positions = table.create(#active)
	for index, powerUp in active do
		positions[index] = powerUp.Part.Position
	end
	return positions
end

return PowerUpService
