--!strict
-- Visual and sound feedback for the bat and power-ups, plus the local
-- victim's knock-back flight. All cosmetic: the server already decided the
-- outcome and returns the victim to their spawn on its own.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BatConfig = require(ReplicatedStorage.Shared.Config.BatConfig)
local Strings = require(ReplicatedStorage.Shared.Config.Strings)
local Widgets = require(script.Parent.Parent.UI.Widgets)
local ClientNet = require(script.Parent.Parent.Util.ClientNet)

local player = Players.LocalPlayer

local TRAIL_SECONDS = 0.3
local POPUP_SECONDS = 1.5
local SPIN_SPEED = 2 -- radians per second
local BOB_HEIGHT = 0.4

local EffectsController = {}

local popup: TextLabel
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
	local trail = bat:FindFirstChild("SwingTrail", true)
	if trail and trail:IsA("Trail") then
		trail.Enabled = true
		task.delay(TRAIL_SECONDS, function()
			trail.Enabled = false
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
	-- Our own character is simulated on this client, so the push is ours to apply.
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
	local gui = Widgets.ScreenGui("Effects", 4)
	popup = Widgets.Label("Popup", gui, UDim2.fromScale(0.5, 0.08), UDim2.fromScale(0.25, 0.22))
	popup.Visible = false
	gui.Parent = player:WaitForChild("PlayerGui")
end

function EffectsController:Start()
	ClientNet.On("BatSwingFx", onSwing)
	ClientNet.On("KnockedOut", onKnockedOut)
	ClientNet.On("PowerUpEvent", onPowerUp)
	RunService.RenderStepped:Connect(animatePowerUps)
end

return EffectsController
