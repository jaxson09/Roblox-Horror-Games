--!strict
--[[
	FawnRig — builds F.A.W.N. out of parts: a nine-foot search-and-rescue
	endoskeleton wearing a deer skull, antlers and a stitched hide, with a
	loudspeaker horn where its chest should be.

	Joints are Motor6Ds with fixed names; the client animates them procedurally
	(see client/Controllers/FawnAnimator), so no animation assets are needed.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Sfx = require(ReplicatedStorage.Shared.Sfx)
local Build = require(script.Parent.Build)

local FawnRig = {}

export type Rig = {
	Model: Model,
	Root: Part,
	Head: Part,
	Humanoid: Humanoid,
	Eye: Part,
	EyeBeam: SpotLight,
	Sounds: { [string]: Sound },
}

local STEEL = Color3.fromRGB(52, 54, 56)
local RUST = Color3.fromRGB(96, 56, 36)
local BONE = Color3.fromRGB(206, 196, 168)
local HIDE = Color3.fromRGB(62, 44, 32)
local HIDE_DARK = Color3.fromRGB(40, 28, 22)
local EYE = Color3.fromRGB(255, 70, 50)

FawnRig.RootHeight = 5.4 -- root centre above the floor
FawnRig.HipHeight = 3.9

local function limb(model: Model, name: string, size: Vector3, color: Color3, material: Enum.Material, transparency: number?): Part
	return Build.block(model, name, size, CFrame.new(), color, material, {
		Anchored = false,
		CanCollide = false,
		Massless = true,
		Group = Build.Groups.Fawn,
		Transparency = transparency,
	})
end

local function joint(name: string, part0: BasePart, part1: BasePart, c0: CFrame, c1: CFrame): Motor6D
	part1.CFrame = part0.CFrame * c0 * c1:Inverse()
	local motor = Instance.new("Motor6D")
	motor.Name = name
	motor.Part0 = part0
	motor.Part1 = part1
	motor.C0 = c0
	motor.C1 = c1
	motor.Parent = part0
	motor:SetAttribute("BaseC0", c0)
	return motor
end

-- Decoration rigidly attached to a bone.
local function deco(model: Model, bone: BasePart, name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material, shape: Enum.PartType?): Part
	local part = Build.block(model, name, size, bone.CFrame * offset, color, material, {
		Anchored = false,
		CanCollide = false,
		Massless = true,
		Group = Build.Groups.Fawn,
		Shape = shape,
	})
	Build.weld(bone, part)
	return part
end

function FawnRig.build(parent: Instance, position: Vector3): Rig
	local model = Build.model(parent, "FAWN")
	local metal = Enum.Material.CorrodedMetal

	local root = Build.block(model, "HumanoidRootPart", Vector3.new(3, 3, 2), CFrame.new(position + Vector3.new(0, FawnRig.RootHeight, 0)), STEEL, metal, {
		Anchored = false,
		CanCollide = true,
		Transparency = 1,
		Group = Build.Groups.Fawn,
	})
	model.PrimaryPart = root

	-- pelvis + spine
	deco(model, root, "Pelvis", Vector3.new(2, 0.7, 1.1), CFrame.new(0, -0.7, 0), STEEL, metal)
	deco(model, root, "SpineLow", Vector3.new(0.5, 1.6, 0.5), CFrame.new(0, 0.1, 0.2), RUST, metal)
	for i = 0, 2 do
		deco(model, root, "Vertebra", Vector3.new(0.9, 0.22, 0.7), CFrame.new(0, -0.3 + i * 0.5, 0.25), BONE, Enum.Material.Sandstone)
	end

	-- chest: an open ribcage around a loudspeaker horn
	local chest = limb(model, "Chest", Vector3.new(2.6, 2.6, 1.6), STEEL, metal, 1)
	joint("Waist", root, chest, CFrame.new(0, 0.9, 0), CFrame.new(0, -1.3, 0))
	deco(model, chest, "Sternum", Vector3.new(0.4, 2.4, 0.3), CFrame.new(0, 0, -0.8), RUST, metal)
	deco(model, chest, "SpineHigh", Vector3.new(0.5, 2.8, 0.5), CFrame.new(0, 0, 0.7), RUST, metal)
	for i = 0, 3 do
		for _, side in { -1, 1 } do
			deco(model, chest, "Rib", Vector3.new(1.3, 0.18, 0.18), CFrame.new(side * 0.75, 0.9 - i * 0.6, -0.55) * CFrame.Angles(0, side * math.rad(28), side * math.rad(-10)), BONE, Enum.Material.Sandstone)
			deco(model, chest, "RibBack", Vector3.new(1.3, 0.18, 0.18), CFrame.new(side * 0.75, 0.9 - i * 0.6, 0.5) * CFrame.Angles(0, side * math.rad(-28), side * math.rad(-10)), BONE, Enum.Material.Sandstone)
		end
	end
	local horn = deco(model, chest, "SpeakerHorn", Vector3.new(0.9, 1.5, 1.5), CFrame.new(0, 0.1, -0.35) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(22, 22, 24), Enum.Material.Metal, Enum.PartType.Cylinder)
	deco(model, chest, "SpeakerCone", Vector3.new(0.3, 0.9, 0.9), CFrame.new(0, 0.1, -0.75) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(10, 10, 10), Enum.Material.Fabric, Enum.PartType.Cylinder)
	deco(model, chest, "ShoulderBar", Vector3.new(3.4, 0.45, 0.45), CFrame.new(0, 1.15, 0.1), STEEL, metal)
	-- the hide: stitched across the shoulders and hanging down the back
	deco(model, chest, "HideShoulders", Vector3.new(3.8, 0.25, 2.2), CFrame.new(0, 1.5, 0.2) * CFrame.Angles(math.rad(8), 0, 0), HIDE, Enum.Material.Fabric)
	deco(model, chest, "HideBack", Vector3.new(3.2, 4.4, 0.2), CFrame.new(0, -0.8, 1.15) * CFrame.Angles(math.rad(-7), 0, 0), HIDE, Enum.Material.Fabric)
	deco(model, chest, "HideTatterL", Vector3.new(0.9, 2.6, 0.18), CFrame.new(-1.3, -3.4, 1.4) * CFrame.Angles(math.rad(-10), 0, math.rad(6)), HIDE_DARK, Enum.Material.Fabric)
	deco(model, chest, "HideTatterR", Vector3.new(1.1, 1.8, 0.18), CFrame.new(1.1, -3.1, 1.4) * CFrame.Angles(math.rad(-10), 0, math.rad(-5)), HIDE_DARK, Enum.Material.Fabric)
	deco(model, chest, "HideFlapL", Vector3.new(0.2, 2.2, 1.6), CFrame.new(-1.75, 0.2, 0.3) * CFrame.Angles(0, 0, math.rad(-6)), HIDE, Enum.Material.Fabric)

	-- head: skull, antlers, one working optic
	-- Named "Skull", not "Head": a Humanoid forces collision on a sibling called Head,
	-- which would catch on every door lintel.
	local head = limb(model, "Skull", Vector3.new(1.4, 1.4, 1.2), BONE, Enum.Material.Sandstone)
	joint("Neck", chest, head, CFrame.new(0, 1.3, -0.35), CFrame.new(0, -0.5, 0.2))
	deco(model, head, "NeckPiston", Vector3.new(0.35, 0.8, 0.35), CFrame.new(0, -0.7, 0.3), STEEL, metal)
	deco(model, head, "Snout", Vector3.new(0.8, 0.75, 1.7), CFrame.new(0, -0.3, -1.25) * CFrame.Angles(math.rad(10), 0, 0), BONE, Enum.Material.Sandstone)
	deco(model, head, "NoseCavity", Vector3.new(0.5, 0.4, 0.3), CFrame.new(0, -0.3, -2.1), Color3.fromRGB(30, 22, 20), Enum.Material.Sandstone)
	for i = 0, 3 do
		deco(model, head, "Tooth", Vector3.new(0.12, 0.3, 0.12), CFrame.new(-0.3 + i * 0.2, -0.78, -1.9), BONE, Enum.Material.Sandstone)
	end
	local jaw = limb(model, "Jaw", Vector3.new(0.7, 0.25, 1.6), BONE, Enum.Material.Sandstone)
	joint("JawHinge", head, jaw, CFrame.new(0, -0.75, -0.3), CFrame.new(0, 0, 0.8))
	local socketDark = deco(model, head, "SocketDark", Vector3.new(0.45, 0.45, 0.45), CFrame.new(-0.52, 0.12, -0.5), Color3.fromRGB(8, 6, 6), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	deco(model, socketDark, "LooseWire", Vector3.new(0.08, 1.1, 0.08), CFrame.new(-0.1, -0.6, -0.1) * CFrame.Angles(0, 0, math.rad(12)), Color3.fromRGB(120, 20, 20), Enum.Material.Plastic)
	local eye = deco(model, head, "Eye", Vector3.new(0.42, 0.42, 0.42), CFrame.new(0.52, 0.12, -0.52), EYE, Enum.Material.Neon, Enum.PartType.Ball)
	local eyeGlow = Build.pointLight(eye, EYE, 1.2, 9)
	eyeGlow.Name = "EyeGlow"
	-- an attachment-free trick: the beam shines from an invisible plate facing forward
	local beamPlate = deco(model, head, "BeamPlate", Vector3.new(0.2, 0.2, 0.2), CFrame.new(0.52, 0.12, -0.8), EYE, Enum.Material.Neon)
	beamPlate.Transparency = 1
	local eyeBeam = Build.spotLight(beamPlate, Enum.NormalId.Front, EYE, 2.2, 52, 34, true)
	eyeBeam.Name = "EyeBeam"
	for _, side in { -1, 1 } do
		local a1 = deco(model, head, "Antler", Vector3.new(0.2, 1.4, 0.2), CFrame.new(side * 0.55, 1.05, 0.2) * CFrame.Angles(math.rad(-14), 0, math.rad(-side * 26)), BONE, Enum.Material.Sandstone)
		local a2 = deco(model, a1, "Antler", Vector3.new(0.16, 1, 0.16), CFrame.new(side * 0.3, 0.95, 0) * CFrame.Angles(0, 0, math.rad(-side * 32)), BONE, Enum.Material.Sandstone)
		deco(model, a1, "Tine", Vector3.new(0.13, 0.8, 0.13), CFrame.new(-side * 0.25, 0.35, -0.3) * CFrame.Angles(math.rad(-40), 0, math.rad(side * 20)), BONE, Enum.Material.Sandstone)
		deco(model, a2, "Tine", Vector3.new(0.12, 0.7, 0.12), CFrame.new(side * 0.1, 0.3, -0.3) * CFrame.Angles(math.rad(-46), 0, 0), BONE, Enum.Material.Sandstone)
	end
	-- the right antler is snapped and splinted with rebar
	deco(model, head, "Splint", Vector3.new(0.1, 1.1, 0.1), CFrame.new(0.72, 1, 0.3) * CFrame.Angles(math.rad(-14), 0, math.rad(-22)), RUST, metal)

	-- arms: too long, ending in rescue-claw manipulators
	for _, side in { -1, 1 } do
		local prefix = if side == -1 then "Left" else "Right"
		local upper = limb(model, prefix .. "UpperArm", Vector3.new(0.5, 3, 0.5), STEEL, metal)
		joint(prefix .. "Shoulder", chest, upper, CFrame.new(side * 1.75, 1.1, 0.1), CFrame.new(0, 1.5, 0))
		deco(model, upper, "ShoulderJoint", Vector3.new(0.9, 0.9, 0.9), CFrame.new(0, 1.5, 0), RUST, metal, Enum.PartType.Ball)
		deco(model, upper, "Hydraulic", Vector3.new(0.18, 2.4, 0.18), CFrame.new(0, 0, 0.35), Color3.fromRGB(110, 112, 110), Enum.Material.Metal)
		local lower = limb(model, prefix .. "LowerArm", Vector3.new(0.4, 3.2, 0.4), STEEL, metal)
		joint(prefix .. "Elbow", upper, lower, CFrame.new(0, -1.5, 0), CFrame.new(0, 1.6, 0))
		deco(model, lower, "ElbowJoint", Vector3.new(0.7, 0.7, 0.7), CFrame.new(0, 1.6, 0), RUST, metal, Enum.PartType.Ball)
		if side == -1 then
			-- left forearm is wrapped in hide, like a sleeve it made for itself
			deco(model, lower, "Sleeve", Vector3.new(0.7, 2.2, 0.7), CFrame.new(0, 0.2, 0), HIDE, Enum.Material.Fabric)
		end
		for f = -1, 1 do
			deco(model, lower, "Claw", Vector3.new(0.14, 1.3, 0.14), CFrame.new(f * 0.22, -2.1, -0.12) * CFrame.Angles(math.rad(14), 0, math.rad(f * 12)), Color3.fromRGB(150, 150, 146), Enum.Material.Metal)
		end
	end

	-- legs: backwards-kneed, built for rough ground
	for _, side in { -1, 1 } do
		local prefix = if side == -1 then "Left" else "Right"
		local upper = limb(model, prefix .. "UpperLeg", Vector3.new(0.6, 2.4, 0.6), STEEL, metal)
		joint(prefix .. "Hip", root, upper, CFrame.new(side * 0.75, -0.9, 0), CFrame.new(0, 1.2, 0))
		deco(model, upper, "HipJoint", Vector3.new(0.85, 0.85, 0.85), CFrame.new(0, 1.2, 0), RUST, metal, Enum.PartType.Ball)
		local lower = limb(model, prefix .. "LowerLeg", Vector3.new(0.5, 2.4, 0.5), STEEL, metal)
		joint(prefix .. "Knee", upper, lower, CFrame.new(0, -1.2, 0), CFrame.new(0, 1.2, 0))
		deco(model, lower, "KneeJoint", Vector3.new(0.7, 0.7, 0.7), CFrame.new(0, 1.2, 0), RUST, metal, Enum.PartType.Ball)
		deco(model, lower, "Hoof", Vector3.new(0.8, 0.4, 1.5), CFrame.new(0, -1.3, -0.35), Color3.fromRGB(26, 24, 24), Enum.Material.Metal)
	end

	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.AutomaticScalingEnabled = false
	humanoid.HipHeight = FawnRig.HipHeight
	humanoid.WalkSpeed = 0
	humanoid.MaxHealth = 1e9
	humanoid.Health = 1e9
	humanoid.RequiresNeck = false
	humanoid.BreakJointsOnDeath = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.AutoJumpEnabled = false
	for _, state in { Enum.HumanoidStateType.Jumping, Enum.HumanoidStateType.Climbing, Enum.HumanoidStateType.Swimming, Enum.HumanoidStateType.FallingDown, Enum.HumanoidStateType.Ragdoll, Enum.HumanoidStateType.Dead, Enum.HumanoidStateType.Seated } do
		humanoid:SetStateEnabled(state, false)
	end
	humanoid.Parent = model

	local far: Sfx.SoundProps = { Volume = 1.6, MinDistance = 40, MaxDistance = 650 }
	local sounds: { [string]: Sound } = {
		Howl1 = Sfx.make(horn, "FawnHowl1", far),
		Howl2 = Sfx.make(horn, "FawnHowl2", far),
		Howl3 = Sfx.make(horn, "FawnHowl3", far),
		Shriek = Sfx.make(horn, "FawnShriek", { Volume = 1.8, MinDistance = 30, MaxDistance = 420 }),
		Mimic1 = Sfx.make(horn, "FawnMimic1", { Volume = 1, MinDistance = 18, MaxDistance = 220 }),
		Mimic2 = Sfx.make(horn, "FawnMimic2", { Volume = 1, MinDistance = 18, MaxDistance = 220 }),
		Idle = Sfx.make(horn, "FawnIdle", { Volume = 0.5, Looped = true, MinDistance = 10, MaxDistance = 85 }),
		Step = Sfx.make(root, "FawnStep", { Volume = 0.9, MinDistance = 12, MaxDistance = 150 }),
	}

	model:SetAttribute("State", "Dormant")
	model:SetAttribute("Height", Config.Fawn.Height)
	CollectionService:AddTag(model, "HS_Fawn")

	return {
		Model = model,
		Root = root,
		Head = head,
		Humanoid = humanoid,
		Eye = eye,
		EyeBeam = eyeBeam,
		Sounds = sounds,
	}
end

return FawnRig
