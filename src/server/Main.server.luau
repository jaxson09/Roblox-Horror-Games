--!strict
--[[
	HOLLOW SIGNAL — server entry point.

	One place, two roles:
	  * Public servers are the LOBBY. Crews form in the circles; starting a lobby
	    teleports that crew to a private reserved server of this same place.
	  * Reserved servers are a MATCH. The crew goes straight down; when the shift
	    is over everyone is sent back to a public lobby.
	In Studio there is no teleporting, so a lobby starts its match in-process.
]]

local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Facility = require(script.Parent.World.Facility)
local Lobby = require(script.Parent.World.Lobby)
local Data = require(script.Parent.Services.Data)
local Parties = require(script.Parent.Services.Parties)
local Shift = require(script.Parent.Services.Shift)
local Store = require(script.Parent.Services.Store)

local isStudio = RunService:IsStudio()
local isMatch = game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0

-- Baseline night. Each client layers its own lobby/sublevel profile on top.
Lighting.ClockTime = 0.5
Lighting.Brightness = 0
Lighting.GlobalShadows = true
Lighting.Ambient = Color3.fromRGB(8, 10, 14)
Lighting.OutdoorAmbient = Color3.fromRGB(14, 18, 26)
Lighting.EnvironmentDiffuseScale = 0
Lighting.EnvironmentSpecularScale = 0
Lighting.FogColor = Color3.fromRGB(6, 8, 10)
Lighting.FogStart = 20
Lighting.FogEnd = 220

Data.init()
Store.init()

local world = Instance.new("Folder")
world.Name = "World"
world.Parent = workspace

local facility = Facility.build(world)
local lobby = Lobby.build(world)
Shift.init(facility, lobby)

local function teleportFailed(player: Player)
	Remotes.ToClient:FireClient(player, "TeleportFailed")
	Remotes.ToClient:FireClient(player, "Toast", "THE LIFT JAMMED. TRY AGAIN.", "bad")
end

-- A lobby was started (by its creator, or by the countdown).
local function launch(members: { Player }, settings: Parties.Settings)
	if isStudio or isMatch then
		Shift.begin(members, settings.Difficulty)
		return
	end
	for _, player in members do
		Remotes.ToClient:FireClient(player, "Teleporting")
	end
	local data = { Difficulty = settings.Difficulty, Part = settings.Part }
	-- a fresh private server for this crew, addressed by an id we choose
	local ok, err = pcall(function()
		local options = Instance.new("TeleportOptions")
		options.ReservedServerId = HttpService:GenerateGUID(false)
		options:SetTeleportData(data)
		TeleportService:TeleportAsync(game.PlaceId, members, options)
	end)
	if not ok then
		-- older route: ask Roblox to reserve a server, then send the crew to it
		warn("[Lobby] teleport by reserved id failed, trying an access code:", err)
		ok, err = pcall(function()
			local code = TeleportService:ReserveServer(game.PlaceId)
			TeleportService:TeleportToPrivateServer(game.PlaceId, code, members, nil, data)
		end)
	end
	if not ok then
		warn("[Lobby] teleport failed:", err)
		for _, player in members do
			teleportFailed(player)
		end
	end
end

-- Roblox reports per-player teleport failures here, after the call above has returned.
TeleportService.TeleportInitFailed:Connect(function(player: Player)
	teleportFailed(player)
end)

Parties.init(lobby.Pads, launch, Shift.inLobby)

if isMatch then
	local matchDifficulty = "Normal"
	local decided = false

	-- In a match the circles are the way back down for anyone who was taken.
	Parties.setReentry(function(player)
		Shift.begin({ player }, matchDifficulty)
	end)

	local function arrive(player: Player)
		if not decided then
			decided = true
			local data = player:GetJoinData().TeleportData
			if type(data) == "table" then
				local chosen = (data :: { [string]: any }).Difficulty
				if type(chosen) == "string" and Config.Difficulties[chosen] then
					matchDifficulty = chosen
				end
			end
		end
		if not player.Character then
			player.CharacterAdded:Wait()
		end
		-- passes decide hearts and break-frees: wait for them (but not forever) before going up
		local waited = 0
		while player.Parent and player:GetAttribute("PassesLoaded") ~= true and waited < 8 do
			waited += task.wait(0.25)
		end
		task.wait(1)
		if player.Parent then
			Shift.begin({ player }, matchDifficulty)
		end
	end
	Players.PlayerAdded:Connect(arrive)
	for _, player in Players:GetPlayers() do
		task.spawn(arrive, player)
	end

	Shift.onEnded(function()
		local everyone = Players:GetPlayers()
		if #everyone > 0 then
			pcall(function()
				TeleportService:TeleportAsync(game.PlaceId, everyone)
			end)
		end
	end)
end

workspace:SetAttribute("HS_Mode", if isMatch then "Match" else "Lobby")
workspace:SetAttribute("HS_Ready", true)
print(`[{Config.GameName}] v{Config.Version} ready ({if isMatch then "match" else "lobby"} server) — {#lobby.Pads} lobby circles, {#facility.Lockers} lockers, {#facility.Stations} tube stations, {#facility.Beds} recovery beds`)
