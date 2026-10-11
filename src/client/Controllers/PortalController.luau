--!strict
-- The portal on the hub island: walking up to it opens a window with
-- SOLO GAME and PARTY GAME. The choice goes to the server (PortalService),
-- which queues the player or their party. While the queue counts down
-- (phase "Starting") a big "Match in N" shows in the middle of the screen.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ArenaConfig = require(ReplicatedStorage.Shared.Config.ArenaConfig)
local Strings = require(ReplicatedStorage.Shared.Config.Strings)
local Widgets = require(script.Parent.Parent.UI.Widgets)
local ClientNet = require(script.Parent.Parent.Util.ClientNet)

local player = Players.LocalPlayer

local PortalController = {}

local UPDATE_SECONDS = 0.2
-- Closing the window keeps it closed until the player steps away.
local REOPEN_DISTANCE = ArenaConfig.PortalRadius + 6

local window: Frame
local countdown: TextLabel
local portal: Model? = nil
local dismissed = false

local function build()
	local gui = Widgets.ScreenGui("Portal", 4)

	window = Widgets.Panel("Window", gui, UDim2.fromScale(0.5, 0.42), UDim2.fromScale(0.5, 0.55))
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.Visible = false
	Widgets.AspectRatio(window, 1.9)
	Widgets.Stroke(window, Color3.fromRGB(170, 90, 255), 3)

	local title =
		Widgets.Label("Title", window, UDim2.fromScale(0.7, 0.16), UDim2.fromScale(0.15, 0.05))
	title.Text = Strings.PortalTitle
	local close = Widgets.Button(
		"Close",
		window,
		UDim2.fromScale(0.08, 0.15),
		UDim2.fromScale(0.9, 0.04),
		Color3.fromRGB(200, 70, 70)
	)
	close.Text = "X"

	local function choice(
		name: string,
		text: string,
		hint: string,
		x: number,
		color: Color3,
		mode: string
	)
		local button = Widgets.Button(
			name,
			window,
			UDim2.fromScale(0.42, 0.42),
			UDim2.fromScale(x, 0.28),
			color
		)
		button.Text = text
		local hintLabel = Widgets.Label(
			`{name}Hint`,
			window,
			UDim2.fromScale(0.42, 0.14),
			UDim2.fromScale(x, 0.74)
		)
		hintLabel.Text = hint
		hintLabel.TextColor3 = Color3.fromRGB(210, 210, 230)
		button.Activated:Connect(function()
			ClientNet.Fire("JoinQueue", mode)
			window.Visible = false
			dismissed = true
		end)
	end
	choice("Solo", Strings.SoloGame, Strings.SoloHint, 0.05, Color3.fromRGB(240, 150, 40), "Solo")
	choice(
		"Party",
		Strings.PartyGame,
		Strings.PartyHint,
		0.53,
		Color3.fromRGB(140, 80, 230),
		"Party"
	)

	close.Activated:Connect(function()
		window.Visible = false
		dismissed = true
	end)

	countdown =
		Widgets.Label("Countdown", gui, UDim2.fromScale(0.5, 0.12), UDim2.fromScale(0.25, 0.4))
	countdown.TextColor3 = Color3.fromRGB(255, 230, 90)
	countdown.Visible = false

	gui.Parent = player:WaitForChild("PlayerGui")
end

local function distanceToPortal(): number
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if portal == nil or not (root and root:IsA("BasePart")) then
		return math.huge
	end
	local offset = (root :: BasePart).Position - (portal :: Model):GetPivot().Position
	return Vector3.new(offset.X, 0, offset.Z).Magnitude
end

local function update()
	local queued = player:GetAttribute("Ready") == true
	local inMatch = player:GetAttribute("Team") ~= nil
	local distance = distanceToPortal()
	if distance > REOPEN_DISTANCE then
		dismissed = false
	end
	local show = not queued
		and not inMatch
		and not dismissed
		and distance <= ArenaConfig.PortalRadius
	if window.Visible ~= show then
		window.Visible = show
		if show then
			Widgets.PlaySound("Click")
		end
	end

	local phase = ReplicatedStorage:GetAttribute("RoundPhase")
	local endsAt = ReplicatedStorage:GetAttribute("PhaseEndsAt")
	if queued and not inMatch and phase == "Starting" and type(endsAt) == "number" then
		local secondsLeft = math.max(0, math.ceil(endsAt - workspace:GetServerTimeNow()))
		countdown.Text = string.format(Strings.MatchIn, secondsLeft)
		countdown.Visible = true
	else
		countdown.Visible = false
	end
end

function PortalController:Init()
	build()
end

function PortalController:Start()
	task.spawn(function()
		local world = workspace:WaitForChild("World")
		local found = world:WaitForChild("Portal")
		if found:IsA("Model") then
			portal = found
		end
	end)

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= UPDATE_SECONDS then
			elapsed = 0
			update()
		end
	end)
end

return PortalController
