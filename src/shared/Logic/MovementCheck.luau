--!strict
-- Speed-hack check (docs/design.md section 11): a move between two server
-- samples is suspicious when it is longer than WalkSpeed x time x factor
-- plus a margin. Only horizontal distance counts, so jumps and falls are
-- fine. Pure Luau, tested with Lune.

export type Settings = {
	Factor: number,
	Margin: number,
}

local MovementCheck = {}

function MovementCheck.IsSuspicious(
	fromX: number,
	fromZ: number,
	toX: number,
	toZ: number,
	dt: number,
	walkSpeed: number,
	settings: Settings
): boolean
	local dx, dz = toX - fromX, toZ - fromZ
	local allowed = walkSpeed * dt * settings.Factor + settings.Margin
	return dx * dx + dz * dz > allowed * allowed
end

return MovementCheck
