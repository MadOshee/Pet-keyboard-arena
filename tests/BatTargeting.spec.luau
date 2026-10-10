local BatTargeting = require("../src/shared/Logic/BatTargeting")

local function p(x: number, z: number)
	return { X = x, Y = 0, Z = z }
end

local ORIGIN = p(0, 0)
local LOOK = p(0, -1) -- facing -Z like a Roblox CFrame.LookVector

local tests = {}

function tests.hitsTargetInFront()
	local target =
		BatTargeting.FindTarget(ORIGIN, LOOK, { { Id = "a", Position = p(0, -5) } }, 7, 60)
	assert(target == "a")
end

function tests.missesBehindAndOutOfRange()
	local candidates = {
		{ Id = "behind", Position = p(0, 3) },
		{ Id = "far", Position = p(0, -8) },
	}
	assert(BatTargeting.FindTarget(ORIGIN, LOOK, candidates, 7, 60) == nil)
end

function tests.coneEdge()
	-- 50 degrees off the look direction is inside a 60 degree half-angle.
	local inside = p(math.sin(math.rad(50)) * 5, -math.cos(math.rad(50)) * 5)
	local outside = p(math.sin(math.rad(70)) * 5, -math.cos(math.rad(70)) * 5)
	assert(
		BatTargeting.FindTarget(ORIGIN, LOOK, { { Id = "in", Position = inside } }, 7, 60) == "in"
	)
	assert(
		BatTargeting.FindTarget(ORIGIN, LOOK, { { Id = "out", Position = outside } }, 7, 60) == nil
	)
end

function tests.picksNearest()
	local candidates = {
		{ Id = "far", Position = p(1, -6) },
		{ Id = "near", Position = p(-1, -3) },
	}
	assert(BatTargeting.FindTarget(ORIGIN, LOOK, candidates, 7, 60) == "near")
end

function tests.ignoresHeight()
	local target = BatTargeting.FindTarget(
		ORIGIN,
		LOOK,
		{ { Id = "a", Position = { X = 0, Y = 30, Z = -4 } } },
		7,
		60
	)
	assert(target == "a")
end

function tests.zeroLookHitsNothing()
	assert(
		BatTargeting.FindTarget(ORIGIN, p(0, 0), { { Id = "a", Position = p(0, -2) } }, 7, 60)
			== nil
	)
end

return tests
