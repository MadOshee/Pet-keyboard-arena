--!strict
-- Types shared by the server and client (profile schema, remote payloads).
-- See docs/design.md section 9. Fields are added stage by stage; ProfileStore
-- Reconcile fills new fields from the template for existing players.

export type Rarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary"

export type TeamId = "Red" | "Blue"
export type Winner = TeamId | "Draw"
export type Outcome = "Win" | "Lose" | "Draw"
export type RoundPhase = "Intermission" | "Countdown" | "Playing" | "Results"

export type Profile = {
	SchemaVersion: number,
	Coins: number,
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

return nil
