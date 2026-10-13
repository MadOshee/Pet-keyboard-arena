--!strict
-- Bat rules (docs/design.md 4.3 "Бита", D11). Pet Power makes the push
-- stronger (BatService); everything else here pets never change.

return table.freeze({
	Range = 7, -- studs from the attacker to the target
	HalfAngle = 60, -- degrees either side of where the attacker looks
	Cooldown = 1.5, -- seconds between swings, counted on the server
	-- While flying from a hit the victim cannot paint, swing or pick up
	-- power-ups. Then they just run on, unless they flew off the arena.
	KnockoutSeconds = 1,
	ImmunitySeconds = 2, -- after a hit or after dropping back in from above
	-- Launch speed of the victim (studs per second). Ivan asked for twice
	-- the push of stage 3 (70 / 45): both are x1.41, so the arc is twice as long.
	KnockSpeed = 99,
	KnockLift = 64,
})
