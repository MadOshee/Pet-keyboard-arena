--!strict
-- The Feedback button (Ivan 2026-10-13): players write what to add or fix
-- and the server keeps each message in a DataStore for Ivan to read
-- (docs/feedback.md).
-- No requires or Roblox types: Lune tests load this file directly.

return table.freeze({
	MinChars = 3,
	MaxChars = 500,
	-- One message per player this often (the server checks it too).
	CooldownSeconds = 30,
	DataStoreName = "Feedback",
})
