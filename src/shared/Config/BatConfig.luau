--!strict
-- Bat rules (docs/design.md 4.3 "Бита", D11). Pet Power makes the push
-- stronger (BatService); everything else here pets never change.

return table.freeze({
	Range = 7, -- studs from the attacker to the target
	HalfAngle = 60, -- degrees either side of where the attacker looks
	Cooldown = 1.5, -- seconds between swings, counted on the server
	KnockoutSeconds = 1.5, -- the victim cannot paint or pick up power-ups
	ImmunitySeconds = 2, -- after returning to the team spawn
	-- Client-side flight of the victim (visual only).
	KnockSpeed = 70,
	KnockLift = 45,
})
