--!strict
-- Keyboard arena geometry: the key layout and "which keys are within the
-- brush radius" queries. Coordinates are studs on the ground plane relative
-- to the arena center. Pure Luau, tested with Lune.

export type KeySpec = {
	Label: string,
	CenterX: number,
	CenterZ: number,
	SizeX: number,
	SizeZ: number,
}

-- Axis-aligned key footprint used by paint queries.
export type KeyRect = {
	CenterX: number,
	CenterZ: number,
	HalfX: number,
	HalfZ: number,
}

type RowKey = { any } -- { label: string, width in key units: number }

-- Every row is 15 units wide, like a standard keyboard.
local ROWS: { { RowKey } } = {
	{
		{ "`", 1 },
		{ "1", 1 },
		{ "2", 1 },
		{ "3", 1 },
		{ "4", 1 },
		{ "5", 1 },
		{ "6", 1 },
		{ "7", 1 },
		{ "8", 1 },
		{ "9", 1 },
		{ "0", 1 },
		{ "-", 1 },
		{ "=", 1 },
		{ "Back", 2 },
	},
	{
		{ "Tab", 1.5 },
		{ "Q", 1 },
		{ "W", 1 },
		{ "E", 1 },
		{ "R", 1 },
		{ "T", 1 },
		{ "Y", 1 },
		{ "U", 1 },
		{ "I", 1 },
		{ "O", 1 },
		{ "P", 1 },
		{ "[", 1 },
		{ "]", 1 },
		{ "\\", 1.5 },
	},
	{
		{ "Caps", 1.75 },
		{ "A", 1 },
		{ "S", 1 },
		{ "D", 1 },
		{ "F", 1 },
		{ "G", 1 },
		{ "H", 1 },
		{ "J", 1 },
		{ "K", 1 },
		{ "L", 1 },
		{ ";", 1 },
		{ "'", 1 },
		{ "Enter", 2.25 },
	},
	{
		{ "Shift", 2.25 },
		{ "Z", 1 },
		{ "X", 1 },
		{ "C", 1 },
		{ "V", 1 },
		{ "B", 1 },
		{ "N", 1 },
		{ "M", 1 },
		{ ",", 1 },
		{ ".", 1 },
		{ "/", 1 },
		{ "Shift", 2.75 },
	},
	{
		{ "Ctrl", 1.25 },
		{ "Win", 1.25 },
		{ "Alt", 1.25 },
		{ "Space", 6.25 },
		{ "Alt", 1.25 },
		{ "Win", 1.25 },
		{ "Menu", 1.25 },
		{ "Ctrl", 1.25 },
	},
}

local ArenaGrid = {}

ArenaGrid.RowUnits = 15
ArenaGrid.RowCount = #ROWS

-- Builds the keyboard layout. `unit` is the size of a 1u key including its
-- share of the gap; each key is shrunk by `gap` so neighbours do not touch.
function ArenaGrid.KeyboardLayout(unit: number, gap: number): { KeySpec }
	local keys: { KeySpec } = {}
	local totalWidth = ArenaGrid.RowUnits * unit
	local totalDepth = #ROWS * unit

	for rowIndex, row in ROWS do
		local z = -totalDepth / 2 + (rowIndex - 0.5) * unit
		local x = -totalWidth / 2
		for _, rowKey in row do
			local width = (rowKey[2] :: number) * unit
			table.insert(keys, {
				Label = rowKey[1] :: string,
				CenterX = x + width / 2,
				CenterZ = z,
				SizeX = width - gap,
				SizeZ = unit - gap,
			})
			x += width
		end
	end

	return keys
end

-- Calls `visit(index)` for every key whose footprint is within `radius`
-- studs of the point (x, z). Allocation-free so it can run every paint tick.
function ArenaGrid.ForEachKeyInRadius(
	keys: { KeyRect },
	x: number,
	z: number,
	radius: number,
	visit: (index: number) -> ()
)
	local radiusSquared = radius * radius
	for index, key in keys do
		local dx = math.max(math.abs(x - key.CenterX) - key.HalfX, 0)
		local dz = math.max(math.abs(z - key.CenterZ) - key.HalfZ, 0)
		if dx * dx + dz * dz <= radiusSquared then
			visit(index)
		end
	end
end

return ArenaGrid
