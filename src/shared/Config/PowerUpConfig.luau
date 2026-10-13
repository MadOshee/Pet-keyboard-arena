--!strict
-- Arena power-ups (docs/design.md 4.3 "Бонусы на арене"). One spawns on a
-- random key every SpawnInterval seconds while a round is playing.

export type Kind = "Speed" | "PaintBomb" | "Lock"

return table.freeze({
	Kinds = table.freeze({ "Speed", "PaintBomb", "Lock" }),
	SpawnInterval = 10,
	MaxActive = 3,
	PickupRadius = 5, -- studs, checked on the server
	SpeedMultiplier = 1.6, -- on top of pets; the pet cap does not apply
	-- Ivan 2026-10-13: longer speed boost, much wider bomb, wider lock (were 5, 12, 12).
	SpeedSeconds = 10,
	BombRadius = 24,
	LockRadius = 20,
	LockSeconds = 4,
	-- Image asset ids of Ivan's icons shown above a power-up (2026-10-13).
	Icons = table.freeze({
		Speed = 0, -- red shoe
		PaintBomb = 0, -- bomb
		Lock = 0, -- padlock
	}) :: { [string]: number },
})
