--!strict
-- Egg offers after a round: 1 of 4, rerolls for coins, auto-pick on timeout
-- and instant hatching (docs/design.md 4.3 "Яйца", sections 9-10).
-- Stage 5 replaces instant hatching with incubators on the player's plot.
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

-- Hatches the egg in `slot` of the current offer and clears the offer.
local function pick(player: Player, slot: number, autoPicked: boolean)
	local offer = EggService:GetOffer(player)
	if offer == nil then
		return
	end
	local egg = (offer :: Types.EggOffer).Eggs[slot]
	local kind = assert(
		EggRoller.RollPet(PetConfig.Pets :: any, egg.Theme, egg.Rarity, rng),
		`PetConfig has no {egg.Rarity} pet in theme {egg.Theme}`
	)

	local petId: string? = nil
	local coins = 0
	PlayerDataService:Update(player, function(profile)
		profile.PendingOffer = nil
		petId = PetService:AddToProfile(profile, kind, egg.Rarity)
		if petId == nil then
			-- Inventory full: the pet is converted to coins (the window warns).
			coins = PetConfig.SellValue[egg.Rarity] or 0
			profile.Coins += coins
		end
	end)

	local payload: Types.PetHatchedPayload = {
		Kind = kind,
		Rarity = egg.Rarity,
		PetId = petId,
		Coins = coins,
		AutoPicked = autoPicked,
	}
	NetService:FireClient("PetHatched", player, payload)
	EggService.PetHatched:Fire(player, payload)
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

function EggService:GetOffer(player: Player): Types.EggOffer?
	local data = PlayerDataService:Get(player)
	if data then
		return data.PendingOffer
	end
	return nil
end

return EggService
