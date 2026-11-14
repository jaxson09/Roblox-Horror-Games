--!strict
--[[
	Crew — per-player state for the current shift (hidden, caged, noise,
	battery, breath...) and the helpers that move characters around.
	State the HUD needs is mirrored onto Player attributes.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Build = require(script.Parent.Parent.World.Build)
local Facility = require(script.Parent.Parent.World.Facility)

local Crew = {}

export type Member = {
	Player: Player,
	InShift: boolean,
	ShiftId: number, -- last shift this player entered
	Eliminated: boolean,
	Escaped: boolean,
	Hearts: number,
	BreakFrees: number, -- times they can still wrench free of a grab
	Grabbed: boolean, -- in HUSH's hands right now
	GrabEnds: number,
	GrabProgress: number,
	Locker: Facility.Locker?,
	Exposed: boolean, -- HUSH watched them climb into the locker
	Noise: number,
	Battery: number,
	LightOn: boolean,
	NightVision: boolean,
	Crouching: boolean,
	Sprinting: boolean,
	HoldingBreath: boolean,
	Breath: number,
	Loud: number, -- seconds of audible breathing next to HUSH
	DazzleReadyAt: number,
	LastPhotoAt: number,
	AskedUntil: number, -- HUSH asked them a question; answering before this gives them away
	Photos: number,
	Sent: number,
	Files: number,
	Caught: number,
	JoinedAt: number,
}

local members: { [Player]: Member } = {}
Crew.Members = members

local function sync(member: Member)
	local p = member.Player
	p:SetAttribute("InShift", member.InShift)
	p:SetAttribute("Hidden", member.Locker ~= nil)
	p:SetAttribute("Grabbed", member.Grabbed)
	p:SetAttribute("Eliminated", member.Eliminated)
	p:SetAttribute("Hearts", member.Hearts)
	p:SetAttribute("BreakFrees", member.BreakFrees)
	p:SetAttribute("LightOn", member.LightOn)
end
Crew.sync = sync

function Crew.get(player: Player): Member?
	return members[player]
end

function Crew.character(player: Player): (Model?, BasePart?, Humanoid?)
	local character = player.Character
	if not character then
		return nil, nil, nil
	end
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	return character, root, humanoid
end

function Crew.position(player: Player): Vector3?
	local _, root = Crew.character(player)
	return if root then root.Position else nil
end

-- In the sublevel and free to act (may be hiding in a locker).
function Crew.isActive(member: Member): boolean
	return member.InShift and not member.Grabbed and not member.Eliminated and not member.Escaped
end

function Crew.active(): { Member }
	local list = {}
	for _, member in members do
		if Crew.isActive(member) then
			table.insert(list, member)
		end
	end
	return list
end

-- Everyone still part of the shift, caged or not.
function Crew.inPlay(): { Member }
	local list = {}
	for _, member in members do
		if member.InShift and not member.Eliminated and not member.Escaped then
			table.insert(list, member)
		end
	end
	return list
end

function Crew.teleport(player: Player, cf: CFrame)
	local character, root = Crew.character(player)
	if character and root then
		root.AssemblyLinearVelocity = Vector3.zero
		character:PivotTo(cf)
	end
end

function Crew.setAnchored(player: Player, anchored: boolean)
	local _, root = Crew.character(player)
	if root then
		root.Anchored = anchored
	end
end

-- Resets the per-shift fields when a player rides the elevator up to the ward.
function Crew.enterShift(member: Member, shiftId: number, hearts: number, breakFrees: number)
	member.InShift = true
	member.ShiftId = shiftId
	member.Eliminated = false
	member.Escaped = false
	member.Hearts = hearts
	member.BreakFrees = breakFrees
	member.Grabbed = false
	member.GrabEnds = 0
	member.GrabProgress = 0
	member.Locker = nil
	member.Exposed = false
	member.Noise = 0
	member.Battery = 1
	member.LightOn = false
	member.NightVision = false
	member.Crouching = false
	member.Sprinting = false
	member.HoldingBreath = false
	member.Breath = Config.Player.BreathSeconds
	member.Loud = 0
	member.DazzleReadyAt = 0
	member.LastPhotoAt = 0
	member.AskedUntil = 0
	member.Photos = 0
	member.Sent = 0
	member.Files = 0
	member.Caught = 0
	member.JoinedAt = os.clock()
	member.Player:SetAttribute("Battery", 1)
	member.Player:SetAttribute("Noise", 0)
	member.Player:SetAttribute("Breath", 1)
	member.Player:SetAttribute("GrabProgress", 0)
	sync(member)
end

local function setLight(member: Member)
	local character = member.Player.Character
	local head = character and character:FindFirstChild("Head")
	local light = head and head:FindFirstChild("CrewLight") :: SpotLight?
	if light then
		light.Enabled = member.LightOn and member.InShift
	end
end

function Crew.setLight(member: Member, on: boolean)
	member.LightOn = on and member.Battery > 0
	setLight(member)
	sync(member)
end

-- Movement noise, battery drain and breath. Called a few times a second.
function Crew.step(dt: number, hasBatteryPass: (Player) -> boolean)
	for _, member in members do
		if not member.InShift then
			continue
		end
		local player = member.Player
		local _, root = Crew.character(player)

		local target = 0
		if root and not member.Locker and not member.Grabbed then
			local v = root.AssemblyLinearVelocity
			local speed = Vector3.new(v.X, 0, v.Z).Magnitude
			if speed > 15 then
				target = Config.Player.NoiseSprint
			elseif speed > 7.5 then
				target = Config.Player.NoiseWalk
			elseif speed > 1 then
				target = Config.Player.NoiseCrouch
			end
		end
		-- noise rises fast and decays slowly, so one sprint burst lingers
		local rate = if target > member.Noise then 6 else 1.2
		member.Noise += math.clamp(target - member.Noise, -rate * dt, rate * dt)
		player:SetAttribute("Noise", math.round(member.Noise * 100) / 100)

		if member.LightOn then
			local seconds = Config.Player.BatterySeconds * (if hasBatteryPass(player) then Config.Player.BatteryPassMultiplier else 1)
			member.Battery = math.max(0, member.Battery - dt / seconds)
			if member.Battery <= 0 then
				Crew.setLight(member, false)
			end
			player:SetAttribute("Battery", math.round(member.Battery * 100) / 100)
		end

		if member.Locker then
			if member.HoldingBreath and member.Breath > 0 then
				member.Breath = math.max(0, member.Breath - dt)
				if member.Breath <= 0 then
					member.HoldingBreath = false -- lungs give out: a loud gasp
					member.Loud += 0.6
				end
			elseif not member.HoldingBreath then
				member.Breath = math.min(Config.Player.BreathSeconds, member.Breath + dt * Config.Player.BreathRecover)
			end
			player:SetAttribute("Breath", math.round(member.Breath / Config.Player.BreathSeconds * 100) / 100)
		end
	end
end

----------------------------------------------------------------------------
-- Character setup
----------------------------------------------------------------------------
local function tagFor(player: Player, character: Model, veteran: boolean)
	local head = character:WaitForChild("Head", 5) :: BasePart?
	if not head then
		return
	end
	local light = Build.spotLight(head, Enum.NormalId.Front, Color3.fromRGB(255, 244, 214), 2.2, 46, 52, true)
	light.Name = "CrewLight"
	light.Enabled = false

	local gui = Instance.new("BillboardGui")
	gui.Name = "CrewTag"
	gui.Size = UDim2.fromOffset(200, 26)
	gui.StudsOffset = Vector3.new(0, 2.4, 0)
	gui.MaxDistance = 70
	gui.LightInfluence = 0.4
	gui.PlayerToHideFrom = player
	gui.Parent = head
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.FontFace = Font.new(Config.Fonts.Mono, Enum.FontWeight.Bold)
	label.Text = player.DisplayName
	label.TextColor3 = if veteran then Color3.fromRGB(240, 205, 110) else Config.Colors.Osd
	label.TextStrokeTransparency = 0.4
	label.TextSize = 15
	label.Parent = gui
end

function Crew.add(player: Player, isVeteran: (Player) -> boolean, onRespawn: (Member) -> ())
	local member: Member = {
		Player = player,
		InShift = false,
		ShiftId = -1,
		Eliminated = false,
		Escaped = false,
		Hearts = 0,
		BreakFrees = 0,
		Grabbed = false,
		GrabEnds = 0,
		GrabProgress = 0,
		Locker = nil,
		Exposed = false,
		Noise = 0,
		Battery = 1,
		LightOn = false,
		NightVision = false,
		Crouching = false,
		Sprinting = false,
		HoldingBreath = false,
		Breath = Config.Player.BreathSeconds,
		Loud = 0,
		DazzleReadyAt = 0,
		LastPhotoAt = 0,
		AskedUntil = 0,
		Photos = 0,
		Sent = 0,
		Files = 0,
		Caught = 0,
		JoinedAt = 0,
	}
	members[player] = member
	sync(member)

	local function onCharacter(character: Model)
		for _, part in character:GetDescendants() do
			if part:IsA("BasePart") then
				(part :: BasePart).CollisionGroup = Build.Groups.Players
			end
		end
		character.DescendantAdded:Connect(function(part)
			if part:IsA("BasePart") then
				(part :: BasePart).CollisionGroup = Build.Groups.Players
			end
		end)
		local humanoid = character:WaitForChild("Humanoid", 5) :: Humanoid?
		if humanoid then
			humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			humanoid.WalkSpeed = Config.Player.LobbySpeed
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
		end
		task.spawn(tagFor, player, character, isVeteran(player))
		-- a fresh character while "in the shift" means they reset: they are out
		if member.InShift then
			onRespawn(member)
		end
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
	return member
end

function Crew.remove(player: Player)
	members[player] = nil
end

function Crew.names(): { string }
	local names = {}
	for _, player in Players:GetPlayers() do
		table.insert(names, player.DisplayName)
	end
	return names
end

return Crew
