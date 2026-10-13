--!strict
-- A soft glow behind a model in the UI: a few see-through circles in one
-- color and, if asked, the pack's shine as slowly turning rays. One
-- RenderStepped turns the rays of every glow that is on screen.

local RunService = game:GetService("RunService")

local Widgets = require(script.Parent.Widgets)

local RAYS_IMAGE = "rbxassetid://98508264222687"
local RAYS_DEGREES_PER_SECOND = 22
-- Outer to inner: bigger and fainter outside, so the light fades out.
local RINGS = {
	{ Size = 1, Transparency = 0.9 },
	{ Size = 0.78, Transparency = 0.82 },
	{ Size = 0.56, Transparency = 0.7 },
	{ Size = 0.34, Transparency = 0.55 },
}

export type Glow = {
	Root: Frame,
	Rays: ImageLabel?,
	Rings: { Frame },
}

local Glow = {}

local turning: { [ImageLabel]: true } = setmetatable({}, { __mode = "k" }) :: any
local connection: RBXScriptConnection? = nil

local function turnAll()
	local angle = (os.clock() * RAYS_DEGREES_PER_SECOND) % 360
	for rays in turning do
		if rays.Parent == nil then
			turning[rays] = nil
		elseif rays.Visible then
			rays.Rotation = angle
		end
	end
	if next(turning) == nil and connection then
		(connection :: RBXScriptConnection):Disconnect()
		connection = nil
	end
end

-- A square glow centered in `parent`, `size` times the parent's height,
-- under the parent's other children (ZIndex `zIndex`).
function Glow.new(
	parent: GuiObject,
	color: Color3,
	size: number,
	withRays: boolean,
	zIndex: number
): Glow
	local root = Instance.new("Frame")
	root.Name = "Glow"
	root.BackgroundTransparency = 1
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = UDim2.fromScale(size, size)
	root.SizeConstraint = Enum.SizeConstraint.RelativeYY
	root.ZIndex = zIndex
	root.Parent = parent

	local rays: ImageLabel? = nil
	if withRays then
		local image = Instance.new("ImageLabel")
		image.Name = "Rays"
		image.BackgroundTransparency = 1
		image.Image = RAYS_IMAGE
		image.ImageColor3 = color
		image.ImageTransparency = 0.25
		image.AnchorPoint = Vector2.new(0.5, 0.5)
		image.Position = UDim2.fromScale(0.5, 0.5)
		image.Size = UDim2.fromScale(1.35, 1.35)
		image.ZIndex = zIndex
		image.Parent = root
		rays = image
		turning[image] = true
		if connection == nil then
			connection = RunService.RenderStepped:Connect(turnAll)
		end
	end

	local rings = {}
	for _, ring in RINGS do
		local circle = Instance.new("Frame")
		circle.Name = "Ring"
		circle.AnchorPoint = Vector2.new(0.5, 0.5)
		circle.Position = UDim2.fromScale(0.5, 0.5)
		circle.Size = UDim2.fromScale(ring.Size, ring.Size)
		circle.BackgroundColor3 = color
		circle.BackgroundTransparency = ring.Transparency
		circle.BorderSizePixel = 0
		circle.ZIndex = zIndex
		circle.Parent = root
		Widgets.Corner(circle, 0.5)
		table.insert(rings, circle)
	end
	return { Root = root, Rays = rays, Rings = rings }
end

function Glow.SetColor(glow: Glow, color: Color3)
	if glow.Rays then
		(glow.Rays :: ImageLabel).ImageColor3 = color
	end
	for _, ring in glow.Rings do
		ring.BackgroundColor3 = color
	end
end

return Glow
