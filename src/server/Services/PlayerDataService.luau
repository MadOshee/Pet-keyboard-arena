--!strict
-- Owns player profiles through ProfileStore (session locking, autosave,
-- save on leave and on shutdown). The in-memory profile is the single source
-- of truth: gameplay code changes it only through Update(), which also
-- pushes a snapshot to the owner (docs/design.md section 9).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ProfileStore = require(ServerScriptService.ServerPackages.ProfileStore)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local ShopConfig = require(ReplicatedStorage.Shared.Config.ShopConfig)
local Purchases = require(ReplicatedStorage.Shared.Logic.Purchases)
local Types = require(ReplicatedStorage.Shared.Types)
local Migrations = require(script.Parent.Parent.Data.Migrations)
local ProfileTemplate = require(script.Parent.Parent.Data.ProfileTemplate)
local NetService = require(script.Parent.NetService)

local STORE_NAME = "PlayerProfiles"
local SAVE_POLL_SECONDS = 0.5

local PlayerDataService = {}

PlayerDataService.ProfileLoaded = Signal.new() :: Signal.Signal<Player, Types.Profile>
PlayerDataService.ProfileReleasing = Signal.new() :: Signal.Signal<Player>
-- Fired after every Update, for systems that mirror profile data in the world.
PlayerDataService.Changed = Signal.new() :: Signal.Signal<Player, Types.Profile>

local store: any
local profiles: { [Player]: any } = {}

local function sync(player: Player)
	local profile = profiles[player]
	if profile then
		NetService:FireClient("DataSync", player, profile.Data)
	end
end

local function loadProfile(player: Player)
	local profile = store:StartSessionAsync(tostring(player.UserId), {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})

	if profile == nil then
		-- Never fall back to a default profile: its next save would overwrite
		-- the player's real data.
		if player.Parent == Players then
			player:Kick("Your data could not be loaded. Please rejoin.")
		end
		return
	end

	profile:AddUserId(player.UserId)
	Migrations.Apply(profile.Data, ProfileTemplate.CurrentSchemaVersion)
	profile:Reconcile()

	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		if player.Parent == Players then
			player:Kick("Your data was opened on another server. Please rejoin.")
		end
	end)

	if player.Parent ~= Players then
		profile:EndSession()
		return
	end

	profiles[player] = profile
	sync(player)
	PlayerDataService.ProfileLoaded:Fire(player, profile.Data)
end

function PlayerDataService:Init()
	store = ProfileStore.New(STORE_NAME, ProfileTemplate.Template)
end

function PlayerDataService:Start()
	Players.PlayerAdded:Connect(function(player)
		task.spawn(loadProfile, player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(loadProfile, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		local profile = profiles[player]
		if profile then
			PlayerDataService.ProfileReleasing:Fire(player)
			profiles[player] = nil
			profile:EndSession()
		end
	end)
end

function PlayerDataService:IsLoaded(player: Player): boolean
	return profiles[player] ~= nil
end

-- Read-only view. Change data only through Update().
function PlayerDataService:Get(player: Player): Types.Profile?
	local profile = profiles[player]
	return if profile then profile.Data else nil
end

-- Applies `mutator` to the live profile and syncs it to the client.
-- The mutator must not yield, which keeps check-and-change atomic.
-- Returns false when the profile is not loaded.
function PlayerDataService:Update(player: Player, mutator: (data: Types.Profile) -> ()): boolean
	local profile = profiles[player]
	if profile == nil then
		return false
	end
	mutator(profile.Data)
	sync(player)
	PlayerDataService.Changed:Fire(player, profile.Data)
	return true
end

-- Grants a Robux purchase exactly once (docs/design.md section 10). The
-- purchase id is recorded in the same update as the grant, so a repeated
-- receipt changes nothing. PurchaseGranted is returned only after a save
-- that contains the id; otherwise Roblox retries the receipt later.
-- Yields while saving.
function PlayerDataService:GrantPurchase(
	player: Player,
	purchaseId: string,
	mutator: (data: Types.Profile) -> ()
): Enum.ProductPurchaseDecision
	local profile = profiles[player]
	if profile == nil or not profile:IsActive() then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	PlayerDataService:Update(player, function(data)
		if
			Purchases.Remember(data.ProcessedPurchases, purchaseId, ShopConfig.PurchaseHistorySize)
		then
			mutator(data)
		end
	end)

	local function saved(): boolean
		local last = profile.LastSavedData
		return last ~= nil
			and type(last.ProcessedPurchases) == "table"
			and table.find(last.ProcessedPurchases, purchaseId) ~= nil
	end
	if saved() then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	profile:Save()
	-- Polling also ends cleanly if the session closes before a save lands.
	while profile:IsActive() and not saved() do
		task.wait(SAVE_POLL_SECONDS)
	end
	return if saved()
		then Enum.ProductPurchaseDecision.PurchaseGranted
		else Enum.ProductPurchaseDecision.NotProcessedYet
end

return PlayerDataService
