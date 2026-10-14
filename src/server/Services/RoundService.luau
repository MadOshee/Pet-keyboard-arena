--!strict
-- The round state machine (docs/design.md 4.3 "Раунд"):
-- Intermission (nobody queued) -> Starting (queue countdown on the hub)
-- -> Countdown (on the arena) -> Playing -> Results -> back to the hub.
-- Players join the queue at the hub portal (PortalService); after the
-- match they leave the queue and return to the hub.
-- Where the match is played depends on MatchMode: a "Local" server (Studio)
-- plays every match itself; a "Hub" server only the matches that fell back
-- to it (MatchmakingService:PlaysHere); an "Arena" server waits for its
-- roster (Starting = waiting for players), plays one match and sends
-- everyone back to their hub.
-- Phase and end time replicate as ReplicatedStorage attributes
-- ("RoundPhase", "PhaseEndsAt", "Winner"); each participant's team is the
-- "Team" Player attribute. RoundEnded lets RewardService react without
-- RoundService knowing about rewards.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ArenaConfig = require(ReplicatedStorage.Shared.Config.ArenaConfig)
local MatchConfig = require(ReplicatedStorage.Shared.Config.MatchConfig)
local RoundConfig = require(ReplicatedStorage.Shared.Config.RoundConfig)
local Reward = require(ReplicatedStorage.Shared.Logic.Reward)
local TeamBalancer = require(ReplicatedStorage.Shared.Logic.TeamBalancer)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local Types = require(ReplicatedStorage.Shared.Types)
local LocalMatchSource = require(script.Parent.Parent.Match.LocalMatchSource)
local MatchMode = require(script.Parent.Parent.Match.MatchMode)
local ArenaService = require(script.Parent.ArenaService)
local Participant = require(script.Parent.Parent.Util.Participant)
local ReadyService = require(script.Parent.ReadyService)
local BatService = require(script.Parent.BatService)
local BotService = require(script.Parent.BotService)
local MatchmakingService = require(script.Parent.MatchmakingService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local MovementGuard = require(script.Parent.MovementGuard)
local PowerUpService = require(script.Parent.PowerUpService)
local StatsService = require(script.Parent.StatsService)

export type RoundResult = {
	RoundId: number,
	Winner: Types.Winner,
	Teams: { [Player]: Types.TeamId }, -- players only; bots get no rewards
	KeysPainted: { [Participant.Participant]: number },
}

local RoundService = {}

RoundService.PhaseChanged = Signal.new() :: Signal.Signal<Types.RoundPhase>
RoundService.RoundEnded = Signal.new() :: Signal.Signal<RoundResult>

local phase: Types.RoundPhase = "Intermission"
local teams: { [Player]: Types.TeamId } = {}
local botCounts = { Red = 0, Blue = 0 }
-- Each player's start spot this match (ArenaService:GetTeamSpawnSlot).
local slots: { [Player]: CFrame } = {}
local roundId = 0

-- During the countdown a player only jumps in place (Ivan 2026-10-14): one
-- who drifts this far from their spot, or drops this far below it, is put
-- back. The client also stops sideways motion (MovementController).
local HOLD_RADIUS = 3
local HOLD_DROP = 6

local function setPhase(newPhase: Types.RoundPhase, duration: number)
	phase = newPhase
	ReplicatedStorage:SetAttribute("RoundPhase", newPhase)
	ReplicatedStorage:SetAttribute("PhaseEndsAt", workspace:GetServerTimeNow() + duration)
	RoundService.PhaseChanged:Fire(newPhase)
end

local function getHumanoid(player: Player): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function setWalkSpeed(player: Player, speed: number)
	local humanoid = getHumanoid(player)
	if humanoid then
		humanoid.WalkSpeed = speed
	end
end

local function teleport(player: Player, cframe: CFrame, spread: boolean)
	local character = player.Character
	if character and character.PrimaryPart then
		-- Spread players a little so they do not stack on one point.
		local offset = if spread
			then Vector3.new(0, 0, (math.random() - 0.5) * 12)
			else Vector3.zero
		character:PivotTo(cframe + offset)
		MovementGuard:Reset(player)
	end
end

local function lobbyCFrame(): CFrame
	return CFrame.new(ArenaConfig.LobbyX, ArenaConfig.LobbyY, ArenaConfig.LobbyZ)
end

local function placeOnArena(player: Player)
	local team: Types.TeamId? = teams[player]
	if team == nil then
		return
	end
	local slot = slots[player]
	if slot then
		teleport(player, slot, false)
	else
		teleport(player, ArenaService:GetTeamSpawn(team :: Types.TeamId), true)
	end
	setWalkSpeed(player, if phase == "Countdown" then 0 else StatsService:GetWalkSpeed(player))
end

-- Gives every player a start spot: party members next to each other, the
-- team's bots in the spots after its players.
local function assignSlots(groups: { { Player } }): (number, number)
	table.clear(slots)
	local red: { Player }, blue: { Player } = {}, {}
	for _, group in groups do
		for _, player in group do
			local team: Types.TeamId? = teams[player]
			if team == "Red" then
				table.insert(red, player)
			elseif team == "Blue" then
				table.insert(blue, player)
			end
		end
	end
	for index, player in red do
		slots[player] = ArenaService:GetTeamSpawnSlot("Red", index, #red + botCounts.Red)
	end
	for index, player in blue do
		slots[player] = ArenaService:GetTeamSpawnSlot("Blue", index, #blue + botCounts.Blue)
	end
	return #red, #blue
end

-- Countdown: no walking (WalkSpeed 0) and no falling; jumping is fine.
local function holdOnSpots()
	for player in teams do
		local slot: CFrame? = slots[player]
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not slot or root == nil or not root:IsA("BasePart") then
			continue
		end
		local humanoid = getHumanoid(player)
		if humanoid and humanoid.WalkSpeed ~= 0 then
			humanoid.WalkSpeed = 0
		end
		local spot = slot :: CFrame
		local offset = (root :: BasePart).Position - spot.Position
		local sideways = Vector3.new(offset.X, 0, offset.Z).Magnitude
		if sideways > HOLD_RADIUS or offset.Y < -HOLD_DROP then
			(character :: Model):PivotTo(spot)
			MovementGuard:Reset(player)
		end
	end
end

local function pruneLeftPlayers()
	for player in teams do
		if player.Parent ~= Players then
			teams[player] = nil
		end
	end
end

local function assignTeams(groups: { { Player } }): boolean
	local byUserId: { [number]: Player } = {}
	local balancerGroups: { TeamBalancer.Group } = {}
	for _, group in groups do
		local members = {}
		for _, player in group do
			byUserId[player.UserId] = player
			table.insert(members, player.UserId)
		end
		local power = 0
		for _, player in group do
			power += StatsService:GetTeamWeight(player)
		end
		table.insert(balancerGroups, { Members = members, Power = power })
	end

	local assignment = TeamBalancer.Assign(balancerGroups, RoundConfig)
	botCounts.Red = assignment.RedBots
	botCounts.Blue = assignment.BlueBots
	table.clear(teams)
	for _, userId in assignment.Red do
		teams[byUserId[userId]] = "Red"
	end
	for _, userId in assignment.Blue do
		teams[byUserId[userId]] = "Blue"
	end
	return next(teams) ~= nil
end

local function playsHere(player: Player): boolean
	return MatchmakingService:PlaysHere(player)
end

local function runRound(groups: { { Player } })
	local count = 0
	for _, group in groups do
		count += #group
	end
	if count < RoundConfig.MinParticipants or not assignTeams(groups) then
		return
	end

	for player: Player, team: Types.TeamId in teams do
		player:SetAttribute("Team", team)
	end

	-- Gray board before anyone lands, not the last match's colors (Ivan).
	ArenaService:ClearBoard()
	local redPlayers, bluePlayers = assignSlots(groups)
	setPhase("Countdown", RoundConfig.CountdownSeconds)
	for player in teams do
		placeOnArena(player)
	end
	local bots =
		BotService:Spawn(botCounts.Red, botCounts.Blue, { Red = redPlayers, Blue = bluePlayers })
	local hold = RunService.Heartbeat:Connect(holdOnSpots)
	task.wait(RoundConfig.CountdownSeconds)
	hold:Disconnect()

	pruneLeftPlayers()
	local everyone: { [Participant.Participant]: Types.TeamId } = table.clone(teams) :: any
	for bot: Model, team: Types.TeamId in bots do
		everyone[bot] = team
	end
	ArenaService:BeginRound(everyone)
	PowerUpService:BeginRound(everyone)
	BatService:BeginRound(everyone)
	BotService:BeginRound(everyone)
	setPhase("Playing", RoundConfig.PlayingSeconds)
	for player in teams do
		setWalkSpeed(player, StatsService:GetWalkSpeed(player))
	end
	task.wait(RoundConfig.PlayingSeconds)

	local score = ArenaService:EndRound()
	PowerUpService:EndRound()
	BatService:EndRound()
	BotService:Despawn()
	pruneLeftPlayers()
	roundId += 1
	local winner: Types.Winner = Reward.DecideWinner(score.Red, score.Blue)
	ReplicatedStorage:SetAttribute("Winner", winner)
	setPhase("Results", RoundConfig.ResultsSeconds)
	RoundService.RoundEnded:Fire({
		RoundId = roundId,
		Winner = winner,
		Teams = table.clone(teams),
		KeysPainted = score.KeysPainted,
	})
	task.wait(RoundConfig.ResultsSeconds)

	local isArena = MatchMode.IsArena()
	for player in teams do
		player:SetAttribute("Team", nil)
		-- Pet Speed only applies in the round.
		setWalkSpeed(player, ArenaConfig.BaseWalkSpeed)
		-- Back to the hub; the next match starts from the portal again.
		ReadyService:SetReady(player, false)
		if not isArena then
			teleport(player, lobbyCFrame(), true)
		end
	end
	table.clear(teams)
	table.clear(slots)
	if isArena then
		-- Everyone here, late arrivals too, goes back to their hub server.
		MatchmakingService:ReturnToHub(Players:GetPlayers())
	end
	ReplicatedStorage:SetAttribute("Winner", nil)
	ArenaService:ClearBoard()
end

-- Waits on the hub until someone is queued, then counts down. Returns
-- false if everyone left the queue during the countdown.
local function waitForQueue(): boolean
	setPhase("Intermission", 0)
	while not LocalMatchSource.HasParticipants(playsHere) do
		task.wait(0.25)
	end
	setPhase("Starting", RoundConfig.StartingSeconds)
	local startAt = os.clock() + RoundConfig.StartingSeconds
	while os.clock() < startAt do
		task.wait(0.25)
		if not LocalMatchSource.HasParticipants(playsHere) then
			return false
		end
	end
	return true
end

-- Arena: arrived players wait in the middle of the board, queued (so they
-- see "Match in N" and LEAVE QUEUE); strangers go back to the hub.
local function greetArrivals()
	for _, player in Players:GetPlayers() do
		if
			PlayerDataService:IsLoaded(player)
			and not ReadyService:IsReady(player)
			and player:GetAttribute("Team") == nil
			and not MatchmakingService:IsReturning(player)
		then
			if MatchmakingService:IsExpected(player) then
				ReadyService:SetReady(player, true, "Solo")
			else
				MatchmakingService:ReturnToHub({ player })
			end
		end
	end
end

-- Arena: waits for the roster's players (all of them, or whoever came
-- within ArrivalSeconds), plays the one match, then keeps sending anyone
-- left here back to the hub.
local function runArenaMatch()
	MatchmakingService:WaitForRoster(MatchConfig.ArrivalSeconds)
	setPhase("Starting", MatchConfig.ArrivalSeconds)
	local deadline = os.clock() + MatchConfig.ArrivalSeconds
	while true do
		task.wait(0.25)
		greetArrivals()
		local groups = MatchmakingService:ArenaGroups()
		if #groups > 0 and (MatchmakingService:AllArrived() or os.clock() >= deadline) then
			runRound(groups)
			break
		end
	end
	setPhase("Intermission", 0)
	while true do
		task.wait(2)
		MatchmakingService:ReturnToHub(Players:GetPlayers())
	end
end

function RoundService:Init()
	setPhase("Intermission", 0)
end

function RoundService:Start()
	-- A participant who respawns mid-round goes straight back to the arena.
	local function onCharacterAdded(player: Player, character: Model)
		if MatchMode.IsArena() and teams[player] == nil then
			-- Arena servers have no hub to stand on: wait on the board.
			local root = character:WaitForChild("HumanoidRootPart", 5)
			if root and teams[player] == nil and character.Parent then
				character:PivotTo(ArenaService:GetWaitingSpot())
				MovementGuard:Reset(player)
			end
			return
		end
		if teams[player] and (phase == "Countdown" or phase == "Playing") then
			character:WaitForChild("HumanoidRootPart", 5)
			if teams[player] and character.Parent then
				placeOnArena(player)
				BatService:Equip(player)
			end
		end
	end
	local function watchPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player, character)
		end)
	end
	Players.PlayerAdded:Connect(watchPlayer)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end

	task.spawn(function()
		if MatchMode.IsArena() then
			runArenaMatch()
			return
		end
		while true do
			if waitForQueue() then
				runRound(LocalMatchSource.CollectParticipants(playsHere))
			end
		end
	end)
end

function RoundService:GetPhase(): Types.RoundPhase
	return phase
end

return RoundService
