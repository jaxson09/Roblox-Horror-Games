--!strict
--[[
	PartyUi — the screen that opens when you stand in a lobby circle.

	  Setting up:  crew size, difficulty, chapter (Parts 2 and 3 show as
	               IN DEVELOPMENT), CREATE LOBBY.
	  In a lobby:  who is in it, the countdown when it is full, START MATCH for
	               the creator.
	  Always:      LEAVE at the bottom, which takes you out of the circle.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sfx = require(ReplicatedStorage.Shared.Sfx)
local Theme = require(script.Parent.Theme)

local PartyUi = {}

local player = Players.LocalPlayer
local C = Config.Colors
local F = Theme.Fonts

local selectedPlayers = Config.Lobby.DefaultPlayers
local selectedDifficulty = "Normal"
local selectedPart = 1

local function style(button: TextButton, selected: boolean, enabled: boolean)
	button.BackgroundColor3 = if selected then C.Amber else Color3.fromRGB(12, 12, 12)
	button.BackgroundTransparency = if selected then 0 else 0.35
	button.TextColor3 = if selected then Color3.new(0, 0, 0) elseif enabled then C.Osd else Color3.fromRGB(110, 110, 105)
	button.AutoButtonColor = enabled
	button.Active = enabled
end

local function header(parent: Instance, text: string, y: number): TextLabel
	return Theme.label(parent, "Header", UDim2.new(1, 0, 0, 16), UDim2.fromOffset(0, y), F.Osd, 10, C.Amber, text)
end

function PartyUi.init()
	local gui = Theme.screen("HS_Party", 70)
	gui.Enabled = false
	local click = Sfx.make(gui, "Blip", { Volume = 0.35 })

	local panel = Theme.frame(gui, "Panel", UDim2.fromOffset(460, 486), UDim2.fromScale(0.5, 0.5), Color3.fromRGB(8, 9, 9), 0.08)
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	Theme.fit(panel, 640)
	local stroke = Instance.new("UIStroke")
	stroke.Color = C.Osd
	stroke.Transparency = 0.5
	stroke.Parent = panel
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 20)
	pad.PaddingRight = UDim.new(0, 20)
	pad.PaddingTop = UDim.new(0, 18)
	pad.PaddingBottom = UDim.new(0, 18)
	pad.Parent = panel

	local title = Theme.label(panel, "Title", UDim2.new(1, 0, 0, 22), UDim2.fromOffset(0, 0), F.Osd, 16, C.Osd, "CREATE LOBBY")

	----------------------------------------------------------------------
	-- setting up
	----------------------------------------------------------------------
	local config = Theme.frame(panel, "Config", UDim2.new(1, 0, 0, 360), UDim2.fromOffset(0, 36), Color3.new(0, 0, 0), 1)
	header(config, "CREW SIZE", 0)
	local sizeButtons: { [number]: TextButton } = {}
	for i, count in Config.Lobby.PlayerOptions do
		local button = Theme.button(config, "Size" .. count, UDim2.fromOffset(72, 34), UDim2.fromOffset((i - 1) * 84, 20), tostring(count))
		sizeButtons[count] = button
		button.MouseButton1Click:Connect(function()
			selectedPlayers = count
			click:Play()
		end)
	end

	header(config, "DIFFICULTY", 70)
	local difficultyButtons: { [string]: TextButton } = {}
	for i, key in Config.DifficultyOrder do
		local button = Theme.button(config, "Diff" .. key, UDim2.fromOffset(132, 34), UDim2.fromOffset((i - 1) * 144, 90), Config.Difficulties[key].Label)
		difficultyButtons[key] = button
		button.MouseButton1Click:Connect(function()
			selectedDifficulty = key
			click:Play()
		end)
	end
	local blurb = Theme.label(config, "Blurb", UDim2.new(1, 0, 0, 32), UDim2.fromOffset(0, 130), F.Mono, 13, C.Osd, "")

	header(config, "CHAPTER", 172)
	local partButtons: { TextButton } = {}
	for i, part in Config.Parts do
		local button = Theme.button(config, "Part" .. i, UDim2.new(1, 0, 0, 34), UDim2.fromOffset(0, 192 + (i - 1) * 40), `{part.Name}  —  {part.Title}`)
		partButtons[i] = button
		button.MouseButton1Click:Connect(function()
			if part.Available then
				selectedPart = i
				click:Play()
			end
		end)
	end
	local create = Theme.button(config, "Create", UDim2.new(1, 0, 0, 40), UDim2.fromOffset(0, 320), "CREATE LOBBY")
	create.TextSize = 14
	style(create, true, true)
	create.MouseButton1Click:Connect(function()
		click:Play()
		Remotes.ToServer:FireServer("PartyCreate", selectedPlayers, selectedDifficulty, selectedPart)
	end)

	----------------------------------------------------------------------
	-- in a lobby
	----------------------------------------------------------------------
	local lobby = Theme.frame(panel, "Lobby", UDim2.new(1, 0, 0, 360), UDim2.fromOffset(0, 36), Color3.new(0, 0, 0), 1)
	local info = Theme.label(lobby, "Info", UDim2.new(1, 0, 0, 36), UDim2.fromOffset(0, 0), F.Mono, 14, C.Osd, "")
	header(lobby, "CREW", 46)
	local members = Theme.label(lobby, "Members", UDim2.new(1, 0, 0, 170), UDim2.fromOffset(0, 66), F.MonoBold, 17, C.Osd, "")
	members.LineHeight = 1.2
	local status = Theme.label(lobby, "Status", UDim2.new(1, 0, 0, 54), UDim2.fromOffset(0, 248), F.Osd, 14, C.Amber, "")
	status.TextXAlignment = Enum.TextXAlignment.Center
	status.TextYAlignment = Enum.TextYAlignment.Center
	local start = Theme.button(lobby, "Start", UDim2.new(1, 0, 0, 40), UDim2.fromOffset(0, 320), "START MATCH")
	start.TextSize = 14
	style(start, true, true)
	start.MouseButton1Click:Connect(function()
		click:Play()
		Remotes.ToServer:FireServer("PartyStart")
	end)

	-- always at the bottom: takes you out of the circle
	local leave = Theme.button(panel, "Leave", UDim2.new(1, 0, 0, 36), UDim2.new(0, 0, 1, -36), "LEAVE")
	leave.Modal = true
	leave.MouseButton1Click:Connect(function()
		click:Play()
		Remotes.ToServer:FireServer("PartyLeave")
	end)

	local function findPad(index: number): Instance?
		local world = workspace:FindFirstChild("World")
		local lobbyFolder = world and world:FindFirstChild("Lobby")
		local hall = lobbyFolder and lobbyFolder:FindFirstChild("Hall")
		return if hall then hall:FindFirstChild("Pad" .. index) else nil
	end

	local function text(instance: Instance, name: string): string
		local value = instance:GetAttribute(name)
		return if type(value) == "string" then value else ""
	end

	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.1 then
			return
		end
		acc = 0
		local role = player:GetAttribute("PartyRole")
		local disc = findPad(Theme.num(player, "PartyPad", 0))
		if type(role) ~= "string" or not disc then
			gui.Enabled = false
			return
		end
		gui.Enabled = true
		config.Visible = role == "Config"
		lobby.Visible = role ~= "Config"

		if role == "Config" then
			title.Text = "CREATE LOBBY"
			for count, button in sizeButtons do
				style(button, count == selectedPlayers, true)
			end
			for key, button in difficultyButtons do
				style(button, key == selectedDifficulty, true)
			end
			blurb.Text = Config.Difficulties[selectedDifficulty].Blurb
			for i, button in partButtons do
				style(button, i == selectedPart, Config.Parts[i].Available)
			end
			return
		end

		local hostName = text(disc, "HostName")
		local count = Theme.num(disc, "Count", 1)
		local max = Theme.num(disc, "Max", 1)
		local countdown = Theme.num(disc, "Countdown", -1)
		local difficulty = Config.Difficulties[text(disc, "Difficulty")] or Config.Difficulties.Normal
		local part = Config.Parts[Theme.num(disc, "PartNo", 1)] or Config.Parts[1]
		title.Text = string.upper(hostName) .. "'S LOBBY"
		info.Text = `{part.Name} — {part.Title}\n{difficulty.Label}  ·  UP TO {max} PLAYERS`
		members.Text = text(disc, "MemberNames")
		if countdown >= 0 then
			status.Text = `LOBBY FULL — STARTING IN {countdown}`
		elseif role == "Host" then
			status.Text = `{count}/{max} CREW — START WHEN READY`
		else
			status.Text = `{count}/{max} CREW — WAITING FOR {string.upper(hostName)}`
		end
		start.Visible = role == "Host"
	end)
end

return PartyUi
