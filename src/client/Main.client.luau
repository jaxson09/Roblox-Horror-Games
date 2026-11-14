--!strict
--[[ HOLLOW SIGNAL — client entry point: starts the controllers and plays out server-driven moments. ]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local Lore = require(ReplicatedStorage.Shared.Lore)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sfx = require(ReplicatedStorage.Shared.Sfx)
local Hud = require(script.Parent.UI.Hud)
local PartyUi = require(script.Parent.UI.PartyUi)
local Vhs = require(script.Parent.UI.Vhs)
local Atmosphere = require(script.Parent.Controllers.Atmosphere)
local Camcorder = require(script.Parent.Controllers.Camcorder)
local Chat = require(script.Parent.Controllers.Chat)
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
Camcorder.init()
FawnAnimator.init()
Prompts.init()
PartyUi.init()
Chat.init()

local stings = Instance.new("Folder")
stings.Name = "HS_Stings"
stings.Parent = player:WaitForChild("PlayerGui")
local jumpscareSound = Sfx.make(stings, "Jumpscare", { Volume = 1.3 })
local grabSound = Sfx.make(stings, "Grab", { Volume = 1 })
local howlSound = Sfx.make(stings, "FawnHowl1", { Volume = 1 })
local stingSound = Sfx.make(stings, "Sting", { Volume = 0.9 })
local elevatorSound = Sfx.make(stings, "Elevator", { Volume = 0.9 })
local powerSound = Sfx.make(stings, "PowerDown", { Volume = 1 })
local gaspSound = Sfx.make(stings, "Breath", { Volume = 0.8 })

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
-- The grab: it lifts you to its face and says something. You get a few seconds.
----------------------------------------------------------------------------
local grabConnection: RBXScriptConnection? = nil

local function releaseCamera()
	if grabConnection then
		grabConnection:Disconnect()
		grabConnection = nil
	end
	local camera = workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Custom
		camera.FieldOfView = 70
	end
end

local function grab(model: Instance?, line: string)
	local camera = workspace.CurrentCamera
	local head = if model then model:FindFirstChild("Skull") :: BasePart? else nil
	jumpscareSound:Play()
	grabSound:Play()
	Vhs.burst(0.85, 0.3)
	shake(1.2, 0.8)
	releaseCamera()
	if camera and head then
		camera.CameraType = Enum.CameraType.Scriptable
		local start = os.clock()
		grabConnection = RunService.RenderStepped:Connect(function()
			local t = os.clock() - start
			local face = head.CFrame
			-- an arm's length from the mask, drifting closer the whole time
			local eye = (face * CFrame.new(0.25, -0.35, -5.4 + math.min(t / 0.4, 1) * 2.2 + math.min(t / 3.4, 1) * 1.1)).Position
			local jitter = if Vhs.ReducedFlashing then 0.004 else 0.014
			camera.CFrame = CFrame.lookAt(eye, face.Position) * CFrame.Angles(rng:NextNumber(-jitter, jitter), rng:NextNumber(-jitter, jitter), math.sin(t * 2.2) * 0.05)
			camera.FieldOfView = 70 - 20 * math.min(t / 0.35, 1)
		end)
	end
	task.delay(0.7, Hud.subtitle, line, false)
end

local function grabEnd(brokeFree: boolean)
	if brokeFree then
		releaseCamera()
		shake(0.9, 0.5)
		gaspSound:Play()
		return
	end
	-- it puts you to bed
	Vhs.burst(1, 0.4)
	Vhs.cut(true)
	releaseCamera()
	task.wait(1.5)
	gaspSound:Play()
	Vhs.fade(false, 1.8)
end

----------------------------------------------------------------------------
-- Other set pieces
----------------------------------------------------------------------------
local function elevator(seconds: number, briefing: boolean?)
	Vhs.fade(true, 1)
	elevatorSound:Play()
	shake(0.15, seconds)
	task.wait(1.1)
	if briefing then
		Hud.briefing()
	end
	task.wait(math.max(0, seconds - 1.1))
	Vhs.fade(false, 1.6)
	Hud.locationCard(Lore.Location, Lore.CaseNumber .. "  —  02:14 AM")
end

-- A camera flash somewhere on the ward: a hard white light for a blink.
local function flash(position: Vector3, mine: boolean)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.Transparency = 1
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.Position = position + Vector3.new(0, 1.5, 0)
	part.Parent = workspace
	local light = Instance.new("PointLight")
	light.Range = 60
	light.Brightness = if Vhs.ReducedFlashing then 2 else 8
	light.Color = Color3.fromRGB(235, 240, 255)
	light.Shadows = true
	light.Parent = part
	if mine then
		Vhs.flash(0.45)
	end
	task.delay(0.14, function()
		part:Destroy()
	end)
end

local handlers: { [string]: (...any) -> () } = {
	Toast = function(text: string, kind: string?)
		Hud.toast(text, kind)
	end,
	Banner = function(headline: string, sub: string?, tone: string?)
		Hud.banner(headline, sub, tone)
	end,
	Subtitle = function(text: string, glitch: boolean?)
		Hud.subtitle(text, glitch)
	end,
	Asked = function(line: string, seconds: number)
		Hud.asked(line, seconds)
	end,
	Note = function(id: string)
		Hud.showNote(id)
	end,
	Results = function(results: Hud.Results)
		task.delay(if results.Outcome == "Escaped" then 0.5 else 3.4, Hud.showResults, results)
	end,
	Flicker = function(seconds: number)
		Atmosphere.flicker(seconds)
	end,
	PowerOut = function()
		powerSound:Play()
		Atmosphere.flicker(1.6)
		Atmosphere.PowerOut = true
		shake(0.4, 0.8)
	end,
	Shake = function(amount: number, seconds: number, position: Vector3?)
		shake(amount, seconds, position)
	end,
	Elevator = function(seconds: number, briefing: boolean?)
		elevator(seconds, briefing)
	end,
	Grab = function(model: Instance?, line: string)
		grab(model, line)
	end,
	GrabEnd = function(brokeFree: boolean)
		grabEnd(brokeFree)
	end,
	Flash = function(position: Vector3, mine: boolean)
		flash(position, mine)
	end,
	ScareAll = function(buyer: string)
		Atmosphere.flicker(3)
		Vhs.burst(0.7, 0.6)
		shake(0.8, 1.4)
		howlSound:Play()
		Hud.banner("CODE BLUE. CODE BLUE.", string.upper(buyer) .. " paged the building. Something answered.", "bad")
	end,
	Teleporting = function()
		elevatorSound:Play()
		Vhs.fade(true, 1.2)
		Hud.toast("GOING UP...", "info")
		-- if the teleport never happens, never leave the player on a black screen
		task.delay(15, Vhs.fade, false, 1)
	end,
	TeleportFailed = function()
		Vhs.fade(false, 0.6)
	end,
	DecoyReveal = function(position: Vector3)
		local camera = workspace.CurrentCamera
		if camera and (camera.CFrame.Position - position).Magnitude < 70 then
			stingSound:Play()
			Vhs.burst(0.8, 0.45)
			shake(0.7, 0.6)
			Hud.banner("THAT WAS NOT YOUR CREWMATE.", "", "bad")
		end
	end,
}

Remotes.ToClient.OnClientEvent:Connect(function(name: string, ...: any)
	local handler = handlers[name]
	if handler then
		task.spawn(handler, ...)
	end
end)

----------------------------------------------------------------------------
-- Event lines driven by what the server knows about you
----------------------------------------------------------------------------
local wasHunted = false
player:GetAttributeChangedSignal("Hunted"):Connect(function()
	local hunted = player:GetAttribute("Hunted") == true
	if hunted and not wasHunted then
		Hud.banner(Lore.Banners.Sees[1], Lore.Banners.Sees[2], "bad")
	elseif wasHunted and not hunted and player:GetAttribute("InShift") and not player:GetAttribute("Grabbed") then
		Hud.banner(Lore.Banners.Lost[1], Lore.Banners.Lost[2], "info")
	end
	wasHunted = hunted
end)
player:GetAttributeChangedSignal("HeardAt"):Connect(function()
	if player:GetAttribute("InShift") and not player:GetAttribute("Hunted") then
		Hud.banner(Lore.Banners.Hears[1], Lore.Banners.Hears[2], "bad")
	end
end)

-- However a grab ends (even by lockdown, or leaving), the camera comes back.
player:GetAttributeChangedSignal("Grabbed"):Connect(function()
	if player:GetAttribute("Grabbed") ~= true then
		releaseCamera()
	end
end)
player:GetAttributeChangedSignal("InShift"):Connect(function()
	if player:GetAttribute("InShift") ~= true then
		releaseCamera()
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
