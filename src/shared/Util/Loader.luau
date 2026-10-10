--!strict
-- Two-phase module loader shared by the server and client bootstraps.
-- Phase 1 calls Init() on every module in order; phase 2 calls Start().
-- Init() grabs dependencies and builds state; Start() connects events.
-- Neither may yield: long-running loops must use task.spawn themselves.
-- Pure Luau with no Roblox APIs, so it is unit-tested with Lune.

export type Lifecycle = {
	Init: ((self: any) -> ())?,
	Start: ((self: any) -> ())?,
}

export type Entry = {
	Name: string,
	Module: Lifecycle,
}

local Loader = {}

local function runPhase(entries: { Entry }, phase: "Init" | "Start")
	for _, entry in entries do
		local method = (entry.Module :: any)[phase]
		if method ~= nil then
			if typeof(method) ~= "function" then
				error(`{entry.Name}.{phase} is not a function`)
			end
			local ok, err = pcall(method, entry.Module)
			if not ok then
				error(`{entry.Name}.{phase} failed: {err}`, 0)
			end
		end
	end
end

function Loader.Run(entries: { Entry })
	local seen: { [string]: boolean } = {}
	for _, entry in entries do
		if seen[entry.Name] then
			error(`Duplicate module name: {entry.Name}`)
		end
		seen[entry.Name] = true
	end

	runPhase(entries, "Init")
	runPhase(entries, "Start")
end

return Loader
