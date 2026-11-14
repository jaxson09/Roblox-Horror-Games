--!strict
--[[
	Movement — walk / sprint / crouch with stamina, first-person lock below
	ground, head bob and FOV kick. Speed is what HUSH hears, so the choice
	between walking and running is the whole game.
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Hud = require(script.Parent.Parent.UI.Hud)
local Theme = require(script.Parent.Parent.UI.Theme)

local Movement = {}

local player = Players.LocalPlayer
local P = Config.Player

local wantSprint = false
local crouching = false
local sprinting = false
local exhausted = false
local stamina = P.StaminaMax
local lastSprintAt = 0
local bobPhase = 0
local fovKick = 0
Movement.Shake = Vector3.zero -- extra camera offset written by scares
Movement.Zoom = 0 -- field-of-view offset written by the camcorder

local function maxStamina(): number
	return P.StaminaMax * (if player:GetAttribute("Pass_Stamina") then P.StaminaPassMultiplier else 1)
end

local function setCrouch(on: boolean)
	if crouching ~= on then
		crouching = on
		Remotes.ToServer:FireServer("Crouch", on)
	end
end

function Movement.init()
	ContextActionService:BindAction("HS_Sprint", function(_, state)
		wantSprint = state == Enum.UserInputState.Begin
		return Enum.ContextActionResult.Pass
	end, true, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)
	Theme.touchButton("HS_Sprint", "RUN", "Run")
	ContextActionService:BindAction("HS_Crouch", function(_, state)
		if state == Enum.UserInputState.Begin then
			setCrouch(not crouching)
		end
		return Enum.ContextActionResult.Pass
	end, true, Enum.KeyCode.C, Enum.KeyCode.LeftControl, Enum.KeyCode.ButtonR3)
	Theme.touchButton("HS_Crouch", "DUCK", "Crouch")

	-- coming back up: pull the camera out of first person so the cursor is free again
	player:GetAttributeChangedSignal("InShift"):Connect(function()
		if not player:GetAttribute("InShift") then
			player.CameraMode = Enum.CameraMode.Classic
			player.CameraMinZoomDistance = 9
			task.delay(0.4, function()
				player.CameraMinZoomDistance = 0.5
			end)
		end
	end)

	RunService.RenderStepped:Connect(function(dt)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local camera = workspace.CurrentCamera
		if not humanoid or not camera then
			return
		end
		if humanoid:GetStateEnabled(Enum.HumanoidStateType.Jumping) then
			-- no jumping in this game; turning the state off here also hides the mobile jump button
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
		end
		local inShift = player:GetAttribute("InShift") == true
		player.CameraMode = if inShift then Enum.CameraMode.LockFirstPerson else Enum.CameraMode.Classic

		local busy = player:GetAttribute("Hidden") == true or player:GetAttribute("Grabbed") == true
		local moving = humanoid.MoveDirection.Magnitude > 0.1
		local cap = maxStamina()
		if not inShift then
			stamina = cap
			exhausted = false
			if crouching then
				setCrouch(false)
			end
		end

		local nowSprinting = inShift and wantSprint and moving and not crouching and not exhausted and not busy
		if nowSprinting then
			stamina = math.max(0, stamina - P.StaminaDrain * dt)
			lastSprintAt = os.clock()
			if stamina <= 0 then
				exhausted = true
			end
		elseif os.clock() - lastSprintAt > P.StaminaRegenDelay then
			stamina = math.min(cap, stamina + P.StaminaRegen * dt)
			if exhausted and stamina > cap * 0.3 then
				exhausted = false
			end
		end
		if nowSprinting ~= sprinting then
			sprinting = nowSprinting
			Remotes.ToServer:FireServer("Sprint", sprinting)
		end
		Hud.Stamina = stamina / cap

		humanoid.WalkSpeed = if not inShift then P.LobbySpeed elseif sprinting then P.SprintSpeed elseif crouching then P.CrouchSpeed else P.WalkSpeed

		-- head bob, crouch height, and scare shake all go through CameraOffset
		local speed = humanoid.WalkSpeed * (if moving then 1 else 0)
		bobPhase += dt * speed * 0.55
		local bob = if inShift and moving then Vector3.new(math.cos(bobPhase * 0.5) * 0.06, math.abs(math.sin(bobPhase)) * 0.11, 0) else Vector3.zero
		local crouchOffset = if crouching and inShift then Vector3.new(0, -1.7, 0) else Vector3.zero
		humanoid.CameraOffset = humanoid.CameraOffset:Lerp(bob + crouchOffset + Movement.Shake, math.min(1, dt * 12))

		local targetKick = if sprinting then 9 elseif exhausted then -3 else 0
		fovKick += (targetKick - fovKick) * math.min(1, dt * 5)
		if camera.CameraType == Enum.CameraType.Custom then
			camera.FieldOfView = 70 + fovKick + Movement.Zoom
		end
	end)
end

return Movement
