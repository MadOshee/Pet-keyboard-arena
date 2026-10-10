local ArenaGrid = require("../src/shared/Logic/ArenaGrid")

local UNIT, GAP = 8, 1

local function toRects(keys)
	local rects = {}
	for _, key in keys do
		table.insert(rects, {
			CenterX = key.CenterX,
			CenterZ = key.CenterZ,
			HalfX = key.SizeX / 2,
			HalfZ = key.SizeZ / 2,
		})
	end
	return rects
end

local function hits(rects, x, z, radius)
	local found = {}
	ArenaGrid.ForEachKeyInRadius(rects, x, z, radius, function(index)
		table.insert(found, index)
	end)
	return found
end

local tests = {}

function tests.layoutIsCenteredAndRowsHaveEqualWidth()
	local keys = ArenaGrid.KeyboardLayout(UNIT, GAP)
	local half = ArenaGrid.RowUnits * UNIT / 2
	local rowEdges: { [number]: { number } } = {}
	for _, key in keys do
		local edges = rowEdges[key.CenterZ] or { math.huge, -math.huge }
		edges[1] = math.min(edges[1], key.CenterX - (key.SizeX + GAP) / 2)
		edges[2] = math.max(edges[2], key.CenterX + (key.SizeX + GAP) / 2)
		rowEdges[key.CenterZ] = edges
	end
	local rows = 0
	for _, edges in rowEdges do
		rows += 1
		assert(
			math.abs(edges[1] + half) < 1e-6 and math.abs(edges[2] - half) < 1e-6,
			"row not 15u wide"
		)
	end
	assert(rows == ArenaGrid.RowCount)
end

function tests.keysDoNotOverlap()
	local rects = toRects(ArenaGrid.KeyboardLayout(UNIT, GAP))
	for i = 1, #rects do
		for j = i + 1, #rects do
			local a, b = rects[i], rects[j]
			local overlapX = math.abs(a.CenterX - b.CenterX) < a.HalfX + b.HalfX
			local overlapZ = math.abs(a.CenterZ - b.CenterZ) < a.HalfZ + b.HalfZ
			assert(not (overlapX and overlapZ), `keys {i} and {j} overlap`)
		end
	end
end

function tests.findsTheKeyUnderThePlayer()
	local keys = ArenaGrid.KeyboardLayout(UNIT, GAP)
	local rects = toRects(keys)
	local target = keys[20]
	local found = hits(rects, target.CenterX, target.CenterZ, 0)
	assert(#found == 1 and found[1] == 20, `found {#found} keys`)
end

function tests.radiusReachesNeighbours()
	local rects = toRects(ArenaGrid.KeyboardLayout(UNIT, GAP))
	local near = hits(rects, rects[20].CenterX, rects[20].CenterZ, 0)
	local wide = hits(rects, rects[20].CenterX, rects[20].CenterZ, UNIT)
	assert(#wide > #near, "a bigger radius should cover more keys")
end

function tests.ignoresPointsFarOutside()
	local rects = toRects(ArenaGrid.KeyboardLayout(UNIT, GAP))
	assert(#hits(rects, 1000, 1000, 3) == 0)
end

function tests.indexedQueryMatchesBruteForce()
	local rects = toRects(ArenaGrid.KeyboardLayout(UNIT, GAP))
	local index = ArenaGrid.BuildIndex(rects, 8)
	local seed = 12345
	local function random(): number
		seed = (seed * 1103515245 + 12345) % 2147483648
		return seed / 2147483648
	end
	for _ = 1, 300 do
		local x, z, radius = (random() - 0.5) * 140, (random() - 0.5) * 60, random() * 10
		local expected = hits(rects, x, z, radius)
		local found = {}
		ArenaGrid.ForEachKeyInRadiusIndexed(index, x, z, radius, function(keyIndex)
			table.insert(found, keyIndex)
		end)
		table.sort(found)
		assert(#found == #expected, `at ({x}, {z}) r={radius}: {#found} vs {#expected}`)
		for i, keyIndex in expected do
			assert(found[i] == keyIndex, "different keys")
		end
	end
end

function tests.indexedQueryVisitsEachKeyOnce()
	-- One wide key spanning many cells must be reported once.
	local index = ArenaGrid.BuildIndex({ { CenterX = 0, CenterZ = 0, HalfX = 30, HalfZ = 2 } }, 4)
	local count = 0
	ArenaGrid.ForEachKeyInRadiusIndexed(index, 0, 0, 20, function()
		count += 1
	end)
	assert(count == 1, `visited {count} times`)
end

return tests
