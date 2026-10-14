--!strict
-- Pets standing on plot platforms come alive (Ivan, 2026-10-14): they
-- breathe, now and then jump or take a short walk round their platform
-- (Logic/PetIdle), and every second a "+$N" pops up beside each one for
-- half a second and fades: the money it just earned (the platform's Income
-- attribute, set by PlotService from PetIncome). Nothing pops while the
-- owner's pets earn nothing (the plot's IncomePaused, egg pick screen open).
--
-- Display only: the server places the pet model ("Shown" under the
-- platform) once; this moves the local copy. Pets far from the camera are
-- left at rest, so a full server of bases costs little.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local PetIdle = require(ReplicatedStorage.Shared.Logic.PetIdle)
local Money = require(ReplicatedStorage.Shared.Util.Money)
local Widgets = require(script.Parent.Parent.UI.Widgets)

local player = Players.LocalPlayer

local ANIMATE_DISTANCE = 140 -- studs from the camera
local POPUP_DISTANCE = 80
local POPUP_SHOW = 0.5 -- seconds fully visible
local POPUP_FADE = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local POPUP_RISE = 1 -- studs the text floats up while it fades
local POPUP_HEIGHT = 2.6 -- above the platform
local POPUP_SIDE = 2.2 -- to the right on screen
local POPUP_COLOR = Color3.fromRGB(110, 255, 120)

local PlotPetController = {}

type Pet = {
	Platform: BasePart,
	Plot: Instance,
	Model: Model,
	-- The pet's rest pivot relative to its rest spot: the platform's top
	-- centre in the platform's rotation, before any breathing.
	Offset: CFrame,
	Scale: number,
	Phase: number,
	Action: PetIdle.Action,
	Moving: boolean,
	Popup: BillboardGui,
	Label: TextLabel,
	Stroke: UIStroke?,
	PopupToken: number,
}

local pets: { [Model]: Pet } = {}
local random = Random.new()
local lastSecond = 0

local function rng(): number
	return random:NextNumber()
end

local function restSpot(platform: BasePart): CFrame
	return platform.CFrame * CFrame.new(0, platform.Size.Y / 2, 0)
end

local function makePopup(platform: BasePart): (BillboardGui, TextLabel, UIStroke?)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "PetIncomePopup"
	billboard.Size = UDim2.fromScale(5, 1.3)
	billboard.LightInfluence = 0
	billboard.MaxDistance = POPUP_DISTANCE
	billboard.AlwaysOnTop = false
	billboard.Enabled = false
	billboard.Adornee = platform
	local label = Widgets.Label("Money", billboard, UDim2.fromScale(1, 1), UDim2.new())
	label.TextColor3 = POPUP_COLOR
	local stroke = label:FindFirstChildOfClass("UIStroke")
	billboard.Parent = player:WaitForChild("PlayerGui")
	return billboard, label, stroke
end

local function track(model: Model, platform: BasePart, plot: Instance)
	if pets[model] then
		return
	end
	local key = model:GetAttribute("Key")
	if type(key) ~= "string" or string.sub(key, 1, 4) ~= "Pet:" then
		return
	end
	local popup, label, stroke = makePopup(platform)
	local pet: Pet = {
		Platform = platform,
		Plot = plot,
		Model = model,
		Offset = restSpot(platform):ToObjectSpace(model:GetPivot()),
		Scale = model:GetScale(),
		Phase = rng(),
		Action = PetIdle.Next(workspace:GetServerTimeNow(), rng),
		Moving = false,
		Popup = popup,
		Label = label,
		Stroke = stroke,
		PopupToken = 0,
	}
	pets[model] = pet
	model.Destroying:Connect(function()
		pets[model] = nil
		popup:Destroy()
	end)
	model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(workspace) and pets[model] then
			pets[model] = nil
			popup:Destroy()
		end
	end)
end

-- Puts the pet in `pose`: moved and turned in the platform's space, scaled
-- around its rest spot so it breathes without sinking or floating.
local function apply(pet: Pet, pose: PetIdle.Pose)
	local spot = restSpot(pet.Platform)
		* CFrame.new(pose.X, pose.Y, pose.Z)
		* CFrame.Angles(0, pose.Yaw, 0)
	local offset = pet.Offset
	pet.Model:ScaleTo(pet.Scale * pose.Scale)
	pet.Model:PivotTo(spot * CFrame.new(offset.Position * pose.Scale) * offset.Rotation)
end

local function popup(pet: Pet, pose: PetIdle.Pose)
	local income = pet.Platform:GetAttribute("Income")
	if type(income) ~= "number" or income <= 0 or pet.Plot:GetAttribute("IncomePaused") == true then
		return
	end
	pet.PopupToken += 1
	local token = pet.PopupToken
	local billboard, label, stroke = pet.Popup, pet.Label, pet.Stroke
	-- Beside where the pet is now, in world space, and a bit to the right.
	local base = pet.Platform.CFrame:VectorToWorldSpace(Vector3.new(pose.X, 0, pose.Z))
	billboard.StudsOffsetWorldSpace = base + Vector3.new(0, POPUP_HEIGHT, 0)
	billboard.StudsOffset = Vector3.new(POPUP_SIDE, 0, 0)
	label.Text = "+" .. Money.Format(income :: number)
	label.TextTransparency = 0
	if stroke then
		stroke.Transparency = 0
	end
	billboard.Enabled = true
	task.delay(POPUP_SHOW, function()
		if token ~= pet.PopupToken then
			return
		end
		TweenService:Create(label, POPUP_FADE, { TextTransparency = 1 }):Play()
		if stroke then
			TweenService:Create(stroke, POPUP_FADE, { Transparency = 1 }):Play()
		end
		TweenService
			:Create(billboard, POPUP_FADE, { StudsOffset = Vector3.new(POPUP_SIDE, POPUP_RISE, 0) })
			:Play()
		task.delay(POPUP_FADE.Time, function()
			if token == pet.PopupToken then
				billboard.Enabled = false
			end
		end)
	end)
end

local function step()
	local camera = workspace.CurrentCamera
	if camera == nil then
		return
	end
	local eye = camera.CFrame.Position
	local now = workspace:GetServerTimeNow()
	local second = math.floor(now)
	local newSecond = second ~= lastSecond
	lastSecond = second
	for _, pet in pets do
		local distance = (pet.Platform.Position - eye).Magnitude
		if distance > ANIMATE_DISTANCE then
			if pet.Moving then
				pet.Moving = false
				apply(pet, { X = 0, Y = 0, Z = 0, Yaw = 0, Scale = 1 })
			end
			continue
		end
		if now >= pet.Action.Start + PetIdle.Duration(pet.Action) then
			pet.Action = PetIdle.Next(now, rng)
		end
		local pose = PetIdle.Pose(now, pet.Phase, pet.Action)
		pet.Moving = true
		apply(pet, pose)
		if newSecond and distance <= POPUP_DISTANCE then
			popup(pet, pose)
		end
	end
end

local function watchPlatform(platform: BasePart, plot: Instance)
	local function scan(child: Instance)
		if child.Name == "Shown" and child:IsA("Model") then
			-- Let the model's parts arrive before measuring its rest pivot.
			task.defer(track, child, platform, plot)
		end
	end
	platform.ChildAdded:Connect(scan)
	for _, child in platform:GetChildren() do
		scan(child)
	end
end

local function watchPlot(plot: Instance)
	local function scan(child: Instance)
		if child:IsA("BasePart") and child:GetAttribute("Index") ~= nil then
			watchPlatform(child, plot)
		end
	end
	plot.ChildAdded:Connect(scan)
	for _, child in plot:GetChildren() do
		scan(child)
	end
end

function PlotPetController:Init() end

function PlotPetController:Start()
	task.spawn(function()
		local folder = workspace:WaitForChild("Plots")
		folder.ChildAdded:Connect(watchPlot)
		for _, plot in folder:GetChildren() do
			watchPlot(plot)
		end
	end)
	RunService.RenderStepped:Connect(step)
end

return PlotPetController
