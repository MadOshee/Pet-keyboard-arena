--!strict
-- Creates every RemoteEvent from Shared/Net/RemoteNames and wraps incoming
-- requests with a per-player rate limit (docs/design.md sections 10-11).
-- Handlers still validate their own arguments with Util/Guard.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteNames = require(ReplicatedStorage.Shared.Net.RemoteNames)
local RateLimiter = require(script.Parent.Parent.Util.RateLimiter)

export type Limit = {
	PerSecond: number,
	Burst: number,
}

local NetService = {}

local remotes: { [string]: RemoteEvent } = {}
local limiters: { RateLimiter.RateLimiter } = {}

local function getRemote(name: string): RemoteEvent
	return assert(remotes[name], `Unknown remote: {name} (add it to Shared/Net/RemoteNames)`)
end

function NetService:Init()
	local folder = Instance.new("Folder")
	folder.Name = "Remotes"
	for _, list in { RemoteNames.ClientToServer, RemoteNames.ServerToClient } do
		for _, name in list do
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
			remotes[name] = remote
		end
	end
	folder.Parent = ReplicatedStorage
end

function NetService:Start()
	Players.PlayerRemoving:Connect(function(player)
		for _, limiter in limiters do
			limiter:Forget(player)
		end
	end)
end

-- Requests over the limit are dropped silently.
function NetService:On(name: string, limit: Limit, handler: (player: Player, ...unknown) -> ())
	local limiter = RateLimiter.new(limit.PerSecond, limit.Burst)
	table.insert(limiters, limiter)
	getRemote(name).OnServerEvent:Connect(function(player: Player, ...: unknown)
		if limiter:Allow(player) then
			handler(player, ...)
		end
	end)
end

function NetService:FireClient(name: string, player: Player, ...: any)
	getRemote(name):FireClient(player, ...)
end

function NetService:FireAllClients(name: string, ...: any)
	getRemote(name):FireAllClients(...)
end

return NetService
