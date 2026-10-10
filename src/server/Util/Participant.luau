--!strict
-- A round participant is either a Player or a bot's character Model
-- (BotService). Arena, bat and power-up code key their state by this
-- Instance and use these helpers to reach the character.

export type Participant = Instance

local Participant = {}

function Participant.AsPlayer(participant: Participant): Player?
	if participant:IsA("Player") then
		return participant :: Player
	end
	return nil
end

function Participant.Character(participant: Participant): Model?
	if participant:IsA("Player") then
		return (participant :: Player).Character
	elseif participant:IsA("Model") then
		return participant :: Model
	end
	return nil
end

function Participant.Humanoid(participant: Participant): Humanoid?
	local character = Participant.Character(participant)
	return if character then character:FindFirstChildOfClass("Humanoid") else nil
end

-- The root part of a living participant, or nil.
function Participant.Root(participant: Participant): BasePart?
	local character = Participant.Character(participant)
	if character == nil then
		return nil
	end
	local root = (character :: Model):FindFirstChild("HumanoidRootPart")
	local humanoid = (character :: Model):FindFirstChildOfClass("Humanoid")
	if root and root:IsA("BasePart") and humanoid and humanoid.Health > 0 then
		return root :: BasePart
	end
	return nil
end

-- Still in the game: a player on the server or a bot model in the world.
function Participant.IsPresent(participant: Participant): boolean
	return participant.Parent ~= nil
end

-- 0 for bots, so clients can tell them apart in remote events.
function Participant.UserId(participant: Participant): number
	local player = Participant.AsPlayer(participant)
	return if player then (player :: Player).UserId else 0
end

return Participant
