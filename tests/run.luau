-- Lune test runner for pure-logic modules: `lune run tests/run`.
-- Every tests/*.spec.luau returns { [testName]: () -> () }.

local fs = require("@lune/fs")
local process = require("@lune/process")

local passed, failed = 0, 0

local files = fs.readDir("tests")
table.sort(files)

for _, file in files do
	if string.match(file, "%.spec%.luau$") then
		local spec = require("./" .. string.gsub(file, "%.luau$", ""))
		local names = {}
		for name in spec do
			table.insert(names, name)
		end
		table.sort(names)
		for _, name in names do
			local ok, err = pcall(spec[name])
			if ok then
				passed += 1
			else
				failed += 1
				print(`FAIL {file} :: {name}\n  {err}`)
			end
		end
	end
end

print(`{passed} passed, {failed} failed`)
process.exit(if failed == 0 then 0 else 1)
