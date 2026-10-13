--!strict
-- Visual and sound feedback for the bat (a gust of wind in the hit cone)
-- and power-ups, the local victim's knock-back flight, the drop back in
-- after falling off the arena, and sounds and confetti for game events (round won,
-- egg picked, pet hatched, refused action, party invite). All cosmetic: the
-- server already decided every outcome.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local BatConfig = require(ReplicatedStorage.Shared.Config.BatConfig)
local Strings = require(ReplicatedStorage.Shared.Config.Strings)
local Types = require(ReplicatedStorage.Shared.Types)
local WindGust = require(script.Parent.Parent.Fx.WindGust)
local Widgets = require(script.Parent.Parent.UI.Widgets)
local ClientNet = require(script.Parent.Parent.Util.ClientNet)

local player = Players.LocalPlayer

-- The strike part of the swing (BatPoseController.SWING): the trail and
-- the wind start with the bat moving forward.
local STRIKE_DELAY = 0.1
local TRAIL_SECONDS = 0.24
local POPUP_SECONDS = 1.5
local SPIN_SPEED = 2 -- radians per second
local BOB_HEIGHT = 0.4
local CONFETTI_PIECES = 60
local CONFETTI_SECONDS = 2.5
local CONFETTI_COLORS = {
	Color3.fromRGB(255, 90, 90),
	Color3.fromRGB(255, 200, 60),
	Color3.fromRGB(90, 200, 255),
	Color3.fromRGB(120, 230, 120),
	Color3.fromRGB(220, 120, 255),
}

local EffectsController = {}

local gui: ScreenGui
local popup: TextLabel
local invitesSeen = 0
local popupToken = 0
local baseHeights: { [BasePart]: number } = {}

local function showPopup(text: string, color: Color3)
	popupToken += 1
	local token = popupToken
	popup.Text = text
	popup.TextColor3 = color
	popup.Visible = true
	task.delay(POPUP_SECONDS, function()
		if token == popupToken then
			popup.Visible = false
		end
	end)
end

local function playSound(name: string, parent: Instance?)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local sounds = assets and assets:FindFirstChild("Sounds")
	local template = sounds and sounds:FindFirstChild(name)
	if template and template:IsA("Sound") then
		local sound = template:Clone()
		sound.Parent = parent or workspace
		sound:Play()
		sound.Ended:Once(function()
			sound:Destroy()
		end)
	end
end

local function batOf(character: Model?): Model?
	local bat = character and character:FindFirstChild("Bat")
	return if bat and bat:IsA("Model") then bat else nil
end

local function onSwing(attacker: Model?)
	local found = batOf(attacker)
	if found == nil then
		return
	end
	local bat = found :: Model
	local root = (attacker :: Model):FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		WindGust.Play(root, STRIKE_DELAY)
	end
	local trail = bat:FindFirstChild("SwingTrail", true)
	if trail and trail:IsA("Trail") then
		task.delay(STRIKE_DELAY, function()
			trail.Enabled = true
			task.delay(TRAIL_SECONDS, function()
				trail.Enabled = false
			end)
		end)
	end
	playSound("Click", bat.PrimaryPart)
end

local function onKnockedOut(victim: Model?, attacker: Model?, direction: Vector3, _seconds: number)
	local bat = batOf(attacker)
	local burst = bat and bat:FindFirstChild("HitBurst", true)
	if burst and burst:IsA("ParticleEmitter") then
		burst:Emit(20)
	end

	local character = player.Character
	if character == nil then
		return
	end
	if attacker == character then
		showPopup(Strings.YouKnocked, Color3.fromRGB(255, 220, 90))
	end
	if victim ~= character then
		return
	end
	showPopup(Strings.KnockedOut, Color3.fromRGB(255, 90, 90))
	playSound("Error")
	-- Our own character is simulated on this client, so the push is ours to
	-- apply. `direction` is longer than 1 when the attacker has Power.
	local root = (character :: Model):FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		root.AssemblyLinearVelocity = direction * BatConfig.KnockSpeed
			+ Vector3.new(0, BatConfig.KnockLift, 0)
	end
	local humanoid = (character :: Model):FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	end
end

-- The server dropped us in above the arena after a fall: stop falling at
-- full speed, so the drop starts gently.
local function onArenaRespawn()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		root.AssemblyLinearVelocity = Vector3.zero
	end
end

local function onPowerUp(kind: string, userId: number, _position: Vector3)
	if userId ~= player.UserId then
		return
	end
	local text = (Strings.PowerUpPicked :: any)[kind]
	if text then
		showPopup(text, Color3.fromRGB(140, 230, 255))
	end
	playSound("Success")
end

-- Paper confetti falling over the screen.
local function confetti()
	for _ = 1, CONFETTI_PIECES do
		local piece = Instance.new("Frame")
		piece.Name = "Confetti"
		piece.BorderSizePixel = 0
		piece.BackgroundColor3 = CONFETTI_COLORS[math.random(#CONFETTI_COLORS)]
		piece.Size = UDim2.fromScale(0.008, 0.02)
		piece.Position = UDim2.fromScale(math.random(), -0.05 - math.random() * 0.2)
		piece.Rotation = math.random(0, 360)
		piece.Parent = gui
		local seconds = CONFETTI_SECONDS * (0.7 + math.random() * 0.6)
		local tween = TweenService:Create(
			piece,
			TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{
				Position = UDim2.fromScale(
					piece.Position.X.Scale + (math.random() - 0.5) * 0.2,
					1.05
				),
				Rotation = piece.Rotation + math.random(-540, 540),
			}
		)
		tween.Completed:Once(function()
			piece:Destroy()
		end)
		tween:Play()
	end
end

local function onRoundResult(result: Types.RoundResultPayload)
	if result.Outcome == "Win" then
		playSound("Tada")
		confetti()
	elseif result.Outcome == "Draw" then
		playSound("Success")
	end
end

local function onHatched(result: Types.PetHatchedPayload)
	if result.Rarity == "Legendary" or result.Rarity == "Epic" then
		playSound("LevelUp")
		confetti()
	else
		playSound("Success")
	end
end

local function onActionResult(_action: string, reason: string)
	if (Strings.Errors :: any)[reason] then
		playSound("Error")
	end
end

-- A sound only when a new invite arrives, not on every party update.
local function onPartyUpdate(party: Types.PartyPayload)
	local count = #party.Invites
	if count > invitesSeen then
		playSound("Notification")
	end
	invitesSeen = count
end

-- Power-up balls spin and bob locally; the server only places them.
local function animatePowerUps()
	local folder = workspace:FindFirstChild("ActivePowerUps")
	if folder == nil then
		return
	end
	local now = os.clock()
	for _, part in folder:GetChildren() do
		if part:IsA("BasePart") then
			local base = baseHeights[part]
			if base == nil then
				base = part.Position.Y
				baseHeights[part] = base
				part.Destroying:Once(function()
					baseHeights[part] = nil
				end)
			end
			local position = Vector3.new(
				part.Position.X,
				(base :: number) + math.sin(now * 3) * BOB_HEIGHT,
				part.Position.Z
			)
			part.CFrame = CFrame.new(position) * CFrame.Angles(0, now * SPIN_SPEED, 0)
		end
	end
end

function EffectsController:Init()
	gui = Widgets.ScreenGui("Effects", 4)
	popup = Widgets.Label("Popup", gui, UDim2.fromScale(0.5, 0.08), UDim2.fromScale(0.25, 0.22))
	popup.Visible = false
	gui.Parent = player:WaitForChild("PlayerGui")
end

function EffectsController:Start()
	ClientNet.On("BatSwingFx", onSwing)
	ClientNet.On("KnockedOut", onKnockedOut)
	ClientNet.On("ArenaRespawn", onArenaRespawn)
	ClientNet.On("PowerUpEvent", onPowerUp)
	ClientNet.On("RoundResult", onRoundResult)
	ClientNet.On("PetHatched", onHatched)
	ClientNet.On("EggPicked", function()
		playSound("Notification")
	end)
	ClientNet.On("ActionResult", onActionResult)
	ClientNet.On("PartyUpdate", onPartyUpdate)
	RunService.RenderStepped:Connect(animatePowerUps)
end

return EffectsController
