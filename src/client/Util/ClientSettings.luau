--!strict
-- The Settings window's switches on this client (Ivan 2026-10-14). Music
-- and sound effects play through two SoundGroups that go silent when their
-- switch is off; visual effects are checked by EffectsController.
-- SettingsController loads the switches from the profile and saves changes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Signal = require(ReplicatedStorage.Shared.Util.Signal)

export type Group = "Music" | "Effects"

local ClientSettings = {}

-- (name, on) when a switch changes.
ClientSettings.Changed = Signal.new() :: Signal.Signal<string, boolean>

local values: { [string]: boolean } = { Music = true, Sfx = true, Vfx = true }
-- Which switch silences which group.
local SWITCH_OF: { [Group]: string } = { Music = "Music", Effects = "Sfx" }
local groups: { [Group]: SoundGroup } = {}

local function volume(group: Group): number
	return if values[SWITCH_OF[group]] then 1 else 0
end

local function getGroup(group: Group): SoundGroup
	local existing = groups[group]
	if existing then
		return existing
	end
	local created = Instance.new("SoundGroup")
	created.Name = `{group}Group`
	created.Volume = volume(group)
	created.Parent = SoundService
	groups[group] = created
	return created
end

function ClientSettings.Get(name: string): boolean
	return values[name] ~= false
end

function ClientSettings.Set(name: string, on: boolean)
	if values[name] == on then
		return
	end
	values[name] = on
	for group: Group, created in groups do
		created.Volume = volume(group)
	end
	ClientSettings.Changed:Fire(name, on)
end

-- Puts a sound in the Music or Effects group, so its switch silences it.
function ClientSettings.Attach(sound: Sound, group: Group)
	sound.SoundGroup = getGroup(group)
end

return ClientSettings
