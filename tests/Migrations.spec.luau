local Migrations = require("../src/server/Data/Migrations")

local tests = {}

function tests.appliesStepsInOrder()
	local data = { SchemaVersion = 1, Gold = 5 }
	Migrations.Apply(data, 3, {
		[1] = function(d)
			d.Coins = d.Gold
			d.Gold = nil
		end,
		[2] = function(d)
			d.Coins *= 2
		end,
	})
	assert(data.SchemaVersion == 3 and data.Coins == 10 and data.Gold == nil)
end

function tests.newProfileGetsCurrentVersion()
	local data = {}
	Migrations.Apply(data, 1, {})
	assert(data.SchemaVersion == 1)
end

function tests.missingStepFails()
	local ok = pcall(Migrations.Apply, { SchemaVersion = 1 }, 2, {})
	assert(not ok, "expected a missing migration to fail")
end

return tests
