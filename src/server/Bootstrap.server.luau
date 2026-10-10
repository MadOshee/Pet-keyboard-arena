--!strict
-- The only server entry point. Requires services in dependency order
-- (docs/design.md section 5.1) and runs them through the two-phase Loader.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Loader = require(ReplicatedStorage.Shared.Util.Loader)

-- Lower layers first. New services are added here as each stage lands.
local SERVICE_ORDER: { string } = {
	"NetService",
	"PlayerDataService",
	"ReadyService",
	"PetService",
	"StatsService",
	"ArenaService",
	"RoundService",
	"EggService",
	"RewardService",
}

local servicesFolder = script.Parent:FindFirstChild("Services")

local entries: { Loader.Entry } = {}
for _, name in SERVICE_ORDER do
	local moduleScript = servicesFolder and servicesFolder:FindFirstChild(name)
	if not (moduleScript and moduleScript:IsA("ModuleScript")) then
		error(`Service module not found: {name}`)
	end
	table.insert(entries, { Name = name, Module = (require :: any)(moduleScript) })
end

Loader.Run(entries)

print(`[PetKeyboardArena] server started ({#entries} services)`)
