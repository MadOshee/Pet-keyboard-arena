local SpawnSlots = require("../src/shared/Logic/SpawnSlots")

local tests = {}

local function distance(a: SpawnSlots.Slot, b: SpawnSlots.Slot): number
	return math.sqrt((a.Inward - b.Inward) ^ 2 + (a.Along - b.Along) ^ 2)
end

function tests.aloneStandsInTheMiddle()
	local slot = SpawnSlots.Get(1, 1, 50)
	assert(slot.Along == 0)
	assert(slot.Inward == SpawnSlots.EdgeInset)
end

function tests.teammatesStandApart()
	for count = 2, 8 do
		local slots = {}
		for index = 1, count do
			slots[index] = SpawnSlots.Get(index, count, 50)
		end
		for a = 1, count do
			assert(math.abs(slots[a].Along) <= 25, "inside the arena depth")
			for b = a + 1, count do
				assert(distance(slots[a], slots[b]) >= 10, `{count}: {a} and {b} too close`)
			end
		end
	end
end

function tests.sixMakeTwoColumnsOfThree()
	local inward = {}
	for index = 1, 6 do
		local slot = SpawnSlots.Get(index, 6, 50)
		inward[slot.Inward] = (inward[slot.Inward] or 0) + 1
	end
	assert(inward[SpawnSlots.EdgeInset] == 3)
	assert(inward[SpawnSlots.EdgeInset + SpawnSlots.ColumnGap] == 3)
end

function tests.outOfRangeIndexIsClamped()
	local slot = SpawnSlots.Get(9, 3, 50)
	local last = SpawnSlots.Get(3, 3, 50)
	assert(slot.Along == last.Along and slot.Inward == last.Inward)
end

return tests
