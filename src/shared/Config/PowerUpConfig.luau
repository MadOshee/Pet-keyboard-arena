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
	SpeedSeconds = 5,
	BombRadius = 12,
	LockRadius = 12,
	LockSeconds = 4,
	Colors = table.freeze({
		Speed = Color3.fromRGB(255, 230, 60),
		PaintBomb = Color3.fromRGB(255, 110, 200),
		Lock = Color3.fromRGB(120, 230, 255),
	}) :: { [string]: Color3 },
	Labels = table.freeze({
		Speed = "SPEED",
		PaintBomb = "BOMB",
		Lock = "LOCK",
	}) :: { [string]: string },
})
