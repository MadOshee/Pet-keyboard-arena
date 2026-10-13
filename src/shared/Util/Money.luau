--!strict
-- Money text (Ivan, 2026-10-12): coins show as dollars. "$1000",
-- "$100 000"; numbers from 10 000 get a space between thousands. From a
-- million on they are shortened (Ivan, 2026-10-13): "$1.1M", "$99.9M",
-- "$1.1B", rounded down so it never shows more than there is.
-- No requires or Roblox types: Lune tests load this file directly.

local Money = {}

local SUFFIXES = { "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

local function short(value: number): string?
	local whole = math.floor(math.abs(value))
	if whole < 1e6 then
		return nil
	end
	local index = math.min(math.floor(math.log10(whole) / 3) - 1, #SUFFIXES)
	local scaled = whole / 10 ^ (3 * (index + 1))
	-- A tiny nudge so 1.1e6 / 1e6 does not floor to 1.0.
	local tenths = math.floor(scaled * 10 + 1e-9)
	local text = if tenths % 10 == 0
		then tostring(tenths // 10)
		else string.format("%d.%d", tenths // 10, tenths % 10)
	return (if value < 0 then "-" else "") .. text .. SUFFIXES[index]
end

function Money.Number(value: number): string
	local shortened = short(value)
	if shortened then
		return shortened
	end
	local text = tostring(math.floor(value))
	if #text <= 4 then
		return text
	end
	local grouped = string.reverse(text):gsub("(%d%d%d)", "%1 ")
	return (string.reverse(grouped):gsub("^ ", ""))
end

function Money.Format(value: number): string
	return "$" .. Money.Number(value)
end

return Money
