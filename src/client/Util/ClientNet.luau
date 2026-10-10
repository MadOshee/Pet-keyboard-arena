--!strict
-- Client access to the RemoteEvents the server creates from RemoteNames.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")

local ClientNet = {}

local function getRemote(name: string): RemoteEvent
	local remote = remotesFolder:WaitForChild(name)
	assert(remote:IsA("RemoteEvent"), `{name} is not a RemoteEvent`)
	return remote
end

function ClientNet.Fire(name: string, ...: any)
	getRemote(name):FireServer(...)
end

function ClientNet.On(name: string, handler: (...any) -> ()): RBXScriptConnection
	return getRemote(name).OnClientEvent:Connect(handler)
end

return ClientNet
