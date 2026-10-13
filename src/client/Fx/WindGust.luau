--!strict
-- Cosmetic gust of wind in front of a bat swing: wavy white streaks and
-- puffs of air that fly out in the same cone the server uses to find the
-- target (BatConfig.Range, BatConfig.HalfAngle), so players see who the hit
-- can reach. Local parts only, nothing is sent to the server.

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local BatConfig = require(game:GetService("ReplicatedStorage").Shared.Config.BatConfig)

local STREAKS = 11
local PUFFS = 9
local SECONDS = 0.42
local REACH = 1.5 -- the wind flies a bit past the hit range
local START = 1.2 -- studs in front of the chest where the wind starts
local WAVE = 0.7 -- studs a streak swings sideways
local WHITE = Color3.fromRGB(255, 255, 255)
local TINT = Color3.fromRGB(200, 235, 255)

type Streak = {
	Part: BasePart,
	Origin: Vector3,
	Direction: Vector3,
	Side: Vector3,
	Lift: number,
	Wave: number,
	Delay: number,
}

local WindGust = {}

local folder: Folder? = nil
local streaks: { Streak } = {}
local startedAt: { [Streak]: number } = {}
local connection: RBXScriptConnection? = nil

local function effectsFolder(): Folder
	local existing = folder
	if existing and existing.Parent then
		return existing
	end
	local created = Instance.new("Folder")
	created.Name = "LocalEffects"
	created.Parent = workspace
	folder = created
	return created
end

local function invisiblePart(): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	return part
end

local function newStreak(origin: Vector3, direction: Vector3, delay: number): Streak
	local part = invisiblePart()
	part.Position = origin
	local top = Instance.new("Attachment")
	top.Position = Vector3.new(0, 0.3, 0)
	top.Parent = part
	local bottom = Instance.new("Attachment")
	bottom.Position = Vector3.new(0, -0.3, 0)
	bottom.Parent = part
	local trail = Instance.new("Trail")
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.FaceCamera = true
	trail.Lifetime = 0.22
	trail.LightEmission = 0.4
	trail.Color = ColorSequence.new(WHITE, TINT)
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(1, 0.2),
	})
	trail.Parent = part
	part.Parent = effectsFolder()
	return {
		Part = part,
		Origin = origin,
		Direction = direction,
		Side = direction:Cross(Vector3.yAxis),
		Lift = (math.random() - 0.5) * 1.6,
		Wave = (math.random() * 2 - 1) * WAVE,
		Delay = delay,
	}
end

local function step()
	local now = os.clock()
	local length = BatConfig.Range + REACH - START
	for i = #streaks, 1, -1 do
		local streak = streaks[i]
		local t = (now - startedAt[streak] - streak.Delay) / SECONDS
		if t >= 1.4 then
			-- Past the end: the trail has faded out too.
			streak.Part:Destroy()
			startedAt[streak] = nil
			table.remove(streaks, i)
		elseif t >= 0 then
			local p = math.min(t, 1)
			local eased = 1 - (1 - p) * (1 - p)
			local position = streak.Origin
				+ streak.Direction * (eased * length)
				+ streak.Side * (math.sin(p * math.pi * 2) * streak.Wave)
				+ Vector3.yAxis * (streak.Lift * eased)
			streak.Part.Position = position
		end
	end
	if #streaks == 0 and connection then
		connection:Disconnect()
		connection = nil
	end
end

local function puff(origin: Vector3, direction: Vector3, delay: number)
	task.delay(delay, function()
		local part = invisiblePart()
		part.Shape = Enum.PartType.Ball
		part.Material = Enum.Material.SmoothPlastic
		part.Color = TINT
		part.Transparency = 0.45
		part.Size = Vector3.one * 0.6
		part.Position = origin
		part.Parent = effectsFolder()
		local distance = BatConfig.Range * (0.55 + math.random() * 0.45)
		local tween = TweenService:Create(
			part,
			TweenInfo.new(SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{
				Position = origin + direction * distance + Vector3.yAxis * (math.random() - 0.3),
				Size = Vector3.one * (2.4 + math.random() * 1.4),
				Transparency = 1,
			}
		)
		tween.Completed:Once(function()
			part:Destroy()
		end)
		tween:Play()
	end)
end

-- Plays one gust from `root` (the attacker's HumanoidRootPart) forward.
function WindGust.Play(root: BasePart, delay: number)
	local cframe = root.CFrame
	local look = Vector3.new(cframe.LookVector.X, 0, cframe.LookVector.Z)
	if look.Magnitude < 0.01 then
		return
	end
	look = look.Unit
	local origin = cframe.Position + look * START + Vector3.new(0, 0.3, 0)
	local half = math.rad(BatConfig.HalfAngle) * 0.85
	local now = os.clock()
	for i = 1, STREAKS do
		local angle = -half + (i - 1) / (STREAKS - 1) * half * 2
		local direction = CFrame.fromAxisAngle(Vector3.yAxis, angle):VectorToWorldSpace(look)
		local streak = newStreak(origin, direction, delay + math.random() * 0.06)
		startedAt[streak] = now
		table.insert(streaks, streak)
	end
	for _ = 1, PUFFS do
		local angle = (math.random() * 2 - 1) * half
		local direction = CFrame.fromAxisAngle(Vector3.yAxis, angle):VectorToWorldSpace(look)
		puff(origin, direction, delay + math.random() * 0.05)
	end
	if connection == nil then
		connection = RunService.RenderStepped:Connect(step)
	end
end

return WindGust
