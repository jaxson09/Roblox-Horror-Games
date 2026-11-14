--!strict
--[[
	FawnAnimator — brings the rig to life on each client with procedural
	joint motion (no animation assets): a hunched, long-armed walk, head
	tics, the thrown-back howl, the lunge. Also turns FAWN's distance into
	dread: static, heartbeat, the tracker needle, the red at the edges.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Hud = require(script.Parent.Parent.UI.Hud)
local Vhs = require(script.Parent.Parent.UI.Vhs)
local Atmosphere = require(script.Parent.Atmosphere)
local Movement = require(script.Parent.Movement)

local FawnAnimator = {}

local player = Players.LocalPlayer
local rng = Random.new()

type Pose = { [string]: Vector3 } -- motor name -> euler angles

local MOTORS = { "Waist", "Neck", "JawHinge", "LeftShoulder", "RightShoulder", "LeftElbow", "RightElbow", "LeftHip", "RightHip", "LeftKnee", "RightKnee" }

local model: Model? = nil
local root: BasePart? = nil
local motors: { [string]: Motor6D } = {}
local bases: { [string]: CFrame } = {}
local angles: { [string]: Vector3 } = {}
local phase = 0
local lastPos = Vector3.zero
local speed = 0
local lastStepSign = 1
local ticYaw, ticTilt, nextTicAt = 0, 0, 0
local stepSound: Sound? = nil

local function bind(found: Model)
	model = found
	root = found:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	table.clear(motors)
	for _, name in MOTORS do
		local motor = found:FindFirstChild(name, true)
		if motor and motor:IsA("Motor6D") then
			local m = motor :: Motor6D
			motors[name] = m
			local base = m:GetAttribute("BaseC0")
			bases[name] = if typeof(base) == "CFrame" then base else m.C0
			angles[name] = Vector3.zero
		end
	end
	if root then
		lastPos = root.Position
		stepSound = root:FindFirstChild("FawnStep") :: Sound?
	end
end

local function pose(state: string, t: number, moving: number, sinceHowl: number, sinceCatch: number): Pose
	local chase = state == "Chase"
	local amp = (if chase then 0.8 else 0.5) * moving
	local s, c = math.sin(phase), math.cos(phase)
	local breathe = math.sin(t * 1.3) * 0.03
	local p: Pose = {
		Waist = Vector3.new(-0.28 + breathe, 0, s * 0.06 * moving),
		Neck = Vector3.new(0.12, ticYaw, ticTilt),
		JawHinge = Vector3.new(-0.06, 0, 0),
		LeftShoulder = Vector3.new(0.12 - s * 0.4 * moving, 0, -0.1),
		RightShoulder = Vector3.new(0.12 + s * 0.4 * moving, 0, 0.1),
		LeftElbow = Vector3.new(0.3, 0, 0),
		RightElbow = Vector3.new(0.3, 0, 0),
		LeftHip = Vector3.new(0.45 + s * amp, 0, 0),
		RightHip = Vector3.new(0.45 - s * amp, 0, 0),
		LeftKnee = Vector3.new(-0.9 - math.max(0, c) * amp * 0.9, 0, 0),
		RightKnee = Vector3.new(-0.9 - math.max(0, -c) * amp * 0.9, 0, 0),
	}
	if state == "Dormant" then
		p.Waist = Vector3.new(-0.95, 0, 0.08)
		p.Neck = Vector3.new(-0.5, 0, 0.2)
		p.LeftShoulder = Vector3.new(0.3, 0, -0.05)
		p.RightShoulder = Vector3.new(0.3, 0, 0.05)
	elseif state == "Stagger" then
		p.Waist = Vector3.new(0.25, math.sin(t * 9) * 0.2, 0)
		p.Neck = Vector3.new(0.3, math.sin(t * 31) * 0.5, math.sin(t * 23) * 0.3)
		p.LeftShoulder = Vector3.new(2.3, 0, 0.5)
		p.RightShoulder = Vector3.new(2.3, 0, -0.5)
		p.LeftElbow = Vector3.new(1.7, 0, 0)
		p.RightElbow = Vector3.new(1.7, 0, 0)
		p.JawHinge = Vector3.new(-0.6, 0, 0)
	elseif chase then
		p.Waist = Vector3.new(-0.55, 0, s * 0.1)
		p.Neck = Vector3.new(0.42, ticYaw * 0.3, math.sin(t * 17) * 0.08)
		p.LeftShoulder = Vector3.new(1.25 + s * 0.25, 0, -0.25)
		p.RightShoulder = Vector3.new(1.25 - s * 0.25, 0, 0.25)
		p.LeftElbow = Vector3.new(0.55 + math.sin(t * 13) * 0.15, 0, 0)
		p.RightElbow = Vector3.new(0.55 + math.cos(t * 11) * 0.15, 0, 0)
		p.JawHinge = Vector3.new(-0.35 + math.sin(t * 20) * 0.1, 0, 0)
	elseif state == "Search" then
		-- sniffing: head low, sweeping
		p.Waist = Vector3.new(-0.5 + breathe, math.sin(t * 0.9) * 0.25, 0)
		p.Neck = Vector3.new(-0.1, math.sin(t * 1.7) * 0.6, ticTilt)
	end
	if sinceHowl < 2.4 then
		local k = math.sin(math.clamp(sinceHowl / 2.4, 0, 1) * math.pi)
		p.Waist = p.Waist:Lerp(Vector3.new(0.3, 0, 0), k)
		p.Neck = p.Neck:Lerp(Vector3.new(0.85, 0, math.sin(t * 40) * 0.05), k)
		p.JawHinge = p.JawHinge:Lerp(Vector3.new(-0.75, 0, 0), k)
		p.LeftShoulder = p.LeftShoulder:Lerp(Vector3.new(-0.2, 0, -0.95), k)
		p.RightShoulder = p.RightShoulder:Lerp(Vector3.new(-0.2, 0, 0.95), k)
	end
	if sinceCatch < 1.6 then
		local k = math.sin(math.clamp(sinceCatch / 1.6, 0, 1) * math.pi)
		p.Waist = p.Waist:Lerp(Vector3.new(-0.75, 0, 0), k)
		p.LeftShoulder = p.LeftShoulder:Lerp(Vector3.new(1.55, 0, 0.3), k)
		p.RightShoulder = p.RightShoulder:Lerp(Vector3.new(1.55, 0, -0.3), k)
		p.LeftElbow = p.LeftElbow:Lerp(Vector3.new(0.95, 0, 0), k)
		p.RightElbow = p.RightElbow:Lerp(Vector3.new(0.95, 0, 0), k)
		p.JawHinge = p.JawHinge:Lerp(Vector3.new(-0.8, 0, 0), k)
	end
	return p
end

local function stepDecoys(now: number)
	local world = workspace:FindFirstChild("World")
	local facility = world and world:FindFirstChild("Facility")
	local dynamic = facility and facility:FindFirstChild("Dynamic")
	if not dynamic then
		return
	end
	for _, child in dynamic:GetChildren() do
		if child:GetAttribute("Decoy") ~= true then
			continue
		end
		local head = child:FindFirstChild("Head") :: BasePart?
		if not head then
			continue
		end
		if child:GetAttribute("Revealed") and not child:GetAttribute("Twisted") then
			-- the moment you realise: its head turns all the way round
			child:SetAttribute("Twisted", true)
			head.CFrame *= CFrame.Angles(0, math.pi, math.rad(35))
		end
		-- the tell: once in a while the name on the tag is not quite right
		local tag = head:FindFirstChild("CrewTag")
		local label = tag and tag:FindFirstChild("Label") :: TextLabel?
		if label then
			local real = label:GetAttribute("Real")
			if type(real) ~= "string" then
				real = label.Text
				label:SetAttribute("Real", real)
			end
			local name = real :: string
			if (now + #name) % 7 < 0.18 then
				label.Text = string.reverse(name)
			else
				label.Text = name
			end
		end
	end
end

function FawnAnimator.init()
	for _, found in CollectionService:GetTagged("HS_Fawn") do
		if found:IsA("Model") then
			task.spawn(bind, found :: Model)
		end
	end
	CollectionService:GetInstanceAddedSignal("HS_Fawn"):Connect(function(found)
		if found:IsA("Model") then
			bind(found :: Model)
		end
	end)

	RunService.RenderStepped:Connect(function(dt)
		local now = os.clock()
		stepDecoys(now)
		local fawn, hrp = model, root
		local camera = workspace.CurrentCamera
		if not fawn or not hrp or not fawn.Parent or not camera then
			Atmosphere.Dread = 0
			Atmosphere.Chased = false
			Vhs.setStatic(0)
			return
		end
		local stateValue = fawn:GetAttribute("State")
		local state = if type(stateValue) == "string" then stateValue else "Dormant"
		local serverNow = workspace:GetServerTimeNow()
		local howlAt = fawn:GetAttribute("HowlAt")
		local catchAt = fawn:GetAttribute("CatchAt")
		local sinceHowl = if type(howlAt) == "number" then serverNow - howlAt else 99
		local sinceCatch = if type(catchAt) == "number" then serverNow - catchAt else 99

		-- speed from replicated position, smoothed
		local pos = hrp.Position
		local moved = Vector3.new(pos.X - lastPos.X, 0, pos.Z - lastPos.Z).Magnitude
		lastPos = pos
		speed += (math.min(moved / math.max(dt, 1 / 240), 30) - speed) * math.min(1, dt * 8)
		local moving = math.clamp(speed / 8, 0, 1)
		phase += dt * speed * 0.62

		if now > nextTicAt then
			nextTicAt = now + rng:NextNumber(0.8, 3.5)
			ticYaw = rng:NextNumber(-0.75, 0.75)
			ticTilt = if rng:NextNumber() < 0.3 then rng:NextNumber(-0.45, 0.45) else 0
		end

		local target = pose(state, now, moving, sinceHowl, sinceCatch)
		for name, motor in motors do
			local goal = target[name] or Vector3.zero
			-- head tics snap; everything else eases
			local rate = if name == "Neck" then 22 else 10
			local a = angles[name]:Lerp(goal, math.min(1, dt * rate))
			angles[name] = a
			motor.C0 = bases[name] * CFrame.Angles(a.X, a.Y, a.Z)
		end

		local distance = (camera.CFrame.Position - pos).Magnitude
		local inShift = player:GetAttribute("InShift") == true

		-- footfalls you can feel
		local sign = if math.sin(phase) >= 0 then 1 else -1
		if sign ~= lastStepSign and moving > 0.2 then
			lastStepSign = sign
			if stepSound then
				stepSound.PlaybackSpeed = rng:NextNumber(0.85, 1.1)
				stepSound:Play()
			end
			if inShift and distance < 45 then
				Movement.Shake = Vector3.new(0, -0.12 * (1 - distance / 45), 0)
				task.delay(0.08, function()
					Movement.Shake = Vector3.zero
				end)
			end
		end

		-- dread
		local awake = state ~= "Dormant"
		local dread = if inShift and awake then math.clamp(1 - (distance - 12) / 75, 0, 1) ^ 1.6 else 0
		local hunted = player:GetAttribute("Hunted") == true
		Atmosphere.Dread = dread
		Atmosphere.Chased = inShift and (hunted or (state == "Chase" and distance < 70))
		Vhs.setStatic(dread * (if Atmosphere.NightVision then 0.85 else 0.42))
		Vhs.setDread(if hunted then 0.6 + 0.4 * math.sin(now * 7) else dread * 0.35)

		if inShift and awake then
			local look = camera.CFrame.LookVector
			local to = pos - camera.CFrame.Position
			local forward = Vector3.new(look.X, 0, look.Z)
			local flatTo = Vector3.new(to.X, 0, to.Z)
			if forward.Magnitude > 0.01 and flatTo.Magnitude > 0.01 then
				forward, flatTo = forward.Unit, flatTo.Unit
				Hud.TrackerAngle = math.atan2(forward.X * flatTo.Z - forward.Z * flatTo.X, forward:Dot(flatTo))
				Hud.TrackerStrength = math.clamp(1 - distance / 260, 0, 1)
			end
		else
			Hud.TrackerAngle = nil
		end
	end)
end

return FawnAnimator
