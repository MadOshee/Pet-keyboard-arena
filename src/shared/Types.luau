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
	PendingOffer: EggOffer?,
	Stats: {
		RoundsPlayed: number,
		Wins: number,
		KeysPainted: number,
	},
	ProcessedPurchases: { string },
	Tutorial: { Done: boolean },
}

-- Sent to a participant after each round (RoundResult remote).
export type RoundResultPayload = {
	Outcome: Outcome,
	KeysPainted: number,
	Coins: number,
	Rewarded: boolean,
}

-- Sent to the owner after an egg is picked (PetHatched remote). PetId is
-- nil when the inventory was full and the pet became Coins instead.
export type PetHatchedPayload = {
	Kind: string,
	Rarity: Rarity,
	PetId: string?,
	Coins: number,
	AutoPicked: boolean,
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

return nil
