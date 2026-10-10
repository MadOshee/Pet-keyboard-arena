--!strict
-- Team colors used by the arena keys and the HUD.

local Types = require(script.Parent.Parent.Types)

local RED = Color3.fromRGB(235, 64, 64)
local BLUE = Color3.fromRGB(56, 128, 245)

return table.freeze({
	Red = RED,
	Blue = BLUE,
	Neutral = Color3.fromRGB(255, 232, 178),
	KeyLabel = Color3.fromRGB(40, 40, 48),

	ForTeam = function(team: Types.TeamId): Color3
		return if team == "Red" then RED else BLUE
	end,
})
