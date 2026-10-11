--!strict
-- The only client entry point. Mirrors the server bootstrap for controllers.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

ReplicatedStorage:WaitForChild("Shared")
local Loader = require(ReplicatedStorage.Shared.Util.Loader)

-- New controllers are added here as each stage lands.
local CONTROLLER_ORDER: { string } = {
	"DataController",
	"HudController",
	"KeyPressController",
	"EggOfferController",
	"InventoryController",
	"PetFollowController",
	"BatController",
	"EffectsController",
	"PlotController",
	"PartyController",
	"PortalController",
	"ShopController",
	"TutorialController",
}

local controllersFolder = script.Parent:FindFirstChild("Controllers")

local entries: { Loader.Entry } = {}
for _, name in CONTROLLER_ORDER do
	local moduleScript = controllersFolder and controllersFolder:FindFirstChild(name)
	if not (moduleScript and moduleScript:IsA("ModuleScript")) then
		error(`Controller module not found: {name}`)
	end
	table.insert(entries, { Name = name, Module = (require :: any)(moduleScript) })
end

Loader.Run(entries)

print(`[PetKeyboardArena] client started ({#entries} controllers)`)
