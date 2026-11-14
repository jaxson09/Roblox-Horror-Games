--!strict
--[[
	Atmosphere — lighting profiles (forest night / blackout / powered /
	lockdown / night vision), music and ambience mixing, and all the little
	local light behaviours: dying fluorescents, candles, beacons.
]]

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Sfx = require(ReplicatedStorage.Shared.Sfx)
local Vhs = require(script.Parent.Parent.UI.Vhs)

local Atmosphere = {}

Atmosphere.NightVision = false -- set by Flashlight
Atmosphere.Dread = 0 -- 0..1, set by FawnAnimator from FAWN's distance
Atmosphere.Chased = false -- set by FawnAnimator

local player = Players.LocalPlayer
local rng = Random.new()

type Profile = {
	Ambient: Color3,
	Outdoor: Color3,
	Density: number,
	Haze: number,
	AtmoColor: Color3,
	Brightness: number,
	Exposure: number,
	Saturation: number,
	Contrast: number,
	Tint: Color3,
}

local PROFILES: { [string]: Profile } = {
	Lobby = { Ambient = Color3.fromRGB(16, 20, 30), Outdoor = Color3.fromRGB(30, 38, 56), Density = 0.44, Haze = 2.2, AtmoColor = Color3.fromRGB(46, 56, 76), Brightness = 0.7, Exposure = 0, Saturation = -0.3, Contrast = 0.12, Tint = Color3.fromRGB(222, 230, 245) },
	Blackout = { Ambient = Color3.fromRGB(4, 5, 5), Outdoor = Color3.fromRGB(0, 0, 0), Density = 0.5, Haze = 1.2, AtmoColor = Color3.fromRGB(8, 10, 10), Brightness = 0, Exposure = -0.1, Saturation = -0.45, Contrast = 0.2, Tint = Color3.fromRGB(226, 236, 226) },
	Powered = { Ambient = Color3.fromRGB(9, 11, 10), Outdoor = Color3.fromRGB(0, 0, 0), Density = 0.46, Haze = 1.4, AtmoColor = Color3.fromRGB(14, 18, 16), Brightness = 0, Exposure = 0, Saturation = -0.4, Contrast = 0.18, Tint = Color3.fromRGB(226, 236, 222) },
	Lockdown = { Ambient = Color3.fromRGB(22, 5, 5), Outdoor = Color3.fromRGB(0, 0, 0), Density = 0.44, Haze = 1.4, AtmoColor = Color3.fromRGB(30, 8, 8), Brightness = 0, Exposure = 0.05, Saturation = -0.25, Contrast = 0.25, Tint = Color3.fromRGB(255, 214, 208) },
	NightVision = { Ambient = Color3.fromRGB(110, 150, 110), Outdoor = Color3.fromRGB(60, 90, 60), Density = 0.3, Haze = 0.5, AtmoColor = Color3.fromRGB(20, 40, 20), Brightness = 0.4, Exposure = 0.5, Saturation = -1, Contrast = 0.3, Tint = Color3.fromRGB(120, 255, 140) },
}

local current: Profile = table.clone(PROFILES.Lobby)
local cc: ColorCorrectionEffect
local atmo: Atmosphere
local sounds: { [string]: Sound } = {}
local volumes: { [string]: number } = {}
local flickerUntil = 0
local lampStates: { [Instance]: number } = {}
local musicSound: Sound? = nil

local function profileName(): string
	if not player:GetAttribute("InShift") then
		return "Lobby"
	end
	if Atmosphere.NightVision then
		return "NightVision"
	end
	local phase = workspace:GetAttribute("HS_Phase")
	if phase == "Escape" then
		return "Lockdown"
	elseif phase == "Blackout" then
		return "Blackout"
	end
	return "Powered"
end

local function mix(key: string, target: number, dt: number)
	local sound = sounds[key]
	if not sound then
		return
	end
	local volume = volumes[key] or 0
	volume += math.clamp(target - volume, -dt * 0.6, dt * 0.9)
	volumes[key] = volume
	sound.Volume = volume
	if volume > 0.01 and not sound.IsPlaying then
		sound:Play()
	elseif volume <= 0.01 and sound.IsPlaying then
		sound:Stop()
	end
end

-- Every lit lamp stutters for a few seconds (power-on, the siren, a scare).
function Atmosphere.flicker(seconds: number)
	flickerUntil = os.clock() + (if Vhs.ReducedFlashing then math.min(seconds, 0.4) else seconds)
	local sound = sounds.LightFlicker
	if sound then
		sound:Play()
	end
end

local function setLamp(part: BasePart, on: boolean)
	local light = part:FindFirstChildOfClass("PointLight")
	if light then
		light.Enabled = on
	end
	part.Material = if on then Enum.Material.Neon else Enum.Material.SmoothPlastic
end

local function stepLights(dt: number)
	local now = os.clock()
	local globalFlicker = now < flickerUntil
	local alarm = workspace:GetAttribute("HS_Phase") == "Escape"
	local world = workspace:FindFirstChild("World")
	local facility = world and world:FindFirstChild("Facility")
	local lights = facility and facility:FindFirstChild("Lights")
	if lights then
		for _, child in lights:GetChildren() do
			if child:GetAttribute("Lit") ~= true or not child:IsA("BasePart") then
				continue
			end
			local part = child :: BasePart
			local flickers = CollectionService:HasTag(part, "HS_Flicker")
			local episodeEnds = lampStates[part] or 0
			if flickers and now > episodeEnds and rng:NextNumber() < dt * 0.25 then
				episodeEnds = now + rng:NextNumber(0.15, 1.1)
				lampStates[part] = episodeEnds
			end
			if globalFlicker or now < episodeEnds then
				setLamp(part, rng:NextNumber() < 0.5)
			else
				setLamp(part, true)
			end
			local light = part:FindFirstChildOfClass("PointLight")
			if light then
				light.Brightness = if alarm then 0.55 + 0.45 * math.sin(now * 5) else 0.85
			end
		end
	end
	for _, candle in CollectionService:GetTagged("HS_Candle") do
		local light = candle:FindFirstChildOfClass("PointLight")
		if light then
			local base = candle:GetAttribute("BaseBrightness")
			if type(base) ~= "number" then
				base = light.Brightness
				candle:SetAttribute("BaseBrightness", base)
			end
			light.Brightness = (base :: number) * (0.78 + 0.22 * math.noise(now * 3, candle.Name:len() * 1.7, 0))
		end
	end
	for _, beacon in CollectionService:GetTagged("HS_Beacon") do
		local light = beacon:FindFirstChildOfClass("PointLight")
		if light then
			light.Enabled = (now % 2.2) < 0.9
		end
	end
	if workspace:GetAttribute("HS_Phase") == "Broadcast" then
		for _, reel in CollectionService:GetTagged("HS_Reel") do
			if reel:IsA("BasePart") then
				local part = reel :: BasePart
				part.CFrame *= CFrame.Angles(dt * 4, 0, 0)
			end
		end
	end
end

function Atmosphere.init()
	for _, effect in Lighting:GetChildren() do
		if effect:IsA("PostEffect") or effect:IsA("Atmosphere") then
			effect:Destroy()
		end
	end
	cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "HS_Grade"
	cc.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.55
	bloom.Size = 28
	bloom.Threshold = 0.95
	bloom.Parent = Lighting
	atmo = Instance.new("Atmosphere")
	atmo.Name = "HS_Fog"
	atmo.Offset = 0
	atmo.Glare = 0
	atmo.Parent = Lighting

	local group = Instance.new("SoundGroup")
	group.Name = "HS_Ambience"
	group.Parent = SoundService
	for _, key in { "LobbyForest", "BunkerDrone", "ChaseTheme", "Alarm", "Heartbeat", "Static" } do
		sounds[key] = Sfx.make(group, key, { Volume = 0, Looped = true })
	end
	sounds.LightFlicker = Sfx.make(group, "LightFlicker", { Volume = 0.5 })

	-- the lobby theme plays out of the ranger's radio set, so it lives in the cabin
	task.spawn(function()
		local world = workspace:WaitForChild("World", 30)
		local lobby = world and world:WaitForChild("Lobby", 30)
		local cabin = lobby and lobby:WaitForChild("Cabin", 30)
		local radio = cabin and cabin:WaitForChild("RadioSet", 30)
		if radio then
			musicSound = Sfx.make(radio, "LobbyTheme", { Volume = 0.85, Looped = true, MinDistance = 26, MaxDistance = 260 })
			musicSound:Play()
		end
	end)

	RunService.RenderStepped:Connect(function(dt)
		local target = PROFILES[profileName()]
		local k = math.min(1, dt * 2.2)
		current.Ambient = current.Ambient:Lerp(target.Ambient, k)
		current.Outdoor = current.Outdoor:Lerp(target.Outdoor, k)
		current.AtmoColor = current.AtmoColor:Lerp(target.AtmoColor, k)
		current.Tint = current.Tint:Lerp(target.Tint, k)
		current.Density += (target.Density - current.Density) * k
		current.Haze += (target.Haze - current.Haze) * k
		current.Brightness += (target.Brightness - current.Brightness) * k
		current.Exposure += (target.Exposure - current.Exposure) * k
		current.Saturation += (target.Saturation - current.Saturation) * k
		current.Contrast += (target.Contrast - current.Contrast) * k

		Lighting.Ambient = current.Ambient
		Lighting.OutdoorAmbient = current.Outdoor
		Lighting.Brightness = current.Brightness
		Lighting.ExposureCompensation = current.Exposure
		atmo.Density = current.Density
		atmo.Haze = current.Haze
		atmo.Color = current.AtmoColor
		atmo.Decay = current.AtmoColor
		local chase = if Atmosphere.Chased then 1 else 0
		cc.Saturation = current.Saturation - 0.2 * chase
		cc.Contrast = current.Contrast + 0.08 * chase
		cc.TintColor = current.Tint:Lerp(Color3.fromRGB(255, 190, 180), 0.35 * chase)

		local inShift = player:GetAttribute("InShift") == true
		local dread = if inShift then Atmosphere.Dread else 0
		mix("LobbyForest", if inShift then 0 else 0.4, dt)
		mix("BunkerDrone", if inShift then 0.45 else 0, dt)
		mix("ChaseTheme", if inShift and Atmosphere.Chased then 0.75 else 0, dt)
		mix("Alarm", if inShift and workspace:GetAttribute("HS_Phase") == "Escape" then 0.4 else 0, dt)
		mix("Heartbeat", dread * 0.9, dt)
		mix("Static", dread * 0.3, dt)
		sounds.Heartbeat.PlaybackSpeed = 1 + dread * 0.7
		if musicSound then
			musicSound.Volume = if inShift then 0 else 0.85
		end
		stepLights(dt)
	end)
end

return Atmosphere
