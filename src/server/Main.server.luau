--!strict
--[[ HOLLOW SIGNAL — server entry point. Builds the world, then starts the systems. ]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Facility = require(script.Parent.World.Facility)
local Lobby = require(script.Parent.World.Lobby)
local Data = require(script.Parent.Services.Data)
local Shift = require(script.Parent.Services.Shift)
local Store = require(script.Parent.Services.Store)

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

workspace:SetAttribute("HS_Ready", true)
print(`[{Config.GameName}] v{Config.Version} ready — {#facility.Lockers} lockers, {#facility.Cages} cages, {#facility.Effigies} effigies, {#facility.Fixtures} lights`)
