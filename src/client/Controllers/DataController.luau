--!strict
-- Read-only mirror of the local player's profile, fed by DataSync.
-- UI reads from here; nothing on the client can change real data.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local Types = require(ReplicatedStorage.Shared.Types)
local ClientNet = require(script.Parent.Parent.Util.ClientNet)

local DataController = {}

DataController.Changed = Signal.new() :: Signal.Signal<Types.Profile>

local profile: Types.Profile? = nil

function DataController:Init() end

function DataController:Start()
	ClientNet.On("DataSync", function(data: Types.Profile)
		profile = data
		DataController.Changed:Fire(data)
	end)
end

function DataController:Get(): Types.Profile?
	return profile
end

return DataController
