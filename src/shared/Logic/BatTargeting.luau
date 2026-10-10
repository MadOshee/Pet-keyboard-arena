--!strict
-- Picks who a bat swing hits (docs/design.md D11): the nearest candidate
-- within range and inside the cone in front of the attacker. Only the
-- horizontal plane counts. Pure Luau, tested with Lune; positions are plain
-- {X, Y, Z} tables so tests need no Roblox types.

export type Point = { X: number, Y: number, Z: number }

export type Candidate<T> = {
	Id: T,
	Position: Point,
}

local BatTargeting = {}

-- `look` is the attacker's facing direction (any length).
function BatTargeting.FindTarget<T>(
	origin: Point,
	look: Point,
	candidates: { Candidate<T> },
	range: number,
	halfAngleDegrees: number
): T?
	local lookLength = math.sqrt(look.X * look.X + look.Z * look.Z)
	if lookLength < 1e-6 then
		return nil
	end
	local lookX, lookZ = look.X / lookLength, look.Z / lookLength
	local minDot = math.cos(math.rad(halfAngleDegrees))

	local best: T? = nil
	local bestDistance = math.huge
	for _, candidate in candidates do
		local dx = candidate.Position.X - origin.X
		local dz = candidate.Position.Z - origin.Z
		local distance = math.sqrt(dx * dx + dz * dz)
		if distance <= range and distance < bestDistance then
			-- A target standing right on top of the attacker always counts.
			local inCone = distance < 1e-6 or (dx * lookX + dz * lookZ) / distance >= minDot
			if inCone then
				best = candidate.Id
				bestDistance = distance
			end
		end
	end
	return best
end

return BatTargeting
