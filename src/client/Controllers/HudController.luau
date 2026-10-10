--!strict
-- Stage 1 HUD built in code: phase + timer, team score bar, coins, the
-- play/ready toggle and a round result banner. Uses Scale sizes so it fits
-- phones, tablets and PC. Art from the asset packs replaces it in stage 7.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local RoundConfig = require(ReplicatedStorage.Shared.Config.RoundConfig)
local Strings = require(ReplicatedStorage.Shared.Config.Strings)
local TeamColors = require(ReplicatedStorage.Shared.Config.TeamColors)
local Types = require(ReplicatedStorage.Shared.Types)
local ClientNet = require(script.Parent.Parent.Util.ClientNet)
local DataController = require(script.Parent.DataController)

local player = Players.LocalPlayer

local HudController = {}

type Refs = {
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

local function corner(parent: GuiObject, radius: number)
	local uiCorner = Instance.new("UICorner")
	uiCorner.CornerRadius = UDim.new(radius, 0)
	uiCorner.Parent = parent
end

local function label(name: string, parent: Instance, size: UDim2, position: UDim2): TextLabel
	local text = Instance.new("TextLabel")
	text.Name = name
	text.Size = size
	text.Position = position
	text.BackgroundTransparency = 1
	text.TextScaled = true
	text.Font = Enum.Font.FredokaOne
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextStrokeTransparency = 0.4
	text.Text = ""
	text.Parent = parent
	return text
end

local function build(): Refs
	local gui = Instance.new("ScreenGui")
	gui.Name = "Hud"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local top = Instance.new("Frame")
	top.Name = "Top"
	top.AnchorPoint = Vector2.new(0.5, 0)
	top.Position = UDim2.fromScale(0.5, 0.02)
	top.Size = UDim2.fromScale(0.42, 0.14)
	top.BackgroundTransparency = 1
	top.Parent = gui
	local topRatio = Instance.new("UIAspectRatioConstraint")
	topRatio.AspectRatio = 5
	topRatio.Parent = top

	local phaseLabel = label("Phase", top, UDim2.fromScale(1, 0.45), UDim2.fromScale(0, 0))

	local bar = Instance.new("Frame")
	bar.Name = "ScoreBar"
	bar.Position = UDim2.fromScale(0.1, 0.5)
	bar.Size = UDim2.fromScale(0.8, 0.3)
	bar.BackgroundColor3 = TeamColors.Blue
	bar.Parent = top
	corner(bar, 0.5)

	local redFill = Instance.new("Frame")
	redFill.Name = "RedFill"
	redFill.Size = UDim2.fromScale(0.5, 1)
	redFill.BackgroundColor3 = TeamColors.Red
	redFill.Parent = bar
	corner(redFill, 0.5)

	local redScore = label("RedScore", bar, UDim2.fromScale(0.3, 1), UDim2.fromScale(0.02, 0))
	redScore.TextXAlignment = Enum.TextXAlignment.Left
	local blueScore = label("BlueScore", bar, UDim2.fromScale(0.3, 1), UDim2.fromScale(0.68, 0))
	blueScore.TextXAlignment = Enum.TextXAlignment.Right

	local teamLabel = label("Team", top, UDim2.fromScale(1, 0.2), UDim2.fromScale(0, 0.82))

	local coinsLabel = label("Coins", gui, UDim2.fromScale(0.2, 0.06), UDim2.fromScale(0.78, 0.03))
	coinsLabel.TextXAlignment = Enum.TextXAlignment.Right
	coinsLabel.TextColor3 = Color3.fromRGB(255, 214, 64)

	local readyButton = Instance.new("TextButton")
	readyButton.Name = "Ready"
	readyButton.AnchorPoint = Vector2.new(0.5, 1)
	readyButton.Position = UDim2.fromScale(0.5, 0.95)
	readyButton.Size = UDim2.fromScale(0.22, 0.1)
	readyButton.TextScaled = true
	readyButton.Font = Enum.Font.FredokaOne
	readyButton.TextColor3 = Color3.new(1, 1, 1)
	readyButton.AutoButtonColor = true
	readyButton.Parent = gui
	corner(readyButton, 0.25)
	local readyRatio = Instance.new("UIAspectRatioConstraint")
	readyRatio.AspectRatio = 3
	readyRatio.Parent = readyButton

	local banner = label("Banner", gui, UDim2.fromScale(0.6, 0.1), UDim2.fromScale(0.2, 0.32))
	banner.Visible = false

	gui.Parent = player:WaitForChild("PlayerGui")

	return {
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
	local title = (Strings.Phase :: any)[phase] or phase
	refs.PhaseLabel.Text = string.format("%s  %d:%02d", title, secondsLeft // 60, secondsLeft % 60)
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

local function updateReady()
	local ready = player:GetAttribute("Ready") == true
	refs.ReadyButton.Text = if ready then Strings.Ready else Strings.NotReady
	refs.ReadyButton.BackgroundColor3 = if ready
		then Color3.fromRGB(64, 190, 90)
		else Color3.fromRGB(90, 90, 110)
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
		ClientNet.Fire("SetReady", player:GetAttribute("Ready") ~= true)
	end)

	ReplicatedStorage:GetAttributeChangedSignal("ScoreRed"):Connect(updateScore)
	ReplicatedStorage:GetAttributeChangedSignal("ScoreBlue"):Connect(updateScore)
	ReplicatedStorage:GetAttributeChangedSignal("Winner"):Connect(onWinner)
	player:GetAttributeChangedSignal("Team"):Connect(updateTeam)
	player:GetAttributeChangedSignal("Ready"):Connect(updateReady)
	DataController.Changed:Connect(updateCoins)
	ClientNet.On("RoundResult", onRoundResult)

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
