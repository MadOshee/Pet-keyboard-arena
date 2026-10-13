--!strict
-- Music and game sounds (SoundConfig, Ivan's picks 2026-10-13). Cosmetic
-- only: it listens to the round phase, the player's attributes and the
-- server's events. Button sounds stay in Widgets (the UI pack).
--
-- Music: the hub track; the queue track while searching for a match; on
-- the arena the 3-2-1 countdown, then the arena track (faster for the last
-- seconds); Victory at the end of the round, then "You win" looped until
-- the player picks an egg.

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local PowerUpConfig = require(ReplicatedStorage.Shared.Config.PowerUpConfig)
local RoundConfig = require(ReplicatedStorage.Shared.Config.RoundConfig)
local SoundConfig = require(ReplicatedStorage.Shared.Config.SoundConfig)
local Levels = require(ReplicatedStorage.Shared.Logic.Levels)
local Types = require(ReplicatedStorage.Shared.Types)
local ClientNet = require(script.Parent.Parent.Util.ClientNet)
local DataController = require(script.Parent.DataController)

local player = Players.LocalPlayer

local UPDATE_SECONDS = 0.2

local SoundController = {}

local folder: Folder
local music: { [string]: Sound } = {}
local effects: { [string]: Sound } = {}
local currentMusic: string? = nil
local countdownUntil = 0
local victoryUntil = 0
local speedToken = 0
local lastLevel: number? = nil

local function newSound(name: string, info: SoundConfig.SoundInfo, looped: boolean): Sound
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = `rbxassetid://{info.Id}`
	sound.Volume = info.Volume
	sound.Looped = looped
	sound.Parent = folder
	return sound
end

-- Plays a copy of an effect: from `part` (heard nearby) or for us alone.
local function playEffect(name: string, part: BasePart?): Sound?
	local template: Sound? = effects[name]
	if template == nil then
		return nil
	end
	local sound = (template :: Sound):Clone()
	if part then
		sound.RollOffMode = Enum.RollOffMode.InverseTapered
		sound.RollOffMaxDistance = SoundConfig.BatHearDistance
		sound.Parent = part
	else
		sound.Parent = SoundService
	end
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	return sound
end

local function fade(sound: Sound, volume: number, after: (() -> ())?)
	local tween =
		TweenService:Create(sound, TweenInfo.new(SoundConfig.FadeSeconds), { Volume = volume })
	if after then
		tween.Completed:Once(after)
	end
	tween:Play()
end

local function setMusic(name: string?)
	if name == currentMusic then
		return
	end
	local old = currentMusic and music[currentMusic]
	currentMusic = name
	if old then
		local fading = old :: Sound
		fade(fading, 0, function()
			if music[currentMusic or ""] ~= fading then
				fading:Stop()
			end
		end)
	end
	local new = name and music[name]
	if new then
		local track = new :: Sound
		local info = (SoundConfig.Music :: any)[name] :: SoundConfig.SoundInfo
		track.PlaybackSpeed = 1
		track.Volume = 0
		track.TimePosition = 0
		track:Play()
		fade(track, info.Volume)
	end
end

local function hasOffer(): boolean
	local profile = DataController:Get()
	return profile ~= nil and profile.PendingOffer ~= nil
end

local function wantedMusic(now: number): string?
	local phase = ReplicatedStorage:GetAttribute("RoundPhase")
	if player:GetAttribute("Team") ~= nil then
		if phase == "Countdown" or now < countdownUntil then
			return nil
		elseif phase == "Playing" then
			return "Arena"
		elseif phase == "Results" then
			return if now >= victoryUntil and hasOffer() then "YouWin" else nil
		end
		return nil
	end
	if hasOffer() then
		return if now >= victoryUntil then "YouWin" else nil
	elseif player:GetAttribute("Ready") == true then
		return "Queue"
	end
	return "Hub"
end

local function update()
	local now = os.clock()
	setMusic(wantedMusic(now))
	-- The arena track speeds up when the round is nearly over.
	local arena = music.Arena
	if currentMusic == "Arena" and arena then
		local endsAt = ReplicatedStorage:GetAttribute("PhaseEndsAt")
		local left = if type(endsAt) == "number"
			then endsAt - workspace:GetServerTimeNow()
			else math.huge
		arena.PlaybackSpeed = if left <= SoundConfig.FastSeconds
			then SoundConfig.FastPlaybackSpeed
			else 1
	end
end

local function onPhase()
	if player:GetAttribute("Team") == nil then
		return
	end
	local phase = ReplicatedStorage:GetAttribute("RoundPhase")
	local now = os.clock()
	if phase == "Countdown" then
		countdownUntil = now + SoundConfig.CountdownPlaySeconds
		local sound = playEffect("Countdown")
		if sound then
			task.delay(SoundConfig.CountdownPlaySeconds, function()
				sound:Destroy()
			end)
		end
	elseif phase == "Results" then
		local sound = playEffect("Victory")
		local length = if sound and sound.TimeLength > 0 then sound.TimeLength else 3
		victoryUntil = now + length
	end
	update()
end

local function batPart(attacker: Model?): BasePart?
	local bat = attacker and attacker:FindFirstChild("Bat")
	if bat and bat:IsA("Model") and bat.PrimaryPart then
		return bat.PrimaryPart
	end
	local root = attacker and attacker:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function onSwing(attacker: Model?, hit: boolean?)
	local part = batPart(attacker)
	if part then
		playEffect(if hit then "BatHit" else "BatMiss", part)
	end
end

local function onKnockedOut(victim: Model?)
	if victim ~= nil and victim == player.Character then
		playEffect("GotHit")
	end
end

local function onPowerUp(kind: string, userId: number)
	if kind ~= "Speed" or userId ~= player.UserId then
		return
	end
	playEffect("Speed")
	-- The same sound when the boost runs out; a new boost restarts the wait.
	speedToken += 1
	local token = speedToken
	task.delay(PowerUpConfig.SpeedSeconds, function()
		if token == speedToken then
			playEffect("Speed")
		end
	end)
end

local function onProfile(profile: Types.Profile)
	local level = Levels.FromXP(profile.XP, RoundConfig.Levels).Level
	if lastLevel and level > (lastLevel :: number) then
		playEffect("Reward")
	end
	lastLevel = level
	update()
end

function SoundController:Init()
	folder = Instance.new("Folder")
	folder.Name = "GameSounds"
	folder.Parent = SoundService
	for name, info in SoundConfig.Music :: any do
		music[name] = newSound(name, info, true)
	end
	for name, info in SoundConfig.Effects :: any do
		effects[name] = newSound(name, info, false)
	end
end

function SoundController:Start()
	task.spawn(function()
		ContentProvider:PreloadAsync(folder:GetChildren())
	end)

	ReplicatedStorage:GetAttributeChangedSignal("RoundPhase"):Connect(onPhase)
	player:GetAttributeChangedSignal("Team"):Connect(update)
	player:GetAttributeChangedSignal("Ready"):Connect(update)
	DataController.Changed:Connect(onProfile)

	ClientNet.On("BatSwingFx", onSwing)
	ClientNet.On("KnockedOut", onKnockedOut)
	ClientNet.On("ArenaFell", function()
		playEffect("Fall")
	end)
	ClientNet.On("ArenaRespawn", function()
		playEffect("Fall")
	end)
	ClientNet.On("PowerUpEvent", onPowerUp)
	ClientNet.On("EggPicked", function()
		playEffect("Reward")
	end)
	ClientNet.On("PetHatched", function()
		playEffect("Reward")
	end)

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= UPDATE_SECONDS then
			elapsed = 0
			update()
		end
	end)
	local profile = DataController:Get()
	if profile then
		lastLevel = Levels.FromXP(profile.XP, RoundConfig.Levels).Level
	end
	update()
end

return SoundController
