--!strict
-- Types shared by the server and client (profile schema, remote payloads).
-- See docs/design.md section 9. Fields are added stage by stage; ProfileStore
-- Reconcile fills new fields from the template for existing players.

export type Rarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary"

export type TeamId = "Red" | "Blue"
export type Winner = TeamId | "Draw"
export type Outcome = "Win" | "Lose" | "Draw"
export type RoundPhase = "Intermission" | "Countdown" | "Playing" | "Results"
export type Stat = "Speed" | "PaintRadius" | "Luck" | "Coins"

-- Totals of equipped pet bonuses as fractions (0.1 = +10%), already capped.
export type Stats = {
	Speed: number,
	PaintRadius: number,
	Luck: number,
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

-- One incubator on the plot; empty when Egg is nil.
export type Incubator = {
	Egg: EggInstance?,
	HatchAt: number?, -- os.time() when the egg is ready
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
	ExpiresAt: number, -- os.time(); clients compare with GetServerTimeNow()
	Context: OfferContext,
}

export type Profile = {
	SchemaVersion: number,
	Coins: number,
	Pets: { [string]: PetInstance }, -- key: unique pet id
	Equipped: { string }, -- up to PetConfig.MaxEquipped pet ids
	PetCapacity: number,
	Eggs: { [string]: EggInstance }, -- stored eggs waiting for an incubator
	EggCapacity: number,
	Incubators: { Incubator }, -- length = incubators owned
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
	KeysPainted: number,
	Coins: number,
	Rewarded: boolean,
}

-- Where a picked egg went (EggPicked remote): straight into an incubator,
-- into egg storage, or turned into Coins when both were full.
export type EggPickedPayload = {
	Theme: string,
	Rarity: Rarity,
	Where: "Incubator" | "Storage" | "Coins",
	HatchAt: number?,
	Coins: number,
	AutoPicked: boolean,
}

-- Sent to the owner when an incubator hatches a collected egg (PetHatched).
export type PetHatchedPayload = {
	Kind: string,
	Rarity: Rarity,
	PetId: string,
}

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

return nil
