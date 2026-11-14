--!strict
--[[
	Camcorder — the tool the job is done with. Raise it (hold right mouse, or
	toggle with Q), get the subject in the brackets, and click. The flash lights
	the whole corridor for an instant — which is how you get the shot, and how
	it finds out where you are standing.
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sfx = require(ReplicatedStorage.Shared.Sfx)
local Hud = require(script.Parent.Parent.UI.Hud)
local Movement = require(script.Parent.Movement)

local Camcorder = {}

local player = Players.LocalPlayer
local toggled = false
local held = false
local lastShot = 0
local shutter: Sound

local function usable(): boolean
	return player:GetAttribute("InShift") == true and not player:GetAttribute("Hidden") and not player:GetAttribute("Grabbed")
end

local function shoot()
	local camera = workspace.CurrentCamera
	if not camera or not usable() or not Hud.CameraUp then
		return
	end
	if os.clock() - lastShot < Config.Player.PhotoCooldown then
		return
	end
	lastShot = os.clock()
	shutter:Play()
	Remotes.ToServer:FireServer("Photo", camera.CFrame.LookVector)
end

function Camcorder.init()
	shutter = Sfx.make(player:WaitForChild("PlayerGui"), "Shutter", { Volume = 0.8 })

	ContextActionService:BindAction("HS_Camera", function(_, state)
		if state == Enum.UserInputState.Begin then
			toggled = not toggled
		end
		return Enum.ContextActionResult.Pass
	end, true, Enum.KeyCode.Q, Enum.KeyCode.ButtonL1)
	ContextActionService:SetTitle("HS_Camera", "CAM")
	ContextActionService:SetPosition("HS_Camera", UDim2.new(1, -230, 1, -170))

	UserInputService.InputBegan:Connect(function(input, processed)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			held = true
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 and not processed then
			shoot()
		elseif input.KeyCode == Enum.KeyCode.ButtonR2 then
			shoot()
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			held = false
		end
	end)
	-- the on-screen PHOTOGRAPH button (touch) asks through an attribute
	player:GetAttributeChangedSignal("ShootRequest"):Connect(shoot)

	RunService.RenderStepped:Connect(function(dt)
		if not usable() then
			toggled = false
			held = false
		end
		Hud.CameraUp = toggled or held
		local target = if Hud.CameraUp then -20 else 0
		Movement.Zoom += (target - Movement.Zoom) * math.min(1, dt * 10)
	end)
end

return Camcorder
