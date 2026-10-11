--!strict
-- The round state machine (docs/design.md 4.3 "Раунд"):
-- Intermission (nobody queued) -> Starting (queue countdown on the hub)
-- -> Countdown (on the arena) -> Playing -> Results -> back to the hub.
-- Players join the queue at the hub portal (PortalService); after the
-- match they leave the queue and return to the hub.
-- Phase and end time replicate as ReplicatedStorage attributes
-- ("RoundPhase", "PhaseEndsAt", "Winner"); each participant's team is the
-- "Team" Player attribute. RoundEnded lets RewardService react without
-- RoundService knowing about rewards.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArenaConfig = require(ReplicatedStorage.Shared.Config.ArenaConfig)
local RoundConfig = require(ReplicatedStorage.Shared.Config.RoundConfig)
local Reward = require(ReplicatedStorage.Shared.Logic.Reward)
local TeamBalancer = require(ReplicatedStorage.Shared.Logic.TeamBalancer)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local Types = require(ReplicatedStorage.Shared.Types)
local LocalMatchSource = require(script.Parent.Parent.Match.LocalMatchSource)
local ArenaService = require(script.Parent.ArenaService)
local Participant = require(script.Parent.Parent.Util.Participant)
local ReadyService = require(script.Parent.ReadyService)
local BatService = require(script.Parent.BatService)
local BotService = require(script.Parent.BotService)
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
local roundId = 0

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

local function teleport(player: Player, cframe: CFrame)
	local character = player.Character
	if character and character.PrimaryPart then
		-- Spread players a little so they do not stack on one point.
		local offset = Vector3.new(0, 0, (math.random() - 0.5) * 12)
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
	teleport(player, ArenaService:GetTeamSpawn(team :: Types.TeamId))
	setWalkSpeed(player, if phase == "Countdown" then 0 else StatsService:GetWalkSpeed(player))
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
			power += StatsService:GetPower(player)
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

local function runRound()
	local groups = LocalMatchSource.CollectParticipants()
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

	setPhase("Countdown", RoundConfig.CountdownSeconds)
	for player in teams do
		placeOnArena(player)
	end
	local bots = BotService:Spawn(botCounts.Red, botCounts.Blue)
	task.wait(RoundConfig.CountdownSeconds)

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

	for player in teams do
		player:SetAttribute("Team", nil)
		-- Pet Speed only applies in the round.
		setWalkSpeed(player, ArenaConfig.BaseWalkSpeed)
		-- Back to the hub; the next match starts from the portal again.
		ReadyService:SetReady(player, false)
		teleport(player, lobbyCFrame())
	end
	table.clear(teams)
	ReplicatedStorage:SetAttribute("Winner", nil)
end

-- Waits on the hub until someone is queued, then counts down. Returns
-- false if everyone left the queue during the countdown.
local function waitForQueue(): boolean
	setPhase("Intermission", 0)
	while not LocalMatchSource.HasParticipants() do
		task.wait(0.25)
	end
	setPhase("Starting", RoundConfig.StartingSeconds)
	local startAt = os.clock() + RoundConfig.StartingSeconds
	while os.clock() < startAt do
		task.wait(0.25)
		if not LocalMatchSource.HasParticipants() then
			return false
		end
	end
	return true
end

function RoundService:Init()
	setPhase("Intermission", 0)
end

function RoundService:Start()
	-- A participant who respawns mid-round goes straight back to the arena.
	local function onCharacterAdded(player: Player, character: Model)
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
		while true do
			if waitForQueue() then
				runRound()
			end
		end
	end)
end

function RoundService:GetPhase(): Types.RoundPhase
	return phase
end

return RoundService
