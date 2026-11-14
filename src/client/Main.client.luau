--!strict
--[[ HOLLOW SIGNAL — client entry point: starts the controllers and plays out server-driven moments. ]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sfx = require(ReplicatedStorage.Shared.Sfx)
local Hud = require(script.Parent.UI.Hud)
local Theme = require(script.Parent.UI.Theme)
local Vhs = require(script.Parent.UI.Vhs)
local Atmosphere = require(script.Parent.Controllers.Atmosphere)
local FawnAnimator = require(script.Parent.Controllers.FawnAnimator)
local Flashlight = require(script.Parent.Controllers.Flashlight)
local Movement = require(script.Parent.Controllers.Movement)
local Prompts = require(script.Parent.Controllers.Prompts)

local player = Players.LocalPlayer
local rng = Random.new()

-- wait for the server to finish building the world
while not workspace:GetAttribute("HS_Ready") do
	task.wait(0.1)
end

for _, core in { Enum.CoreGuiType.Health, Enum.CoreGuiType.Backpack, Enum.CoreGuiType.EmotesMenu, Enum.CoreGuiType.PlayerList } do
	pcall(function()
		StarterGui:SetCoreGuiEnabled(core, false)
	end)
end

Vhs.init()
Hud.init()
Atmosphere.init()
Movement.init()
Flashlight.init()
FawnAnimator.init()
Prompts.init()

local stings = Instance.new("Folder")
stings.Name = "HS_Stings"
stings.Parent = player:WaitForChild("PlayerGui")
local jumpscareSound = Sfx.make(stings, "Jumpscare", { Volume = 1.4 })
local howlSound = Sfx.make(stings, "FawnHowl1", { Volume = 1 })
local stingSound = Sfx.make(stings, "Sting", { Volume = 0.9 })
local elevatorSound = Sfx.make(stings, "Elevator", { Volume = 0.9 })

----------------------------------------------------------------------------
-- Camera shake (shared by every scare)
----------------------------------------------------------------------------
local shakeAmount = 0
local shakeUntil = 0

local function shake(amount: number, seconds: number, position: Vector3?)
	if position then
		local camera = workspace.CurrentCamera
		local distance = if camera then (camera.CFrame.Position - position).Magnitude else 999
		amount *= math.clamp(1 - distance / 90, 0, 1)
	end
	if amount > 0.01 then
		shakeAmount = math.max(shakeAmount, amount)
		shakeUntil = math.max(shakeUntil, os.clock() + seconds)
	end
end

RunService.RenderStepped:Connect(function()
	if os.clock() < shakeUntil then
		local a = shakeAmount * (if Vhs.ReducedFlashing then 0.4 else 1)
		Movement.Shake = Vector3.new(rng:NextNumber(-a, a), rng:NextNumber(-a, a), 0) * 0.5
	elseif shakeAmount > 0 then
		shakeAmount = 0
		Movement.Shake = Vector3.zero
	end
end)

----------------------------------------------------------------------------
-- Set pieces
----------------------------------------------------------------------------
local function jumpscare(model: Instance?)
	local camera = workspace.CurrentCamera
	local head = if model then model:FindFirstChild("Skull") :: BasePart? else nil
	jumpscareSound:Play()
	Vhs.burst(0.9, 0.3)
	shake(1.4, 1.6)
	local connection: RBXScriptConnection? = nil
	if camera and head then
		camera.CameraType = Enum.CameraType.Scriptable
		local start = os.clock()
		connection = RunService.RenderStepped:Connect(function()
			local t = os.clock() - start
			local face = head.CFrame
			-- start an arm's length from its face and get dragged in
			local eye = (face * CFrame.new(0.2, -0.3, -5.2 + math.min(t / 0.35, 1) * 2.6)).Position
			local jitter = if Vhs.ReducedFlashing then 0.01 else 0.05
			camera.CFrame = CFrame.lookAt(eye, face.Position) * CFrame.Angles(rng:NextNumber(-jitter, jitter), rng:NextNumber(-jitter, jitter), rng:NextNumber(-0.12, 0.12))
			camera.FieldOfView = 70 - 22 * math.min(t / 0.3, 1)
		end)
	end
	task.wait(1.15)
	local overlay = Theme.screen("HS_Taken", 86)
	local word = Theme.label(overlay, "Word", UDim2.new(1, 0, 0, 120), UDim2.new(0, 0, 0.4, 0), Theme.Fonts.Horror, 96, Config.Colors.Dread, "IT HAS YOUR VOICE")
	word.TextXAlignment = Enum.TextXAlignment.Center
	Vhs.burst(1, 0.5)
	task.wait(0.5)
	Vhs.cut(true)
	task.wait(0.9)
	if connection then
		connection:Disconnect()
	end
	if camera then
		camera.CameraType = Enum.CameraType.Custom
		camera.FieldOfView = 70
	end
	TweenService:Create(word, TweenInfo.new(0.8), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Vhs.fade(false, 1.4)
	task.wait(1)
	overlay:Destroy()
end

local function elevator(seconds: number)
	Vhs.fade(true, 1)
	elevatorSound:Play()
	shake(0.18, seconds)
	task.wait(seconds)
	Vhs.fade(false, 1.6)
	Hud.locationCard("SUBLEVEL 1", "MARROW CREEK RELAY  —  02:14 AM")
end

local handlers: { [string]: (...any) -> () } = {
	Toast = function(text: string, kind: string?)
		Hud.toast(text, kind)
	end,
	Subtitle = function(text: string, glitch: boolean?)
		Hud.subtitle(text, glitch)
	end,
	Tape = function(index: number, title: string, body: string)
		Hud.showTape(index, title, body)
	end,
	Note = function(id: string)
		Hud.showNote(id)
	end,
	Results = function(results: Hud.Results)
		task.delay(if results.Outcome == "Escaped" then 0.5 else 3.2, Hud.showResults, results)
	end,
	Flicker = function(seconds: number)
		Atmosphere.flicker(seconds)
	end,
	Shake = function(amount: number, seconds: number, position: Vector3?)
		shake(amount, seconds, position)
	end,
	Elevator = function(seconds: number)
		elevator(seconds)
	end,
	Jumpscare = function(model: Instance?)
		jumpscare(model)
	end,
	ScareAll = function(buyer: string)
		Atmosphere.flicker(3)
		Vhs.burst(0.7, 0.6)
		shake(0.8, 1.4)
		howlSound:Play()
		Hud.subtitle(`{buyer} CRANKED THE SIREN. SOMETHING ANSWERED.`, true)
	end,
	DecoyReveal = function(position: Vector3)
		local camera = workspace.CurrentCamera
		if camera and (camera.CFrame.Position - position).Magnitude < 70 then
			stingSound:Play()
			Vhs.burst(0.8, 0.45)
			shake(0.7, 0.6)
			Hud.subtitle("THAT WAS NOT YOUR CREWMATE.", true)
		end
	end,
}

Remotes.ToClient.OnClientEvent:Connect(function(name: string, ...: any)
	local handler = handlers[name]
	if handler then
		task.spawn(handler, ...)
	end
end)

-- intro: full premise on a first visit, a short title card afterwards
task.spawn(function()
	local waited = 0
	while player:GetAttribute("SeenIntro") == nil and waited < 4 do
		waited += task.wait(0.1)
	end
	local first = player:GetAttribute("SeenIntro") ~= true
	Hud.intro(first, function()
		if first then
			Remotes.ToServer:FireServer("IntroSeen")
		end
	end)
end)
