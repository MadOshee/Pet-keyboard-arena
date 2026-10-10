--!strict
-- The bat (docs/design.md 4.3 "Бита", D11). A swing request carries no
-- target: the server finds the nearest enemy in front of the attacker from
-- server positions. A hit knocks the victim out: they cannot paint or pick
-- up power-ups, clients play the flight, and after KnockoutSeconds the
-- server puts them back on their team spawn with a short immunity.
-- Every participant holds a bat model (welded to the hand) during a round.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BatConfig = require(ReplicatedStorage.Shared.Config.BatConfig)
local BatTargeting = require(ReplicatedStorage.Shared.Logic.BatTargeting)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local Types = require(ReplicatedStorage.Shared.Types)
local Participant = require(script.Parent.Parent.Util.Participant)
local ArenaService = require(script.Parent.ArenaService)
local MovementGuard = require(script.Parent.MovementGuard)
local NetService = require(script.Parent.NetService)

local BAT_NAME = "Bat"
local SPAWN_SPREAD = 12 -- studs along the spawn line, so returns do not stack

local BatService = {}

-- (attacker, victim); each is a Player or a bot Model.
BatService.KnockedOut =
	Signal.new() :: Signal.Signal<Participant.Participant, Participant.Participant>

local random = Random.new()
local participants: { [Participant.Participant]: Types.TeamId } = {}
local nextSwingAt: { [Participant.Participant]: number } = {}
local knockedUntil: { [Participant.Participant]: number } = {}
local immuneUntil: { [Participant.Participant]: number } = {}
local roundToken = 0
local active = false

local function removeBat(participant: Participant.Participant)
	local character = Participant.Character(participant)
	local bat = character and character:FindFirstChild(BAT_NAME)
	if bat then
		bat:Destroy()
	end
end

-- Welds a copy of Assets.Bat to the character's right hand (R15 or R6).
-- Without the asset nobody holds a visible bat, but swings still work.
local function giveBat(participant: Participant.Participant)
	local character = Participant.Character(participant)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local template = assets and assets:FindFirstChild(BAT_NAME)
	local gripFound = character and character:FindFirstChild("RightGripAttachment", true)
	local handFound = gripFound and gripFound.Parent
	if
		character == nil
		or character:FindFirstChild(BAT_NAME)
		or template == nil
		or not template:IsA("Model")
		or gripFound == nil
		or not gripFound:IsA("Attachment")
		or handFound == nil
		or not handFound:IsA("BasePart")
	then
		return
	end
	-- The type checker does not narrow after an early return, hence the casts.
	local gripAttachment = gripFound :: Attachment
	local hand = handFound :: BasePart

	local bat = (template :: Model):Clone()
	local handleFound = bat.PrimaryPart
	local batGripFound = handleFound and handleFound:FindFirstChild("Grip")
	if handleFound == nil or batGripFound == nil or not batGripFound:IsA("Attachment") then
		bat:Destroy()
		return
	end
	local handle = handleFound :: BasePart
	local batGrip = batGripFound :: Attachment

	for _, descendant in bat:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.Massless = true
		end
	end
	-- The bat's long axis is its X axis; turn it to point up from the grip.
	local weld = Instance.new("Weld")
	weld.Name = "BatGrip"
	weld.Part0 = hand
	weld.Part1 = handle
	weld.C0 = gripAttachment.CFrame * CFrame.Angles(0, -math.pi / 2, 0)
	weld.C1 = batGrip.CFrame
	weld.Parent = handle
	bat.Name = BAT_NAME
	bat.Parent = character
end

local function returnToSpawn(victim: Participant.Participant, token: number)
	if token ~= roundToken or not active then
		return
	end
	local team: Types.TeamId? = participants[victim]
	knockedUntil[victim] = nil
	if team == nil or not Participant.IsPresent(victim) then
		return
	end
	local character = Participant.Character(victim)
	if character then
		local offset = Vector3.new(0, 0, (random:NextNumber() - 0.5) * SPAWN_SPREAD)
		character:PivotTo(ArenaService:GetTeamSpawn(team :: Types.TeamId) + offset)
	end
	local player = Participant.AsPlayer(victim)
	if player then
		MovementGuard:Reset(player)
	end
	immuneUntil[victim] = os.clock() + BatConfig.ImmunitySeconds
end

local function knock(
	attacker: Participant.Participant,
	victim: Participant.Participant,
	attackerRoot: BasePart,
	victimRoot: BasePart
)
	local now = os.clock()
	knockedUntil[victim] = now + BatConfig.KnockoutSeconds
	ArenaService:BlockPainting(victim, now + BatConfig.KnockoutSeconds)

	local offset = (victimRoot.Position - attackerRoot.Position) * Vector3.new(1, 0, 1)
	local direction = if offset.Magnitude > 0.01
		then offset.Unit
		else attackerRoot.CFrame.LookVector
	-- A player's client flies its own character; the server flies bots.
	if Participant.AsPlayer(victim) == nil then
		victimRoot.AssemblyLinearVelocity = direction * BatConfig.KnockSpeed
			+ Vector3.new(0, BatConfig.KnockLift, 0)
	end
	NetService:FireAllClients(
		"KnockedOut",
		Participant.Character(victim),
		Participant.Character(attacker),
		direction,
		BatConfig.KnockoutSeconds
	)
	BatService.KnockedOut:Fire(attacker, victim)

	local token = roundToken
	task.delay(BatConfig.KnockoutSeconds, returnToSpawn, victim, token)
end

local function canBeHit(participant: Participant.Participant, now: number): boolean
	return now >= (knockedUntil[participant] or 0) and now >= (immuneUntil[participant] or 0)
end

local function swing(attacker: Participant.Participant)
	local team: Types.TeamId? = participants[attacker]
	if not active or team == nil then
		return
	end
	local now = os.clock()
	if now < (nextSwingAt[attacker] or 0) or now < (knockedUntil[attacker] or 0) then
		return
	end
	local attackerRoot = Participant.Root(attacker)
	if attackerRoot == nil then
		return
	end
	nextSwingAt[attacker] = now + BatConfig.Cooldown
	NetService:FireAllClients("BatSwingFx", Participant.Character(attacker))

	local root = attackerRoot :: BasePart
	local candidates: { BatTargeting.Candidate<Participant.Participant> } = {}
	local roots: { [Participant.Participant]: BasePart } = {}
	for other: Participant.Participant, otherTeam: Types.TeamId in participants do
		if otherTeam ~= team and canBeHit(other, now) then
			local otherRoot = Participant.Root(other)
			if otherRoot then
				roots[other] = otherRoot
				local position = otherRoot.Position
				table.insert(
					candidates,
					{ Id = other, Position = { X = position.X, Y = position.Y, Z = position.Z } }
				)
			end
		end
	end

	local look = root.CFrame.LookVector
	local target = BatTargeting.FindTarget(
		{ X = root.Position.X, Y = root.Position.Y, Z = root.Position.Z },
		{ X = look.X, Y = look.Y, Z = look.Z },
		candidates,
		BatConfig.Range,
		BatConfig.HalfAngle
	)
	if target then
		knock(attacker, target, root, roots[target])
	end
end

function BatService:Init() end

function BatService:Start()
	-- Extra requests are dropped by the server-side cooldown anyway.
	NetService:On("BatSwing", { PerSecond = 4, Burst = 4 }, function(player)
		swing(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		participants[player] = nil
		nextSwingAt[player] = nil
		knockedUntil[player] = nil
		immuneUntil[player] = nil
	end)
end

-- `teams` holds players and bots.
function BatService:BeginRound(teams: { [Participant.Participant]: Types.TeamId })
	roundToken += 1
	table.clear(participants)
	table.clear(nextSwingAt)
	table.clear(knockedUntil)
	table.clear(immuneUntil)
	for participant: Participant.Participant, team: Types.TeamId in teams do
		participants[participant] = team
		giveBat(participant)
	end
	active = true
end

-- Gives the bat again after a participant respawns mid-round.
function BatService:Equip(player: Player)
	if participants[player] then
		giveBat(player)
	end
end

-- Bots swing through here; players use the BatSwing remote.
function BatService:Swing(participant: Participant.Participant)
	swing(participant)
end

function BatService:IsKnockedOut(participant: Participant.Participant): boolean
	return os.clock() < (knockedUntil[participant] or 0)
end

function BatService:CanBeHit(participant: Participant.Participant): boolean
	return canBeHit(participant, os.clock())
end

function BatService:EndRound()
	roundToken += 1
	active = false
	for participant in participants do
		removeBat(participant)
	end
	table.clear(participants)
	table.clear(knockedUntil)
	table.clear(immuneUntil)
end

return BatService
