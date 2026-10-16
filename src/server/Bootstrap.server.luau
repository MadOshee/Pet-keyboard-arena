--!strict
-- The only server entry point. Requires services in dependency order
-- (docs/design.md section 5.1) and runs them through the two-phase Loader.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Loader = require(ReplicatedStorage.Shared.Util.Loader)

-- Lower layers first. New services are added here as each stage lands.
local SERVICE_ORDER: { string } = {
	"NetService",
	"PlayerDataService",
	"GamePassService",
	"ReadyService",
	"PartyService",
	"PortalService",
	"PetService",
	"StatsService",
	"NameplateService",
	"MovementGuard",
	"ArenaService",
	"PowerUpService",
	"BatService",
	"BotService",
	"MatchmakingService",
	"RoundService",
	"EggService",
	"PlatformService",
	"PlotService",
	"TutorialService",
	"FeedbackService",
	"SettingsService",
	"MonetizationService",
	"RewardService",
}

-- An arena server (MatchMode) only needs the keyboard. The hub map is about
-- half of all parts, and without streaming every client downloads all of it
-- on each arrival while the match already runs: on the live game that held
-- up replication for seconds (Ivan 2026-10-16, data ping 1.6-2.4 s).
-- Players join only after this script has run.
local MatchMode = require(script.Parent.Match.MatchMode)
if MatchMode.IsArena() then
	local world = workspace:FindFirstChild("World")
	if world then
		world:Destroy()
	end
end

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

print(`[EggKeyboardArena] server started ({#entries} services)`)
