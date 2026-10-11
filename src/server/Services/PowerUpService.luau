--!strict
-- Arena power-ups (docs/design.md 4.3 "Бонусы на арене"): one appears on a
-- random key every few seconds during Playing, at most MaxActive at once.
-- The server decides pickups by distance; clients never ask to pick up.
-- Knocked-out participants cannot pick anything up.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PowerUpConfig = require(ReplicatedStorage.Shared.Config.PowerUpConfig)
local Types = require(ReplicatedStorage.Shared.Types)
local ArenaService = require(script.Parent.ArenaService)
local NetService = require(script.Parent.NetService)
local StatsService = require(script.Parent.StatsService)

local CHECK_INTERVAL = 0.1
local FLOAT_HEIGHT = 2.5
local SIZE = 2.5

type Active = {
	Kind: string,
	Part: BasePart,
}

local PowerUpService = {}

local random = Random.new()
local folder: Folder
local participants: { [Player]: Types.TeamId } = {}
local active: { Active } = {}
local running = false
local roundToken = 0
local spawnElapsed = 0

local function makePart(kind: string, position: Vector3): BasePart
	local part = Instance.new("Part")
	part.Name = kind
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(SIZE, SIZE, SIZE)
	part.Material = Enum.Material.Neon
	part.Color = PowerUpConfig.Colors[kind] or Color3.new(1, 1, 1)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Position = position
	part:SetAttribute("PowerUp", kind)

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromScale(4, 1.2)
	billboard.StudsOffset = Vector3.new(0, SIZE, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 120
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = part.Color
	label.TextStrokeTransparency = 0.2
	label.Text = PowerUpConfig.Labels[kind] or kind
	label.Parent = billboard
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

local function applySpeed(player: Player, token: number)
	StatsService:SetSpeedBoost(player, PowerUpConfig.SpeedMultiplier, PowerUpConfig.SpeedSeconds)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = StatsService:GetWalkSpeed(player)
	end
	task.delay(PowerUpConfig.SpeedSeconds, function()
		-- GetWalkSpeed still includes a newer boost that has not ended.
		if token ~= roundToken or participants[player] == nil then
			return
		end
		local current = player.Character
		local currentHumanoid = current and current:FindFirstChildOfClass("Humanoid")
		if currentHumanoid then
			currentHumanoid.WalkSpeed = StatsService:GetWalkSpeed(player)
		end
	end)
end

local function apply(player: Player, team: Types.TeamId, kind: string, position: Vector3)
	if kind == "Speed" then
		applySpeed(player, roundToken)
	elseif kind == "PaintBomb" then
		ArenaService:PaintArea(team, position.X, position.Z, PowerUpConfig.BombRadius, player)
	elseif kind == "Lock" then
		ArenaService:LockArea(
			team,
			position.X,
			position.Z,
			PowerUpConfig.LockRadius,
			PowerUpConfig.LockSeconds
		)
	end
	NetService:FireAllClients("PowerUpEvent", kind, player.UserId, position)
end

local function checkPickups()
	local radiusSquared = PowerUpConfig.PickupRadius * PowerUpConfig.PickupRadius
	for player: Player, team: Types.TeamId in participants do
		if ArenaService:IsPaintBlocked(player) then
			continue
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root == nil or not root:IsA("BasePart") then
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
				apply(player, team, powerUp.Kind, position)
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

function PowerUpService:BeginRound(teams: { [Player]: Types.TeamId })
	roundToken += 1
	spawnElapsed = 0
	clearActive()
	table.clear(participants)
	for player: Player, team: Types.TeamId in teams do
		participants[player] = team
	end
	running = true
end

function PowerUpService:EndRound()
	roundToken += 1
	running = false
	clearActive()
	for player in participants do
		StatsService:ClearSpeedBoost(player)
	end
	table.clear(participants)
end

return PowerUpService
