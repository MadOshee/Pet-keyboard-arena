--!strict
-- Bat rules (docs/design.md 4.3 "Бита", D11). Pet Power makes the push
-- stronger (BatService); everything else here pets never change.

return table.freeze({
	-- Ivan 2026-10-13: hits were too hard to land, so the reach is wider
	-- (was 7 studs, 60 degrees) and players can swing almost nonstop.
	Range = 12, -- studs from the attacker to the target
	HalfAngle = 75, -- degrees either side of where the attacker looks
	Cooldown = 0.3, -- seconds between swings, counted on the server
	-- Bots keep their old reach and swing every few seconds (BotService),
	-- so the wider bat helps players more than bots.
	BotReach = 6,
	-- While flying from a hit the victim cannot paint, swing or pick up
	-- power-ups. Then they just run on, unless they flew off the arena.
	KnockoutSeconds = 1,
	ImmunitySeconds = 2, -- after a hit or after dropping back in from above
	-- Launch speed of the victim (studs per second). Ivan asked for twice
	-- the push of stage 3 (70 / 45): both are x1.41, so the arc is twice as long.
	KnockSpeed = 99,
	KnockLift = 64,
})
