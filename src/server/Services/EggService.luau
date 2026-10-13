--!strict
-- Egg offers after a round (1 of 4, rerolls for coins; the offer waits
-- until the player picks, Ivan 2026-10-13), egg storage, platform
-- purchases and speed-ups (docs/design.md 4.3 "Яйца", D3, sections 9-10).
-- A picked egg goes into egg storage; the player puts it on a platform of
-- the plot (PlatformService), where it hatches. Each call checks the
-- profile itself, so the world never decides a result.
--
-- The offer lives in the profile (PendingOffer), so leaving the game does
-- not lose it, and the client sees it through DataSync. Every pick and
-- reroll checks the OfferId and replaces or clears the offer in the same
-- profile update, so a double click or a replayed request cannot give two
-- pets or charge twice.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EggConfig = require(ReplicatedStorage.Shared.Config.EggConfig)
local PetConfig = require(ReplicatedStorage.Shared.Config.PetConfig)
local ShopConfig = require(ReplicatedStorage.Shared.Config.ShopConfig)
local EggRoller = require(ReplicatedStorage.Shared.Logic.EggRoller)
local Incubation = require(ReplicatedStorage.Shared.Logic.Incubation)
local Types = require(ReplicatedStorage.Shared.Types)
local Guard = require(script.Parent.Parent.Util.Guard)
local GamePassService = require(script.Parent.GamePassService)
local NetService = require(script.Parent.NetService)
local PlayerDataService = require(script.Parent.PlayerDataService)

local OFFER_ID_MAX_LENGTH = 64

local EggService = {}

local random = Random.new()
local function rng(): number
	return random:NextNumber()
end

local function refuse(player: Player, action: string, reason: Types.ActionError)
	NetService:FireClient("ActionResult", player, action, reason)
end

-- Incubation time for this player; the FastHatch pass shortens it.
local function hatchSeconds(player: Player, rarity: string): number
	local seconds = Incubation.HatchSeconds(rarity, EggConfig)
	if GamePassService:Owns(player, "FastHatch") then
		seconds = math.ceil(seconds * ShopConfig.FastHatchMultiplier)
	end
	return seconds
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
		Context = context,
	}
end

local function countEggs(data: Types.Profile): number
	local count = 0
	for _ in data.Eggs do
		count += 1
	end
	return count
end

-- Takes the egg in `slot` of the current offer and clears the offer. The egg
-- goes into egg storage, or becomes coins when storage is full.
local function pick(player: Player, slot: number, autoPicked: boolean)
	local offer = EggService:GetOffer(player)
	if offer == nil then
		return
	end
	local egg = (offer :: Types.EggOffer).Eggs[slot]

	local where: "Incubator" | "Storage" | "Coins" = "Coins"
	local coins = 0
	PlayerDataService:Update(player, function(profile)
		profile.PendingOffer = nil
		if countEggs(profile) < profile.EggCapacity then
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
		HatchAt = nil,
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
	-- A bought reroll is used before coins.
	local free = (data :: Types.Profile).FreeRerolls > 0
	if not free and (data :: Types.Profile).Coins < cost then
		refuse(player, "EggReroll", "NotEnoughCoins")
		return
	end

	PlayerDataService:Update(player, function(profile)
		if free then
			profile.FreeRerolls -= 1
		else
			profile.Coins -= cost
		end
		profile.PendingOffer = newOffer(offer.Context, offer.RerollCount + 1)
	end)
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
	-- A bought speed-up that had no egg to finish is used before coins.
	local free = (data :: Types.Profile).FreeSpeedUps > 0
	if not free and (data :: Types.Profile).Coins < cost then
		refuse(player, "IncubatorSpeedUp", "NotEnoughCoins")
		return
	end
	PlayerDataService:Update(player, function(profile)
		if free then
			profile.FreeSpeedUps -= 1
		else
			profile.Coins -= cost
		end
		profile.Incubators[index].HatchAt = os.time()
	end)
end

-- Buys the next platform.
function EggService:BuyIncubator(player: Player)
	local data = PlayerDataService:Get(player)
	if data == nil then
		return
	end
	local price = EggService:NextIncubatorPrice(data :: Types.Profile)
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
		table.insert(profile.Incubators, {})
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

-- Price of the player's next incubator, or nil at the maximum. The VIP
-- incubator is free, so it does not move the price list.
function EggService:NextIncubatorPrice(data: Types.Profile): number?
	local extra = if data.VipIncubator then ShopConfig.VipExtraIncubators else 0
	if #data.Incubators >= EggConfig.MaxIncubators then
		return nil
	end
	return Incubation.NextIncubatorPrice(#data.Incubators - extra, EggConfig)
end

-- Robux speed-up, run inside a GrantPurchase update: finishes the egg with
-- the most time left, or keeps a credit for the next SpeedUp prompt.
function EggService:GrantSpeedUp(data: Types.Profile)
	local now = os.time()
	local best: Types.Incubator? = nil
	for _, slot in data.Incubators do
		if slot.Egg ~= nil and slot.HatchAt ~= nil and (slot.HatchAt :: number) > now then
			if
				best == nil
				or (slot.HatchAt :: number) > ((best :: Types.Incubator).HatchAt :: number)
			then
				best = slot
			end
		end
	end
	if best then
		(best :: Types.Incubator).HatchAt = now
	else
		data.FreeSpeedUps += 1
	end
end

-- VIP pass: one free platform, given once. With every incubator already
-- bought, the player gets the price of the last one in coins instead.
function EggService:GrantVipIncubator(player: Player)
	local data = PlayerDataService:Get(player)
	if data == nil or (data :: Types.Profile).VipIncubator then
		return
	end
	PlayerDataService:Update(player, function(profile)
		profile.VipIncubator = true
		for _ = 1, ShopConfig.VipExtraIncubators do
			if #profile.Incubators < EggConfig.MaxIncubators then
				table.insert(profile.Incubators, {})
			else
				profile.Coins += EggConfig.IncubatorPrices[#EggConfig.IncubatorPrices]
			end
		end
	end)
end

-- Incubation time of an egg for this player (FastHatch pass included).
function EggService:HatchSeconds(player: Player, rarity: string): number
	return hatchSeconds(player, rarity)
end

function EggService:GetOffer(player: Player): Types.EggOffer?
	local data = PlayerDataService:Get(player)
	if data then
		return data.PendingOffer
	end
	return nil
end

return EggService
