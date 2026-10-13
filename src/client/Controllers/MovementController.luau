--!strict
-- Double jump: one more jump in the air after jumping or falling off a
-- ledge, with a puff of air under the feet. Works everywhere (hub and
-- arena). Not while flying from a bat hit, so a hit cannot be cancelled.
-- The player's own client moves its character, so this is all local; the
-- server's speed check only counts horizontal moves (MovementCheck).

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local ClientNet = require(script.Parent.Parent.Util.ClientNet)

local player = Players.LocalPlayer

-- The second jump only counts this long after leaving the ground, so one
-- press (or a held button) does not fire both jumps at once.
local MIN_AIR_SECONDS = 0.18
local JUMP_SCALE = 1 -- the air jump is as strong as a normal one
local PUFF_SECONDS = 0.35

local MovementController = {}

local airSince = 0
local usedAirJump = false
local knockedUntil = 0

local function jumpSpeed(humanoid: Humanoid): number
	if humanoid.UseJumpPower then
		return humanoid.JumpPower
	end
	return math.sqrt(2 * workspace.Gravity * humanoid.JumpHeight)
end

-- A flat ring of air that spreads out under the feet.
local function puff(position: Vector3)
	local ring = Instance.new("Part")
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Shape = Enum.PartType.Cylinder
	ring.Material = Enum.Material.SmoothPlastic
	ring.Color = Color3.fromRGB(220, 240, 255)
	ring.Transparency = 0.35
	ring.Size = Vector3.new(0.2, 1.5, 1.5)
	-- A cylinder's axis is X; turn it upright.
	ring.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.pi / 2)
	ring.Parent = workspace
	local tween = TweenService:Create(
		ring,
		TweenInfo.new(PUFF_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.new(0.1, 5, 5), Transparency = 1 }
	)
	tween.Completed:Once(function()
		ring:Destroy()
	end)
	tween:Play()
end

local function onJumpRequest()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or root == nil or not root:IsA("BasePart") then
		return
	end
	local state = humanoid:GetState()
	local inAir = state == Enum.HumanoidStateType.Freefall
		or state == Enum.HumanoidStateType.Jumping
	local now = os.clock()
	if
		not inAir
		or usedAirJump
		or now - airSince < MIN_AIR_SECONDS
		or now < knockedUntil
		or humanoid.Health <= 0
	then
		return
	end
	usedAirJump = true
	local velocity = root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity =
		Vector3.new(velocity.X, jumpSpeed(humanoid) * JUMP_SCALE, velocity.Z)
	humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	puff(root.Position - Vector3.new(0, humanoid.HipHeight + root.Size.Y / 2, 0))
end

local function watch(character: Model)
	local found = character:WaitForChild("Humanoid", 10)
	if found == nil or not found:IsA("Humanoid") then
		return
	end
	local humanoid = found :: Humanoid
	usedAirJump = false
	humanoid.StateChanged:Connect(function(old, new)
		local Jumping, Freefall = Enum.HumanoidStateType.Jumping, Enum.HumanoidStateType.Freefall
		if new == Jumping or new == Freefall then
			-- Just left the ground (not jumping -> falling, not the air jump).
			if old ~= Jumping and old ~= Freefall then
				airSince = os.clock()
			end
		elseif
			new == Enum.HumanoidStateType.Landed
			or new == Enum.HumanoidStateType.Running
			or new == Enum.HumanoidStateType.Swimming
		then
			usedAirJump = false
		end
	end)
end

function MovementController:Start()
	UserInputService.JumpRequest:Connect(onJumpRequest)
	player.CharacterAdded:Connect(watch)
	if player.Character then
		task.spawn(watch, player.Character)
	end
	ClientNet.On(
		"KnockedOut",
		function(victim: Model?, _attacker: Model?, _direction, seconds: number)
			if victim ~= nil and victim == player.Character then
				knockedUntil = os.clock() + seconds
			end
		end
	)
end

return MovementController
