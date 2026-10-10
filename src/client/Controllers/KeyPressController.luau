--!strict
-- Cosmetic only: arena keys sink under every character standing on them and
-- play their click sound. The server never sees these moves, so painting and
-- scoring are unaffected (keys are visual; players walk on Arena.Floor).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local ArenaConfig = require(ReplicatedStorage.Shared.Config.ArenaConfig)

local RAY_LENGTH = 8

local KeyPressController = {}

local tweenInfo =
	TweenInfo.new(ArenaConfig.KeyPressTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local random = Random.new()

local restY: { [BasePart]: number } = {}
local pressCount: { [BasePart]: number } = {}
local keyUnder: { [Player]: BasePart } = {}
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
	moveKey(key, restY[key] - ArenaConfig.KeyPressDepth)
	local sound = key:FindFirstChild("KeySound")
	if sound and sound:IsA("Sound") then
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

	RunService.Heartbeat:Connect(function()
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local key: BasePart? = nil
			if root and root:IsA("BasePart") then
				local result =
					workspace:Raycast(root.Position, Vector3.new(0, -RAY_LENGTH, 0), params)
				if result then
					key = result.Instance :: BasePart
				end
			end

			local previous = keyUnder[player]
			if key ~= previous then
				if previous then
					release(previous)
				end
				if key then
					press(key)
					keyUnder[player] = key
				else
					keyUnder[player] = nil
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		local key = keyUnder[player]
		if key then
			release(key)
			keyUnder[player] = nil
		end
	end)
end

function KeyPressController:Start()
	-- The arena is built by the server and may replicate after Start.
	task.spawn(run)
end

return KeyPressController
