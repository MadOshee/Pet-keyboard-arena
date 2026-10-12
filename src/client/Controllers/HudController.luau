--!strict
-- HUD built in code: phase + timer and team score bar (shown while queued or
-- in a match), coins, the LEAVE QUEUE button and a banner for round results
-- and refused requests. Joining the queue happens at the hub portal
-- (PortalController). Uses Scale sizes so it fits phones, tablets and PC,
-- and the UI pack look through Widgets.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local RoundConfig = require(ReplicatedStorage.Shared.Config.RoundConfig)
local Strings = require(ReplicatedStorage.Shared.Config.Strings)
local TeamColors = require(ReplicatedStorage.Shared.Config.TeamColors)
local Types = require(ReplicatedStorage.Shared.Types)
local ClientNet = require(script.Parent.Parent.Util.ClientNet)
local DataController = require(script.Parent.DataController)
local Widgets = require(script.Parent.Parent.UI.Widgets)

local player = Players.LocalPlayer

local HudController = {}

type Refs = {
	Top: Frame,
	ScoreBar: Frame,
	PhaseLabel: TextLabel,
	TeamLabel: TextLabel,
	RedFill: Frame,
	RedScore: TextLabel,
	BlueScore: TextLabel,
	CoinsLabel: TextLabel,
	ReadyButton: TextButton,
	Banner: TextLabel,
}

local refs: Refs
local bannerToken = 0

local ERROR_SECONDS = 2.5

local function build(): Refs
	local gui = Widgets.ScreenGui("Hud", 1)

	local top = Instance.new("Frame")
	top.Name = "Top"
	top.AnchorPoint = Vector2.new(0.5, 0)
	top.Position = UDim2.fromScale(0.5, 0.02)
	top.Size = UDim2.fromScale(0.42, 0.14)
	top.BackgroundTransparency = 1
	top.Parent = gui
	Widgets.AspectRatio(top, 5)

	local phaseLabel = Widgets.Label("Phase", top, UDim2.fromScale(1, 0.45), UDim2.fromScale(0, 0))

	local bar, redFill, redScore, blueScore = Widgets.ProgressBar(
		"ScoreBar",
		top,
		UDim2.fromScale(0.8, 0.3),
		UDim2.fromScale(0.1, 0.5),
		TeamColors.Blue,
		TeamColors.Red
	)

	local teamLabel = Widgets.Label("Team", top, UDim2.fromScale(1, 0.2), UDim2.fromScale(0, 0.82))

	local coinsLabel =
		Widgets.MoneyLabel("Coins", gui, UDim2.fromScale(0.2, 0.06), UDim2.fromScale(0.78, 0.03))
	coinsLabel.TextXAlignment = Enum.TextXAlignment.Right

	local readyButton = Widgets.Button(
		"Ready",
		gui,
		UDim2.fromScale(0.22, 0.1),
		UDim2.fromScale(0.5, 0.95),
		Color3.fromRGB(230, 50, 50)
	)
	readyButton.AnchorPoint = Vector2.new(0.5, 1)
	readyButton.Text = Strings.LeaveQueue
	readyButton.Visible = false
	Widgets.AspectRatio(readyButton, 3)

	local banner =
		Widgets.Label("Banner", gui, UDim2.fromScale(0.6, 0.1), UDim2.fromScale(0.2, 0.32))
	banner.Visible = false

	gui.Parent = player:WaitForChild("PlayerGui")

	return {
		Top = top,
		ScoreBar = bar,
		PhaseLabel = phaseLabel,
		TeamLabel = teamLabel,
		RedFill = redFill,
		RedScore = redScore,
		BlueScore = blueScore,
		CoinsLabel = coinsLabel,
		ReadyButton = readyButton,
		Banner = banner,
	}
end

local function showBanner(text: string, seconds: number)
	bannerToken += 1
	local token = bannerToken
	refs.Banner.Text = text
	refs.Banner.Visible = true
	task.delay(seconds, function()
		if token == bannerToken then
			refs.Banner.Visible = false
		end
	end)
end

local function updatePhase()
	local phase = ReplicatedStorage:GetAttribute("RoundPhase")
	local endsAt = ReplicatedStorage:GetAttribute("PhaseEndsAt")
	if type(phase) ~= "string" or type(endsAt) ~= "number" then
		return
	end
	local secondsLeft = math.max(0, math.ceil(endsAt - workspace:GetServerTimeNow()))
	local inMatch = player:GetAttribute("Team") ~= nil
	local title = (Strings.Phase :: any)[phase] or phase
	if not inMatch and (phase == "Countdown" or phase == "Playing" or phase == "Results") then
		-- Queued while another match is on the arena.
		title = Strings.ArenaBusy
	end
	if phase == "Intermission" then
		refs.PhaseLabel.Text = title
	else
		refs.PhaseLabel.Text =
			string.format("%s  %d:%02d", title, secondsLeft // 60, secondsLeft % 60)
	end
end

local function updateScore()
	local red = ReplicatedStorage:GetAttribute("ScoreRed")
	local blue = ReplicatedStorage:GetAttribute("ScoreBlue")
	local redCount = if type(red) == "number" then red else 0
	local blueCount = if type(blue) == "number" then blue else 0
	local total = redCount + blueCount
	refs.RedFill.Size = UDim2.fromScale(if total > 0 then redCount / total else 0.5, 1)
	refs.RedScore.Text = tostring(redCount)
	refs.BlueScore.Text = tostring(blueCount)
end

local function updateTeam()
	local team = player:GetAttribute("Team")
	if team == "Red" or team == "Blue" then
		refs.TeamLabel.Text = string.format(Strings.YourTeam, Strings.TeamName[team])
		refs.TeamLabel.TextColor3 = TeamColors.ForTeam(team)
	else
		refs.TeamLabel.Text = ""
	end
end

-- The top panel shows only to players who are queued or playing; the
-- score bar only in a match.
local function updateReady()
	local ready = player:GetAttribute("Ready") == true
	local inMatch = player:GetAttribute("Team") ~= nil
	refs.ReadyButton.Visible = ready and not inMatch
	refs.Top.Visible = ready or inMatch
	refs.ScoreBar.Visible = inMatch
end

local function updateCoins(profile: Types.Profile?)
	refs.CoinsLabel.Text = if profile then string.format(Strings.Coins, profile.Coins) else ""
end

local function onWinner()
	local winner = ReplicatedStorage:GetAttribute("Winner")
	if winner == "Red" or winner == "Blue" or winner == "Draw" then
		showBanner(Strings.Winner[winner], RoundConfig.ResultsSeconds)
	end
end

local function onRoundResult(result: Types.RoundResultPayload)
	local text = Strings.Outcome[result.Outcome]
	if result.Rewarded then
		text ..= "  " .. string.format(Strings.CoinsGained, result.Coins)
	else
		text ..= "\n" .. string.format(Strings.NoReward, RoundConfig.MinKeysForReward)
	end
	showBanner(text, RoundConfig.ResultsSeconds)
end

function HudController:Init()
	refs = build()
end

function HudController:Start()
	refs.ReadyButton.Activated:Connect(function()
		ClientNet.Fire("SetReady", false)
	end)

	ReplicatedStorage:GetAttributeChangedSignal("ScoreRed"):Connect(updateScore)
	ReplicatedStorage:GetAttributeChangedSignal("ScoreBlue"):Connect(updateScore)
	ReplicatedStorage:GetAttributeChangedSignal("Winner"):Connect(onWinner)
	player:GetAttributeChangedSignal("Team"):Connect(function()
		updateTeam()
		updateReady()
	end)
	player:GetAttributeChangedSignal("Ready"):Connect(updateReady)
	DataController.Changed:Connect(updateCoins)
	ClientNet.On("RoundResult", onRoundResult)
	ClientNet.On("ActionResult", function(_action: string, reason: string)
		local text = (Strings.Errors :: any)[reason]
		if text then
			showBanner(text, ERROR_SECONDS)
		end
	end)

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= 0.2 then
			elapsed = 0
			updatePhase()
		end
	end)

	updatePhase()
	updateScore()
	updateTeam()
	updateReady()
	updateCoins(DataController:Get())
end

return HudController
