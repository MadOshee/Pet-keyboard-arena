--!strict
-- HUD built in code: phase + timer and team score bar (in a match), the
-- LEAVE QUEUE button, small icons of the equipped pets bottom right in a
-- match (the pets themselves stay off the arena), the dark results screen
-- after a match ("RED TEAM WINS!", Ivan 2026-10-16) and a banner for
-- refused requests. Money shows only in the pack's bottom-left cash counter
-- (PackUiController; Ivan, 2026-10-13). Joining the queue happens at the hub portal
-- (PortalController). Uses Scale sizes so it fits phones, tablets and PC,
-- and the UI pack look through Widgets.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local PetConfig = require(ReplicatedStorage.Shared.Config.PetConfig)
local PetStyle = require(ReplicatedStorage.Shared.Config.PetStyle)
local RoundConfig = require(ReplicatedStorage.Shared.Config.RoundConfig)
local Strings = require(ReplicatedStorage.Shared.Config.Strings)
local TeamColors = require(ReplicatedStorage.Shared.Config.TeamColors)
local Types = require(ReplicatedStorage.Shared.Types)
local ClientNet = require(script.Parent.Parent.Util.ClientNet)
local AssetModels = require(script.Parent.Parent.UI.AssetModels)
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
	ReadyButton: TextButton,
	Banner: TextLabel,
	ArenaPets: Frame,
	Results: Frame,
	ResultsTitle: TextLabel,
	ResultsNote: TextLabel,
}

local refs: Refs
local bannerToken = 0

local ERROR_SECONDS = 2.5
local RESULTS_DIM = 0.25 -- background transparency of the results screen
local DRAW_COLOR = Color3.new(1, 1, 1)

-- The result screen's state: in this match, the last winner and the note
-- for a player who painted too little.
local playedMatch = false
local lastWinner: string? = nil
local noRewardNote = ""
local PET_ICON_HEIGHT = 0.055

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

	-- In the middle of the screen under the portal's "Match in N" (Ivan).
	local readyButton = Widgets.Button(
		"Ready",
		gui,
		UDim2.fromScale(0.2, 0.09),
		UDim2.fromScale(0.5, 0.55),
		Color3.fromRGB(230, 50, 50)
	)
	readyButton.AnchorPoint = Vector2.new(0.5, 0)
	readyButton.Text = Strings.LeaveQueue
	readyButton.Visible = false
	Widgets.AspectRatio(readyButton, 3)

	local banner =
		Widgets.Label("Banner", gui, UDim2.fromScale(0.6, 0.1), UDim2.fromScale(0.2, 0.32))
	banner.Visible = false

	-- Equipped pets as small icons in a row, about as tall as the cash
	-- icon (Ivan). On touch screens above the Hit button, clear of the
	-- jump button.
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local arenaPets = Instance.new("Frame")
	arenaPets.Name = "ArenaPets"
	arenaPets.BackgroundTransparency = 1
	arenaPets.AnchorPoint = Vector2.new(1, 1)
	arenaPets.Position = if touch
		then UDim2.fromScale(0.985, 0.54)
		else UDim2.fromScale(0.985, 0.975)
	arenaPets.Size = UDim2.fromScale(0.3, PET_ICON_HEIGHT)
	arenaPets.Visible = false
	arenaPets.Parent = gui
	local row = Instance.new("UIListLayout")
	row.FillDirection = Enum.FillDirection.Horizontal
	row.HorizontalAlignment = Enum.HorizontalAlignment.Right
	row.VerticalAlignment = Enum.VerticalAlignment.Center
	row.Padding = UDim.new(0.01, 0)
	row.SortOrder = Enum.SortOrder.LayoutOrder
	row.Parent = arenaPets

	gui.Parent = player:WaitForChild("PlayerGui")

	-- Over everything, top bar included: the screen goes dark and names
	-- the winner for RoundConfig.ResultsSeconds, then the hub loads.
	local resultsGui = Widgets.ScreenGui("Results", 50)
	resultsGui.IgnoreGuiInset = true
	local results = Instance.new("Frame")
	results.Name = "Dim"
	results.BackgroundColor3 = Color3.new(0, 0, 0)
	results.BackgroundTransparency = RESULTS_DIM
	results.BorderSizePixel = 0
	results.Size = UDim2.fromScale(1, 1)
	results.Visible = false
	results.Active = true
	results.Parent = resultsGui
	local resultsTitle =
		Widgets.Label("Winner", results, UDim2.fromScale(0.8, 0.14), UDim2.fromScale(0.5, 0.45))
	resultsTitle.AnchorPoint = Vector2.new(0.5, 0.5)
	local resultsNote =
		Widgets.Label("Note", results, UDim2.fromScale(0.7, 0.05), UDim2.fromScale(0.5, 0.56))
	resultsNote.AnchorPoint = Vector2.new(0.5, 0.5)
	resultsGui.Parent = player:WaitForChild("PlayerGui")

	return {
		Top = top,
		ScoreBar = bar,
		PhaseLabel = phaseLabel,
		TeamLabel = teamLabel,
		RedFill = redFill,
		RedScore = redScore,
		BlueScore = blueScore,
		ReadyButton = readyButton,
		Banner = banner,
		ArenaPets = arenaPets,
		Results = results,
		ResultsTitle = resultsTitle,
		ResultsNote = resultsNote,
	}
end

-- One small round icon per equipped pet, shown only in a match.
local shownPets: string? = nil
local function updateArenaPets()
	local inMatch = player:GetAttribute("Team") ~= nil
	refs.ArenaPets.Visible = inMatch
	local value = player:GetAttribute("EquippedPets")
	local kinds = if type(value) == "string" then value else ""
	if not inMatch or kinds == shownPets then
		return
	end
	shownPets = kinds
	for _, child in refs.ArenaPets:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	for order, kind in string.split(kinds, ",") do
		local entry = PetConfig.Pets[kind]
		if entry == nil then
			continue
		end
		local color = PetStyle.Rarity[entry.Rarity] or Color3.new(1, 1, 1)
		local icon = Instance.new("Frame")
		icon.Name = kind
		icon.LayoutOrder = order
		icon.BackgroundColor3 = Color3.fromRGB(20, 22, 40)
		icon.BackgroundTransparency = 0.35
		icon.Size = UDim2.fromScale(1, 1)
		icon.SizeConstraint = Enum.SizeConstraint.RelativeYY
		icon.Parent = refs.ArenaPets
		Widgets.Corner(icon, 0.5)
		Widgets.Stroke(icon, color, 2)
		local holder = Instance.new("Frame")
		holder.BackgroundTransparency = 1
		holder.AnchorPoint = Vector2.new(0.5, 0.5)
		holder.Position = UDim2.fromScale(0.5, 0.5)
		holder.Size = UDim2.fromScale(0.86, 0.86)
		holder.Parent = icon
		AssetModels.Viewport(holder, AssetModels.Pet(kind), color)
	end
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
	-- Each team's share of all arena keys, in percent (Ivan 2026-10-13).
	local keys = ReplicatedStorage:GetAttribute("ScoreTotal")
	local keyCount = if type(keys) == "number" and keys > 0 then keys else math.max(total, 1)
	refs.RedScore.Text = string.format("%d%%", math.floor(redCount / keyCount * 100 + 0.5))
	refs.BlueScore.Text = string.format("%d%%", math.floor(blueCount / keyCount * 100 + 0.5))
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

-- The top panel shows only in a match; in the queue there is only the
-- portal's "Match in N" and LEAVE QUEUE (Ivan).
local function updateReady()
	local ready = player:GetAttribute("Ready") == true
	local inMatch = player:GetAttribute("Team") ~= nil
	-- An arena has no queue to leave: the match starts once everyone is
	-- there (Ivan 2026-10-16).
	local onArena = ReplicatedStorage:GetAttribute("ServerMode") == "Arena"
	refs.ReadyButton.Visible = ready and not inMatch and not onArena
	refs.Top.Visible = inMatch
	refs.ScoreBar.Visible = inMatch
end

-- The dark results screen: while the match's Results last for its
-- players, and on an arena until the teleport home takes them.
local function updateResults()
	local phase = ReplicatedStorage:GetAttribute("RoundPhase")
	if player:GetAttribute("Team") ~= nil then
		playedMatch = true
	elseif phase ~= "Results" then
		playedMatch = false
	end
	local winner = ReplicatedStorage:GetAttribute("Winner")
	if winner == "Red" or winner == "Blue" or winner == "Draw" then
		lastWinner = winner
	end
	local returning = ReplicatedStorage:GetAttribute("ReturningToHub") == true
	local show = lastWinner ~= nil and ((phase == "Results" and playedMatch) or returning)
	local wasShown = refs.Results.Visible
	refs.Results.Visible = show
	if not show then
		if phase ~= "Results" and not returning then
			noRewardNote = ""
		end
		return
	end
	local shown = lastWinner :: string
	refs.ResultsTitle.Text = (Strings.TeamWins :: any)[shown] or shown
	refs.ResultsTitle.TextColor3 = if shown == "Draw"
		then DRAW_COLOR
		else TeamColors.ForTeam(shown :: any)
	refs.ResultsNote.Text = if noRewardNote ~= ""
		then noRewardNote
		elseif returning then Strings.ReturningToHub
		else ""
	if not wasShown then
		refs.Results.BackgroundTransparency = 1
		TweenService
			:Create(refs.Results, TweenInfo.new(0.3), { BackgroundTransparency = RESULTS_DIM })
			:Play()
	end
end

-- Only the arena's own result: a result carried to the hub belongs to the
-- egg offer (EggOfferController).
local function onRoundResult(result: Types.RoundResultPayload)
	if ReplicatedStorage:GetAttribute("RoundPhase") ~= "Results" then
		return
	end
	noRewardNote = if result.Rewarded
		then ""
		else string.format(Strings.NoReward, RoundConfig.MinKeysForReward)
	updateResults()
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
	ReplicatedStorage:GetAttributeChangedSignal("ScoreTotal"):Connect(updateScore)
	ReplicatedStorage:GetAttributeChangedSignal("Winner"):Connect(updateResults)
	ReplicatedStorage:GetAttributeChangedSignal("RoundPhase"):Connect(updateResults)
	ReplicatedStorage:GetAttributeChangedSignal("ReturningToHub"):Connect(updateResults)
	player:GetAttributeChangedSignal("Team"):Connect(function()
		updateTeam()
		updateReady()
		updateArenaPets()
		updateResults()
	end)
	player:GetAttributeChangedSignal("EquippedPets"):Connect(updateArenaPets)
	player:GetAttributeChangedSignal("Ready"):Connect(updateReady)
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
	updateArenaPets()
	updateResults()
end

return HudController
