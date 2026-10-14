--!strict
-- Cosmetic only: arena keys sink under every character standing on them and
-- play their click sound. The server never sees these moves, so painting and
-- scoring are unaffected (keys are visual; players walk on Arena.Floor).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local ClientSettings = require(script.Parent.Parent.Util.ClientSettings)

local RAY_LENGTH = 8 -- a character higher than this above the keys presses nothing
-- Every key within this distance of the spot under the character sinks, so
-- a character stands on a small patch of pressed keys, not on one.
local FOOT_RADIUS = 1.2
-- Same as the Free Ocean Keyboard key script.
local PRESS_DEPTH = 1.35 -- studs a key sinks under a character
local PRESS_TIME = 0.3 -- seconds

local KeyPressController = {}

local tweenInfo = TweenInfo.new(PRESS_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local random = Random.new()

local restY: { [BasePart]: number } = {}
local pressCount: { [BasePart]: number } = {}
-- Keyed by character model, so bots press keys too.
local keysUnder: { [Model]: { [BasePart]: true } } = {}
local tweens: { [BasePart]: Tween } = {}

local function moveKey(key: BasePart, y: number)
	local previous = tweens[key]
	if previous then
		previous:Cancel()
	end
	local position = key.Position
	local tween =
		TweenService:Create(key, tweenInfo, { Position = Vector3.new(position.X, y, position.Z) })
	tweens[key] = tween
	tween:Play()
end

local function press(key: BasePart)
	local count = (pressCount[key] or 0) + 1
	pressCount[key] = count
	if count > 1 then
		return
	end
	if restY[key] == nil then
		restY[key] = key.Position.Y
	end
	moveKey(key, restY[key] - PRESS_DEPTH)
	local sound = key:FindFirstChild("KeySound")
	if sound and sound:IsA("Sound") then
		ClientSettings.Attach(sound, "Effects")
		sound.PlaybackSpeed = random:NextNumber(0.95, 1.05)
		sound:Play()
	end
end

local function release(key: BasePart)
	local count = (pressCount[key] or 1) - 1
	if count > 0 then
		pressCount[key] = count
		return
	end
	pressCount[key] = nil
	local y = restY[key]
	if y then
		moveKey(key, y)
	end
end

local function run()
	local arena = workspace:WaitForChild("Arena")
	local keysFolder = arena:WaitForChild("Keys")

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { keysFolder }
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Include
	overlap.FilterDescendantsInstances = { keysFolder }

	local direction = Vector3.new(0, -RAY_LENGTH, 0)
	local function characters(): { Model }
		local list = {}
		for _, player in Players:GetPlayers() do
			if player.Character then
				table.insert(list, player.Character)
			end
		end
		local bots = workspace:FindFirstChild("Bots")
		if bots then
			for _, bot in bots:GetChildren() do
				if bot:IsA("Model") then
					table.insert(list, bot)
				end
			end
		end
		return list
	end

	RunService.Heartbeat:Connect(function()
		local seen: { [Model]: true } = {}
		for _, character in characters() do
			seen[character] = true
			local now: { [BasePart]: true } = {}
			local root = character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				local hit = workspace:Raycast(root.Position, direction, params)
				if hit then
					for _, part in
						workspace:GetPartBoundsInRadius(hit.Position, FOOT_RADIUS, overlap)
					do
						now[part] = true
					end
				end
			end

			local before: { [BasePart]: true } = keysUnder[character] or {}
			for key in now do
				if not before[key] then
					press(key)
				end
			end
			for key in before do
				if not now[key] then
					release(key)
				end
			end
			keysUnder[character] = now
		end

		-- Characters that left (respawn, bot removed, player gone) let go.
		for character, keys in keysUnder do
			if not seen[character] then
				for key in keys do
					release(key)
				end
				keysUnder[character] = nil
			end
		end
	end)
end

function KeyPressController:Start()
	-- The arena is built by the server and may replicate after Start.
	task.spawn(run)
end

return KeyPressController
