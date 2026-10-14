--!strict
-- Bots fill empty team seats (docs/design.md 4.3 "Боты", D6). A bot is a
-- server-owned R15 character in Workspace.Bots. Twice a second it walks to
-- a nearby key its team does not own (sometimes to a power-up) with
-- Humanoid:MoveTo, and swings its bat at an enemy in reach at most every
-- few seconds. Bots run at the base speed and have no pets.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ArenaConfig = require(ReplicatedStorage.Shared.Config.ArenaConfig)
local BatConfig = require(ReplicatedStorage.Shared.Config.BatConfig)
local TeamColors = require(ReplicatedStorage.Shared.Config.TeamColors)
local Types = require(ReplicatedStorage.Shared.Types)
local Nameplate = require(script.Parent.Parent.Util.Nameplate)
local Participant = require(script.Parent.Parent.Util.Participant)
local ArenaService = require(script.Parent.ArenaService)
local BatService = require(script.Parent.BatService)
local PowerUpService = require(script.Parent.PowerUpService)

local THINK_INTERVAL = 0.5
local KEY_SAMPLES = 24 -- random keys looked at when picking a target
local POWER_UP_CHANCE = 0.3
local POWER_UP_RANGE = 30
local RETARGET_SECONDS = 3
local STUCK_SECONDS = 2
local STUCK_DISTANCE = 1
local ARRIVE_DISTANCE = 2
local SWING_INTERVAL = 3 -- bots swing at most this often
local SWING_REACH = BatConfig.BotReach
local SPAWN_SPREAD = 12
-- Default Roblox R15 walk animation; bots glide if it fails to load.
local WALK_ANIMATION = "rbxassetid://507777826"

type Bot = {
	Model: Model,
	Team: Types.TeamId,
	Target: Vector3?,
	TargetSetAt: number,
	ProgressFrom: Vector3,
	ProgressAt: number,
	NextSwingAt: number,
	Walk: AnimationTrack?,
}

local BotService = {}

local random = Random.new()
local folder: Folder
local bots: { Bot } = {}
local running = false
local nameCounter = 0

local function makeModel(team: Types.TeamId): Model
	local color = TeamColors.ForTeam(team)
	local description = Instance.new("HumanoidDescription")
	description.HeadColor = color
	description.TorsoColor = color
	description.LeftArmColor = color
	description.RightArmColor = color
	description.LeftLegColor = color:Lerp(Color3.new(0, 0, 0), 0.3)
	description.RightLegColor = color:Lerp(Color3.new(0, 0, 0), 0.3)
	local model = Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	description:Destroy()

	nameCounter += 1
	model.Name = `Bot{nameCounter}`
	model:SetAttribute("Team", team)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayName = `Bot {nameCounter}`
		humanoid.WalkSpeed = 0
	end
	-- Same tag as players, in the team color, without a level.
	local plate = Nameplate.Attach(model)
	if plate then
		Nameplate.Set(plate, `Bot {nameCounter}`, nil, color)
	end
	return model
end

local function loadWalk(model: Model): AnimationTrack?
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if animator == nil then
		return nil
	end
	local animation = Instance.new("Animation")
	animation.AnimationId = WALK_ANIMATION
	local ok, track = pcall(function()
		return (animator :: Animator):LoadAnimation(animation)
	end)
	if ok and track then
		track.Looped = true
		return track
	end
	return nil
end

local function spawnBot(team: Types.TeamId): Bot
	local model = makeModel(team)
	local offset = Vector3.new(0, 0, (random:NextNumber() - 0.5) * SPAWN_SPREAD)
	model:PivotTo(ArenaService:GetTeamSpawn(team) + offset)
	model.Parent = folder
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		root:SetNetworkOwner(nil)
	end
	local now = os.clock()
	return {
		Model = model,
		Team = team,
		Target = nil,
		TargetSetAt = 0,
		ProgressFrom = model:GetPivot().Position,
		ProgressAt = now,
		NextSwingAt = now + random:NextNumber() * SWING_INTERVAL,
		Walk = loadWalk(model),
	}
end

local function pickTarget(bot: Bot, from: Vector3): Vector3
	if random:NextNumber() < POWER_UP_CHANCE then
		local best, bestDistance = nil, POWER_UP_RANGE
		for _, position in PowerUpService:GetActivePositions() do
			local distance = (position - from).Magnitude
			if distance < bestDistance then
				best, bestDistance = position, distance
			end
		end
		if best then
			return best
		end
	end
	return ArenaService:FindKeyToPaint(bot.Team, from, random, KEY_SAMPLES)
end

-- Swings when an enemy that can be hit is within reach, after turning to it.
local function trySwing(
	bot: Bot,
	root: BasePart,
	enemies: { [Participant.Participant]: Types.TeamId },
	now: number
)
	if now < bot.NextSwingAt then
		return
	end
	local nearest: BasePart? = nil
	local nearestDistance = SWING_REACH
	for enemy: Participant.Participant, team: Types.TeamId in enemies do
		if team ~= bot.Team and BatService:CanBeHit(enemy) then
			local enemyRoot = Participant.Root(enemy)
			if enemyRoot then
				local distance = ((enemyRoot.Position - root.Position) * Vector3.new(1, 0, 1)).Magnitude
				if distance < nearestDistance then
					nearest, nearestDistance = enemyRoot, distance
				end
			end
		end
	end
	if nearest == nil then
		return
	end
	local target = (nearest :: BasePart).Position
	root.CFrame = CFrame.lookAt(root.Position, Vector3.new(target.X, root.Position.Y, target.Z))
	bot.NextSwingAt = now + SWING_INTERVAL
	BatService:Swing(bot.Model)
end

local function think(everyone: { [Participant.Participant]: Types.TeamId })
	local now = os.clock()
	for _, bot in bots do
		local root = Participant.Root(bot.Model)
		local humanoid = Participant.Humanoid(bot.Model)
		if root == nil or humanoid == nil or BatService:IsKnockedOut(bot.Model) then
			continue
		end
		local rootPart = root :: BasePart
		local position = rootPart.Position

		trySwing(bot, rootPart, everyone, now)

		if (position - bot.ProgressFrom).Magnitude >= STUCK_DISTANCE then
			bot.ProgressFrom = position
			bot.ProgressAt = now
		end
		local target = bot.Target
		local arrived = target ~= nil
			and ((target :: Vector3 - position) * Vector3.new(1, 0, 1)).Magnitude
				< ARRIVE_DISTANCE
		local stuck = now - bot.ProgressAt > STUCK_SECONDS
		if target == nil or arrived or stuck or now - bot.TargetSetAt > RETARGET_SECONDS then
			target = pickTarget(bot, position)
			bot.Target = target
			bot.TargetSetAt = now
			bot.ProgressAt = now
		end
		(humanoid :: Humanoid):MoveTo(target :: Vector3)
	end
end

local currentTeams: { [Participant.Participant]: Types.TeamId } = {}

function BotService:Init()
	folder = Instance.new("Folder")
	folder.Name = "Bots"
	folder.Parent = workspace
end

function BotService:Start()
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		if not running then
			return
		end
		elapsed += dt
		if elapsed >= THINK_INTERVAL then
			elapsed = 0
			think(currentTeams)
		end
	end)
end

-- Creates the bots for the coming round on their team spawns, frozen until
-- BeginRound. Returns each bot model with its team.
function BotService:Spawn(redCount: number, blueCount: number): { [Model]: Types.TeamId }
	BotService:Despawn()
	local result: { [Model]: Types.TeamId } = {}
	for _ = 1, redCount do
		local bot = spawnBot("Red")
		table.insert(bots, bot)
		result[bot.Model] = "Red"
	end
	for _ = 1, blueCount do
		local bot = spawnBot("Blue")
		table.insert(bots, bot)
		result[bot.Model] = "Blue"
	end
	return result
end

-- Starts the bots. `everyone` holds players and bots, for finding enemies.
function BotService:BeginRound(everyone: { [Participant.Participant]: Types.TeamId })
	currentTeams = everyone
	for _, bot in bots do
		local humanoid = Participant.Humanoid(bot.Model)
		if humanoid then
			humanoid.WalkSpeed = ArenaConfig.BaseWalkSpeed
		end
		if bot.Walk then
			(bot.Walk :: AnimationTrack):Play()
		end
	end
	running = true
end

function BotService:Despawn()
	running = false
	currentTeams = {}
	for _, bot in bots do
		bot.Model:Destroy()
	end
	table.clear(bots)
end

return BotService
