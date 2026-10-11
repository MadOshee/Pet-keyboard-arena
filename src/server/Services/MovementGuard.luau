--!strict
-- Speed-hack protection for painting (docs/design.md section 11).
-- ArenaService samples every participant's server-side position each paint
-- tick and asks Check(). A move longer than the humanoid's (server-set)
-- WalkSpeed allows is "Skip": that tick does not paint. Repeated skips in a
-- short window return "Return": ArenaService puts the player back on their
-- team spawn and the event is logged. Every server teleport must call
-- Reset(), or the jump would count as a violation.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MovementCheck = require(ReplicatedStorage.Shared.Logic.MovementCheck)

export type Verdict = "Ok" | "Skip" | "Return"

local SETTINGS: MovementCheck.Settings = {
	Factor = 1.5,
	Margin = 2, -- studs; covers network jitter between samples
}
local STRIKES_TO_RETURN = 5
local STRIKE_WINDOW = 10 -- seconds

type Sample = { X: number, Z: number, Time: number }

local MovementGuard = {}

local lastSample: { [Player]: Sample } = {}
local strikes: { [Player]: { number } } = {}

local function addStrike(player: Player, now: number): number
	local list: { number } = strikes[player] or {}
	strikes[player] = list
	table.insert(list, now)
	while list[1] and now - list[1] > STRIKE_WINDOW do
		table.remove(list, 1)
	end
	return #list
end

function MovementGuard:Init() end

function MovementGuard:Start()
	Players.PlayerRemoving:Connect(function(player)
		lastSample[player] = nil
		strikes[player] = nil
	end)
end

function MovementGuard:Check(player: Player, position: Vector3, walkSpeed: number): Verdict
	local now = os.clock()
	local previous = lastSample[player]
	lastSample[player] = { X = position.X, Z = position.Z, Time = now }
	if previous == nil then
		return "Ok"
	end
	local sample = previous :: Sample
	local dt = now - sample.Time
	if dt <= 0 then
		return "Ok"
	end
	if
		not MovementCheck.IsSuspicious(
			sample.X,
			sample.Z,
			position.X,
			position.Z,
			dt,
			walkSpeed,
			SETTINGS
		)
	then
		return "Ok"
	end
	if addStrike(player, now) >= STRIKES_TO_RETURN then
		strikes[player] = nil
		warn(
			`[MovementGuard] {player.Name} ({player.UserId}) moved too fast repeatedly; returned to spawn`
		)
		return "Return"
	end
	return "Skip"
end

-- Forget the last position, for example after a server teleport.
function MovementGuard:Reset(player: Player)
	lastSample[player] = nil
end

return MovementGuard
