--!strict
-- The Settings window's switches (Ivan 2026-10-14): background music, sound
-- effects and visual effects, all on by default. SettingsService saves them
-- in the profile and accepts only these names with a boolean. Pure Luau,
-- tested with Lune.

local PlayerSettings = {}

PlayerSettings.Names = table.freeze({ "Music", "Sfx", "Vfx" })

function PlayerSettings.IsValid(name: unknown, on: unknown): boolean
	return type(name) == "string"
		and table.find(PlayerSettings.Names, name :: string) ~= nil
		and type(on) == "boolean"
end

-- A switch from a saved table; anything missing or broken counts as on.
function PlayerSettings.Get(settings: { [string]: any }?, name: string): boolean
	local value = if settings then settings[name] else nil
	return if type(value) == "boolean" then value else true
end

return PlayerSettings
