--!strict
-- Arena geometry and painting rules (docs/design.md 4.3 "Покраска").

return table.freeze({
	-- Width of a 1u key in studs and the gap between keys.
	KeyUnit = 8,
	KeyGap = 1,
	KeyHeight = 2,
	-- Arena center on the ground plane; key tops sit at KeyHeight. The arena
	-- is far from the hub islands (world/World.rbxm), out of sight; players
	-- are teleported there for a match. tools/build-arena reads these too.
	CenterX = 0,
	CenterZ = 3000,

	PaintTickRate = 10, -- paint checks per second
	IndexCellSize = 8, -- studs per cell of the key lookup grid
	ScoreSyncRate = 4, -- score attribute updates per second
	BasePaintRadius = 3, -- studs from the player to a key's edge
	MaxPaintHeight = 6, -- studs above the key tops; higher jumps do not paint

	BaseWalkSpeed = 16,

	-- Where players come back after a match: the hub island, by the portal
	-- (World.HubSpawn in tools/world/Builder.luau).
	LobbyX = 0,
	LobbyY = 8,
	LobbyZ = 46,

	-- How close to the portal a player must be for the Solo/Party window.
	PortalRadius = 14,
	-- The server allows a little more for lag.
	PortalServerRadius = 24,
})
