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
local ArenaService = require(script.Parent.ArenaService)
local MovementGuard = require(script.Parent.MovementGuard)
local NetService = require(script.Parent.NetService)

local BAT_NAME = "Bat"
local SPAWN_SPREAD = 12 -- studs along the spawn line, so returns do not stack

local BatService = {}

-- (attacker, victim)
BatService.KnockedOut = Signal.new() :: Signal.Signal<Player, Player>

local random = Random.new()
local participants: { [Player]: Types.TeamId } = {}
local nextSwingAt: { [Player]: number } = {}
local knockedUntil: { [Player]: number } = {}
local immuneUntil: { [Player]: number } = {}
local roundToken = 0
local active = false

local function getRoot(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if root and root:IsA("BasePart") and humanoid and humanoid.Health > 0 then
		return root
	end
	return nil
end

local function removeBat(player: Player)
	local character = player.Character
	local bat = character and character:FindFirstChild(BAT_NAME)
	if bat then
		bat:Destroy()
	end
end

-- Welds a copy of Assets.Bat to the character's right hand (R15 or R6).
-- Without the asset nobody holds a visible bat, but swings still work.
local function giveBat(player: Player)
	local character = player.Character
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

local function returnToSpawn(victim: Player, token: number)
	if token ~= roundToken or not active then
		return
	end
	local team: Types.TeamId? = participants[victim]
	knockedUntil[victim] = nil
	if team == nil or victim.Parent ~= Players then
		return
	end
	local character = victim.Character
	if character then
		local offset = Vector3.new(0, 0, (random:NextNumber() - 0.5) * SPAWN_SPREAD)
		character:PivotTo(ArenaService:GetTeamSpawn(team :: Types.TeamId) + offset)
		MovementGuard:Reset(victim)
	end
	immuneUntil[victim] = os.clock() + BatConfig.ImmunitySeconds
end

local function knock(attacker: Player, victim: Player, attackerRoot: BasePart, victimRoot: BasePart)
	local now = os.clock()
	knockedUntil[victim] = now + BatConfig.KnockoutSeconds
	ArenaService:BlockPainting(victim, now + BatConfig.KnockoutSeconds)

	local offset = (victimRoot.Position - attackerRoot.Position) * Vector3.new(1, 0, 1)
	local direction = if offset.Magnitude > 0.01
		then offset.Unit
		else attackerRoot.CFrame.LookVector
	NetService:FireAllClients(
		"KnockedOut",
		victim.UserId,
		attacker.UserId,
		direction,
		BatConfig.KnockoutSeconds
	)
	BatService.KnockedOut:Fire(attacker, victim)

	local token = roundToken
	task.delay(BatConfig.KnockoutSeconds, returnToSpawn, victim, token)
end

local function canBeHit(player: Player, now: number): boolean
	return now >= (knockedUntil[player] or 0) and now >= (immuneUntil[player] or 0)
end

local function onSwing(player: Player)
	local team: Types.TeamId? = participants[player]
	if not active or team == nil then
		return
	end
	local now = os.clock()
	if now < (nextSwingAt[player] or 0) or now < (knockedUntil[player] or 0) then
		return
	end
	local attackerRoot = getRoot(player)
	if attackerRoot == nil then
		return
	end
	nextSwingAt[player] = now + BatConfig.Cooldown
	NetService:FireAllClients("BatSwingFx", player.UserId)

	local root = attackerRoot :: BasePart
	local candidates: { BatTargeting.Candidate<Player> } = {}
	local roots: { [Player]: BasePart } = {}
	for other: Player, otherTeam: Types.TeamId in participants do
		if otherTeam ~= team and canBeHit(other, now) then
			local otherRoot = getRoot(other)
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
		knock(player, target, root, roots[target])
	end
end

function BatService:Init() end

function BatService:Start()
	-- Extra requests are dropped by the server-side cooldown anyway.
	NetService:On("BatSwing", { PerSecond = 4, Burst = 4 }, function(player)
		onSwing(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		participants[player] = nil
		nextSwingAt[player] = nil
		knockedUntil[player] = nil
		immuneUntil[player] = nil
	end)
end

function BatService:BeginRound(teams: { [Player]: Types.TeamId })
	roundToken += 1
	table.clear(participants)
	table.clear(nextSwingAt)
	table.clear(knockedUntil)
	table.clear(immuneUntil)
	for player: Player, team: Types.TeamId in teams do
		participants[player] = team
		giveBat(player)
	end
	active = true
end

-- Gives the bat again after a participant respawns mid-round.
function BatService:Equip(player: Player)
	if participants[player] then
		giveBat(player)
	end
end

function BatService:IsKnockedOut(player: Player): boolean
	return os.clock() < (knockedUntil[player] or 0)
end

function BatService:EndRound()
	roundToken += 1
	active = false
	for player in participants do
		removeBat(player)
	end
	table.clear(participants)
	table.clear(knockedUntil)
	table.clear(immuneUntil)
end

return BatService
