--!strict
-- Arena geometry and painting rules (docs/design.md 4.3 "Покраска").

return table.freeze({
	-- Width of a 1u key in studs and the gap between keys.
	KeyUnit = 8,
	KeyGap = 1,
	KeyHeight = 2,
	-- Arena center on the ground plane; key tops sit at KeyHeight.
	CenterX = 0,
	CenterZ = 0,

	PaintTickRate = 10, -- paint checks per second
	ScoreSyncRate = 4, -- score attribute updates per second
	BasePaintRadius = 3, -- studs from the player to a key's edge
	MaxPaintHeight = 6, -- studs above the key tops; higher jumps do not paint

	BaseWalkSpeed = 16,

	-- Where players stand between rounds.
	LobbyX = 0,
	LobbyY = 4,
	LobbyZ = 70,
})
