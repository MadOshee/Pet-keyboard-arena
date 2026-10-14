local PetIdle = require("../src/shared/Logic/PetIdle")

local tests = {}

local function near(a: number, b: number): boolean
	return math.abs(a - b) < 1e-6
end

local function atRest(pose: PetIdle.Pose): boolean
	return near(pose.X, 0) and near(pose.Y, 0) and near(pose.Z, 0) and near(pose.Yaw, 0)
end

function tests.breathingStaysSmall()
	for step = 0, 100 do
		local scale = PetIdle.Breath(step * 0.1, 0.3)
		assert(
			scale >= 1 - PetIdle.BreathAmount - 1e-9 and scale <= 1 + PetIdle.BreathAmount + 1e-9
		)
	end
	assert(not near(PetIdle.Breath(1, 0), PetIdle.Breath(1, 0.25)))
end

function tests.restWithoutAction()
	assert(atRest(PetIdle.Pose(5, 0, nil)))
	local jump = { Kind = "Jump", Start = 10, Angle = 0, Hops = 1 } :: PetIdle.Action
	assert(atRest(PetIdle.Pose(9, 0, jump)))
	assert(atRest(PetIdle.Pose(10 + PetIdle.Duration(jump), 0, jump)))
end

function tests.jumpPeaksInTheMiddle()
	local jump = { Kind = "Jump", Start = 0, Angle = 0, Hops = 2 } :: PetIdle.Action
	assert(near(PetIdle.Duration(jump), PetIdle.HopSeconds * 2))
	local peak = PetIdle.Pose(PetIdle.HopSeconds / 2, 0, jump)
	assert(near(peak.Y, PetIdle.HopHeight))
	local second = PetIdle.Pose(PetIdle.HopSeconds * 1.5, 0, jump)
	assert(near(second.Y, PetIdle.HopHeight))
end

function tests.walkGoesOutAndComesBack()
	for _, angle in { -PetIdle.MaxWalkAngle, -0.5, 0, 0.7, PetIdle.MaxWalkAngle } do
		local walk = { Kind = "Walk", Start = 0, Angle = angle, Hops = 0 } :: PetIdle.Action
		local duration = PetIdle.Duration(walk)
		local farthest = 0
		local t = 0
		while t < duration do
			local pose = PetIdle.Pose(t, 0, walk)
			local distance = math.sqrt(pose.X * pose.X + pose.Z * pose.Z)
			assert(distance <= PetIdle.WalkDistance + 1e-6)
			farthest = math.max(farthest, distance)
			t += 0.01
		end
		assert(near(farthest, PetIdle.WalkDistance))
		local last = PetIdle.Pose(duration - 1e-4, 0, walk)
		assert(math.abs(last.Yaw) < 0.01 and math.abs(last.X) < 0.01 and math.abs(last.Z) < 0.01)
	end
end

function tests.walkStraightAheadGoesTowardsTheButton()
	local walk = { Kind = "Walk", Start = 0, Angle = 0, Hops = 0 } :: PetIdle.Action
	local pose = PetIdle.Pose(1.1, 0, walk) -- turned round at the far end
	assert(near(pose.X, 0) and near(pose.Z, -PetIdle.WalkDistance))
end

function tests.nextActionComesAfterAGap()
	local values = { 0.5, 0.9, 0.2 }
	local i = 0
	local action = PetIdle.Next(100, function()
		i += 1
		return values[i]
	end)
	assert(action.Kind == "Walk")
	assert(action.Start >= 100 + PetIdle.MinGap and action.Start <= 100 + PetIdle.MaxGap)
	assert(math.abs(action.Angle) <= PetIdle.MaxWalkAngle)
end

return tests
