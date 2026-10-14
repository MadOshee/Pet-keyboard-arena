--!strict
-- Player level from total XP (XP comes after each rewarded round, Ivan
-- 2026-10-13). Going from level n to n + 1 takes Base + Step * (n - 1) XP.
-- Every level above 1 adds BonusPerLevel (+1%) to all of the player's
-- stats: Speed, paint Area, Luck, bat Power and round Money (Ivan).
-- Pure Luau, tested with Lune. The config table is RoundConfig.Levels.

export type Config = {
	Base: number,
	Step: number,
	BonusPerLevel: number,
}

export type Progress = {
	Level: number,
	Into: number, -- XP earned inside the current level
	Need: number, -- XP the current level takes in total
}

local Levels = {}

function Levels.Need(level: number, config: Config): number
	return config.Base + config.Step * (level - 1)
end

function Levels.FromXP(xp: number, config: Config): Progress
	local level = 1
	local left = math.max(math.floor(xp), 0)
	while true do
		local need = Levels.Need(level, config)
		if left < need then
			return { Level = level, Into = left, Need = need }
		end
		left -= need
		level += 1
	end
end

-- Stat bonus of a level as a fraction: 0 at level 1, + BonusPerLevel for
-- each level above (level 11: 0.1, that is +10% to every stat).
function Levels.Bonus(level: number, config: Config): number
	return config.BonusPerLevel * math.max(math.floor(level) - 1, 0)
end

return Levels
