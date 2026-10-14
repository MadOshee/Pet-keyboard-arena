--!strict
-- Where each member of a team stands when the match starts (Ivan
-- 2026-10-14: teammates stood too close). Up to three in one column at
-- the team's edge; more fill a second column further in. Rows spread over
-- most of the arena's depth, at most MaxSpacing apart.

local SpawnSlots = {}

SpawnSlots.EdgeInset = 8 -- studs in from the team's edge (one key)
SpawnSlots.ColumnGap = 14 -- studs between the two columns
SpawnSlots.MaxSpacing = 16 -- studs between rows at most
SpawnSlots.DepthShare = 0.8 -- share of the arena depth the rows may use

export type Slot = {
	Inward: number, -- studs from the team's edge towards the middle
	Along: number, -- studs from the arena's centre line, across its depth
}

-- Slot `index` (1..count) of `count` on an arena `depth` studs deep.
function SpawnSlots.Get(index: number, count: number, depth: number): Slot
	count = math.max(count, 1)
	index = math.clamp(index, 1, count)
	local columns = if count > 3 then 2 else 1
	local rows = math.ceil(count / columns)
	local column = (index - 1) % columns
	local row = (index - 1) // columns
	local spacing = if rows > 1
		then math.min(SpawnSlots.MaxSpacing, depth * SpawnSlots.DepthShare / (rows - 1))
		else 0
	return {
		Inward = SpawnSlots.EdgeInset + column * SpawnSlots.ColumnGap,
		Along = (row - (rows - 1) / 2) * spacing,
	}
end

return table.freeze(SpawnSlots)
