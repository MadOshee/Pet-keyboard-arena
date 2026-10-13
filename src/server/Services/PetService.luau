--!strict
-- Pet inventory and equipping (docs/design.md 4.3 "Питомцы", section 10).
-- Equipped pet kinds are mirrored to the "EquippedPets" Player attribute
-- (comma-separated PetConfig keys) so every client can draw them.
-- Round participants cannot change pets: the "Team" attribute is set from
-- Countdown to the end of Results, which also keeps team balance honest.
-- Pets standing on plot platforms (Incubators[i].PetId) earn coins there:
-- they cannot be equipped or sold and do not count towards PetCapacity.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PetConfig = require(ReplicatedStorage.Shared.Config.PetConfig)
local PetIncome = require(ReplicatedStorage.Shared.Logic.PetIncome)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local Types = require(ReplicatedStorage.Shared.Types)
local Guard = require(script.Parent.Parent.Util.Guard)
local NetService = require(script.Parent.NetService)
local PlayerDataService = require(script.Parent.PlayerDataService)

local PET_ID_MAX_LENGTH = 64

local PetService = {}

PetService.EquippedChanged = Signal.new() :: Signal.Signal<Player>

local function refuse(player: Player, action: string, reason: Types.ActionError)
	NetService:FireClient("ActionResult", player, action, reason)
end

local function publishEquipped(player: Player, data: Types.Profile)
	local kinds = {}
	for _, petId in data.Equipped do
		local pet = data.Pets[petId]
		if pet then
			table.insert(kinds, pet.Kind)
		end
	end
	player:SetAttribute("EquippedPets", table.concat(kinds, ","))
	PetService.EquippedChanged:Fire(player)
end

-- Drops equipped ids whose pet no longer exists (for example after a
-- removed config entry), so slots never stay blocked.
local function cleanEquipped(data: Types.Profile)
	for index = #data.Equipped, 1, -1 do
		if data.Pets[data.Equipped[index]] == nil then
			table.remove(data.Equipped, index)
		end
	end
end

local function inRound(player: Player): boolean
	return player:GetAttribute("Team") ~= nil
end

local function onEquip(player: Player, petId: unknown, equip: unknown)
	if not Guard.String(petId, PET_ID_MAX_LENGTH) or not Guard.Boolean(equip) then
		return
	end
	local id = petId :: string
	local loaded = PlayerDataService:Get(player)
	if loaded == nil then
		return
	end
	-- The type checker does not narrow after an early return, hence the cast.
	local data = loaded :: Types.Profile
	if data.Pets[id] == nil then
		refuse(player, "PetEquip", "NotOwned")
		return
	end
	if equip and PetIncome.PlacedPets(data.Incubators :: any)[id] then
		refuse(player, "PetEquip", "OnPlatform")
		return
	end
	if inRound(player) then
		refuse(player, "PetEquip", "InRound")
		return
	end

	local index = table.find(data.Equipped, id)
	if equip then
		if index then
			return
		end
		if #data.Equipped >= PetConfig.MaxEquipped then
			refuse(player, "PetEquip", "SlotsFull")
			return
		end
	elseif index == nil then
		return
	end

	PlayerDataService:Update(player, function(profile)
		if equip then
			table.insert(profile.Equipped, id)
		else
			local current = table.find(profile.Equipped, id)
			if current then
				table.remove(profile.Equipped, current)
			end
		end
	end)
	publishEquipped(player, data)
end

local function onSell(player: Player, petId: unknown)
	if not Guard.String(petId, PET_ID_MAX_LENGTH) then
		return
	end
	local id = petId :: string
	local loaded = PlayerDataService:Get(player)
	if loaded == nil then
		return
	end
	-- The type checker does not narrow after an early return, hence the cast.
	local data = loaded :: Types.Profile
	local pet = data.Pets[id]
	if pet == nil then
		refuse(player, "PetSell", "NotOwned")
		return
	end
	if table.find(data.Equipped, id) then
		refuse(player, "PetSell", "Equipped")
		return
	end
	if PetIncome.PlacedPets(data.Incubators :: any)[id] then
		refuse(player, "PetSell", "OnPlatform")
		return
	end

	local value = PetConfig.SellValue[pet.Rarity] or 0
	PlayerDataService:Update(player, function(profile)
		profile.Pets[id] = nil
		profile.Coins += value
	end)
end

function PetService:Init() end

function PetService:Start()
	NetService:On("PetEquip", { PerSecond = 4, Burst = 8 }, onEquip)
	NetService:On("PetSell", { PerSecond = 4, Burst = 8 }, onSell)

	local function onLoaded(player: Player, data: Types.Profile)
		PlayerDataService:Update(player, cleanEquipped)
		publishEquipped(player, data)
	end
	PlayerDataService.ProfileLoaded:Connect(onLoaded)
	-- Profiles that finished loading before this service started.
	for _, player in Players:GetPlayers() do
		local data = PlayerDataService:Get(player)
		if data then
			onLoaded(player, data)
		end
	end
end

-- Pets in the inventory, without the ones standing on platforms.
function PetService:Count(data: Types.Profile): number
	local placed = PetIncome.PlacedPets(data.Incubators :: any)
	local count = 0
	for id in data.Pets do
		if placed[id] == nil then
			count += 1
		end
	end
	return count
end

-- Adds a pet inside an existing PlayerDataService:Update mutator, so the
-- caller's other changes (like clearing an egg offer) land atomically.
-- Returns the new pet id, or nil when the inventory is full. A pet that
-- hatches on a platform stays there, so it skips the inventory limit.
function PetService:AddToProfile(
	data: Types.Profile,
	kind: string,
	rarity: Types.Rarity,
	onPlatform: boolean?
): string?
	if not onPlatform and PetService:Count(data) >= data.PetCapacity then
		return nil
	end
	local petId = HttpService:GenerateGUID(false)
	data.Pets[petId] = { Kind = kind, Rarity = rarity, ObtainedAt = os.time() }
	return petId
end

-- Mirrors the equipped pets to the player after a change made elsewhere.
function PetService:PublishEquipped(player: Player)
	local data = PlayerDataService:Get(player)
	if data then
		publishEquipped(player, data)
	end
end

function PetService:GetEquipped(player: Player): { Types.PetInstance }
	local data = PlayerDataService:Get(player)
	local pets = {}
	if data then
		for _, petId in data.Equipped do
			local pet = data.Pets[petId]
			if pet then
				table.insert(pets, pet)
			end
		end
	end
	return pets
end

return PetService
