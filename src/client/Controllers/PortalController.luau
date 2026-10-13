--!strict
-- The portal on the hub island: walking up to it opens a window with PvP
-- (the solo queue) and PARTY GAME, dimmed with "Soon" for now (Ivan
-- 2026-10-13). The choice goes to the server (PortalService),
-- which queues the player or their party. While the queue counts down
-- (phase "Starting") a big "Match in N" shows in the middle of the screen.
-- The controller also animates the portal: the core spins, the crystals
-- float (tools/world/Portal.luau names the parts).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ArenaConfig = require(ReplicatedStorage.Shared.Config.ArenaConfig)
local IconConfig = require(ReplicatedStorage.Shared.Config.IconConfig)
local Strings = require(ReplicatedStorage.Shared.Config.Strings)
local Widgets = require(script.Parent.Parent.UI.Widgets)
local ClientNet = require(script.Parent.Parent.Util.ClientNet)

local player = Players.LocalPlayer

local PortalController = {}

local UPDATE_SECONDS = 0.2
-- Closing the window keeps it closed until the player steps away.
local REOPEN_DISTANCE = ArenaConfig.PortalRadius + 6
-- Portal animation, only while the player is close enough to see it.
local ANIMATE_DISTANCE = 300
local SPIN_SPEED = 1.2 -- radians per second
local FLOAT_HEIGHT = 0.8
local FLOAT_SPEED = 2
-- Party play is for a later update: its button is dimmed like Rebirth.
local SOON_COLOR = Color3.fromRGB(255, 220, 60)
local DIM_COLOR = Color3.fromRGB(95, 90, 110)

local window: Frame
local countdown: TextLabel
local portal: Model? = nil
local dismissed = false

type Animated = { Part: BasePart, Offset: CFrame }
local spinning: { Animated } = {}
local floating: { Animated } = {}
local animationTime = 0

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
	): TextButton
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
		return button
	end
	local pvp = choice(
		"Solo",
		Strings.SoloGame,
		Strings.SoloHint,
		0.05,
		Color3.fromRGB(240, 150, 40),
		"Solo"
	)
	local sword = Instance.new("ImageLabel")
	sword.Name = "Sword"
	sword.AnchorPoint = Vector2.new(0, 0.5)
	sword.Position = UDim2.fromScale(0.04, 0.5)
	sword.Size = UDim2.fromScale(0.6, 0.6)
	sword.SizeConstraint = Enum.SizeConstraint.RelativeYY
	sword.BackgroundTransparency = 1
	sword.Image = IconConfig.Sword
	sword.ScaleType = Enum.ScaleType.Fit
	sword.ZIndex = 20
	sword.Parent = pvp
	-- The pack button centers its caption; move it right of the sword.
	local container = pvp:FindFirstChild("Container")
	local caption = container and container:FindFirstChild("Name")
	if caption and caption:IsA("GuiObject") then
		caption.Position = UDim2.fromScale(0.66, 0.5)
		caption.Size = UDim2.fromScale(0.58, 0.7)
	end

	local party = choice("Party", Strings.PartyGame, Strings.PartyHint, 0.53, DIM_COLOR, "Party")
	party.Interactable = false
	party.TextColor3 = Color3.fromRGB(170, 165, 180)
	local soon = Widgets.Label("Soon", party, UDim2.fromScale(0.8, 0.42), UDim2.fromScale(0.5, 0.5))
	soon.AnchorPoint = Vector2.new(0.5, 0.5)
	soon.Rotation = -12
	soon.ZIndex = 30
	soon.TextColor3 = SOON_COLOR
	soon.Text = Strings.Soon

	close.Activated:Connect(function()
		window.Visible = false
		dismissed = true
	end)

	countdown =
		Widgets.Label("Countdown", gui, UDim2.fromScale(0.5, 0.12), UDim2.fromScale(0.25, 0.42))
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
	-- In the queue only this line and LEAVE QUEUE (HudController) show.
	if queued and not inMatch then
		if phase == "Starting" and type(endsAt) == "number" then
			local secondsLeft = math.max(0, math.ceil(endsAt - workspace:GetServerTimeNow()))
			countdown.Text = string.format(Strings.MatchIn, secondsLeft)
		elseif phase == "Countdown" or phase == "Playing" or phase == "Results" then
			-- Another match is on the arena.
			countdown.Text = Strings.ArenaBusy
		else
			countdown.Text = Strings.Queued
		end
		countdown.Visible = true
	else
		countdown.Visible = false
	end
end

-- Remembers the parts to animate relative to the swirl (whose X axis is
-- the gate axis) or to their own start position.
local function collectAnimated(found: Model)
	local primary = found.PrimaryPart
	if primary == nil then
		return
	end
	local swirl = primary :: BasePart
	-- Studio loads the sign built by tools/build-world with TextScaled off.
	local signText = swirl:FindFirstChild("Sign") and (swirl :: any).Sign:FindFirstChild("Text")
	if signText and signText:IsA("TextLabel") then
		signText.TextScaled = true
	end
	local spin = found:FindFirstChild("Spin")
	if spin then
		for _, descendant in spin:GetDescendants() do
			if descendant:IsA("BasePart") then
				table.insert(
					spinning,
					{ Part = descendant, Offset = swirl.CFrame:ToObjectSpace(descendant.CFrame) }
				)
			end
		end
	end
	local float = found:FindFirstChild("Float")
	if float then
		for _, descendant in float:GetDescendants() do
			if descendant:IsA("BasePart") then
				table.insert(floating, { Part = descendant, Offset = descendant.CFrame })
			end
		end
	end
end

local function animate(dt: number)
	local found = portal
	local primary = found and found.PrimaryPart
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if primary == nil or not (root and root:IsA("BasePart")) then
		return
	end
	local swirl = primary :: BasePart
	if ((root :: BasePart).Position - swirl.Position).Magnitude > ANIMATE_DISTANCE then
		return
	end
	animationTime += dt
	local turn = swirl.CFrame * CFrame.Angles(animationTime * SPIN_SPEED, 0, 0)
	for _, item in spinning do
		item.Part.CFrame = turn * item.Offset
	end
	for index, item in floating do
		local lift = math.sin(animationTime * FLOAT_SPEED + index * 1.7) * FLOAT_HEIGHT
		item.Part.CFrame = item.Offset * CFrame.new(0, lift, 0) * CFrame.Angles(0, animationTime, 0)
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
			collectAnimated(found)
		end
	end)

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		animate(dt)
		elapsed += dt
		if elapsed >= UPDATE_SECONDS then
			elapsed = 0
			update()
		end
	end)
end

return PortalController
