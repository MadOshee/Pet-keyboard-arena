--!strict
-- Plot platforms (docs/design.md 4.3 "Участок", 4.5): each platform of the
-- player's base holds an egg or a pet. The player steps on the green button
-- in front of it and picks what to put there (PlatformController); this
-- service checks and applies the request. An egg hatches on its own when
-- its time comes and the pet takes the platform. Pets on platforms earn
-- their kind's Income (PetConfig) coins every second, and on joining the player
-- gets what they earned while away (capped, see PetIncome).
--
-- Platforms are Profile.Incubators (the name predates them). Income is paid
-- up to Profile.IncomeAt; every change to the pets on platforms settles the
-- income first, in the same profile update, so no second is paid twice.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EggConfig = require(ReplicatedStorage.Shared.Config.EggConfig)
local PetConfig = require(ReplicatedStorage.Shared.Config.PetConfig)
local EggRoller = require(ReplicatedStorage.Shared.Logic.EggRoller)
local PetIncome = require(ReplicatedStorage.Shared.Logic.PetIncome)
local Types = require(ReplicatedStorage.Shared.Types)
local Guard = require(script.Parent.Parent.Util.Guard)
local EggService = require(script.Parent.EggService)
local NetService = require(script.Parent.NetService)
local PetService = require(script.Parent.PetService)
local PlayerDataService = require(script.Parent.PlayerDataService)

local ID_MAX_LENGTH = 64
local TICK_SECONDS = 1
-- Shorter absences are not worth a "while you were away" message.
local OFFLINE_NOTICE_SECONDS = 60

local ACTIONS: { [string]: true } = {
	PlaceEgg = true,
	PlacePet = true,
	Take = true,
	SpeedUp = true,
	Buy = true,
}

local PlatformService = {}

local random = Random.new()
local function rng(): number
	return random:NextNumber()
end

local function refuse(player: Player, action: string, reason: Types.ActionError)
	NetService:FireClient("ActionResult", player, action, reason)
end

local function countEggs(data: Types.Profile): number
	local count = 0
	for _ in data.Eggs do
		count += 1
	end
	return count
end

-- Runs inside a profile Update: hatches every ready egg on a platform, then
-- pays the pets on platforms up to `now`. A pet that hatched inside the
-- period earns from its hatch time. Returns the hatched pets and the coins.
local function settle(data: Types.Profile, now: number): ({ Types.PetHatchedPayload }, number)
	local hatched: { Types.PetHatchedPayload } = {}
	local earners: { PetIncome.Earner } = {}
	for _, slot in data.Incubators do
		local egg = slot.Egg
		if egg ~= nil and slot.HatchAt ~= nil and (slot.HatchAt :: number) <= now then
			local hatchAt = slot.HatchAt :: number
			local kind = EggRoller.RollPet(PetConfig.Pets :: any, egg.Theme, egg.Rarity, rng)
			local petId = kind and PetService:AddToProfile(data, kind, egg.Rarity, true)
			if kind and petId then
				slot.Egg = nil
				slot.HatchAt = nil
				slot.PetId = petId
				table.insert(hatched, { Kind = kind, Rarity = egg.Rarity, PetId = petId })
				table.insert(earners, { Kind = kind :: string, From = hatchAt })
			end
		elseif slot.PetId ~= nil then
			local pet = data.Pets[slot.PetId :: string]
			if pet then
				table.insert(earners, { Kind = pet.Kind })
			else
				slot.PetId = nil -- the pet is gone (for example a removed kind)
			end
		end
	end
	local coins = if data.IncomeAt > 0
		then PetIncome.Earned(earners, data.IncomeAt, now, PetConfig :: any)
		else 0
	data.Coins += coins
	data.IncomeAt = now
	return hatched, coins
end

local function needsSettle(data: Types.Profile, now: number): boolean
	for _, slot in data.Incubators do
		if slot.PetId ~= nil then
			return true
		end
		if slot.Egg ~= nil and slot.HatchAt ~= nil and (slot.HatchAt :: number) <= now then
			return true
		end
	end
	return false
end

local function announce(player: Player, hatched: { Types.PetHatchedPayload })
	for _, payload in hatched do
		NetService:FireClient("PetHatched", player, payload)
	end
end

-- Applies `change` to the platform after settling income, in one update.
local function changePlatform(player: Player, change: (data: Types.Profile) -> ())
	local hatched: { Types.PetHatchedPayload } = {}
	PlayerDataService:Update(player, function(profile)
		hatched = settle(profile, os.time())
		change(profile)
	end)
	announce(player, hatched)
end

local function onAction(player: Player, index: unknown, action: unknown, id: unknown)
	if
		not Guard.Integer(index, 1, EggConfig.MaxIncubators)
		or type(action) ~= "string"
		or not ACTIONS[action :: string]
		or (id ~= nil and not Guard.String(id, ID_MAX_LENGTH))
	then
		return
	end
	local slotIndex = index :: number
	local kind = action :: string
	local loaded = PlayerDataService:Get(player)
	if loaded == nil then
		return
	end
	local data = loaded :: Types.Profile
	local owned = #data.Incubators

	if kind == "Buy" then
		if slotIndex ~= owned + 1 then
			refuse(player, "Platform", if slotIndex <= owned then "Busy" else "Locked")
			return
		end
		EggService:BuyIncubator(player)
		return
	end
	if slotIndex > owned then
		refuse(player, "Platform", "Locked")
		return
	end
	local slot = data.Incubators[slotIndex]
	local empty = slot.Egg == nil and slot.PetId == nil

	if kind == "SpeedUp" then
		EggService:SpeedUp(player, slotIndex)
	elseif kind == "PlaceEgg" then
		local eggId = id :: string?
		if not empty then
			refuse(player, "Platform", "Busy")
			return
		end
		if eggId == nil or data.Eggs[eggId :: string] == nil then
			refuse(player, "Platform", "NoEggs")
			return
		end
		changePlatform(player, function(profile)
			local egg = profile.Eggs[eggId :: string]
			profile.Eggs[eggId :: string] = nil
			local target = profile.Incubators[slotIndex]
			target.Egg = egg
			target.HatchAt = os.time() + EggService:HatchSeconds(player, egg.Rarity)
		end)
	elseif kind == "PlacePet" then
		local petId = id :: string?
		if not empty then
			refuse(player, "Platform", "Busy")
			return
		end
		if petId == nil or data.Pets[petId :: string] == nil then
			refuse(player, "Platform", "NotOwned")
			return
		end
		if PetIncome.PlacedPets(data.Incubators :: any)[petId :: string] then
			refuse(player, "Platform", "OnPlatform")
			return
		end
		local equipped = table.find(data.Equipped, petId :: string) ~= nil
		if equipped and player:GetAttribute("Team") ~= nil then
			refuse(player, "Platform", "InRound")
			return
		end
		changePlatform(player, function(profile)
			-- A pet either follows its owner or earns on a platform.
			local at = table.find(profile.Equipped, petId :: string)
			if at then
				table.remove(profile.Equipped, at)
			end
			profile.Incubators[slotIndex].PetId = petId
		end)
		if equipped then
			PetService:PublishEquipped(player)
		end
	else -- Take: the pet goes back to the inventory, an egg back to storage.
		if slot.PetId ~= nil then
			if PetService:Count(data) >= data.PetCapacity then
				refuse(player, "Platform", "PetsFull")
				return
			end
			changePlatform(player, function(profile)
				profile.Incubators[slotIndex].PetId = nil
			end)
		elseif slot.Egg ~= nil then
			if countEggs(data) >= data.EggCapacity then
				refuse(player, "Platform", "EggsFull")
				return
			end
			changePlatform(player, function(profile)
				local target = profile.Incubators[slotIndex]
				local egg = target.Egg
				target.Egg = nil
				target.HatchAt = nil
				if egg then
					profile.Eggs[HttpService:GenerateGUID(false)] =
						{ Theme = egg.Theme, Rarity = egg.Rarity }
				end
			end)
		end
	end
end

-- Pays what the pets earned while the player was away, and hatches the
-- eggs whose time came meanwhile.
local function onLoaded(player: Player, data: Types.Profile)
	local paidBefore = data.IncomeAt > 0
	local away = os.time() - data.IncomeAt
	local coins = 0
	PlayerDataService:Update(player, function(profile)
		local _, earned = settle(profile, os.time())
		coins = earned
	end)
	if coins > 0 and paidBefore and away >= OFFLINE_NOTICE_SECONDS then
		local payload: Types.OfflineIncomePayload = {
			Coins = coins,
			Seconds = math.min(away, PetConfig.OfflineIncomeMaxSeconds),
		}
		NetService:FireClient("OfflineIncome", player, payload)
	end
end

local function tick()
	local now = os.time()
	for _, player in Players:GetPlayers() do
		local data = PlayerDataService:Get(player)
		if data and needsSettle(data :: Types.Profile, now) then
			local hatched: { Types.PetHatchedPayload } = {}
			PlayerDataService:Update(player, function(profile)
				hatched = settle(profile, now)
			end)
			announce(player, hatched)
		end
	end
end

function PlatformService:Init() end

function PlatformService:Start()
	NetService:On("PlatformAction", { PerSecond = 4, Burst = 8 }, onAction)
	PlayerDataService.ProfileLoaded:Connect(onLoaded)
	for _, player in Players:GetPlayers() do
		local data = PlayerDataService:Get(player)
		if data then
			onLoaded(player, data)
		end
	end
	task.spawn(function()
		while true do
			task.wait(TICK_SECONDS)
			local ok, err = pcall(function()
				tick()
			end)
			if not ok then
				warn(`[PlatformService] {err}`)
			end
		end
	end)
end

return PlatformService
