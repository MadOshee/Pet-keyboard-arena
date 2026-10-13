--!strict
-- Checks a feedback message a player sends (FeedbackService): a string of
-- valid UTF-8 with MinChars..MaxChars characters once the spaces around it
-- are trimmed. Pure Luau, tested with Lune.

local FeedbackText = {}

function FeedbackText.Clean(text: unknown, minChars: number, maxChars: number): string?
	if type(text) ~= "string" then
		return nil
	end
	local raw = text :: string
	-- A UTF-8 character is at most 4 bytes.
	if #raw > maxChars * 4 or utf8.len(raw) == nil then
		return nil
	end
	local trimmed = string.match(raw, "^%s*(.-)%s*$") or ""
	local length = utf8.len(trimmed) or 0
	if length < minChars or length > maxChars then
		return nil
	end
	return trimmed
end

return FeedbackText
