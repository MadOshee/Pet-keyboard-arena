local Loader = require("../src/shared/Util/Loader")

local function makeModule(log: { string }, name: string)
	return {
		Init = function()
			table.insert(log, name .. ".Init")
		end,
		Start = function()
			table.insert(log, name .. ".Start")
		end,
	}
end

local tests = {}

function tests.initsAllBeforeStartingInOrder()
	local log = {}
	Loader.Run({
		{ Name = "A", Module = makeModule(log, "A") },
		{ Name = "B", Module = makeModule(log, "B") },
	})
	assert(table.concat(log, ",") == "A.Init,B.Init,A.Start,B.Start", table.concat(log, ","))
end

function tests.allowsMissingLifecycleMethods()
	Loader.Run({ { Name = "Empty", Module = {} } })
end

function tests.rejectsDuplicateNames()
	local ok = pcall(Loader.Run, {
		{ Name = "A", Module = {} },
		{ Name = "A", Module = {} },
	})
	assert(not ok, "expected duplicate names to fail")
end

function tests.reportsWhichModuleFailed()
	local ok, err = pcall(Loader.Run, {
		{
			Name = "Broken",
			Module = {
				Init = function()
					error("boom")
				end,
			},
		},
	})
	assert(not ok and string.find(tostring(err), "Broken.Init failed", 1, true), tostring(err))
end

return tests
