--!strict
-- Cosmetic only: how every character holding the bat (players and bots)
-- moves. Roblox animations need uploaded animation assets, so the bat arm
-- is posed in code instead: each frame, after the default animations, the
-- right arm and the waist joints get their own Transform. The joints are
-- Motor6Ds or, with Roblox's new avatar joints, AnimationConstraints; both
-- have a Transform.
--
-- Standing: the bat rests on the right shoulder. Running: the body leans
-- into the run, the bat bounces on the shoulder in step and the torso
-- twists with the legs. Swinging (BatSwingFx): wind-up, a flat swing
-- across the front and a follow-through back to the shoulder.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ClientNet = require(script.Parent.Parent.Util.ClientNet)

local rad = math.rad

-- A pose is the rotation (degrees, X/Y/Z) of each joint we drive.
type Pose = {
	Shoulder: Vector3,
	Elbow: Vector3,
	Wrist: Vector3,
	Waist: Vector3,
}

-- Bat on the shoulder, fist by the collarbone (tuned in Studio).
local CARRY: Pose = {
	Shoulder = Vector3.new(35, 0, 22),
	Elbow = Vector3.new(115, 0, 0),
	Wrist = Vector3.new(-5, 0, 0),
	Waist = Vector3.new(0, 0, 0),
}

-- A flat one-handed swing from behind the right shoulder, through the front
-- (where the hit lands) to the left: { seconds from the start, pose }.
-- The wrist at -90 turns the bat to point along the arm.
local SWING: { { any } } = {
	{ 0, CARRY },
	{
		0.1, -- wind-up: arm back, bat pointing behind, body turned right
		{
			Shoulder = Vector3.new(20, -30, 80),
			Elbow = Vector3.new(30, 0, 0),
			Wrist = Vector3.new(-90, 0, 0),
			Waist = Vector3.new(0, -35, 0),
		},
	},
	{
		0.2, -- the hit: arm and bat straight ahead
		{
			Shoulder = Vector3.new(90, 0, 0),
			Elbow = Vector3.new(0, 0, 0),
			Wrist = Vector3.new(-90, 0, 0),
			Waist = Vector3.new(0, 10, 0),
		},
	},
	{
		0.32, -- follow-through: bat swept round to the left
		{
			Shoulder = Vector3.new(90, 85, 0),
			Elbow = Vector3.new(10, 0, 0),
			Wrist = Vector3.new(-90, 0, 0),
			Waist = Vector3.new(0, 40, 0),
		},
	},
	{ 0.6, CARRY },
}
local SWING_SECONDS = 0.6

-- Running motion.
local RUN_SPEED = 14 -- studs/s at which the run motion is at full strength
-- Radians of the step cycle per stud run, so the bounce keeps pace with the legs.
local STEP_RATE = 0.575
local LEAN = 10 -- degrees forward at full run
local TWIST = 9 -- degrees of torso twist per step
local BOUNCE = 9 -- degrees the bat bounces on the shoulder per step

-- A Motor6D or an AnimationConstraint.
type Joint = { Transform: CFrame }

type Rig = {
	Shoulder: Joint,
	Elbow: Joint,
	Wrist: Joint,
	Waist: Joint,
	Root: BasePart,
	Humanoid: Humanoid,
	Phase: number,
	SwingStart: number,
}

local BatPoseController = {}

local rigs: { [Model]: Rig } = {}

local function joint(character: Model, partName: string, jointName: string): Joint?
	local part = character:FindFirstChild(partName)
	local found = part and part:FindFirstChild(jointName)
	if found and (found:IsA("Motor6D") or found:IsA("AnimationConstraint")) then
		return found :: any
	end
	return nil
end

local function rigOf(character: Model): Rig?
	local rig = rigs[character]
	if rig then
		return rig
	end
	local shoulder = joint(character, "RightUpperArm", "RightShoulder")
	local elbow = joint(character, "RightLowerArm", "RightElbow")
	local wrist = joint(character, "RightHand", "RightWrist")
	local waist = joint(character, "UpperTorso", "Waist")
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if
		shoulder == nil
		or elbow == nil
		or wrist == nil
		or waist == nil
		or root == nil
		or not root:IsA("BasePart")
		or humanoid == nil
	then
		return nil
	end
	local created: Rig = {
		Shoulder = shoulder :: Joint,
		Elbow = elbow :: Joint,
		Wrist = wrist :: Joint,
		Waist = waist :: Joint,
		Root = root :: BasePart,
		Humanoid = humanoid :: Humanoid,
		Phase = 0,
		SwingStart = -math.huge,
	}
	rigs[character] = created
	character.Destroying:Once(function()
		rigs[character] = nil
	end)
	return created
end

local function angles(v: Vector3): CFrame
	return CFrame.fromOrientation(rad(v.X), rad(v.Y), rad(v.Z))
end

local function smooth(t: number): number
	return t * t * (3 - 2 * t)
end

local function lerpPose(a: Pose, b: Pose, t: number): Pose
	return {
		Shoulder = a.Shoulder:Lerp(b.Shoulder, t),
		Elbow = a.Elbow:Lerp(b.Elbow, t),
		Wrist = a.Wrist:Lerp(b.Wrist, t),
		Waist = a.Waist:Lerp(b.Waist, t),
	}
end

local function swingPose(elapsed: number): Pose
	for i = 2, #SWING do
		local fromTime, fromPose = SWING[i - 1][1] :: number, SWING[i - 1][2] :: Pose
		local toTime, toPose = SWING[i][1] :: number, SWING[i][2] :: Pose
		if elapsed <= toTime then
			return lerpPose(fromPose, toPose, smooth((elapsed - fromTime) / (toTime - fromTime)))
		end
	end
	return CARRY
end

local function characters(): { Model }
	local list = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(list, player.Character)
		end
	end
	local bots = workspace:FindFirstChild("Bots")
	if bots then
		for _, bot in bots:GetChildren() do
			if bot:IsA("Model") then
				table.insert(list, bot)
			end
		end
	end
	return list
end

local function update(dt: number)
	local now = os.clock()
	for _, character in characters() do
		if character:FindFirstChild("Bat") == nil then
			continue
		end
		local rig = rigOf(character)
		if rig == nil then
			continue
		end
		local r = rig :: Rig
		local elapsed = now - r.SwingStart
		local pose = if elapsed < SWING_SECONDS then swingPose(elapsed) else CARRY

		-- How much of a run this is, from the ground speed.
		local velocity = r.Root.AssemblyLinearVelocity
		local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
		local grounded = r.Humanoid.FloorMaterial ~= Enum.Material.Air
		local run = if grounded then math.clamp(speed / RUN_SPEED, 0, 1) else 0
		r.Phase = (r.Phase + dt * speed * STEP_RATE) % (2 * math.pi)
		local step = math.sin(r.Phase)
		local bounce = math.abs(math.cos(r.Phase))
		local swinging = elapsed < SWING_SECONDS

		local shoulder = pose.Shoulder
		local waist = pose.Waist
		if not swinging then
			shoulder += Vector3.new(-BOUNCE * bounce * run, 0, 0)
			waist += Vector3.new(-LEAN * run, TWIST * step * run, 0)
		else
			waist += Vector3.new(-LEAN * run, 0, 0)
		end

		r.Shoulder.Transform = angles(shoulder)
		r.Elbow.Transform = angles(pose.Elbow)
		r.Wrist.Transform = angles(pose.Wrist)
		r.Waist.Transform = angles(waist)
	end
end

function BatPoseController:Start()
	ClientNet.On("BatSwingFx", function(attacker: Model?)
		local rig = attacker and rigOf(attacker)
		if rig then
			rig.SwingStart = os.clock()
		end
	end)
	-- After the animations, before physics and rendering.
	RunService.PreSimulation:Connect(update)
end

return BatPoseController
