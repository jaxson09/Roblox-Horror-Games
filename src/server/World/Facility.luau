--!strict
--[[
	Facility — builds the Marrow Creek sublevel from MapData and exposes the
	interactive pieces (doors, lockers, cages, effigies, lights, item spawns).
	Everything is generated from the ASCII map, so editing the map edits the level.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Grid = require(ReplicatedStorage.Shared.Grid)
local MapData = require(ReplicatedStorage.Shared.MapData)
local Sfx = require(ReplicatedStorage.Shared.Sfx)
local Build = require(script.Parent.Build)

local Facility = {}

export type Door = {
	Idx: number,
	Kind: string,
	Panel: Part,
	Core: Part,
	ClosedCF: CFrame,
	OpenCF: CFrame,
	Open: boolean,
	Locked: boolean,
	Prompt: ProximityPrompt,
	Position: Vector3,
}
export type Locker = {
	Idx: number,
	Model: Model,
	InsideCF: CFrame,
	ExitCF: CFrame,
	Prompt: ProximityPrompt,
	Occupant: Player?,
	Position: Vector3,
}
export type Cage = {
	Idx: number,
	Gate: Part,
	GateClosedCF: CFrame,
	GateOpenCF: CFrame,
	InsideCF: CFrame,
	ExitCF: CFrame,
	RescuePrompt: ProximityPrompt,
	KeyPrompt: ProximityPrompt,
	Occupants: { Player },
}
export type Effigy = { Kind: string, Prompt: ProximityPrompt, Root: Part, Position: Vector3 }
export type Fixture = { Part: Part, Light: PointLight, Dead: boolean, Emergency: boolean }
export type Item = { Kind: string, Root: Part, Prompt: ProximityPrompt, Idx: number, Data: string? }

export type Facility = {
	Map: Grid.Map,
	Folder: Folder,
	Dynamic: Folder,
	FloorY: number,
	Doors: { [number]: Door },
	Lockers: { Locker },
	Cages: { Cage },
	Effigies: { Effigy },
	Fixtures: { Fixture },
	BreakerPrompt: ProximityPrompt,
	BreakerSockets: { Part },
	ConsolePrompt: ProximityPrompt,
	ConsoleScreen: TextLabel,
	ConsolePosition: Vector3,
	ElevatorSpawns: { Vector3 },
	NestPosition: Vector3,
	MimicSpots: { Vector3 },
	WanderCells: { number },
	Items: { Item },
}

local CELL = Config.World.CellSize
local CEIL = Config.World.CeilingHeight
local DOOR_H = Config.World.DoorHeight
local ORIGIN = Config.World.FacilityOrigin

local C_WALL = Color3.fromRGB(46, 49, 47)
local C_TRIM = Color3.fromRGB(30, 32, 31)
local C_STEEL = Color3.fromRGB(74, 78, 80)
local C_RUST = Color3.fromRGB(92, 58, 40)
local C_LOCKER = Color3.fromRGB(58, 74, 68)
local C_HAZARD = Color3.fromRGB(196, 150, 28)
local C_BONE = Color3.fromRGB(214, 204, 178)
local C_LAMP = Color3.fromRGB(214, 226, 190)
local C_RED = Color3.fromRGB(255, 40, 30)

local FLOORS: { [string]: { Color: Color3, Material: Enum.Material } } = {
	["."] = { Color = Color3.fromRGB(58, 58, 56), Material = Enum.Material.Concrete },
	[","] = { Color = Color3.fromRGB(66, 68, 70), Material = Enum.Material.DiamondPlate },
	[":"] = { Color = Color3.fromRGB(104, 112, 104), Material = Enum.Material.CeramicTiles },
	["="] = { Color = Color3.fromRGB(70, 44, 40), Material = Enum.Material.Carpet },
}

local function at(map: Grid.Map, cx: number, cy: number, y: number): Vector3
	local x, z = Grid.cellCenter(map, cx, cy)
	return Vector3.new(x, ORIGIN.Y + y, z)
end

local function open(map: Grid.Map, cx: number, cy: number): boolean
	return Grid.inBounds(map, cx, cy) and map.Floor[Grid.index(map, cx, cy)] ~= ""
end

-- Facing for furniture that sits on a floor cell: toward open floor, wall behind.
local function faceOpen(map: Grid.Map, cx: number, cy: number, avoid: string): (number, number)
	local bestScore, bx, by = -1, 0, -1
	for _, d in Grid.Dirs do
		local fx, fy = cx + d[1], cy + d[2]
		if open(map, fx, fy) and Grid.charAt(map, fx, fy) ~= avoid then
			local score = 1
			if not open(map, cx - d[1], cy - d[2]) then
				score += 4
			end
			if score > bestScore then
				bestScore, bx, by = score, d[1], d[2]
			end
		end
	end
	return bx, by
end

-- Local frame for something in a cell: -Z looks along (dx, dy), origin on the floor.
local function frame(map: Grid.Map, cx: number, cy: number, dx: number, dy: number, forward: number): CFrame
	local base = at(map, cx, cy, 0) + Vector3.new(dx, 0, dy) * forward
	return CFrame.lookAt(base, base + Vector3.new(dx, 0, dy))
end

----------------------------------------------------------------------------
-- Shell: floors, walls, ceiling
----------------------------------------------------------------------------
local function buildShell(map: Grid.Map, folder: Folder)
	local shell = Build.folder(folder, "Shell")
	for cy = 1, map.Height do
		-- floors: merge horizontal runs of the same floor type
		local cx = 1
		while cx <= map.Width do
			local f = map.Floor[Grid.index(map, cx, cy)]
			if f ~= "" then
				local startX = cx
				while cx + 1 <= map.Width and map.Floor[Grid.index(map, cx + 1, cy)] == f do
					cx += 1
				end
				local run = cx - startX + 1
				local style = FLOORS[f]
				local mid = (at(map, startX, cy, -0.5) + at(map, cx, cy, -0.5)) / 2
				Build.block(shell, "Floor", Vector3.new(run * CELL, 1, CELL), CFrame.new(mid), style.Color, style.Material)
			end
			cx += 1
		end
		-- walls: merge horizontal runs of rock that touch something open
		cx = 1
		while cx <= map.Width do
			local function isWall(x: number): boolean
				if Grid.charAt(map, x, cy) ~= "#" then
					return false
				end
				for dy = -1, 1 do
					for dx = -1, 1 do
						if Grid.charAt(map, x + dx, cy + dy) ~= "#" then
							return true
						end
					end
				end
				return false
			end
			if isWall(cx) then
				local startX = cx
				while cx + 1 <= map.Width and isWall(cx + 1) do
					cx += 1
				end
				local run = cx - startX + 1
				local mid = (at(map, startX, cy, CEIL / 2) + at(map, cx, cy, CEIL / 2)) / 2
				Build.block(shell, "Wall", Vector3.new(run * CELL, CEIL, CELL), CFrame.new(mid), C_WALL, Enum.Material.Concrete)
				-- grimy skirting so walls read as walls in a flashlight beam
				Build.block(shell, "Skirt", Vector3.new(run * CELL + 0.1, 1.2, CELL + 0.1), CFrame.new(mid.X, ORIGIN.Y + 0.6, mid.Z), C_TRIM, Enum.Material.Concrete, { CastShadow = false })
			end
			cx += 1
		end
	end
	local w, h = map.Width * CELL, map.Height * CELL
	Build.block(shell, "Ceiling", Vector3.new(w, 1, h), CFrame.new(ORIGIN.X + w / 2, ORIGIN.Y + CEIL + 0.5, ORIGIN.Z + h / 2), C_TRIM, Enum.Material.Concrete)
	-- ceiling pipes along the corridors sell the scale
	for cy = 1, map.Height do
		local cx = 1
		while cx <= map.Width do
			if map.Cells[Grid.index(map, cx, cy)] == "." then
				local startX = cx
				while cx + 1 <= map.Width and map.Cells[Grid.index(map, cx + 1, cy)] == "." do
					cx += 1
				end
				if cx - startX >= 3 then
					local mid = (at(map, startX, cy, CEIL - 0.9) + at(map, cx, cy, CEIL - 0.9)) / 2
					Build.block(shell, "Pipe", Vector3.new((cx - startX + 1) * CELL, 0.7, 0.7), CFrame.new(mid + Vector3.new(0, 0, 2.6)), C_RUST, Enum.Material.CorrodedMetal, { CanCollide = false, CastShadow = false, Shape = Enum.PartType.Cylinder })
				end
			end
			cx += 1
		end
	end
end

----------------------------------------------------------------------------
-- Doors
----------------------------------------------------------------------------
local function buildDoor(map: Grid.Map, folder: Instance, idx: number): Door
	local cx, cy = Grid.coords(map, idx)
	local kind = map.Cells[idx]
	local alongX = open(map, cx - 1, cy) and open(map, cx + 1, cy)
	local model = Build.model(folder, "Door_" .. kind)
	local center = at(map, cx, cy, 0)
	-- rot maps "door local" (passage along local Z) into the world
	local rot = if alongX then CFrame.Angles(0, math.rad(90), 0) else CFrame.new()
	local base = CFrame.new(center) * rot

	Build.block(model, "PillarL", Vector3.new(1.5, CEIL, CELL), base * CFrame.new(-3.25, CEIL / 2, 0), C_TRIM, Enum.Material.Concrete)
	Build.block(model, "PillarR", Vector3.new(1.5, CEIL, CELL), base * CFrame.new(3.25, CEIL / 2, 0), C_TRIM, Enum.Material.Concrete)
	local lintel = Build.block(model, "Lintel", Vector3.new(5, CEIL - DOOR_H, CELL), base * CFrame.new(0, DOOR_H + (CEIL - DOOR_H) / 2, 0), C_TRIM, Enum.Material.Concrete)

	-- room names over the door, readable from the side you are walking in from
	local function nameFor(dx: number, dy: number): string?
		return Grid.regionAt(MapData.Regions, cx + dx, cy + dy)
	end
	local signOpts: Build.SignOpts = { TextColor = Color3.fromRGB(226, 214, 170), LightInfluence = 0.6, PixelsPerStud = 30 }
	-- The lintel's Front face is seen by someone walking in the + direction, so it
	-- names the room ahead of them; the Back face does the same for the way back.
	local frontName = if alongX then nameFor(1, 0) else nameFor(0, 1)
	local backName = if alongX then nameFor(-1, 0) else nameFor(0, -1)
	if frontName then
		Build.sign(lintel, Enum.NormalId.Front, frontName, Config.Fonts.Sign, signOpts)
	end
	if backName then
		Build.sign(lintel, Enum.NormalId.Back, backName, Config.Fonts.Sign, signOpts)
	end

	local thickness = if kind == "B" then 2 else 0.6
	local color = if kind == "D" then C_STEEL else Color3.fromRGB(52, 54, 58)
	local closedCF = base * CFrame.new(0, DOOR_H / 2, 0)
	local openCF = if kind == "B" then closedCF * CFrame.new(0, DOOR_H - 0.4, 0) else closedCF * CFrame.new(4.9, 0, 0)
	local panel = Build.block(model, "Panel", Vector3.new(5, DOOR_H, thickness), closedCF, color, Enum.Material.Metal)
	-- detail welded to the panel so it travels with it
	local stripeColor = if kind == "D" then C_RUST else C_HAZARD
	for _, y in { -2.5, 2.5 } do
		local stripe = Build.block(model, "Stripe", Vector3.new(5.02, 0.5, thickness + 0.06), closedCF * CFrame.new(0, y, 0), stripeColor, Enum.Material.Metal, { Anchored = false, Massless = true, CanCollide = false })
		Build.weld(panel, stripe)
	end
	if kind == "D" then
		local window = Build.block(model, "Window", Vector3.new(1.6, 1.2, thickness + 0.08), closedCF * CFrame.new(0, 1.6, 0), Color3.fromRGB(20, 26, 26), Enum.Material.Glass, { Anchored = false, Massless = true, CanCollide = false, Reflectance = 0.2 })
		Build.weld(panel, window)
	end

	local core = Build.block(model, "Core", Vector3.new(1, 1, 1), base * CFrame.new(0, 4.5, 0), C_TRIM, Enum.Material.Metal, { Transparency = 1, CanCollide = false })
	core.CanQuery = false
	Sfx.make(core, "DoorOpen", { Volume = 0.7, MaxDistance = 90 })
	Sfx.make(core, "DoorClose", { Volume = 0.7, MaxDistance = 90 })
	Sfx.make(core, "DoorSlam", { Volume = 1, MaxDistance = 160 })
	if kind == "B" then
		Sfx.make(core, "BlastDoor", { Volume = 1, MaxDistance = 400 })
	end

	local label = if kind == "D" then "Door" elseif kind == "L" then "Security Door" else "Blast Door"
	local prompt = Build.prompt(core, label, "Open", 0, 9)
	prompt.Enabled = kind == "D"

	return {
		Idx = idx,
		Kind = kind,
		Panel = panel,
		Core = core,
		ClosedCF = closedCF,
		OpenCF = openCF,
		Open = false,
		Locked = kind ~= "D",
		Prompt = prompt,
		Position = center + Vector3.new(0, 4, 0),
	}
end

-- Opens or closes a door. `slam` is the fast, loud version FAWN uses.
function Facility.setDoor(facility: Facility, door: Door, isOpen: boolean, slam: boolean?)
	if door.Open == isOpen then
		return
	end
	door.Open = isOpen
	facility.Map.Closed[door.Idx] = if isOpen then nil else true
	local duration = if door.Kind == "B" then 5 elseif slam then 0.22 else 0.7
	local style = if slam then Enum.EasingStyle.Back else Enum.EasingStyle.Quad
	TweenService:Create(door.Panel, TweenInfo.new(duration, style, Enum.EasingDirection.Out), { CFrame = if isOpen then door.OpenCF else door.ClosedCF }):Play()
	door.Prompt.ActionText = if isOpen then "Close" else "Open"
	local key = if door.Kind == "B" then "BlastDoor" elseif slam then "DoorSlam" elseif isOpen then "DoorOpen" else "DoorClose"
	local sound = door.Core:FindFirstChild(key) :: Sound?
	if sound then
		sound:Play()
	end
end

function Facility.unlockDoor(facility: Facility, door: Door, openNow: boolean)
	door.Locked = false
	facility.Map.Sealed[door.Idx] = nil
	door.Prompt.Enabled = door.Kind ~= "B"
	if openNow then
		Facility.setDoor(facility, door, true)
	end
end

----------------------------------------------------------------------------
-- Lockers, cages, effigies
----------------------------------------------------------------------------
local function buildLocker(map: Grid.Map, folder: Instance, idx: number): Locker
	local cx, cy = Grid.coords(map, idx)
	local dx, dy = Grid.mountFacing(map, idx)
	local alcove = Grid.isAlcove(map, idx)
	local model = Build.model(folder, "Locker")
	if alcove then
		-- seal the back half of the wall cell; the locker stands in the recess
		local fill = if dx ~= 0 then Vector3.new(4, CEIL, CELL) else Vector3.new(CELL, CEIL, 4)
		Build.block(model, "Fill", fill, CFrame.new(at(map, cx, cy, CEIL / 2) - Vector3.new(dx, 0, dy) * 2), C_WALL, Enum.Material.Concrete)
		-- wall cells get no floor from the shell, so the recess needs its own
		Build.block(model, "Floor", Vector3.new(CELL, 1, CELL), CFrame.new(at(map, cx, cy, -0.5)), FLOORS["."].Color, FLOORS["."].Material)
	end
	local cf = frame(map, cx, cy, dx, dy, if alcove then 1.9 else -2.2)
	local W, D, H = 4.4, 3.4, 8
	local metal = Enum.Material.Metal
	Build.block(model, "Back", Vector3.new(W, H, 0.2), cf * CFrame.new(0, H / 2, D / 2), C_LOCKER, metal)
	Build.block(model, "SideL", Vector3.new(0.2, H, D), cf * CFrame.new(-W / 2, H / 2, 0), C_LOCKER, metal)
	Build.block(model, "SideR", Vector3.new(0.2, H, D), cf * CFrame.new(W / 2, H / 2, 0), C_LOCKER, metal)
	Build.block(model, "Top", Vector3.new(W, 0.2, D), cf * CFrame.new(0, H, 0), C_LOCKER, metal)
	-- door: solid below and above, slats at eye level to peer through
	local doorLow = Build.block(model, "DoorLow", Vector3.new(W, 4.3, 0.2), cf * CFrame.new(0, 2.15, -D / 2), C_LOCKER, metal)
	Build.block(model, "DoorHigh", Vector3.new(W, 1.9, 0.2), cf * CFrame.new(0, 7.05, -D / 2), C_LOCKER, metal)
	for i = 0, 3 do
		Build.block(model, "Slat", Vector3.new(W, 0.22, 0.3), cf * CFrame.new(0, 4.52 + i * 0.44, -D / 2) * CFrame.Angles(math.rad(-25), 0, 0), C_LOCKER, metal)
	end
	Build.block(model, "Handle", Vector3.new(0.25, 1.1, 0.25), cf * CFrame.new(1.6, 3.6, -D / 2 - 0.2), C_RUST, metal, { CanCollide = false })
	Sfx.make(doorLow, "Locker", { Volume = 0.8, MaxDistance = 70 })
	local prompt = Build.prompt(doorLow, "Locker", "Hide", 0.2, 7)
	local pos = (cf * CFrame.new(0, 3, 0)).Position
	return {
		Idx = idx,
		Model = model,
		InsideCF = cf * CFrame.new(0, 3, 0.2),
		ExitCF = cf * CFrame.new(0, 3, -D / 2 - 3),
		Prompt = prompt,
		Occupant = nil,
		Position = pos,
	}
end

local function buildCage(map: Grid.Map, folder: Instance, idx: number): Cage
	local cx, cy = Grid.coords(map, idx)
	local dx, dy = faceOpen(map, cx, cy, "K")
	local cf = frame(map, cx, cy, dx, dy, 0)
	local model = Build.model(folder, "Cage")
	local bar = Enum.Material.CorrodedMetal
	for x = -3.5, 3.5, 1 do
		if math.abs(x) > 1.6 then
			Build.block(model, "Bar", Vector3.new(0.35, CEIL, 0.35), cf * CFrame.new(x, CEIL / 2, -3.6), C_RUST, bar)
		end
	end
	Build.block(model, "Header", Vector3.new(3.6, CEIL - 9, 0.35), cf * CFrame.new(0, 9 + (CEIL - 9) / 2, -3.6), C_RUST, bar)
	for _, side in { -1, 1 } do
		Build.block(model, "Mesh", Vector3.new(0.3, CEIL, 7.6), cf * CFrame.new(side * 3.95, CEIL / 2, 0.2), C_STEEL, Enum.Material.DiamondPlate)
	end
	local gateCF = cf * CFrame.new(0, 4.5, -3.6)
	local gate = Build.block(model, "Gate", Vector3.new(3.4, 9, 0.4), gateCF, C_RUST, bar, { Transparency = 1 })
	for x = -1.4, 1.4, 0.7 do
		local b = Build.block(model, "GateBar", Vector3.new(0.3, 9, 0.3), gateCF * CFrame.new(x, 0, 0), C_RUST, bar, { Anchored = false, Massless = true, CanCollide = false })
		Build.weld(gate, b)
	end
	Sfx.make(gate, "CageRattle", { Volume = 0.8, MaxDistance = 90 })
	Sfx.make(gate, "CageOpen", { Volume = 0.9, MaxDistance = 110 })
	local rescue = Build.prompt(gate, "Cage", "Free", Config.Shift.RescueHold, 8)
	rescue.Enabled = false

	-- "a key, just within reach" — the diegetic self-revive
	local key = Build.block(model, "RustedKey", Vector3.new(0.25, 0.9, 0.12), cf * CFrame.new(2.6, 3.6, 3.5) * CFrame.Angles(0, 0, math.rad(20)), Color3.fromRGB(150, 110, 60), Enum.Material.Metal, { CanCollide = false })
	Build.pointLight(key, Color3.fromRGB(255, 190, 110), 0.5, 5)
	local keyPrompt = Build.prompt(key, Config.Products.Revive.Name, "Take", 0.6, 7)
	keyPrompt.Enabled = false
	keyPrompt:SetAttribute("Product", "Revive")
	keyPrompt:SetAttribute("CagedOnly", true)
	keyPrompt.Exclusivity = Enum.ProximityPromptExclusivity.AlwaysShow -- never loses the E key to the gate prompt
	rescue:SetAttribute("HideWhenCaged", true)

	return {
		Idx = idx,
		Gate = gate,
		GateClosedCF = gateCF,
		GateOpenCF = gateCF * CFrame.new(0, 8.4, 0),
		InsideCF = cf * CFrame.new(0, 3, 0.6),
		ExitCF = cf * CFrame.new(0, 3, -8),
		RescuePrompt = rescue,
		KeyPrompt = keyPrompt,
		Occupants = {},
	}
end

function Facility.setCageOpen(cage: Cage, isOpen: boolean)
	TweenService:Create(cage.Gate, TweenInfo.new(0.5, Enum.EasingStyle.Quad), { CFrame = if isOpen then cage.GateOpenCF else cage.GateClosedCF }):Play()
	local sound = cage.Gate:FindFirstChild(if isOpen then "CageOpen" else "CageRattle") :: Sound?
	if sound then
		sound:Play()
	end
end

local EFFIGY_KINDS = { ["1"] = "DeadAir", ["2"] = "ReviveAll", ["3"] = "ScareAll", ["4"] = "Sight" }

-- A deer skull wired to the wall. The same model hangs in the lobby.
function Facility.buildSkull(parent: Instance, cf: CFrame, scale: number): Part
	local bone = Enum.Material.Sandstone
	local function s(v: Vector3): Vector3
		return v * scale
	end
	local function p(x: number, y: number, z: number): CFrame
		return cf * CFrame.new(x * scale, y * scale, z * scale)
	end
	local cranium = Build.block(parent, "Cranium", s(Vector3.new(1.5, 1.4, 0.9)), p(0, 0.5, 0), C_BONE, bone, { CanCollide = false })
	Build.block(parent, "Snout", s(Vector3.new(0.9, 1.6, 0.7)), p(0, -0.8, -0.15) * CFrame.Angles(math.rad(12), 0, 0), C_BONE, bone, { CanCollide = false })
	Build.block(parent, "Nose", s(Vector3.new(0.55, 0.5, 0.5)), p(0, -1.75, -0.35), Color3.fromRGB(60, 50, 44), bone, { CanCollide = false })
	for _, side in { -1, 1 } do
		local socket = Build.block(parent, "Socket", s(Vector3.new(0.42, 0.42, 0.3)), p(side * 0.45, 0.4, -0.42), Color3.fromRGB(10, 6, 6), Enum.Material.SmoothPlastic, { CanCollide = false, Shape = Enum.PartType.Ball })
		socket.Name = "Socket"
		-- antlers: three crooked segments each
		local a1 = p(side * 0.7, 1.3, 0) * CFrame.Angles(0, 0, math.rad(-side * 28))
		Build.block(parent, "Antler", s(Vector3.new(0.18, 1.6, 0.18)), a1 * CFrame.new(0, 0.6 * scale, 0), C_BONE, bone, { CanCollide = false })
		local a2 = a1 * CFrame.new(0, 1.4 * scale, 0) * CFrame.Angles(0, 0, math.rad(-side * 30))
		Build.block(parent, "Antler", s(Vector3.new(0.15, 1.2, 0.15)), a2 * CFrame.new(0, 0.5 * scale, 0), C_BONE, bone, { CanCollide = false })
		local a3 = a1 * CFrame.new(0, 0.9 * scale, 0) * CFrame.Angles(0, 0, math.rad(side * 40))
		Build.block(parent, "Antler", s(Vector3.new(0.13, 0.9, 0.13)), a3 * CFrame.new(0, 0.45 * scale, 0), C_BONE, bone, { CanCollide = false })
	end
	return cranium
end

local function buildEffigy(map: Grid.Map, folder: Instance, idx: number): Effigy
	local cx, cy = Grid.coords(map, idx)
	local dx, dy = Grid.mountFacing(map, idx)
	local kind = EFFIGY_KINDS[map.Cells[idx]]
	local model = Build.model(folder, "Effigy_" .. kind)
	local fill = if dx ~= 0 then Vector3.new(6.5, CEIL, CELL) else Vector3.new(CELL, CEIL, 6.5)
	Build.block(model, "Fill", fill, CFrame.new(at(map, cx, cy, CEIL / 2) - Vector3.new(dx, 0, dy) * 0.75), C_WALL, Enum.Material.Concrete)
	Build.block(model, "Floor", Vector3.new(CELL, 1, CELL), CFrame.new(at(map, cx, cy, -0.5)), FLOORS["."].Color, FLOORS["."].Material)
	local cf = frame(map, cx, cy, dx, dy, 2.9) * CFrame.new(0, 5.6, 0)
	-- scorched plate, wire, and the skull
	Build.block(model, "Plate", Vector3.new(4.2, 5.4, 0.2), cf * CFrame.new(0, 0, 0.3), Color3.fromRGB(22, 18, 18), Enum.Material.Slate, { CanCollide = false })
	local skull = Facility.buildSkull(model, cf, 1.15)
	for _, x in { -1.5, 1.5 } do
		local candle = Build.block(model, "Candle", Vector3.new(0.3, 0.7, 0.3), cf * CFrame.new(x, -2.9, 0), Color3.fromRGB(196, 186, 160), Enum.Material.SmoothPlastic, { CanCollide = false })
		local flame = Build.block(model, "Flame", Vector3.new(0.14, 0.26, 0.14), cf * CFrame.new(x, -2.45, 0), Color3.fromRGB(255, 150, 60), Enum.Material.Neon, { CanCollide = false })
		Build.pointLight(flame, Color3.fromRGB(255, 120, 50), 0.9, 9)
		CollectionService:AddTag(flame, "HS_Candle")
		Build.weld(candle, flame)
	end
	Build.block(model, "Shelf", Vector3.new(4.2, 0.2, 0.9), cf * CFrame.new(0, -3.35, 0), C_RUST, Enum.Material.Wood, { CanCollide = false })
	Sfx.make(skull, "Effigy", { Volume = 0.35, Looped = true, MaxDistance = 28 }):Play()

	local product = Config.Products[kind]
	local prompt = Build.prompt(skull, product.Name, "Leave an offering", 0.5, 7)
	prompt:SetAttribute("Product", kind)
	return { Kind = kind, Prompt = prompt, Root = skull, Position = skull.Position }
end

----------------------------------------------------------------------------
-- Fixed props: breaker, console, elevator bay, exit, nest, candidate crates
----------------------------------------------------------------------------
local function buildBreaker(map: Grid.Map, folder: Instance, idx: number): (ProximityPrompt, { Part })
	local cx, cy = Grid.coords(map, idx)
	local dx, dy = faceOpen(map, cx, cy, "X")
	local cf = frame(map, cx, cy, dx, dy, 0)
	local model = Build.model(folder, "Breaker")
	local box = Build.block(model, "Box", Vector3.new(4.5, 5.5, 1), cf * CFrame.new(0, 5, 3.4), Color3.fromRGB(64, 70, 66), Enum.Material.Metal)
	Build.sign(Build.block(model, "Label", Vector3.new(4, 0.9, 0.1), cf * CFrame.new(0, 7.1, 2.85), C_HAZARD, Enum.Material.Metal, { CanCollide = false }), Enum.NormalId.Front, "MAIN BREAKER", Config.Fonts.Sign, { TextColor = Color3.new(0, 0, 0), LightInfluence = 0.7 })
	local sockets = {}
	for i = 1, Config.Shift.FusesNeeded do
		local x = (i - (Config.Shift.FusesNeeded + 1) / 2) * 1.2
		local socket = Build.block(model, "Socket", Vector3.new(0.6, 1.6, 0.6), cf * CFrame.new(x, 5, 2.75), Color3.fromRGB(24, 24, 24), Enum.Material.Glass, { CanCollide = false })
		table.insert(sockets, socket)
	end
	Sfx.make(box, "FuseInsert", { Volume = 0.9, MaxDistance = 80 })
	Sfx.make(box, "PowerUp", { Volume = 1, MaxDistance = 500, MinDistance = 60 })
	local prompt = Build.prompt(box, "Main Breaker", "Install fuses", 2.5, 9)
	prompt.Enabled = false
	return prompt, sockets
end

local function buildConsole(map: Grid.Map, folder: Instance, idx: number): (ProximityPrompt, TextLabel, Vector3)
	local cx, cy = Grid.coords(map, idx)
	local dx, dy = faceOpen(map, cx, cy, "C")
	local cf = frame(map, cx, cy, dx, dy, 0)
	local model = Build.model(folder, "Console")
	local desk = Build.block(model, "Desk", Vector3.new(7.4, 3.2, 3), cf * CFrame.new(0, 1.6, 0), Color3.fromRGB(56, 60, 58), Enum.Material.Metal)
	local screen = Build.block(model, "Screen", Vector3.new(3.4, 2.4, 0.3), cf * CFrame.new(-1.6, 4.6, 0.6) * CFrame.Angles(math.rad(-8), 0, 0), Color3.fromRGB(8, 16, 12), Enum.Material.Glass, { CanCollide = false })
	Build.block(model, "ScreenBody", Vector3.new(3.8, 2.8, 2), cf * CFrame.new(-1.6, 4.6, 1.75), Color3.fromRGB(70, 68, 60), Enum.Material.Plastic)
	local label = Build.sign(screen, Enum.NormalId.Front, "RECALL TONE\nNO POWER", Config.Fonts.Mono, { TextColor = Config.Colors.Phosphor, LightInfluence = 0, Brightness = 1.6, PixelsPerStud = 36, Background = Color3.fromRGB(4, 12, 8), BackgroundTransparency = 0 })
	Build.pointLight(screen, Config.Colors.Phosphor, 0.6, 12)
	-- reel-to-reel deck
	Build.block(model, "Deck", Vector3.new(3, 3, 1.2), cf * CFrame.new(2, 4.7, 0.8), Color3.fromRGB(40, 40, 42), Enum.Material.Metal, { CanCollide = false })
	for _, x in { 1.3, 2.7 } do
		local reel = Build.block(model, "Reel", Vector3.new(0.25, 1.2, 1.2), cf * CFrame.new(x, 5.2, 0.1) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(150, 150, 140), Enum.Material.Metal, { CanCollide = false, Shape = Enum.PartType.Cylinder })
		CollectionService:AddTag(reel, "HS_Reel")
	end
	Sfx.make(desk, "BroadcastTone", { Volume = 0.8, Looped = true, MaxDistance = 260, MinDistance = 25 })
	Sfx.make(desk, "TapeStart", { Volume = 0.8, MaxDistance = 80 })
	local prompt = Build.prompt(desk, "Broadcast Console", "Load reels", 2, 9)
	prompt.Enabled = false
	return prompt, label, desk.Position
end

local function buildSetPieces(map: Grid.Map, folder: Folder, facility: Facility)
	local props = Build.folder(folder, "Props")
	-- elevator cage around the arrival cells
	local eCells = map.Markers["E"] or {}
	if #eCells > 0 then
		local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
		for _, idx in eCells do
			local cx, cy = Grid.coords(map, idx)
			minX, minY, maxX, maxY = math.min(minX, cx), math.min(minY, cy), math.max(maxX, cx), math.max(maxY, cy)
			table.insert(facility.ElevatorSpawns, at(map, cx, cy, 3))
		end
		local a, b = at(map, minX, minY, 0), at(map, maxX, maxY, 0)
		local mid = (a + b) / 2
		local sx, sz = (maxX - minX + 1) * CELL, (maxY - minY + 1) * CELL
		Build.block(props, "ElevatorPlate", Vector3.new(sx, 0.2, sz), CFrame.new(mid + Vector3.new(0, 0.1, 0)), C_HAZARD, Enum.Material.DiamondPlate)
		for _, ox in { -1, 1 } do
			for _, oz in { -1, 1 } do
				Build.block(props, "ElevatorPost", Vector3.new(0.8, CEIL, 0.8), CFrame.new(mid + Vector3.new(ox * (sx / 2 - 0.4), CEIL / 2, oz * (sz / 2 - 0.4))), C_STEEL, Enum.Material.Metal)
			end
		end
		local lamp = Build.block(props, "ElevatorLamp", Vector3.new(2, 0.3, 2), CFrame.new(mid + Vector3.new(0, CEIL - 0.2, 0)), C_RED, Enum.Material.Neon, { CanCollide = false })
		local light = Build.pointLight(lamp, C_RED, 1.1, 30, true)
		table.insert(facility.Fixtures, { Part = lamp, Light = light, Dead = false, Emergency = true })
		local sign = Build.block(props, "ElevatorSign", Vector3.new(10, 1.6, 0.2), CFrame.new(mid + Vector3.new(0, 9, sz / 2 - 0.3)), Color3.fromRGB(20, 20, 20), Enum.Material.Metal, { CanCollide = false })
		Build.sign(sign, Enum.NormalId.Front, "FREIGHT 01 — RETURNS AT END OF SHIFT", Config.Fonts.Sign, { TextColor = C_HAZARD, LightInfluence = 0.3 })
	end

	-- the way out: a ladder under a shaft of surface light
	local zCells = map.Markers["Z"] or {}
	for i, idx in zCells do
		local cx, cy = Grid.coords(map, idx)
		if i == #zCells then
			local base = at(map, cx, cy, 0)
			local ladder = Instance.new("TrussPart")
			ladder.Name = "SurfaceLadder"
			ladder.Size = Vector3.new(2, CEIL, 2)
			ladder.CFrame = CFrame.new(base + Vector3.new(2.5, CEIL / 2, 0))
			ladder.Color = C_RUST
			ladder.Anchored = true
			ladder.Parent = props
			local shaft = Build.block(props, "SurfaceLight", Vector3.new(5, 0.3, 5), CFrame.new(base + Vector3.new(0, CEIL - 0.2, 0)), Color3.fromRGB(190, 210, 255), Enum.Material.Neon, { CanCollide = false })
			Build.spotLight(shaft, Enum.NormalId.Bottom, Color3.fromRGB(190, 210, 255), 4, 40, 70, true)
			local sign = Build.block(props, "SurfaceSign", Vector3.new(0.2, 2, 6), CFrame.new(base + Vector3.new(3.8, 8, 0)), Color3.fromRGB(16, 40, 22), Enum.Material.Metal, { CanCollide = false })
			Build.sign(sign, Enum.NormalId.Left, "SURFACE", Config.Fonts.Sign, { TextColor = Color3.fromRGB(190, 255, 200), LightInfluence = 0.2 })
		end
	end

	-- FAWN's nest: a heap of what it has collected
	local sCells = map.Markers["S"] or {}
	if sCells[1] then
		local cx, cy = Grid.coords(map, sCells[1])
		facility.NestPosition = at(map, cx, cy, 0)
		local rng = Random.new(41)
		for _ = 1, 9 do
			local offset = Vector3.new(rng:NextNumber(-5, 5), 0.4, rng:NextNumber(-5, 5))
			Build.block(props, "Hide", Vector3.new(rng:NextNumber(2, 4), 0.5, rng:NextNumber(2, 4)), CFrame.new(facility.NestPosition + offset) * CFrame.Angles(0, rng:NextNumber(0, 6), rng:NextNumber(-0.15, 0.15)), Color3.fromRGB(74, 52, 38), Enum.Material.Fabric, { CanCollide = false })
		end
		for _ = 1, 4 do
			local offset = Vector3.new(rng:NextNumber(-6, 6), 1.2, rng:NextNumber(-6, 6))
			Facility.buildSkull(props, CFrame.new(facility.NestPosition + offset) * CFrame.Angles(rng:NextNumber(-1.4, -0.9), rng:NextNumber(0, 6), 0), 0.8)
		end
		local scrawl = Build.block(props, "NestScrawl", Vector3.new(0.2, 4, 12), CFrame.new(facility.NestPosition + Vector3.new(-19.8, 6, 0)), C_WALL, Enum.Material.Concrete, { CanCollide = false, Transparency = 1 })
		Build.sign(scrawl, Enum.NormalId.Right, "SHE IS TRYING TO LOOK LIKE US", Config.Fonts.Scrawl, { TextColor = Color3.fromRGB(120, 16, 16), LightInfluence = 1 })
	end

	for _, idx in map.Markers["m"] or {} do
		local cx, cy = Grid.coords(map, idx)
		table.insert(facility.MimicSpots, at(map, cx, cy, 0))
	end

	-- crates/shelves under every candidate spawn so items sit at hand height
	for _, ch in { "F", "T", "b", "n" } do
		for _, idx in map.Markers[ch] or {} do
			local cx, cy = Grid.coords(map, idx)
			local ox = if not open(map, cx - 1, cy) then -1 elseif not open(map, cx + 1, cy) then 1 else -1
			local oz = if not open(map, cx, cy - 1) then -1 elseif not open(map, cx, cy + 1) then 1 else -1
			local base = at(map, cx, cy, 0) + Vector3.new(ox * 2.6, 0, oz * 2.6)
			local isShelf = ch == "T"
			local size = if isShelf then Vector3.new(2.6, 3.4, 2.6) else Vector3.new(2.4, 2.4, 2.4)
			local color = if isShelf then C_STEEL else Color3.fromRGB(88, 66, 44)
			local material = if isShelf then Enum.Material.Metal else Enum.Material.WoodPlanks
			local crate = Build.block(props, "Stand_" .. ch, size, CFrame.new(base + Vector3.new(0, size.Y / 2, 0)) * CFrame.Angles(0, ((cx * 7 + cy * 13) % 5 - 2) * 0.09, 0), color, material, { Group = Build.Groups.Props })
			crate:SetAttribute("Cell", idx)
		end
	end
end

----------------------------------------------------------------------------
-- Lights
----------------------------------------------------------------------------
local function buildLights(map: Grid.Map, folder: Folder, facility: Facility)
	local lights = Build.folder(folder, "Lights")
	local rng = Random.new(1989)
	for cy = 1, map.Height do
		for cx = 1, map.Width do
			local idx = Grid.index(map, cx, cy)
			local ch = map.Cells[idx]
			local f = map.Floor[idx]
			if f ~= "" and not Grid.isDoorChar(ch) then
				local want = if f == "." then (cx + cy) % 4 == 0 else (cx % 3 == 0 and cy % 3 == 0)
				if want then
					local alongX = open(map, cx - 1, cy) and open(map, cx + 1, cy)
					local size = if alongX then Vector3.new(3.4, 0.25, 0.9) else Vector3.new(0.9, 0.25, 3.4)
					local part = Build.block(lights, "Lamp", size, CFrame.new(at(map, cx, cy, CEIL - 0.13)), Color3.fromRGB(40, 42, 40), Enum.Material.SmoothPlastic, { CanCollide = false, CastShadow = false })
					local roll = rng:NextNumber()
					local light = Build.pointLight(part, C_LAMP, 0.85, 22, roll > 0.8)
					light.Enabled = false
					local dead = roll < 0.3
					if not dead and roll < 0.5 then
						CollectionService:AddTag(part, "HS_Flicker")
					end
					table.insert(facility.Fixtures, { Part = part, Light = light, Dead = dead, Emergency = false })
				end
			elseif ch == "B" or ch == "L" then
				local part = Build.block(lights, "Beacon", Vector3.new(0.8, 0.5, 0.8), CFrame.new(at(map, cx, cy, CEIL - 0.3)), C_RED, Enum.Material.Neon, { CanCollide = false, CastShadow = false })
				local light = Build.pointLight(part, C_RED, 0.8, 16)
				table.insert(facility.Fixtures, { Part = part, Light = light, Dead = false, Emergency = true })
			end
		end
	end
end

function Facility.setPower(facility: Facility, on: boolean)
	for _, fx in facility.Fixtures do
		if not fx.Emergency then
			local lit = on and not fx.Dead
			fx.Light.Enabled = lit
			fx.Light.Color = C_LAMP
			fx.Part.Material = if lit then Enum.Material.Neon else Enum.Material.SmoothPlastic
			fx.Part.Color = if lit then C_LAMP else Color3.fromRGB(40, 42, 40)
			fx.Part:SetAttribute("Lit", lit)
		end
	end
end

function Facility.setAlarm(facility: Facility, on: boolean)
	for _, fx in facility.Fixtures do
		if not fx.Emergency and not fx.Dead then
			fx.Light.Color = if on then C_RED else C_LAMP
			fx.Part.Color = if on then C_RED else C_LAMP
		end
	end
end

----------------------------------------------------------------------------
-- Per-shift items
----------------------------------------------------------------------------
local function standTop(facility: Facility, idx: number): Vector3
	for _, child in (facility.Folder:FindFirstChild("Props") :: Folder):GetChildren() do
		if child:GetAttribute("Cell") == idx and child:IsA("BasePart") then
			local stand = child :: BasePart
			return stand.Position + Vector3.new(0, stand.Size.Y / 2, 0)
		end
	end
	local cx, cy = Grid.coords(facility.Map, idx)
	return at(facility.Map, cx, cy, 0)
end

local function pick(list: { number }, count: number, rng: Random): { number }
	local pool = table.clone(list)
	local out = {}
	for _ = 1, math.min(count, #pool) do
		local i = rng:NextInteger(1, #pool)
		table.insert(out, pool[i])
		pool[i] = pool[#pool]
		pool[#pool] = nil
	end
	return out
end

local function makeItem(facility: Facility, kind: string, idx: number, data: string?): Item
	local top = standTop(facility, idx)
	local root: Part
	local prompt: ProximityPrompt
	if kind == "Fuse" then
		root = Build.block(facility.Dynamic, "Fuse", Vector3.new(1.5, 0.7, 0.7), CFrame.new(top + Vector3.new(0, 0.4, 0)) * CFrame.Angles(0, 0.6, 0), Config.Colors.Amber, Enum.Material.Neon, { CanCollide = false, Shape = Enum.PartType.Cylinder })
		Build.pointLight(root, Config.Colors.Amber, 0.8, 9)
		prompt = Build.prompt(root, "Fuse", "Take", 0.3, 8)
	elseif kind == "Reel" then
		root = Build.block(facility.Dynamic, "Reel", Vector3.new(0.5, 2.2, 2.2), CFrame.new(top + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(34, 34, 36), Enum.Material.Metal, { CanCollide = false, Shape = Enum.PartType.Cylinder })
		local led = Build.block(root, "ReelLed", Vector3.new(0.3, 0.3, 0.3), CFrame.new(top + Vector3.new(0.9, 0.7, 0.9)), C_RED, Enum.Material.Neon, { CanCollide = false, Anchored = false, Massless = true })
		Build.weld(root, led)
		Build.pointLight(led, C_RED, 0.6, 7)
		prompt = Build.prompt(root, "Voice Reel", "Take", 0.6, 8)
		prompt.Enabled = false -- reel cases unseal when the power returns
	elseif kind == "Battery" then
		root = Build.block(facility.Dynamic, "Battery", Vector3.new(0.6, 1, 0.6), CFrame.new(top + Vector3.new(0, 0.5, 0)), Color3.fromRGB(210, 190, 40), Enum.Material.Metal, { CanCollide = false })
		Build.pointLight(root, Config.Colors.Phosphor, 0.35, 6)
		prompt = Build.prompt(root, "Battery", "Take", 0.2, 8)
	else
		root = Build.block(facility.Dynamic, "Note", Vector3.new(1.3, 0.05, 1.7), CFrame.new(top + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, 0.4, 0), Config.Colors.Paper, Enum.Material.SmoothPlastic, { CanCollide = false })
		Build.pointLight(root, Config.Colors.Paper, 0.25, 5)
		prompt = Build.prompt(root, "Paper", "Read", 0.2, 8)
	end
	root:SetAttribute("ItemKind", kind)
	CollectionService:AddTag(root, "HS_Item")
	Sfx.make(root, "Pickup", { Volume = 0.6, MaxDistance = 50 })
	local item: Item = { Kind = kind, Root = root, Prompt = prompt, Idx = idx, Data = data }
	table.insert(facility.Items, item)
	return item
end

-- Clears last shift's items and scatters a fresh set. Returns the new items.
function Facility.spawnItems(facility: Facility, rng: Random, noteIds: { string }): { Item }
	facility.Dynamic:ClearAllChildren()
	table.clear(facility.Items)
	local markers = facility.Map.Markers
	for _, idx in pick(markers["F"] or {}, Config.Shift.FusesNeeded, rng) do
		makeItem(facility, "Fuse", idx)
	end
	for _, idx in pick(markers["T"] or {}, Config.Shift.TapesNeeded, rng) do
		makeItem(facility, "Reel", idx)
	end
	for _, idx in pick(markers["b"] or {}, Config.Shift.BatteriesSpawned, rng) do
		makeItem(facility, "Battery", idx)
	end
	local noteCells = pick(markers["n"] or {}, math.min(Config.Shift.NotesSpawned, #noteIds), rng)
	for i, idx in noteCells do
		makeItem(facility, "Note", idx, noteIds[i])
	end
	return facility.Items
end

-- Puts every door, light, cage and locker back to its start-of-shift state.
function Facility.reset(facility: Facility)
	for _, door in facility.Doors do
		Facility.setDoor(facility, door, false)
		door.Locked = door.Kind ~= "D"
		facility.Map.Sealed[door.Idx] = if door.Locked then true else nil
		door.Prompt.Enabled = door.Kind == "D"
	end
	for _, cage in facility.Cages do
		table.clear(cage.Occupants)
		cage.RescuePrompt.Enabled = false
		cage.KeyPrompt.Enabled = false
		Facility.setCageOpen(cage, false)
	end
	for _, locker in facility.Lockers do
		locker.Occupant = nil
		locker.Prompt.Enabled = true
	end
	for _, socket in facility.BreakerSockets do
		socket.Color = Color3.fromRGB(24, 24, 24)
		socket.Material = Enum.Material.Glass
	end
	facility.BreakerPrompt.Enabled = false
	facility.ConsolePrompt.Enabled = false
	facility.ConsoleScreen.Text = "RECALL TONE\nNO POWER"
	Facility.setAlarm(facility, false)
	Facility.setPower(facility, false)
	facility.Dynamic:ClearAllChildren()
	table.clear(facility.Items)
end

function Facility.cellPosition(facility: Facility, idx: number, y: number): Vector3
	local cx, cy = Grid.coords(facility.Map, idx)
	return at(facility.Map, cx, cy, y)
end

function Facility.cellOf(facility: Facility, position: Vector3): (number, number)
	return Grid.worldToCell(facility.Map, position.X, position.Z)
end

-- Is a world position inside the sublevel volume?
function Facility.contains(position: Vector3): boolean
	return position.Y < ORIGIN.Y + CEIL + 20 and position.Y > ORIGIN.Y - 30
end

function Facility.build(parent: Instance): Facility
	Build.setupCollisionGroups()
	local map = Grid.parse(MapData.Rows, CELL, ORIGIN.X, ORIGIN.Z)
	local folder = Build.folder(parent, "Facility")
	local facility: Facility = {
		Map = map,
		Folder = folder,
		Dynamic = Build.folder(folder, "Dynamic"),
		FloorY = ORIGIN.Y,
		Doors = {},
		Lockers = {},
		Cages = {},
		Effigies = {},
		Fixtures = {},
		BreakerPrompt = nil :: any,
		BreakerSockets = {},
		ConsolePrompt = nil :: any,
		ConsoleScreen = nil :: any,
		ConsolePosition = Vector3.zero,
		ElevatorSpawns = {},
		NestPosition = Vector3.zero,
		MimicSpots = {},
		WanderCells = {},
		Items = {},
	}

	buildShell(map, folder)

	local doors = Build.folder(folder, "Doors")
	for _, ch in { "D", "L", "B" } do
		for _, idx in map.Markers[ch] or {} do
			facility.Doors[idx] = buildDoor(map, doors, idx)
		end
	end
	local lockers = Build.folder(folder, "Lockers")
	for _, idx in map.Markers["H"] or {} do
		table.insert(facility.Lockers, buildLocker(map, lockers, idx))
	end
	local cages = Build.folder(folder, "Cages")
	for _, idx in map.Markers["K"] or {} do
		table.insert(facility.Cages, buildCage(map, cages, idx))
	end
	local effigies = Build.folder(folder, "Effigies")
	for ch in EFFIGY_KINDS do
		for _, idx in map.Markers[ch] or {} do
			table.insert(facility.Effigies, buildEffigy(map, effigies, idx))
		end
	end
	local breakerCells = map.Markers["X"] or {}
	facility.BreakerPrompt, facility.BreakerSockets = buildBreaker(map, folder, breakerCells[1])
	local consoleCells = map.Markers["C"] or {}
	facility.ConsolePrompt, facility.ConsoleScreen, facility.ConsolePosition = buildConsole(map, folder, consoleCells[1])

	buildSetPieces(map, folder, facility)
	buildLights(map, folder, facility)

	-- cells FAWN wanders between: every plain room/corridor cell
	for idx, f in map.Floor do
		if f ~= "" and Grid.isFloorChar(map.Cells[idx]) then
			local _, cy = Grid.coords(map, idx)
			if cy > 4 then -- it does not patrol the surface tunnel
				table.insert(facility.WanderCells, idx)
			end
		end
	end
	return facility
end

return Facility
