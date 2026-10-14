--!strict
-- The tag over a character's head: name on top, "Lv. N" under it (Ivan
-- 2026-10-14). Server-made, so every client sees the same tag; the default
-- Roblox name is hidden. Bots get a tag with their name and no level.

local NAMEPLATE_NAME = "Nameplate"
local NAME_COLOR = Color3.fromRGB(255, 255, 255)
local LEVEL_COLOR = Color3.fromRGB(255, 214, 80)

local Nameplate = {}

local function label(name: string, color: Color3, top: number, height: number): TextLabel
	local text = Instance.new("TextLabel")
	text.Name = name
	text.BackgroundTransparency = 1
	text.Position = UDim2.fromScale(0, top)
	text.Size = UDim2.fromScale(1, height)
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextColor3 = color
	text.TextStrokeTransparency = 0.2
	return text
end

-- Adds the tag to `character` (or returns the one it has) and hides the
-- humanoid's own name.
function Nameplate.Attach(character: Model): BillboardGui?
	local head = character:FindFirstChild("Head")
	if not (head and head:IsA("BasePart")) then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	local existing = (head :: BasePart):FindFirstChild(NAMEPLATE_NAME)
	if existing and existing:IsA("BillboardGui") then
		return existing
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = NAMEPLATE_NAME
	gui.Size = UDim2.fromScale(5, 1.5)
	gui.StudsOffset = Vector3.new(0, 2.4, 0)
	gui.MaxDistance = 100
	gui.ResetOnSpawn = false
	label("PlayerName", NAME_COLOR, 0, 0.6).Parent = gui
	label("Level", LEVEL_COLOR, 0.6, 0.4).Parent = gui
	gui.Parent = head
	return gui
end

-- Sets the texts; `level` nil hides the level line. `color` tints the name
-- (team color in a match), nil is white.
function Nameplate.Set(gui: BillboardGui, name: string, level: number?, color: Color3?)
	local nameLabel = gui:FindFirstChild("PlayerName")
	local levelLabel = gui:FindFirstChild("Level")
	if nameLabel and nameLabel:IsA("TextLabel") then
		nameLabel.Text = name
		nameLabel.TextColor3 = color or NAME_COLOR
	end
	if levelLabel and levelLabel:IsA("TextLabel") then
		levelLabel.Visible = level ~= nil
		levelLabel.Text = if level then `Lv. {level}` else ""
	end
end

return Nameplate
