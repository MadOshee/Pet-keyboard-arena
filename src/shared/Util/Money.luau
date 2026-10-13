--!strict
-- Money text (Ivan, 2026-10-12): coins show as dollars. "$1000",
-- "$100 000"; numbers from 10 000 get a space between thousands.
-- No requires or Roblox types: Lune tests load this file directly.

local Money = {}

function Money.Number(value: number): string
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
