--!strict
-- Egg offers after a round (1 of 4, rerolls for coins, auto-pick on
-- timeout), egg storage and incubators (docs/design.md 4.3 "Яйца", D3,
-- sections 9-10). A picked egg goes straight into a free incubator when
-- there is one. PlotService turns incubator prompts into the calls below;
-- each checks the profile itself, so the world never decides a result.
--
-- The offer lives in the profile (PendingOffer), so leaving the game does
-- not lose it, and the client sees it through DataSync. Every pick and
-- reroll checks the OfferId and replaces or clears the offer in the same
-- profile update, so a double click or a replayed request cannot give two
-- pets or charge twice.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EggConfig = require(ReplicatedStorage.Shared.Config.EggConfig)
local PetConfig = require(ReplicatedStorage.Shared.Config.PetConfig)
local EggRoller = require(ReplicatedStorage.Shared.Logic.EggRoller)
local Incubation = require(ReplicatedStorage.Shared.Logic.Incubation)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local Types = require(ReplicatedStorage.Shared.Types)
local Guard = require(script.Parent.Parent.Util.Guard)
local NetService = require(script.Parent.NetService)
local PetService = require(script.Parent.PetService)
local PlayerDataService = require(script.Parent.PlayerDataService)

local OFFER_ID_MAX_LENGTH = 64
local EXPIRY_CHECK_SECONDS = 1

local EggService = {}

EggService.PetHatched = Signal.new() :: Signal.Signal<Player, Types.PetHatchedPayload>

local random = Random.new()
local function rng(): number
	return random:NextNumber()
end

local function refuse(player: Player, action: string, reason: Types.ActionError)
	NetService:FireClient("ActionResult", player, action, reason)
end

local function newOffer(context: Types.OfferContext, rerollCount: number): Types.EggOffer
	local eggs = EggRoller.RollOffer(
		context :: any,
		EggConfig.OfferThemes,
		PetConfig.Rarities,
		EggConfig,
		rng
	)
	return {
		OfferId = HttpService:GenerateGUID(false),
		Eggs = eggs :: any,
		RerollCount = rerollCount,
		ExpiresAt = os.time() + EggConfig.OfferSeconds,
		Context = context,
	}
end

-- Puts `egg` into the first empty incubator. Returns its HatchAt, or nil
-- when every incubator is busy. Runs inside a profile Update.
local function placeInFreeIncubator(data: Types.Profile, egg: Types.EggInstance): number?
	for _, incubator in data.Incubators do
		if incubator.Egg == nil then
			local hatchAt = os.time() + Incubation.HatchSeconds(egg.Rarity, EggConfig)
			incubator.Egg = { Theme = egg.Theme, Rarity = egg.Rarity }
			incubator.HatchAt = hatchAt
			return hatchAt
		end
	end
	return nil
end

local function countEggs(data: Types.Profile): number
	local count = 0
	for _ in data.Eggs do
		count += 1
	end
	return count
end

-- Takes the egg in `slot` of the current offer and clears the offer. The egg
-- goes into a free incubator, else into egg storage, else becomes coins.
local function pick(player: Player, slot: number, autoPicked: boolean)
	local offer = EggService:GetOffer(player)
	if offer == nil then
		return
	end
	local egg = (offer :: Types.EggOffer).Eggs[slot]

	local where: "Incubator" | "Storage" | "Coins" = "Coins"
	local hatchAt: number? = nil
	local coins = 0
	PlayerDataService:Update(player, function(profile)
		profile.PendingOffer = nil
		hatchAt = placeInFreeIncubator(profile, egg)
		if hatchAt then
			where = "Incubator"
		elseif countEggs(profile) < profile.EggCapacity then
			profile.Eggs[HttpService:GenerateGUID(false)] =
				{ Theme = egg.Theme, Rarity = egg.Rarity }
			where = "Storage"
		else
			-- Everything full: the egg is converted to coins (the window warns).
			coins = PetConfig.SellValue[egg.Rarity] or 0
			profile.Coins += coins
		end
	end)

	local payload: Types.EggPickedPayload = {
		Theme = egg.Theme,
		Rarity = egg.Rarity,
		Where = where,
		HatchAt = hatchAt,
		Coins = coins,
		AutoPicked = autoPicked,
	}
	NetService:FireClient("EggPicked", player, payload)
end

-- Returns the offer if `offerId` names the player's current one.
local function currentOffer(player: Player, offerId: unknown, action: string): Types.EggOffer?
	if not Guard.String(offerId, OFFER_ID_MAX_LENGTH) then
		return nil
	end
	local offer = EggService:GetOffer(player)
	if offer == nil or (offer :: Types.EggOffer).OfferId ~= offerId then
		refuse(player, action, "NoOffer")
		return nil
	end
	return offer
end

local function onPick(player: Player, offerId: unknown, slot: unknown)
	if not Guard.Integer(slot, 1, EggConfig.EggsPerOffer) then
		refuse(player, "EggPick", "BadSlot")
		return
	end
	if currentOffer(player, offerId, "EggPick") then
		pick(player, slot :: number, false)
	end
end

local function onReroll(player: Player, offerId: unknown)
	local current = currentOffer(player, offerId, "EggReroll")
	local data = PlayerDataService:Get(player)
	if current == nil or data == nil then
		return
	end
	-- The type checker does not narrow after an early return, hence the casts.
	local offer = current :: Types.EggOffer
	local cost = EggConfig.RerollCosts[offer.RerollCount + 1]
	if cost == nil then
		refuse(player, "EggReroll", "RerollLimit")
		return
	end
	if (data :: Types.Profile).Coins < cost then
		refuse(player, "EggReroll", "NotEnoughCoins")
		return
	end

	PlayerDataService:Update(player, function(profile)
		profile.Coins -= cost
		profile.PendingOffer = newOffer(offer.Context, offer.RerollCount + 1)
	end)
end

local function autoPickExpired()
	local now = os.time()
	for _, player in Players:GetPlayers() do
		local offer = EggService:GetOffer(player)
		if offer and now >= offer.ExpiresAt then
			pick(player, EggRoller.BestSlot(offer.Eggs :: any, PetConfig.Rarities), true)
		end
	end
end

function EggService:Init() end

function EggService:Start()
	NetService:On("EggPick", { PerSecond = 2, Burst = 4 }, onPick)
	NetService:On("EggReroll", { PerSecond = 2, Burst = 4 }, onReroll)
	NetService:On("BuyUpgrade", { PerSecond = 2, Burst = 4 }, function(player, upgradeId)
		if upgradeId == "Incubator" then
			EggService:BuyIncubator(player)
		elseif upgradeId == "PetSlots" then
			EggService:BuyPetSlots(player)
		else
			refuse(player, "BuyUpgrade", "Unknown")
		end
	end)

	task.spawn(function()
		while true do
			task.wait(EXPIRY_CHECK_SECONDS)
			autoPickExpired()
		end
	end)
end

-- Gives the player a new offer. An unpicked older offer is auto-picked
-- first, so a reward is never lost.
function EggService:CreateOffer(player: Player, context: Types.OfferContext)
	local previous = EggService:GetOffer(player)
	if previous then
		pick(player, EggRoller.BestSlot(previous.Eggs :: any, PetConfig.Rarities), true)
	end
	PlayerDataService:Update(player, function(profile)
		profile.PendingOffer = newOffer(context, 0)
	end)
end

local function incubatorAt(player: Player, index: number): (Types.Profile?, Types.Incubator?)
	local data = PlayerDataService:Get(player)
	if data == nil then
		return nil, nil
	end
	return data, (data :: Types.Profile).Incubators[index]
end

-- Hatches a ready egg into a pet and refills the incubator from storage.
function EggService:Collect(player: Player, index: number)
	local data, incubator = incubatorAt(player, index)
	if data == nil or incubator == nil then
		return
	end
	local current = incubator :: Types.Incubator
	local egg = current.Egg
	if egg == nil or os.time() < (current.HatchAt or math.huge) then
		refuse(player, "IncubatorCollect", "NotReady")
		return
	end
	if PetService:Count(data :: Types.Profile) >= (data :: Types.Profile).PetCapacity then
		refuse(player, "IncubatorCollect", "PetsFull")
		return
	end
	local hatched = egg :: Types.EggInstance
	local kind = assert(
		EggRoller.RollPet(PetConfig.Pets :: any, hatched.Theme, hatched.Rarity, rng),
		`PetConfig has no {hatched.Rarity} pet in theme {hatched.Theme}`
	)

	local petId: string? = nil
	PlayerDataService:Update(player, function(profile)
		local slot = profile.Incubators[index]
		slot.Egg = nil
		slot.HatchAt = nil
		petId = PetService:AddToProfile(profile, kind, hatched.Rarity)
		local nextId = Incubation.RarestEgg(profile.Eggs :: any, PetConfig.Rarities)
		if nextId then
			local nextEgg = profile.Eggs[nextId]
			profile.Eggs[nextId] = nil
			slot.Egg = nextEgg
			slot.HatchAt = os.time() + Incubation.HatchSeconds(nextEgg.Rarity, EggConfig)
		end
	end)

	if petId then
		local payload: Types.PetHatchedPayload =
			{ Kind = kind, Rarity = hatched.Rarity, PetId = petId :: string }
		NetService:FireClient("PetHatched", player, payload)
		EggService.PetHatched:Fire(player, payload)
	end
end

-- Puts the rarest stored egg into an empty incubator.
function EggService:PlaceStored(player: Player, index: number)
	local data, incubator = incubatorAt(player, index)
	if data == nil or incubator == nil then
		return
	end
	if (incubator :: Types.Incubator).Egg ~= nil then
		refuse(player, "IncubatorPlace", "Busy")
		return
	end
	local eggId = Incubation.RarestEgg((data :: Types.Profile).Eggs :: any, PetConfig.Rarities)
	if eggId == nil then
		refuse(player, "IncubatorPlace", "NoEggs")
		return
	end
	PlayerDataService:Update(player, function(profile)
		local egg = profile.Eggs[eggId :: string]
		profile.Eggs[eggId :: string] = nil
		local slot = profile.Incubators[index]
		slot.Egg = egg
		slot.HatchAt = os.time() + Incubation.HatchSeconds(egg.Rarity, EggConfig)
	end)
end

-- Finishes an incubating egg now for coins.
function EggService:SpeedUp(player: Player, index: number)
	local data, incubator = incubatorAt(player, index)
	if data == nil or incubator == nil then
		return
	end
	local current = incubator :: Types.Incubator
	if current.Egg == nil or current.HatchAt == nil then
		refuse(player, "IncubatorSpeedUp", "NoEggs")
		return
	end
	local cost = Incubation.SpeedUpCost(current.HatchAt :: number, os.time(), EggConfig)
	if cost <= 0 then
		return
	end
	if (data :: Types.Profile).Coins < cost then
		refuse(player, "IncubatorSpeedUp", "NotEnoughCoins")
		return
	end
	PlayerDataService:Update(player, function(profile)
		profile.Coins -= cost
		profile.Incubators[index].HatchAt = os.time()
	end)
end

-- Buys the next incubator; a stored egg moves into it right away.
function EggService:BuyIncubator(player: Player)
	local data = PlayerDataService:Get(player)
	if data == nil then
		return
	end
	local price = Incubation.NextIncubatorPrice(#(data :: Types.Profile).Incubators, EggConfig)
	if price == nil then
		refuse(player, "BuyUpgrade", "MaxLevel")
		return
	end
	if (data :: Types.Profile).Coins < (price :: number) then
		refuse(player, "BuyUpgrade", "NotEnoughCoins")
		return
	end
	PlayerDataService:Update(player, function(profile)
		profile.Coins -= price :: number
		local slot: Types.Incubator = {}
		table.insert(profile.Incubators, slot)
		local eggId = Incubation.RarestEgg(profile.Eggs :: any, PetConfig.Rarities)
		if eggId then
			local egg = profile.Eggs[eggId]
			profile.Eggs[eggId] = nil
			slot.Egg = egg
			slot.HatchAt = os.time() + Incubation.HatchSeconds(egg.Rarity, EggConfig)
		end
	end)
end

function EggService:BuyPetSlots(player: Player)
	local data = PlayerDataService:Get(player)
	if data == nil then
		return
	end
	local price = Incubation.NextPetSlotsPrice(
		(data :: Types.Profile).PetCapacity,
		PetConfig.StartCapacity,
		EggConfig
	)
	if (data :: Types.Profile).Coins < price then
		refuse(player, "BuyUpgrade", "NotEnoughCoins")
		return
	end
	PlayerDataService:Update(player, function(profile)
		profile.Coins -= price
		profile.PetCapacity += EggConfig.PetSlotsStep
	end)
end

function EggService:GetOffer(player: Player): Types.EggOffer?
	local data = PlayerDataService:Get(player)
	if data then
		return data.PendingOffer
	end
	return nil
end

return EggService
