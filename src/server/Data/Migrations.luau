--!strict
-- Ordered schema migrations, applied on load before Reconcile().
-- STEPS[n] upgrades a profile from version n to n + 1. Only renames,
-- removals and reshapes need a step: new fields come from the template.
-- Pure Luau, tested with Lune.

local STEPS: { [number]: (data: any) -> () } = {}

local Migrations = {}

function Migrations.Apply(
	data: any,
	currentVersion: number,
	steps: { [number]: (data: any) -> () }?
)
	local stepTable = steps or STEPS
	local version = if type(data.SchemaVersion) == "number"
		then data.SchemaVersion
		else currentVersion
	while version < currentVersion do
		local step = stepTable[version]
		if step == nil then
			error(`Missing profile migration from version {version}`)
		end
		step(data)
		version += 1
	end
	data.SchemaVersion = version
end

return Migrations
