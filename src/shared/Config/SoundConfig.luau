--!strict
-- Music and game sounds Ivan picked (2026-10-13). Each is a Roblox audio
-- asset id; SoundController plays them. Button sounds stay in the UI pack.
--
-- Hub, Arena and YouWin did not load in Studio on 2026-10-13: those assets
-- are private to their owner. Ivan uploads the files himself and the new
-- ids go here.

export type SoundInfo = {
	Id: number,
	Volume: number,
}

local function sound(id: number, volume: number): SoundInfo
	return table.freeze({ Id = id, Volume = volume })
end

return table.freeze({
	Music = table.freeze({
		Hub = sound(110676261724204, 0.35), -- GearshockBeach Training
		Queue = sound(81962372207399, 0.35), -- Tug Of War Theme, while searching for a match
		Arena = sound(135337255401037, 0.35), -- factory theme mini mix
		YouWin = sound(17828922294, 0.4), -- rewards and egg pick, looped until an egg is picked
	}),
	Effects = table.freeze({
		Countdown = sound(6238869231, 0.7), -- 3-2-1, only its first CountdownPlaySeconds
		Victory = sound(74216560469867, 0.7), -- end of the round
		Speed = sound(96643104586269, 0.7), -- Magic Circle Warp: speed boost picked and over
		BatHit = sound(182765513, 0.7), -- magic cast 43: a swing that hit someone
		BatMiss = sound(9116406375, 0.6), -- Magic Poofs Thumpy: a swing that hit nobody
		GotHit = sound(7846700665, 0.7), -- Magic Lock: you were hit
		Fall = sound(6494675393, 0.7), -- magic ramen done: fell off the arena, dropped back in
		Reward = sound(128222963416516, 0.7), -- Banana collect 9: level up, egg picked, pet hatched
	}),
	CountdownPlaySeconds = 4, -- then the arena music starts
	-- The arena music speeds up for the last seconds of a round.
	FastSeconds = 10,
	FastPlaybackSpeed = 1.25,
	-- Bat sounds come from the bat, so far away swings are quiet.
	BatHearDistance = 80,
	FadeSeconds = 0.6,
})
