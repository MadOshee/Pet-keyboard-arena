--!strict
-- How a pet on a plot platform moves (Ivan, 2026-10-14: pets breathe and
-- now and then jump or take a short walk). Everything is measured from the
-- pet's rest spot in the platform's own space: X right, Y up, Z back (the
-- pet faces -Z, towards the button), Yaw in radians around Y. Pure Luau,
-- tested with Lune; PlotPetController turns the pose into a CFrame.

export type ActionKind = "Jump" | "Walk"

export type Action = {
	Kind: ActionKind,
	Start: number,
	-- Walk: the direction (radians, 0 = straight ahead); Jump: unused.
	Angle: number,
	-- Jump: how many hops in a row.
	Hops: number,
}

export type Pose = {
	X: number,
	Y: number,
	Z: number,
	Yaw: number,
	Scale: number,
}

local PetIdle = {}

PetIdle.BreathSeconds = 2.4
PetIdle.BreathAmount = 0.04 -- the pet grows and shrinks by this part
PetIdle.HopSeconds = 0.55
PetIdle.HopHeight = 1.3
PetIdle.WalkDistance = 1.1 -- studs: the platform is about 4 x 4
PetIdle.WalkHop = 0.15 -- little bounces while walking
PetIdle.MaxWalkAngle = math.rad(110) -- not straight back into the wall
PetIdle.MinGap = 3
PetIdle.MaxGap = 8

-- Walk phases: turn out, walk out, turn round, walk back, turn to the front.
local TURN = 0.25
local TURN_ROUND = 0.3
local STEP = 0.8
local WALK_SECONDS = TURN + STEP + TURN_ROUND + STEP + TURN

local function ease(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

-- The yaw after turning round from `angle`, turning the short way back
-- towards the front.
local function roundAngle(angle: number): number
	return if angle < 0 then angle + math.pi else angle - math.pi
end

function PetIdle.Duration(action: Action): number
	return if action.Kind == "Jump" then PetIdle.HopSeconds * action.Hops else WALK_SECONDS
end

-- Breathing: the pet's size factor at time `t` (seconds), shifted by
-- `phase` (0..1) so pets side by side do not breathe in step.
function PetIdle.Breath(t: number, phase: number): number
	local turn = t / PetIdle.BreathSeconds + phase
	return 1 + PetIdle.BreathAmount * math.sin(turn * 2 * math.pi)
end

-- The pose at time `now`. Without an action, or outside it, the pet
-- stands at rest and only breathes.
function PetIdle.Pose(now: number, phase: number, action: Action?): Pose
	local pose: Pose = { X = 0, Y = 0, Z = 0, Yaw = 0, Scale = PetIdle.Breath(now, phase) }
	if action == nil then
		return pose
	end
	local current = action :: Action
	local u = now - current.Start
	if u <= 0 or u >= PetIdle.Duration(current) then
		return pose
	end
	if current.Kind == "Jump" then
		local p = (u % PetIdle.HopSeconds) / PetIdle.HopSeconds
		pose.Y = 4 * PetIdle.HopHeight * p * (1 - p)
		return pose
	end
	local angle = current.Angle
	local back = roundAngle(angle)
	local out = 0 -- how far along the walk, 0..1
	if u < TURN then
		pose.Yaw = angle * ease(u / TURN)
	elseif u < TURN + STEP then
		local p = (u - TURN) / STEP
		out = ease(p)
		pose.Yaw = angle
		pose.Y = PetIdle.WalkHop * math.abs(math.sin(p * 3 * math.pi))
	elseif u < TURN + STEP + TURN_ROUND then
		out = 1
		pose.Yaw = angle + (back - angle) * ease((u - TURN - STEP) / TURN_ROUND)
	elseif u < TURN + 2 * STEP + TURN_ROUND then
		local p = (u - TURN - STEP - TURN_ROUND) / STEP
		out = 1 - ease(p)
		pose.Yaw = back
		pose.Y = PetIdle.WalkHop * math.abs(math.sin(p * 3 * math.pi))
	else
		pose.Yaw = back * (1 - ease((u - TURN - 2 * STEP - TURN_ROUND) / TURN))
	end
	-- Facing -Z turned by `angle`: right is +X, ahead is -Z.
	pose.X = -math.sin(angle) * PetIdle.WalkDistance * out
	pose.Z = -math.cos(angle) * PetIdle.WalkDistance * out
	return pose
end

-- Picks the next action after `now`: a jump of one or two hops or a walk,
-- MinGap..MaxGap seconds later. `rng` returns 0..1.
function PetIdle.Next(now: number, rng: () -> number): Action
	local start = now + PetIdle.MinGap + (PetIdle.MaxGap - PetIdle.MinGap) * rng()
	if rng() < 0.5 then
		return { Kind = "Jump", Start = start, Angle = 0, Hops = if rng() < 0.35 then 2 else 1 }
	end
	return {
		Kind = "Walk",
		Start = start,
		Angle = (rng() * 2 - 1) * PetIdle.MaxWalkAngle,
		Hops = 0,
	}
end

return PetIdle
