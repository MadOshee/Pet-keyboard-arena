--!strict
-- Keeps players' feedback messages (the Feedback button, Ivan 2026-10-13)
-- in a DataStore so Ivan can read them after the release (docs/feedback.md).
-- One key per message, "<unix time>_<user id>_<n>", so a key listing comes
-- out in time order. Nobody else sees the text, so it is not filtered.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FeedbackConfig = require(ReplicatedStorage.Shared.Config.FeedbackConfig)
local FeedbackText = require(ReplicatedStorage.Shared.Logic.FeedbackText)
local NetService = require(script.Parent.NetService)

local SAVE_ATTEMPTS = 3

local FeedbackService = {}

local store: DataStore? = nil
local lastSentAt: { [Player]: number } = {}
local saved = 0

local function save(player: Player, text: string)
	saved += 1
	local key = `{os.time()}_{player.UserId}_{saved}`
	local entry = {
		UserId = player.UserId,
		Name = player.Name,
		Text = text,
		Time = os.time(),
		PlaceVersion = game.PlaceVersion,
	}
	for attempt = 1, SAVE_ATTEMPTS do
		local ok, err = pcall(function()
			(store :: DataStore):SetAsync(key, entry, { player.UserId })
		end)
		if ok then
			return
		end
		warn(`[FeedbackService] save failed (try {attempt}): {err}`)
		task.wait(2 ^ attempt)
	end
	-- Not lost from the server log at least.
	warn(`[FeedbackService] not saved, {player.UserId}: {text}`)
end

function FeedbackService:Init()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(FeedbackConfig.DataStoreName)
	end)
	if ok then
		store = result
	else
		warn(`[FeedbackService] no DataStore: {result}`)
	end
end

function FeedbackService:Start()
	NetService:On("SendFeedback", { PerSecond = 1, Burst = 2 }, function(player, text)
		local clean = FeedbackText.Clean(text, FeedbackConfig.MinChars, FeedbackConfig.MaxChars)
		if clean == nil then
			return
		end
		local now = os.clock()
		local last = lastSentAt[player]
		if last and now - last < FeedbackConfig.CooldownSeconds then
			return
		end
		lastSentAt[player] = now
		print(`[FeedbackService] {player.Name} ({player.UserId}): {clean}`)
		if store then
			task.spawn(save, player, clean :: string)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastSentAt[player] = nil
	end)
end

return FeedbackService
