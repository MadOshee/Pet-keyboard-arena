--!strict
-- Types shared by the server and client (profile schema, remote payloads).
-- See docs/design.md section 9. Fields are added stage by stage; ProfileStore
-- Reconcile fills new fields from the template for existing players.

export type Rarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary"

export type TeamId = "Red" | "Blue"
export type Winner = TeamId | "Draw"
export type Outcome = "Win" | "Lose" | "Draw"
-- Intermission: nobody is queued. Starting: the queue countdown before the
-- teleport to the arena.
export type RoundPhase = "Intermission" | "Starting" | "Countdown" | "Playing" | "Results"
export type QueueMode = "Solo" | "Party"
export type Stat = "Speed" | "PaintRadius" | "Luck" | "Power" | "Coins"

-- Totals of equipped pet bonuses as fractions (0.1 = +10%), already capped.
export type Stats = {
	Speed: number,
	PaintRadius: number,
	Luck: number,
	Power: number, -- bat hit strength
	Coins: number,
}

export type PetInstance = {
	Kind: string, -- key in PetConfig.Pets
	Rarity: Rarity,
	ObtainedAt: number, -- os.time()
}

export type EggInstance = {
	Theme: string, -- key in PetConfig.Themes
	Rarity: Rarity,
}

-- One platform of the plot ("incubator" in older code): empty, an
-- incubating egg, or a pet that earns coins. When the egg's HatchAt passes,
-- PlatformService hatches it and the pet takes the platform.
export type Incubator = {
	Egg: EggInstance?,
	HatchAt: number?, -- os.time() when the egg is ready
	PetId: string?, -- key in Profile.Pets of the pet standing here
}

-- What an egg offer's odds were rolled from; rerolls reuse it.
export type OfferContext = {
	Outcome: Outcome,
	ContributionPct: number, -- 0..1, keys painted / best painter on the team
	Luck: number, -- pet Luck when the offer was made
}

export type EggOffer = {
	OfferId: string,
	Eggs: { EggInstance },
	RerollCount: number,
	Context: OfferContext,
}

export type Profile = {
	SchemaVersion: number,
	Coins: number,
	XP: number, -- total XP; the level comes from Logic/Levels
	Pets: { [string]: PetInstance }, -- key: unique pet id
	Equipped: { string }, -- up to PetConfig.MaxEquipped pet ids
	PetCapacity: number,
	Eggs: { [string]: EggInstance }, -- stored eggs waiting for an incubator
	EggCapacity: number,
	Incubators: { Incubator }, -- platforms; length = platforms owned
	IncomeAt: number, -- os.time() pet income was paid up to; 0 = never
	PendingOffer: EggOffer?,
	Stats: {
		RoundsPlayed: number,
		Wins: number,
		KeysPainted: number,
	},
	ProcessedPurchases: { string },
	Tutorial: { Done: boolean },
	-- Robux extras (stage 9)
	FreeRerolls: number, -- bought rerolls, used before coins
	FreeSpeedUps: number, -- bought speed-ups with no egg to finish at the time
	LuckPotionOffers: number, -- egg offers left with the luck potion bonus
	VipIncubator: boolean, -- the VIP pass incubator was added
}

-- Sent to a participant after each round (RoundResult remote).
export type RoundResultPayload = {
	Outcome: Outcome,
	Winner: Winner,
	KeysPainted: number,
	Coins: number,
	XP: number,
	Rewarded: boolean,
}

-- Where a picked egg went (EggPicked remote): into egg storage (the player
-- puts it on a platform), or turned into Coins when storage was full.
-- "Incubator" is no longer sent.
export type EggPickedPayload = {
	Theme: string,
	Rarity: Rarity,
	Where: "Incubator" | "Storage" | "Coins",
	HatchAt: number?,
	Coins: number,
	AutoPicked: boolean,
}

-- Sent to the owner when an egg on a platform hatches (PetHatched).
export type PetHatchedPayload = {
	Kind: string,
	Rarity: Rarity,
	PetId: string,
}

-- Coins pets earned while the player was away (OfflineIncome remote).
export type OfflineIncomePayload = {
	Coins: number,
	Seconds: number, -- counted time, at most PetConfig.OfflineIncomeMaxSeconds
}

-- What a platform request asks for (PlatformAction remote).
export type PlatformActionKind = "PlaceEgg" | "PlacePet" | "Take" | "SpeedUp" | "Buy"

-- A player's party as they see it (PartyUpdate remote). Members holds
-- just the player when solo; Invites lists users inviting them.
export type PartyPayload = {
	Members: { number },
	Leader: number,
	Invites: { number },
}

-- Why a request was refused (ActionResult remote).
export type ActionError =
	"NoOffer"
	| "BadSlot"
	| "NotEnoughCoins"
	| "RerollLimit"
	| "NotOwned"
	| "SlotsFull"
	| "InRound"
	| "Equipped"
	| "PetsFull"
	| "NotReady"
	| "NoEggs"
	| "Busy"
	| "MaxLevel"
	| "Unknown"
	| "NotYourPlot"
	| "Self"
	| "AlreadyTogether"
	| "PartyFull"
	| "AlreadyInvited"
	| "NoInvite"
	| "InvalidTarget"
	| "NoParty"
	| "TooFar"
	| "InMatch"
	| "OnPlatform"
	| "EggsFull"
	| "Locked"

return nil
