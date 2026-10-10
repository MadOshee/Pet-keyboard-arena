--!strict
-- Party window and invite popup (docs/design.md 4.3 "Группы"). Lists the
-- players on the server (friends first) with INVITE buttons, shows your
-- party with LEAVE, and pops up incoming invites with ACCEPT / DECLINE.
-- The server owns the party; this only sends user ids.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Strings = require(ReplicatedStorage.Shared.Config.Strings)
local Types = require(ReplicatedStorage.Shared.Types)
local Widgets = require(script.Parent.Parent.UI.Widgets)
local ClientNet = require(script.Parent.Parent.Util.ClientNet)

local player = Players.LocalPlayer

local MAX_SIZE = 3
local ROW_HEIGHT = 0.11

local PartyController = {}

local window: Frame
local titleLabel: TextLabel
local membersLabel: TextLabel
local leaveButton: TextButton
local list: ScrollingFrame
local emptyLabel: TextLabel
local noteLabel: TextLabel
local popup: Frame
local popupLabel: TextLabel

local party: Types.PartyPayload =
	{ Members = { player.UserId }, Leader = player.UserId, Invites = {} }
local friends: { [number]: boolean } = {}
local popupInviter: number? = nil
local noteToken = 0

local function nameOf(userId: number): string
	local other = Players:GetPlayerByUserId(userId)
	return if other then other.DisplayName else tostring(userId)
end

local function showNote(text: string)
	noteToken += 1
	local token = noteToken
	noteLabel.Text = text
	task.delay(3, function()
		if token == noteToken then
			noteLabel.Text = ""
		end
	end)
end

local function refreshList()
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local others = {}
	for _, other in Players:GetPlayers() do
		if other ~= player and not table.find(party.Members, other.UserId) then
			table.insert(others, other)
		end
	end
	table.sort(others, function(a, b)
		local friendA, friendB = friends[a.UserId] == true, friends[b.UserId] == true
		if friendA ~= friendB then
			return friendA
		end
		return a.DisplayName < b.DisplayName
	end)

	for order, other in others do
		local row = Instance.new("Frame")
		row.Name = tostring(other.UserId)
		row.LayoutOrder = order
		row.Size = UDim2.fromScale(1, ROW_HEIGHT)
		row.BackgroundColor3 = Color3.fromRGB(52, 56, 80)
		row.Parent = list
		Widgets.Corner(row, 0.2)
		local name =
			Widgets.Label("Name", row, UDim2.fromScale(0.6, 0.8), UDim2.fromScale(0.03, 0.1))
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.Text = if friends[other.UserId]
			then `{other.DisplayName}  ({Strings.PartyFriend})`
			else other.DisplayName
		local invite = Widgets.Button(
			"Invite",
			row,
			UDim2.fromScale(0.3, 0.8),
			UDim2.fromScale(0.68, 0.1),
			Color3.fromRGB(64, 170, 90)
		)
		invite.Text = Strings.PartyInviteButton
		local userId = other.UserId
		invite.Activated:Connect(function()
			ClientNet.Fire("PartyInvite", userId)
			showNote(string.format(Strings.PartyInvited, nameOf(userId)))
		end)
	end
	emptyLabel.Visible = #others == 0
end

local function refreshParty()
	titleLabel.Text = string.format(Strings.PartyTitle, #party.Members, MAX_SIZE)
	local names = {}
	for _, userId in party.Members do
		local name = nameOf(userId)
		table.insert(
			names,
			if userId == party.Leader and #party.Members > 1
				then string.format(Strings.PartyLeader, name)
				else name
		)
	end
	membersLabel.Text = table.concat(names, ", ")
	leaveButton.Visible = #party.Members > 1
	refreshList()
end

local function refreshPopup()
	local first = party.Invites[1]
	popupInviter = first
	if first then
		popupLabel.Text = string.format(Strings.PartyInvitePopup, nameOf(first))
	end
	popup.Visible = first ~= nil
end

local function respond(accept: boolean)
	local inviter = popupInviter
	if inviter then
		ClientNet.Fire("PartyRespond", inviter, accept)
		popup.Visible = false
	end
end

local function cacheFriend(other: Player)
	if other == player then
		return
	end
	task.spawn(function()
		local ok, isFriend = pcall(function()
			return player:IsFriendsWith(other.UserId)
		end)
		if ok and isFriend then
			friends[other.UserId] = true
			if window.Visible then
				refreshList()
			end
		end
	end)
end

local function build()
	local gui = Widgets.ScreenGui("Party", 3)

	local toggle = Widgets.Button(
		"PartyButton",
		gui,
		UDim2.fromScale(0.1, 0.08),
		UDim2.fromScale(0.015, 0.35),
		Color3.fromRGB(60, 140, 220)
	)
	toggle.Text = Strings.PartyButton
	Widgets.AspectRatio(toggle, 2.2)

	window = Widgets.Panel("Window", gui, UDim2.fromScale(0.42, 0.62), UDim2.fromScale(0.5, 0.5))
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.Visible = false
	Widgets.AspectRatio(window, 1)

	titleLabel =
		Widgets.Label("Title", window, UDim2.fromScale(0.7, 0.08), UDim2.fromScale(0.04, 0.03))
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	local close = Widgets.Button(
		"Close",
		window,
		UDim2.fromScale(0.1, 0.09),
		UDim2.fromScale(0.87, 0.025),
		Color3.fromRGB(200, 70, 70)
	)
	close.Text = "X"
	membersLabel =
		Widgets.Label("Members", window, UDim2.fromScale(0.62, 0.07), UDim2.fromScale(0.04, 0.13))
	membersLabel.TextXAlignment = Enum.TextXAlignment.Left
	membersLabel.TextColor3 = Color3.fromRGB(200, 220, 255)
	leaveButton = Widgets.Button(
		"Leave",
		window,
		UDim2.fromScale(0.28, 0.08),
		UDim2.fromScale(0.68, 0.125),
		Color3.fromRGB(200, 90, 70)
	)
	leaveButton.Text = Strings.PartyLeave

	local header = Widgets.Label(
		"PlayersHeader",
		window,
		UDim2.fromScale(0.92, 0.06),
		UDim2.fromScale(0.04, 0.24)
	)
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.Text = Strings.PartyPlayers

	list = Instance.new("ScrollingFrame")
	list.Name = "List"
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Size = UDim2.fromScale(0.92, 0.58)
	list.Position = UDim2.fromScale(0.04, 0.31)
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.ScrollBarThickness = 8
	list.Parent = window
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0.015, 0)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	emptyLabel =
		Widgets.Label("Empty", window, UDim2.fromScale(0.84, 0.07), UDim2.fromScale(0.08, 0.5))
	emptyLabel.Text = Strings.PartyNobody
	noteLabel =
		Widgets.Label("Note", window, UDim2.fromScale(0.92, 0.06), UDim2.fromScale(0.04, 0.91))
	noteLabel.TextColor3 = Color3.fromRGB(140, 230, 140)

	popup = Widgets.Panel("Invite", gui, UDim2.fromScale(0.36, 0.16), UDim2.fromScale(0.5, 0.2))
	popup.AnchorPoint = Vector2.new(0.5, 0)
	popup.Visible = false
	Widgets.AspectRatio(popup, 3.2)
	popupLabel =
		Widgets.Label("Text", popup, UDim2.fromScale(0.92, 0.42), UDim2.fromScale(0.04, 0.06))
	local accept = Widgets.Button(
		"Accept",
		popup,
		UDim2.fromScale(0.42, 0.38),
		UDim2.fromScale(0.05, 0.56),
		Color3.fromRGB(64, 170, 90)
	)
	accept.Text = Strings.Accept
	local decline = Widgets.Button(
		"Decline",
		popup,
		UDim2.fromScale(0.42, 0.38),
		UDim2.fromScale(0.53, 0.56),
		Color3.fromRGB(150, 90, 90)
	)
	decline.Text = Strings.Decline

	toggle.Activated:Connect(function()
		window.Visible = not window.Visible
		if window.Visible then
			refreshParty()
		end
	end)
	close.Activated:Connect(function()
		window.Visible = false
	end)
	leaveButton.Activated:Connect(function()
		ClientNet.Fire("PartyLeave")
	end)
	accept.Activated:Connect(function()
		respond(true)
	end)
	decline.Activated:Connect(function()
		respond(false)
	end)

	gui.Parent = player:WaitForChild("PlayerGui")
end

function PartyController:Init()
	build()
end

function PartyController:Start()
	ClientNet.On("PartyUpdate", function(payload: Types.PartyPayload)
		party = payload
		refreshPopup()
		if window.Visible then
			refreshParty()
		end
	end)
	Players.PlayerAdded:Connect(function(other)
		cacheFriend(other)
		if window.Visible then
			refreshList()
		end
	end)
	Players.PlayerRemoving:Connect(function()
		if window.Visible then
			task.defer(refreshList)
		end
	end)
	for _, other in Players:GetPlayers() do
		cacheFriend(other)
	end
	refreshParty()
end

return PartyController
