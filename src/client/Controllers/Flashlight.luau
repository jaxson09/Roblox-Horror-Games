--!strict
--[[
	Flashlight — a handheld beam that follows the camera with a little lag.
	It lets you see; it also lets HUSH see you from much farther away. Held
	steady in its eye at close range, it whites out the optic for a moment.
	N toggles Camcorder Night Mode for owners of that pass.
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sfx = require(ReplicatedStorage.Shared.Sfx)
local Hud = require(script.Parent.Parent.UI.Hud)
local Theme = require(script.Parent.Parent.UI.Theme)
local Atmosphere = require(script.Parent.Atmosphere)

local Flashlight = {}

local player = Players.LocalPlayer
local P = Config.Player

local on = false
local holder: Part
local beam: SpotLight
local fill: PointLight
local click: Sound
local dazzle = 0

local function usable(): boolean
	return player:GetAttribute("InShift") == true and not player:GetAttribute("Hidden") and not player:GetAttribute("Grabbed")
end

local function set(value: boolean)
	if value and (not usable() or Theme.num(player, "Battery", 1) <= 0) then
		value = false
	end
	if on == value then
		return
	end
	on = value
	click:Play()
	Remotes.ToServer:FireServer("Flashlight", on)
end

local function fawnHead(): BasePart?
	local world = workspace:FindFirstChild("World")
	local facility = world and world:FindFirstChild("Facility")
	local fawn = facility and facility:FindFirstChild("FAWN")
	return if fawn then fawn:FindFirstChild("Skull") :: BasePart? else nil
end

function Flashlight.init()
	holder = Instance.new("Part")
	holder.Name = "HS_Flashlight"
	holder.Size = Vector3.new(0.2, 0.2, 0.2)
	holder.Transparency = 1
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Parent = workspace
	beam = Instance.new("SpotLight")
	beam.Face = Enum.NormalId.Front
	beam.Range = 60
	beam.Angle = 52
	beam.Brightness = 2.6
	beam.Color = Color3.fromRGB(255, 244, 214)
	beam.Shadows = true
	beam.Enabled = false
	beam.Parent = holder
	fill = Instance.new("PointLight")
	fill.Range = 9
	fill.Brightness = 0.35
	fill.Color = Color3.fromRGB(255, 244, 214)
	fill.Enabled = false
	fill.Parent = holder
	click = Sfx.make(holder, "FlashlightClick", { Volume = 0.5 })

	ContextActionService:BindAction("HS_Light", function(_, state)
		if state == Enum.UserInputState.Begin then
			set(not on)
		end
		return Enum.ContextActionResult.Pass
	end, true, Enum.KeyCode.F, Enum.KeyCode.ButtonY)
	Theme.touchButton("HS_Light", "LITE", "Light")
	-- Night mode is only bound (and only gets a touch button) for owners of the pass
	local nightBound = false
	local function bindNight()
		if nightBound or not player:GetAttribute("Pass_NightVision") then
			return
		end
		nightBound = true
		ContextActionService:BindAction("HS_NightVision", function(_, state)
			if state == Enum.UserInputState.Begin and usable() then
				Atmosphere.NightVision = not Atmosphere.NightVision
				Remotes.ToServer:FireServer("NightVision", Atmosphere.NightVision)
				click:Play()
			end
			return Enum.ContextActionResult.Pass
		end, true, Enum.KeyCode.N, Enum.KeyCode.DPadUp)
		Theme.touchButton("HS_NightVision", "NV", "Night")
	end
	bindNight()
	player:GetAttributeChangedSignal("Pass_NightVision"):Connect(bindNight)

	-- the server turns the light off when the battery dies or you are grabbed
	player:GetAttributeChangedSignal("LightOn"):Connect(function()
		if not player:GetAttribute("LightOn") and on then
			on = false
		end
	end)

	RunService.RenderStepped:Connect(function(dt)
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		if not usable() then
			on = false
			Atmosphere.NightVision = false
		end
		-- hide our own replicated head light: the handheld beam replaces it
		local character = player.Character
		local head = character and character:FindFirstChild("Head")
		local own = head and head:FindFirstChild("CrewLight") :: SpotLight?
		if own and own.Enabled then
			own.Enabled = false
		end

		local battery = Theme.num(player, "Battery", 1)
		local wide = player:GetAttribute("Pass_Flashlight") == true
		beam.Enabled = on
		Hud.LightOn = on
		fill.Enabled = on
		beam.Angle = if wide then 68 else 52
		-- a dying battery gutters
		local gutter = if battery < 0.15 then 0.55 + 0.45 * math.noise(os.clock() * 9, 0, 0) else 1
		beam.Brightness = 2.6 * gutter
		local goal = camera.CFrame * CFrame.new(0.55, -0.45, -0.3)
		holder.CFrame = holder.CFrame:Lerp(goal, math.min(1, dt * 18))

		-- dazzle: hold the beam on its eye
		local head2 = fawnHead()
		local readyAt = Theme.num(player, "DazzleReadyAt", 0)
		local aiming = false
		if on and head2 and workspace:GetServerTimeNow() >= readyAt then
			local toHead = head2.Position - camera.CFrame.Position
			if toHead.Magnitude <= P.DazzleRange and camera.CFrame.LookVector:Dot(toHead.Unit) > 0.968 then
				local params = RaycastParams.new()
				params.FilterType = Enum.RaycastFilterType.Exclude
				local ignore: { Instance } = { holder, head2.Parent :: Instance }
				if character then
					table.insert(ignore, character)
				end
				params.FilterDescendantsInstances = ignore
				aiming = workspace:Raycast(camera.CFrame.Position, toHead, params) == nil
			end
		end
		dazzle = if aiming then dazzle + dt / P.DazzleTime else math.max(0, dazzle - dt * 2)
		if dazzle >= 1 then
			dazzle = 0
			Remotes.ToServer:FireServer("Dazzle")
		end
		Hud.DazzleProgress = dazzle
	end)
end

return Flashlight
