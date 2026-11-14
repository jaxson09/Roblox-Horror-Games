--!strict
--[[
	Facility — builds Meridian General's Ward C from MapData and exposes the
	interactive pieces: doors, lockers, tube stations, dispensers, filing
	cabinets, recovery beds, the elevator, and the lights.

	The look is deliberately plain and nearly colourless — two-tone walls,
	vinyl floor, ceiling light panels — because the lighting does the work:
	pools of hard fluorescent light, and black between them.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Grid = require(ReplicatedStorage.Shared.Grid)
local MapData = require(ReplicatedStorage.Shared.MapData)
local Sfx = require(ReplicatedStorage.Shared.Sfx)
local Build = require(script.Parent.Build)
local Furnish = require(script.Parent.Furnish)

local Facility = {}

export type Door = { Idx: number, Panel: Part, Core: Part, ClosedCF: CFrame, OpenCF: CFrame, Open: boolean, Prompt: ProximityPrompt, Position: Vector3 }
export type Locker = { Idx: number, Model: Model, InsideCF: CFrame, ExitCF: CFrame, Prompt: ProximityPrompt, Occupant: Player?, Position: Vector3 }
export type Station = { Idx: number, Root: Part, Lamp: Part, Prompt: ProximityPrompt, Left: number, Position: Vector3 }
export type Dispenser = { Kind: string, Root: Part, Prompt: ProximityPrompt, Position: Vector3 }
export type Cabinet = { Idx: number, Root: Part, Drawer: Part, Prompt: ProximityPrompt, File: string?, Position: Vector3 }
export type Bed = { Idx: number, WakeCF: CFrame, Position: Vector3 }
export type Fixture = { Part: Part, Light: PointLight, Dead: boolean, Emergency: boolean }
export type Item = { Kind: string, Root: Part, Prompt: ProximityPrompt, Idx: number }

export type Facility = {
	Map: Grid.Map,
	Folder: Folder,
	Dynamic: Folder,
	FloorY: number,
	Doors: { [number]: Door },
	Lockers: { Locker },
	Stations: { Station },
	Dispensers: { Dispenser },
	Cabinets: { Cabinet },
	Beds: { Bed },
	Fixtures: { Fixture },
	ElevatorSpawns: { Vector3 },
	ElevatorPosition: Vector3,
	ElevatorLamp: Part?,
	ElevatorLabel: TextLabel?,
	NestPosition: Vector3,
	MimicSpots: { Vector3 },
	WanderCells: { number },
	Items: { Item },
}

local CELL = Config.World.CellSize
local CEIL = Config.World.CeilingHeight
local DOOR_H = Config.World.DoorHeight
local ORIGIN = Config.World.FacilityOrigin

local C_WALL = Color3.fromRGB(146, 148, 142) -- upper wall
local C_BAND = Color3.fromRGB(84, 100, 96) -- painted lower third
local C_TRIM = Color3.fromRGB(44, 46, 46)
local C_CEIL = Color3.fromRGB(104, 104, 100)
local C_STEEL = Color3.fromRGB(120, 124, 126)
local C_DOOR = Color3.fromRGB(110, 96, 78)
local C_LOCKER = Color3.fromRGB(86, 104, 110)
local C_LAMP = Color3.fromRGB(236, 240, 232)
local C_RED = Color3.fromRGB(255, 40, 30)
local C_GREEN = Color3.fromRGB(90, 255, 140)

local FLOORS: { [string]: { Color: Color3, Material: Enum.Material } } = {
	["."] = { Color = Color3.fromRGB(96, 98, 94), Material = Enum.Material.SmoothPlastic },
	[","] = { Color = Color3.fromRGB(78, 80, 80), Material = Enum.Material.Concrete },
	[":"] = { Color = Color3.fromRGB(118, 124, 120), Material = Enum.Material.CeramicTiles },
	["="] = { Color = Color3.fromRGB(70, 66, 62), Material = Enum.Material.Carpet },
}

local function at(map: Grid.Map, cx: number, cy: number, y: number): Vector3
	local x, z = Grid.cellCenter(map, cx, cy)
	return Vector3.new(x, ORIGIN.Y + y, z)
end

local function open(map: Grid.Map, cx: number, cy: number): boolean
	return Grid.inBounds(map, cx, cy) and map.Floor[Grid.index(map, cx, cy)] ~= ""
end

-- Facing for furniture that sits on a floor cell: toward open floor, wall behind.
local function faceOpen(map: Grid.Map, cx: number, cy: number): (number, number)
	local bestScore, bx, by = -1, 0, -1
	for _, d in Grid.Dirs do
		local fx, fy = cx + d[1], cy + d[2]
		if open(map, fx, fy) and Grid.isWalkable(map, fx, fy) then
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

-- Wall-mounted things replace a wall cell: seal the back, floor the recess.
local function alcove(map: Grid.Map, model: Instance, idx: number, dx: number, dy: number, depth: number)
	local cx, cy = Grid.coords(map, idx)
	local fill = if dx ~= 0 then Vector3.new(CELL - depth, CEIL, CELL) else Vector3.new(CELL, CEIL, CELL - depth)
	Build.block(model, "Fill", fill, CFrame.new(at(map, cx, cy, CEIL / 2) - Vector3.new(dx, 0, dy) * (depth / 2)), C_WALL, Enum.Material.Plaster)
	Build.block(model, "Floor", Vector3.new(CELL, 1, CELL), CFrame.new(at(map, cx, cy, -0.5)), FLOORS["."].Color, FLOORS["."].Material)
end

----------------------------------------------------------------------------
-- Shell: floors, two-tone walls, ceiling
----------------------------------------------------------------------------
local function buildShell(map: Grid.Map, folder: Folder)
	local shell = Build.folder(folder, "Shell")
	for cy = 1, map.Height do
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
				local floor = Build.block(shell, "Floor", Vector3.new(run * CELL, 1, CELL), CFrame.new(mid), style.Color, style.Material)
				if f == "." then
					floor.Reflectance = 0.06 -- waxed vinyl catches the flashlight
				end
			end
			cx += 1
		end
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
				Build.block(shell, "Wall", Vector3.new(run * CELL, CEIL, CELL), CFrame.new(mid), C_WALL, Enum.Material.Plaster)
				-- the institutional painted band, a handrail line, and a scuffed skirting
				Build.block(shell, "Band", Vector3.new(run * CELL + 0.08, 4.2, CELL + 0.08), CFrame.new(mid.X, ORIGIN.Y + 2.1, mid.Z), C_BAND, Enum.Material.Plaster, { CastShadow = false })
				Build.block(shell, "Rail", Vector3.new(run * CELL + 0.3, 0.3, CELL + 0.3), CFrame.new(mid.X, ORIGIN.Y + 4.3, mid.Z), C_TRIM, Enum.Material.Wood, { CastShadow = false })
				Build.block(shell, "Skirt", Vector3.new(run * CELL + 0.16, 0.7, CELL + 0.16), CFrame.new(mid.X, ORIGIN.Y + 0.35, mid.Z), C_TRIM, Enum.Material.Plastic, { CastShadow = false })
			end
			cx += 1
		end
	end
	local w, h = map.Width * CELL, map.Height * CELL
	Build.block(shell, "Ceiling", Vector3.new(w, 1, h), CFrame.new(ORIGIN.X + w / 2, ORIGIN.Y + CEIL + 0.5, ORIGIN.Z + h / 2), C_CEIL, Enum.Material.Plaster)
end

----------------------------------------------------------------------------
-- Doors
----------------------------------------------------------------------------
local function buildDoor(map: Grid.Map, folder: Instance, idx: number): Door
	local cx, cy = Grid.coords(map, idx)
	local alongX = open(map, cx - 1, cy) and open(map, cx + 1, cy)
	local model = Build.model(folder, "Door")
	local center = at(map, cx, cy, 0)
	local rot = if alongX then CFrame.Angles(0, math.rad(90), 0) else CFrame.new()
	local base = CFrame.new(center) * rot

	Build.block(model, "PillarL", Vector3.new(1.5, CEIL, CELL), base * CFrame.new(-3.25, CEIL / 2, 0), C_WALL, Enum.Material.Plaster)
	Build.block(model, "PillarR", Vector3.new(1.5, CEIL, CELL), base * CFrame.new(3.25, CEIL / 2, 0), C_WALL, Enum.Material.Plaster)
	local lintel = Build.block(model, "Lintel", Vector3.new(5, CEIL - DOOR_H, CELL), base * CFrame.new(0, DOOR_H + (CEIL - DOOR_H) / 2, 0), C_WALL, Enum.Material.Plaster)
	for _, x in { -2.6, 2.6 } do
		Build.block(model, "Jamb", Vector3.new(0.3, DOOR_H, CELL + 0.2), base * CFrame.new(x, DOOR_H / 2, 0), C_TRIM, Enum.Material.Metal, { CastShadow = false })
	end

	-- room names over the door, readable from the side you are walking in from
	local opts: Build.SignOpts = { TextColor = Color3.fromRGB(30, 34, 34), LightInfluence = 0.9, PixelsPerStud = 30, Background = Color3.fromRGB(190, 190, 180), BackgroundTransparency = 0 }
	local frontName = if alongX then Grid.regionAt(MapData.Regions, cx + 1, cy) else Grid.regionAt(MapData.Regions, cx, cy + 1)
	local backName = if alongX then Grid.regionAt(MapData.Regions, cx - 1, cy) else Grid.regionAt(MapData.Regions, cx, cy - 1)
	if frontName then
		Build.sign(lintel, Enum.NormalId.Front, frontName, Config.Fonts.Sign, opts)
	end
	if backName then
		Build.sign(lintel, Enum.NormalId.Back, backName, Config.Fonts.Sign, opts)
	end

	local closedCF = base * CFrame.new(0, DOOR_H / 2, 0)
	local openCF = closedCF * CFrame.new(4.9, 0, 0)
	local panel = Build.block(model, "Panel", Vector3.new(5, DOOR_H, 0.5), closedCF, C_DOOR, Enum.Material.Wood)
	local kick = Build.block(model, "KickPlate", Vector3.new(5.02, 1.6, 0.56), closedCF * CFrame.new(0, -DOOR_H / 2 + 0.9, 0), C_STEEL, Enum.Material.Metal, { Anchored = false, Massless = true, CanCollide = false })
	Build.weld(panel, kick)
	local window = Build.block(model, "Window", Vector3.new(1.4, 2.6, 0.58), closedCF * CFrame.new(1.2, 1.4, 0), Color3.fromRGB(26, 32, 32), Enum.Material.Glass, { Anchored = false, Massless = true, CanCollide = false, Reflectance = 0.25 })
	Build.weld(panel, window)

	local core = Build.block(model, "Core", Vector3.new(1, 1, 1), base * CFrame.new(0, 4.5, 0), C_TRIM, Enum.Material.Metal, { Transparency = 1, CanCollide = false })
	core.CanQuery = false
	Sfx.make(core, "DoorOpen", { Volume = 0.7, MaxDistance = 90 })
	Sfx.make(core, "DoorClose", { Volume = 0.7, MaxDistance = 90 })
	Sfx.make(core, "DoorSlam", { Volume = 1, MaxDistance = 160 })
	local prompt = Build.prompt(core, "Door", "Open", 0, 9)
	return { Idx = idx, Panel = panel, Core = core, ClosedCF = closedCF, OpenCF = openCF, Open = false, Prompt = prompt, Position = center + Vector3.new(0, 4, 0) }
end

-- Opens or closes a door. `slam` is the fast, loud version HUSH uses.
function Facility.setDoor(facility: Facility, door: Door, isOpen: boolean, slam: boolean?)
	if door.Open == isOpen then
		return
	end
	door.Open = isOpen
	facility.Map.Closed[door.Idx] = if isOpen then nil else true
	local style = if slam then Enum.EasingStyle.Back else Enum.EasingStyle.Quad
	TweenService:Create(door.Panel, TweenInfo.new(if slam then 0.22 else 0.7, style, Enum.EasingDirection.Out), { CFrame = if isOpen then door.OpenCF else door.ClosedCF }):Play()
	door.Prompt.ActionText = if isOpen then "Close" else "Open"
	local sound = door.Core:FindFirstChild(if slam then "DoorSlam" elseif isOpen then "DoorOpen" else "DoorClose") :: Sound?
	if sound then
		sound:Play()
	end
end

----------------------------------------------------------------------------
-- Lockers
----------------------------------------------------------------------------
local function buildLocker(map: Grid.Map, folder: Instance, idx: number): Locker
	local cx, cy = Grid.coords(map, idx)
	local dx, dy = Grid.mountFacing(map, idx)
	local isAlcove = Grid.isAlcove(map, idx)
	local model = Build.model(folder, "Locker")
	if isAlcove then
		alcove(map, model, idx, dx, dy, 4)
	end
	local cf = frame(map, cx, cy, dx, dy, if isAlcove then 1.9 else -2.2)
	local W, D, H = 4.4, 3.4, 8
	local metal = Enum.Material.Metal
	Build.block(model, "Back", Vector3.new(W, H, 0.2), cf * CFrame.new(0, H / 2, D / 2), C_LOCKER, metal)
	Build.block(model, "SideL", Vector3.new(0.2, H, D), cf * CFrame.new(-W / 2, H / 2, 0), C_LOCKER, metal)
	Build.block(model, "SideR", Vector3.new(0.2, H, D), cf * CFrame.new(W / 2, H / 2, 0), C_LOCKER, metal)
	Build.block(model, "Top", Vector3.new(W, 0.2, D), cf * CFrame.new(0, H, 0), C_LOCKER, metal)
	local doorLow = Build.block(model, "DoorLow", Vector3.new(W, 4.3, 0.2), cf * CFrame.new(0, 2.15, -D / 2), C_LOCKER, metal)
	Build.block(model, "DoorHigh", Vector3.new(W, 1.9, 0.2), cf * CFrame.new(0, 7.05, -D / 2), C_LOCKER, metal)
	for i = 0, 3 do
		Build.block(model, "Slat", Vector3.new(W, 0.22, 0.3), cf * CFrame.new(0, 4.52 + i * 0.44, -D / 2) * CFrame.Angles(math.rad(-25), 0, 0), C_LOCKER, metal)
	end
	Build.block(model, "Seam", Vector3.new(0.08, H - 0.4, 0.24), cf * CFrame.new(0, H / 2, -D / 2), C_TRIM, metal, { CanCollide = false })
	Build.block(model, "Handle", Vector3.new(0.25, 1.1, 0.25), cf * CFrame.new(0.5, 3.6, -D / 2 - 0.2), C_STEEL, metal, { CanCollide = false })
	Sfx.make(doorLow, "Locker", { Volume = 0.8, MaxDistance = 70 })
	local prompt = Build.prompt(doorLow, "Locker", "Hide", 0.2, 7)
	return {
		Idx = idx,
		Model = model,
		InsideCF = cf * CFrame.new(0, 3, 0.2),
		ExitCF = cf * CFrame.new(0, 3, -D / 2 - 3),
		Prompt = prompt,
		Occupant = nil,
		Position = (cf * CFrame.new(0, 3, 0)).Position,
	}
end

----------------------------------------------------------------------------
-- Pneumatic tube stations: where the evidence leaves the building
----------------------------------------------------------------------------
local function buildStation(map: Grid.Map, folder: Instance, idx: number): Station
	local cx, cy = Grid.coords(map, idx)
	local dx, dy = Grid.mountFacing(map, idx)
	local model = Build.model(folder, "TubeStation")
	alcove(map, model, idx, dx, dy, 2)
	local cf = frame(map, cx, cy, dx, dy, 2.6)
	local body = Build.block(model, "Body", Vector3.new(3.2, 4.4, 1.4), cf * CFrame.new(0, 3.6, 0), Color3.fromRGB(150, 150, 140), Enum.Material.Metal)
	Build.block(model, "Hatch", Vector3.new(1.8, 2, 0.2), cf * CFrame.new(0, 3.2, -0.72), Color3.fromRGB(40, 44, 46), Enum.Material.Metal, { CanCollide = false })
	-- the tube itself, up into the ceiling
	local tube = Build.block(model, "Tube", Vector3.new(CEIL - 5.8, 1.5, 1.5), cf * CFrame.new(0, 5.8 + (CEIL - 5.8) / 2, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(170, 200, 200), Enum.Material.Glass, { CanCollide = false, Shape = Enum.PartType.Cylinder })
	tube.Transparency = 0.5
	Build.block(model, "Canister", Vector3.new(1.6, 0.9, 0.9), cf * CFrame.new(0, 6.8, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(196, 150, 28), Enum.Material.Plastic, { CanCollide = false, Shape = Enum.PartType.Cylinder })
	local plate = Build.block(model, "Plate", Vector3.new(2.8, 0.7, 0.1), cf * CFrame.new(0, 5.3, -0.72), Color3.fromRGB(20, 24, 24), Enum.Material.Metal, { CanCollide = false })
	Build.sign(plate, Enum.NormalId.Front, "TUBE STATION", Config.Fonts.Mono, { TextColor = Config.Colors.Amber, LightInfluence = 0.2 })
	local lamp = Build.block(model, "Lamp", Vector3.new(0.5, 0.5, 0.3), cf * CFrame.new(1.1, 1.9, -0.72), C_GREEN, Enum.Material.Neon, { CanCollide = false })
	local glow = Build.pointLight(lamp, C_GREEN, 0.7, 12)
	glow.Name = "Glow"
	Sfx.make(body, "TubeSend", { Volume = 1.2, MinDistance = 30, MaxDistance = 320 })
	local prompt = Build.prompt(body, "Tube Station", "Send evidence", Config.Shift.SendHold, 8)
	prompt.Enabled = false
	CollectionService:AddTag(body, "HS_Station")
	return { Idx = idx, Root = body, Lamp = lamp, Prompt = prompt, Left = Config.Shift.CanistersPerStation, Position = body.Position }
end

function Facility.setStationLamp(station: Station)
	local empty = station.Left <= 0
	station.Lamp.Color = if empty then C_RED else C_GREEN
	local glow = station.Lamp:FindFirstChild("Glow") :: PointLight?
	if glow then
		glow.Color = station.Lamp.Color
	end
	station.Root:SetAttribute("Left", station.Left)
end

----------------------------------------------------------------------------
-- Dispensers: the in-world shop. Each sells one thing.
----------------------------------------------------------------------------
local DISPENSER_KINDS = { ["1"] = "DeadAir", ["2"] = "ReviveAll", ["3"] = "ScareAll", ["4"] = "Sight" }
local DISPENSER_TINT = { DeadAir = Color3.fromRGB(120, 200, 255), ReviveAll = Color3.fromRGB(255, 90, 90), ScareAll = Color3.fromRGB(110, 150, 255), Sight = Color3.fromRGB(255, 190, 90), Revive = Color3.fromRGB(255, 120, 120) }

-- A wall-mounted medication dispenser with a glowing window. Also used in the lobby.
function Facility.buildDispenser(parent: Instance, cf: CFrame, kind: string): (Part, ProximityPrompt)
	local product = Config.Products[kind]
	local tint = DISPENSER_TINT[kind] or Config.Colors.Amber
	local body = Build.block(parent, "Dispenser_" .. kind, Vector3.new(3.4, 5.2, 1.2), cf * CFrame.new(0, 4.4, 0), Color3.fromRGB(196, 198, 190), Enum.Material.Metal)
	local window = Build.block(parent, "DispenserWindow", Vector3.new(2.6, 2.2, 0.1), cf * CFrame.new(0, 5.4, -0.62), tint, Enum.Material.Neon, { CanCollide = false })
	window.Transparency = 0.35
	Build.pointLight(window, tint, 0.8, 11)
	CollectionService:AddTag(window, "HS_Candle")
	for i = -1, 1 do
		Build.block(parent, "Vial", Vector3.new(0.3, 1.2, 0.3), cf * CFrame.new(i * 0.7, 5.3, -0.4), Color3.fromRGB(230, 230, 230), Enum.Material.Glass, { CanCollide = false })
	end
	local label = Build.block(parent, "DispenserLabel", Vector3.new(3, 0.9, 0.1), cf * CFrame.new(0, 3.5, -0.62), Color3.fromRGB(24, 28, 28), Enum.Material.Metal, { CanCollide = false })
	Build.sign(label, Enum.NormalId.Front, string.upper(product.Name), Config.Fonts.Mono, { TextColor = tint, LightInfluence = 0.1, Brightness = 1.2 })
	Build.block(parent, "DispenserTray", Vector3.new(2.2, 0.3, 0.9), cf * CFrame.new(0, 2.5, -0.5), Color3.fromRGB(40, 44, 44), Enum.Material.Metal, { CanCollide = false })
	Sfx.make(body, "Effigy", { Volume = 0.25, Looped = true, MaxDistance = 24 }):Play()
	local prompt = Build.prompt(body, product.Name, "Dispense", 0.5, 7)
	prompt:SetAttribute("Product", kind)
	return body, prompt
end

local function buildDispenser(map: Grid.Map, folder: Instance, idx: number): Dispenser
	local cx, cy = Grid.coords(map, idx)
	local dx, dy = Grid.mountFacing(map, idx)
	local kind = DISPENSER_KINDS[map.Cells[idx]]
	local model = Build.model(folder, "Dispenser")
	alcove(map, model, idx, dx, dy, 1.6)
	local body, prompt = Facility.buildDispenser(model, frame(map, cx, cy, dx, dy, 3), kind)
	return { Kind = kind, Root = body, Prompt = prompt, Position = body.Position }
end

----------------------------------------------------------------------------
-- Filing cabinets and recovery beds
----------------------------------------------------------------------------
local function buildCabinet(map: Grid.Map, folder: Instance, idx: number): Cabinet
	local cx, cy = Grid.coords(map, idx)
	local dx, dy = faceOpen(map, cx, cy)
	local cf = frame(map, cx, cy, dx, dy, -2.4)
	local model = Build.model(folder, "FilingCabinet")
	local body = Build.block(model, "Body", Vector3.new(2.8, 6, 2.8), cf * CFrame.new(0, 3, 0), Color3.fromRGB(128, 132, 128), Enum.Material.Metal, { Group = Build.Groups.Props })
	local drawer: Part = body
	for i = 0, 2 do
		local front = Build.block(model, "Drawer", Vector3.new(2.5, 1.7, 0.15), cf * CFrame.new(0, 1.1 + i * 1.9, -1.45), Color3.fromRGB(140, 144, 140), Enum.Material.Metal, { CanCollide = false })
		Build.block(model, "Handle", Vector3.new(1, 0.15, 0.2), cf * CFrame.new(0, 1.5 + i * 1.9, -1.6), C_TRIM, Enum.Material.Metal, { CanCollide = false })
		if i == 1 then
			drawer = front
		end
	end
	Sfx.make(body, "Locker", { Volume = 0.5, MaxDistance = 60, Speed = 1.5 })
	local prompt = Build.prompt(body, "Filing Cabinet", "Search", 1.2, 7)
	return { Idx = idx, Root = body, Drawer = drawer, Prompt = prompt, File = nil, Position = body.Position }
end

local function buildRecoveryBed(map: Grid.Map, folder: Instance, idx: number): Bed
	local cx, cy = Grid.coords(map, idx)
	local dx, dy = faceOpen(map, cx, cy)
	local cf = frame(map, cx, cy, dx, dy, 0)
	local model = Furnish.bed(folder, cf, false)
	model.Name = "RecoveryBed"
	-- restraints, and a chart that has your name on it
	Build.block(model, "Restraint", Vector3.new(3.6, 0.15, 0.5), cf * CFrame.new(0, 2.6, 0.6), Color3.fromRGB(96, 74, 54), Enum.Material.Leather, { CanCollide = false })
	Build.block(model, "Restraint", Vector3.new(3.6, 0.15, 0.5), cf * CFrame.new(0, 2.6, -1.8), Color3.fromRGB(96, 74, 54), Enum.Material.Leather, { CanCollide = false })
	local chart = Build.block(model, "Chart", Vector3.new(1.2, 1.6, 0.08), cf * CFrame.new(0, 2.2, -3.75), Config.Colors.Paper, Enum.Material.SmoothPlastic, { CanCollide = false })
	Build.sign(chart, Enum.NormalId.Front, "DO NOT\nDISCHARGE", Config.Fonts.Typewriter, { TextColor = Config.Colors.Ink })
	local stand = (cf * CFrame.new(3.2, 3, -1)).Position
	return { Idx = idx, WakeCF = CFrame.lookAt(stand, stand + Vector3.new(dx, 0, dy)), Position = stand }
end

----------------------------------------------------------------------------
-- Elevator, HUSH's corner, mimic spots
----------------------------------------------------------------------------
local function buildSetPieces(map: Grid.Map, folder: Folder, facility: Facility)
	local props = Build.folder(folder, "Props")
	local eCells = map.Markers["E"] or {}
	if #eCells > 0 then
		local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
		for _, idx in eCells do
			local cx, cy = Grid.coords(map, idx)
			minX, minY, maxX, maxY = math.min(minX, cx), math.min(minY, cy), math.max(maxX, cx), math.max(maxY, cy)
			table.insert(facility.ElevatorSpawns, at(map, cx, cy, 3))
		end
		local mid = (at(map, minX, minY, 0) + at(map, maxX, maxY, 0)) / 2
		local sx, sz = (maxX - minX + 1) * CELL, (maxY - minY + 1) * CELL
		facility.ElevatorPosition = mid
		-- the car: steel floor, three walls, open toward the lobby (-Z)
		Build.block(props, "CarFloor", Vector3.new(sx, 0.2, sz), CFrame.new(mid + Vector3.new(0, 0.1, 0)), C_STEEL, Enum.Material.DiamondPlate)
		Build.block(props, "CarBack", Vector3.new(sx, CEIL, 0.4), CFrame.new(mid + Vector3.new(0, CEIL / 2, sz / 2 - 0.2)), C_STEEL, Enum.Material.Metal)
		for _, side in { -1, 1 } do
			Build.block(props, "CarSide", Vector3.new(0.4, CEIL, sz), CFrame.new(mid + Vector3.new(side * (sx / 2 - 0.2), CEIL / 2, 0)), C_STEEL, Enum.Material.Metal)
			Build.block(props, "CarRail", Vector3.new(0.3, 0.3, sz - 2), CFrame.new(mid + Vector3.new(side * (sx / 2 - 0.6), 3.6, 0)), C_TRIM, Enum.Material.Metal, { CanCollide = false })
		end
		local header = Build.block(props, "CarHeader", Vector3.new(sx, 1.6, 0.4), CFrame.new(mid + Vector3.new(0, CEIL - 0.8, -sz / 2)), Color3.fromRGB(18, 20, 20), Enum.Material.Metal, { CanCollide = false })
		facility.ElevatorLabel = Build.sign(header, Enum.NormalId.Front, "ELEVATOR RECALLED — SEND THE EVIDENCE FIRST", Config.Fonts.Mono, { TextColor = C_RED, LightInfluence = 0, Brightness = 1.3 })
		local lamp = Build.block(props, "CarLamp", Vector3.new(3, 0.3, 3), CFrame.new(mid + Vector3.new(0, CEIL - 0.2, 0)), C_RED, Enum.Material.Neon, { CanCollide = false })
		local light = Build.pointLight(lamp, C_RED, 0.9, 26, true)
		facility.ElevatorLamp = lamp
		table.insert(facility.Fixtures, { Part = lamp, Light = light, Dead = false, Emergency = true })
		Sfx.make(lamp, "Elevator", { Volume = 0.9, MaxDistance = 200 })
	end

	local sCells = map.Markers["S"] or {}
	if sCells[1] then
		local cx, cy = Grid.coords(map, sCells[1])
		facility.NestPosition = at(map, cx, cy, 0)
		-- its charging alcove in the morgue: where it stands when nobody is awake
		local dock = Build.block(props, "ChargingDock", Vector3.new(4, 0.3, 4), CFrame.new(facility.NestPosition + Vector3.new(0, 0.15, 0)), Color3.fromRGB(40, 44, 46), Enum.Material.DiamondPlate, { CanCollide = false })
		Build.pointLight(dock, Color3.fromRGB(120, 200, 255), 0.5, 12)
	end
	for _, idx in map.Markers["m"] or {} do
		local cx, cy = Grid.coords(map, idx)
		table.insert(facility.MimicSpots, at(map, cx, cy, 0))
	end
	-- small shelves under every battery candidate so they sit at hand height
	for _, idx in map.Markers["b"] or {} do
		local cx, cy = Grid.coords(map, idx)
		local ox = if not open(map, cx - 1, cy) then -1 elseif not open(map, cx + 1, cy) then 1 else -1
		local oz = if not open(map, cx, cy - 1) then -1 elseif not open(map, cx, cy + 1) then 1 else -1
		local base = at(map, cx, cy, 0) + Vector3.new(ox * 2.7, 0, oz * 2.7)
		local stand = Build.block(props, "Trolley", Vector3.new(2.2, 3, 2.2), CFrame.new(base + Vector3.new(0, 1.5, 0)), C_STEEL, Enum.Material.Metal, { Group = Build.Groups.Props })
		stand:SetAttribute("Cell", idx)
	end
end

-- The elevator comes back when all the evidence is out.
function Facility.setElevator(facility: Facility, ready: boolean)
	local lamp, label = facility.ElevatorLamp, facility.ElevatorLabel
	if lamp then
		lamp.Color = if ready then C_GREEN else C_RED
		local light = lamp:FindFirstChildOfClass("PointLight")
		if light then
			light.Color = lamp.Color
		end
		local sound = lamp:FindFirstChild("Elevator") :: Sound?
		if ready and sound then
			sound:Play()
		end
	end
	if label then
		label.Text = if ready then "GOING DOWN — GET IN" else "ELEVATOR RECALLED — SEND THE EVIDENCE FIRST"
		label.TextColor3 = if ready then C_GREEN else C_RED
	end
end

----------------------------------------------------------------------------
-- Lights: ceiling panels. Most still work. That is the unsettling part.
----------------------------------------------------------------------------
local function buildLights(map: Grid.Map, folder: Folder, facility: Facility)
	local lights = Build.folder(folder, "Lights")
	local rng = Random.new(1994)
	for cy = 1, map.Height do
		for cx = 1, map.Width do
			local idx = Grid.index(map, cx, cy)
			local ch = map.Cells[idx]
			local f = map.Floor[idx]
			if f == "" or Grid.isDoorChar(ch) then
				continue
			end
			local want = if f == "." then (cx + cy) % 3 == 0 else (cx % 3 == 1 and cy % 3 == 1)
			if not want then
				continue
			end
			local alongX = open(map, cx - 1, cy) and open(map, cx + 1, cy)
			local size = if alongX then Vector3.new(4.4, 0.2, 2) else Vector3.new(2, 0.2, 4.4)
			local part = Build.block(lights, "Lamp", size, CFrame.new(at(map, cx, cy, CEIL - 0.1)), Color3.fromRGB(60, 62, 60), Enum.Material.SmoothPlastic, { CanCollide = false, CastShadow = false })
			local roll = rng:NextNumber()
			local light = Build.pointLight(part, C_LAMP, 1.15, 26, roll > 0.72)
			light.Enabled = false
			local dead = roll < 0.42
			if not dead and roll < 0.56 then
				CollectionService:AddTag(part, "HS_Flicker")
			end
			table.insert(facility.Fixtures, { Part = part, Light = light, Dead = dead, Emergency = false })
		end
	end
	-- a red emergency lamp over every tube station: they are how you find them in the dark
	for _, station in facility.Stations do
		local part = Build.block(lights, "Beacon", Vector3.new(0.7, 0.4, 0.7), CFrame.new(station.Position + Vector3.new(0, CEIL - station.Position.Y + ORIGIN.Y - 0.3, 0)), C_RED, Enum.Material.Neon, { CanCollide = false, CastShadow = false })
		local light = Build.pointLight(part, C_RED, 0.6, 14)
		table.insert(facility.Fixtures, { Part = part, Light = light, Dead = false, Emergency = true })
	end
end

function Facility.setPower(facility: Facility, on: boolean)
	for _, fx in facility.Fixtures do
		if not fx.Emergency then
			local lit = on and not fx.Dead
			fx.Light.Enabled = lit
			fx.Part.Material = if lit then Enum.Material.Neon else Enum.Material.SmoothPlastic
			fx.Part.Color = if lit then C_LAMP else Color3.fromRGB(60, 62, 60)
			fx.Part:SetAttribute("Lit", lit)
		end
	end
end

----------------------------------------------------------------------------
-- Per-shift contents
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

-- Scatters batteries and hides this shift's case files. Returns the battery items.
function Facility.stock(facility: Facility, rng: Random, fileIds: { string }): { Item }
	facility.Dynamic:ClearAllChildren()
	table.clear(facility.Items)
	for _, idx in pick(facility.Map.Markers["b"] or {}, Config.Shift.BatteriesSpawned, rng) do
		local top = standTop(facility, idx)
		local root = Build.block(facility.Dynamic, "Battery", Vector3.new(0.6, 1, 0.6), CFrame.new(top + Vector3.new(0, 0.5, 0)), Color3.fromRGB(210, 190, 40), Enum.Material.Metal, { CanCollide = false })
		Build.pointLight(root, Config.Colors.Phosphor, 0.35, 6)
		CollectionService:AddTag(root, "HS_Item")
		table.insert(facility.Items, { Kind = "Battery", Root = root, Prompt = Build.prompt(root, "Battery", "Take", 0.2, 8), Idx = idx })
	end
	local order = {}
	for i = 1, #facility.Cabinets do
		order[i] = i
	end
	for i = #order, 2, -1 do
		local j = rng:NextInteger(1, i)
		order[i], order[j] = order[j], order[i]
	end
	for i, cabinet in facility.Cabinets do
		cabinet.File = nil
		cabinet.Prompt.Enabled = true
		cabinet.Root:SetAttribute("HasFile", false)
	end
	for i = 1, math.min(#fileIds, Config.Shift.FilesHidden, #order) do
		local cabinet = facility.Cabinets[order[i]]
		cabinet.File = fileIds[i]
		cabinet.Root:SetAttribute("HasFile", true)
	end
	return facility.Items
end

-- Puts every door, light, locker and station back to its start-of-shift state.
function Facility.reset(facility: Facility)
	for _, door in facility.Doors do
		Facility.setDoor(facility, door, false)
	end
	for _, locker in facility.Lockers do
		locker.Occupant = nil
		locker.Prompt.Enabled = true
	end
	for _, station in facility.Stations do
		station.Left = Config.Shift.CanistersPerStation
		station.Prompt.Enabled = false
		Facility.setStationLamp(station)
	end
	Facility.setElevator(facility, false)
	Facility.setPower(facility, true)
	facility.Dynamic:ClearAllChildren()
	table.clear(facility.Items)
end

function Facility.cellOf(facility: Facility, position: Vector3): (number, number)
	return Grid.worldToCell(facility.Map, position.X, position.Z)
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
		Stations = {},
		Dispensers = {},
		Cabinets = {},
		Beds = {},
		Fixtures = {},
		ElevatorSpawns = {},
		ElevatorPosition = Vector3.zero,
		ElevatorLamp = nil,
		ElevatorLabel = nil,
		NestPosition = Vector3.zero,
		MimicSpots = {},
		WanderCells = {},
		Items = {},
	}

	buildShell(map, folder)
	local doors = Build.folder(folder, "Doors")
	for _, idx in map.Markers["D"] or {} do
		facility.Doors[idx] = buildDoor(map, doors, idx)
	end
	local lockers = Build.folder(folder, "Lockers")
	for _, idx in map.Markers["H"] or {} do
		table.insert(facility.Lockers, buildLocker(map, lockers, idx))
	end
	local stations = Build.folder(folder, "Stations")
	for _, idx in map.Markers["P"] or {} do
		table.insert(facility.Stations, buildStation(map, stations, idx))
	end
	local dispensers = Build.folder(folder, "Dispensers")
	for ch in DISPENSER_KINDS do
		for _, idx in map.Markers[ch] or {} do
			table.insert(facility.Dispensers, buildDispenser(map, dispensers, idx))
		end
	end
	local cabinets = Build.folder(folder, "Cabinets")
	for _, idx in map.Markers["F"] or {} do
		table.insert(facility.Cabinets, buildCabinet(map, cabinets, idx))
	end
	local beds = Build.folder(folder, "Beds")
	for _, idx in map.Markers["R"] or {} do
		table.insert(facility.Beds, buildRecoveryBed(map, beds, idx))
	end

	buildSetPieces(map, folder, facility)
	Furnish.all(map, folder)
	buildLights(map, folder, facility)
	Facility.setPower(facility, true)

	for idx, f in map.Floor do
		if f ~= "" and Grid.isFloorChar(map.Cells[idx]) then
			table.insert(facility.WanderCells, idx)
		end
	end
	return facility
end

return Facility
