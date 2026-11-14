--!strict
--[[
	Furnish — everything that makes Ward C read as a hospital rather than a
	maze: beds and curtains, the nurse station, waiting-room chairs, shelves of
	binders, gurneys left in corridors. Rooms are dressed automatically from the
	`Kind` of their region in MapData, so a new room only needs a rectangle.

	Local frames: -Z is "front" (into the room), +Z is the wall behind the prop.
	All furniture is in the Props collision group: players bump into it, HUSH
	walks through it (it navigates by cell, and must never get wedged).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Grid = require(ReplicatedStorage.Shared.Grid)
local MapData = require(ReplicatedStorage.Shared.MapData)
local Build = require(script.Parent.Build)

local Furnish = {}

local CELL = Config.World.CellSize
local ORIGIN = Config.World.FacilityOrigin

local STEEL = Color3.fromRGB(128, 132, 134)
local STEEL_DARK = Color3.fromRGB(64, 68, 70)
local WHITE = Color3.fromRGB(196, 196, 190)
local SHEET = Color3.fromRGB(170, 176, 172)
local CURTAIN = Color3.fromRGB(112, 138, 130)
local WOOD = Color3.fromRGB(96, 74, 54)
local PLASTIC_BLUE = Color3.fromRGB(62, 84, 108)
local BLACK = Color3.fromRGB(22, 22, 24)
local LEAF = Color3.fromRGB(44, 82, 50)
local BINDERS = { Color3.fromRGB(132, 44, 40), Color3.fromRGB(46, 70, 112), Color3.fromRGB(150, 140, 110), Color3.fromRGB(60, 60, 62) }

local function solid(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, shape: Enum.PartType?): Part
	return Build.block(parent, name, size, cf, color, material, { Group = Build.Groups.Props, Shape = shape })
end

local function decor(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, shape: Enum.PartType?): Part
	return Build.block(parent, name, size, cf, color, material, { CanCollide = false, Shape = shape, CastShadow = false })
end

----------------------------------------------------------------------------
-- Pieces
----------------------------------------------------------------------------
function Furnish.bed(parent: Instance, cf: CFrame, made: boolean): Model
	local model = Build.model(parent, "Bed")
	solid(model, "Frame", Vector3.new(3.6, 0.4, 7.4), cf * CFrame.new(0, 1.7, 0), STEEL, Enum.Material.Metal)
	for _, x in { -1.6, 1.6 } do
		for _, z in { -3.4, 3.4 } do
			decor(model, "Leg", Vector3.new(0.3, 1.6, 0.3), cf * CFrame.new(x, 0.8, z), STEEL_DARK, Enum.Material.Metal)
		end
	end
	solid(model, "Mattress", Vector3.new(3.4, 0.6, 7), cf * CFrame.new(0, 2.2, 0), WHITE, Enum.Material.Fabric)
	decor(model, "Pillow", Vector3.new(2.4, 0.4, 1.4), cf * CFrame.new(0, 2.65, 2.5), WHITE, Enum.Material.Fabric)
	decor(model, "Headboard", Vector3.new(3.6, 2.2, 0.25), cf * CFrame.new(0, 3, 3.6), STEEL, Enum.Material.Metal)
	if made then
		decor(model, "Sheet", Vector3.new(3.5, 0.2, 4.6), cf * CFrame.new(0, 2.6, -1.1), SHEET, Enum.Material.Fabric)
	else
		-- someone was here
		decor(model, "SheetHeap", Vector3.new(2.6, 0.8, 2.2), cf * CFrame.new(0.4, 2.8, -1.6) * CFrame.Angles(0, 0.4, 0.1), SHEET, Enum.Material.Fabric)
	end
	return model
end

function Furnish.ivStand(parent: Instance, cf: CFrame)
	decor(parent, "IvBase", Vector3.new(1.6, 0.2, 1.6), cf * CFrame.new(0, 0.1, 0), STEEL_DARK, Enum.Material.Metal)
	decor(parent, "IvPole", Vector3.new(0.18, 6.4, 0.18), cf * CFrame.new(0, 3.2, 0), STEEL, Enum.Material.Metal)
	decor(parent, "IvArm", Vector3.new(1.2, 0.14, 0.14), cf * CFrame.new(0, 6.3, 0), STEEL, Enum.Material.Metal)
	decor(parent, "IvBag", Vector3.new(0.6, 1, 0.25), cf * CFrame.new(0.45, 5.6, 0), Color3.fromRGB(190, 200, 190), Enum.Material.Glass)
end

function Furnish.curtain(parent: Instance, cf: CFrame, width: number)
	decor(parent, "CurtainRail", Vector3.new(width, 0.15, 0.15), cf * CFrame.new(0, 9, 0), STEEL, Enum.Material.Metal)
	local cloth = decor(parent, "Curtain", Vector3.new(width - 0.4, 7.6, 0.12), cf * CFrame.new(0, 5.1, 0), CURTAIN, Enum.Material.Fabric)
	cloth.Transparency = 0.12
end

function Furnish.gurney(parent: Instance, cf: CFrame)
	local model = Build.model(parent, "Gurney")
	solid(model, "Top", Vector3.new(2.8, 0.4, 6.6), cf * CFrame.new(0, 3, 0), STEEL, Enum.Material.Metal)
	decor(model, "Pad", Vector3.new(2.6, 0.3, 6.2), cf * CFrame.new(0, 3.35, 0), BLACK, Enum.Material.Leather)
	for _, x in { -1.2, 1.2 } do
		for _, z in { -2.9, 2.9 } do
			decor(model, "Leg", Vector3.new(0.2, 2.6, 0.2), cf * CFrame.new(x, 1.6, z), STEEL_DARK, Enum.Material.Metal)
			decor(model, "Wheel", Vector3.new(0.3, 0.7, 0.7), cf * CFrame.new(x, 0.35, z), BLACK, Enum.Material.Rubber, Enum.PartType.Cylinder)
		end
	end
	decor(model, "Strap", Vector3.new(2.9, 0.12, 0.5), cf * CFrame.new(0, 3.55, -0.6), WOOD, Enum.Material.Leather)
	decor(model, "Strap", Vector3.new(2.9, 0.12, 0.5), cf * CFrame.new(0, 3.55, 1.4), WOOD, Enum.Material.Leather)
end

function Furnish.wheelchair(parent: Instance, cf: CFrame)
	local model = Build.model(parent, "Wheelchair")
	solid(model, "Seat", Vector3.new(2.2, 0.3, 2.2), cf * CFrame.new(0, 2, 0), BLACK, Enum.Material.Leather)
	decor(model, "Back", Vector3.new(2.2, 2.4, 0.25), cf * CFrame.new(0, 3.2, 1.1), BLACK, Enum.Material.Leather)
	for _, x in { -1.25, 1.25 } do
		decor(model, "Wheel", Vector3.new(0.25, 3, 3), cf * CFrame.new(x, 1.5, 0.5), STEEL_DARK, Enum.Material.Metal, Enum.PartType.Cylinder)
		decor(model, "Arm", Vector3.new(0.2, 0.2, 2.2), cf * CFrame.new(x * 0.9, 2.9, 0), STEEL, Enum.Material.Metal)
	end
	decor(model, "Foot", Vector3.new(1.8, 0.15, 0.8), cf * CFrame.new(0, 0.6, -1.5), STEEL, Enum.Material.Metal)
end

function Furnish.desk(parent: Instance, cf: CFrame, withComputer: boolean)
	local model = Build.model(parent, "Desk")
	solid(model, "Top", Vector3.new(6, 0.3, 3), cf * CFrame.new(0, 3, 0), WOOD, Enum.Material.Wood)
	solid(model, "PanelL", Vector3.new(0.25, 2.9, 2.8), cf * CFrame.new(-2.8, 1.45, 0), WOOD, Enum.Material.Wood)
	solid(model, "PanelR", Vector3.new(0.25, 2.9, 2.8), cf * CFrame.new(2.8, 1.45, 0), WOOD, Enum.Material.Wood)
	decor(model, "Modesty", Vector3.new(5.4, 1.8, 0.2), cf * CFrame.new(0, 2, 1.3), WOOD, Enum.Material.Wood)
	if withComputer then
		decor(model, "Monitor", Vector3.new(2, 1.8, 1.8), cf * CFrame.new(-1.2, 4.1, 0.4), Color3.fromRGB(150, 146, 132), Enum.Material.Plastic)
		decor(model, "Screen", Vector3.new(1.6, 1.3, 0.1), cf * CFrame.new(-1.2, 4.15, -0.52), Color3.fromRGB(12, 18, 16), Enum.Material.Glass)
		decor(model, "Keyboard", Vector3.new(1.9, 0.12, 0.7), cf * CFrame.new(-1.2, 3.22, -0.9), Color3.fromRGB(150, 146, 132), Enum.Material.Plastic)
	end
	decor(model, "Papers", Vector3.new(1.3, 0.06, 1.7), cf * CFrame.new(1.4, 3.19, -0.2) * CFrame.Angles(0, 0.3, 0), Config.Colors.Paper, Enum.Material.SmoothPlastic)
	-- chair, pushed back as if someone just stood up
	local chair = cf * CFrame.new(0.4, 0, -3.2) * CFrame.Angles(0, 0.35, 0)
	solid(model, "ChairSeat", Vector3.new(2, 0.4, 2), chair * CFrame.new(0, 2, 0), BLACK, Enum.Material.Fabric)
	decor(model, "ChairBack", Vector3.new(2, 2.6, 0.3), chair * CFrame.new(0, 3.5, -0.95), BLACK, Enum.Material.Fabric)
	decor(model, "ChairPost", Vector3.new(0.3, 1.8, 0.3), chair * CFrame.new(0, 0.95, 0), STEEL_DARK, Enum.Material.Metal)
	decor(model, "ChairBase", Vector3.new(2, 0.2, 0.3), chair * CFrame.new(0, 0.15, 0), STEEL_DARK, Enum.Material.Metal)
	decor(model, "ChairBase", Vector3.new(0.3, 0.2, 2), chair * CFrame.new(0, 0.15, 0), STEEL_DARK, Enum.Material.Metal)
end

function Furnish.waitingChairs(parent: Instance, cf: CFrame, seats: number)
	local model = Build.model(parent, "WaitingChairs")
	local width = seats * 2.1
	decor(model, "Beam", Vector3.new(width, 0.25, 0.4), cf * CFrame.new(0, 1.3, 0.2), STEEL_DARK, Enum.Material.Metal)
	for _, x in { -width / 2 + 0.4, width / 2 - 0.4 } do
		decor(model, "Foot", Vector3.new(0.3, 1.3, 1.8), cf * CFrame.new(x, 0.65, 0.2), STEEL_DARK, Enum.Material.Metal)
	end
	for i = 1, seats do
		local x = -width / 2 + (i - 0.5) * 2.1
		solid(model, "Seat", Vector3.new(1.9, 0.3, 1.9), cf * CFrame.new(x, 1.6, 0), PLASTIC_BLUE, Enum.Material.Plastic)
		decor(model, "Back", Vector3.new(1.9, 1.9, 0.3), cf * CFrame.new(x, 2.7, 0.95) * CFrame.Angles(math.rad(-8), 0, 0), PLASTIC_BLUE, Enum.Material.Plastic)
	end
end

function Furnish.plant(parent: Instance, cf: CFrame)
	local model = Build.model(parent, "Plant")
	solid(model, "Pot", Vector3.new(1.4, 1.5, 1.5), cf * CFrame.new(0, 0.7, 0) * CFrame.Angles(0, 0, math.rad(90)), WHITE, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	decor(model, "Stem", Vector3.new(0.2, 2.6, 0.2), cf * CFrame.new(0, 2.6, 0), Color3.fromRGB(70, 56, 40), Enum.Material.Wood)
	for i = 0, 5 do
		local leaf = cf * CFrame.new(0, 3 + (i % 3) * 0.7, 0) * CFrame.Angles(0, i * 1.05, math.rad(38))
		decor(model, "Leaf", Vector3.new(2.2, 0.08, 1), leaf * CFrame.new(1, 0, 0), LEAF, Enum.Material.Grass)
	end
end

function Furnish.shelf(parent: Instance, cf: CFrame, rng: Random)
	local model = Build.model(parent, "Shelf")
	for _, x in { -2.9, 2.9 } do
		solid(model, "Upright", Vector3.new(0.2, 7, 1.6), cf * CFrame.new(x, 3.5, 0), STEEL_DARK, Enum.Material.Metal)
	end
	for level = 0, 3 do
		local y = 0.5 + level * 2.1
		solid(model, "Board", Vector3.new(5.8, 0.2, 1.6), cf * CFrame.new(0, y, 0), STEEL, Enum.Material.Metal)
		local x = -2.5
		while x < 2.3 do
			local w = rng:NextNumber(0.3, 0.9)
			if rng:NextNumber() < 0.7 then
				local h = rng:NextNumber(1, 1.6)
				decor(model, "Binder", Vector3.new(w, h, 1.2), cf * CFrame.new(x + w / 2, y + 0.1 + h / 2, 0), BINDERS[rng:NextInteger(1, #BINDERS)], Enum.Material.SmoothPlastic)
			end
			x += w + 0.08
		end
	end
end

function Furnish.boxes(parent: Instance, cf: CFrame, rng: Random)
	for i = 1, rng:NextInteger(2, 4) do
		local size = Vector3.new(rng:NextNumber(1.6, 2.6), rng:NextNumber(1.4, 2.2), rng:NextNumber(1.6, 2.6))
		-- kept well inside the cell so a box never pokes into the wall behind or the cell beside it
		local offset = CFrame.new(rng:NextNumber(-1, 1), size.Y / 2 + (if i > 2 then 2.2 else 0), rng:NextNumber(-0.8, 0.8)) * CFrame.Angles(0, rng:NextNumber(-0.3, 0.3), 0)
		solid(parent, "Box", size, cf * offset, Color3.fromRGB(138, 108, 74), Enum.Material.Cardboard)
	end
end

function Furnish.waterCooler(parent: Instance, cf: CFrame)
	solid(parent, "CoolerBase", Vector3.new(1.6, 4, 1.6), cf * CFrame.new(0, 2, 0), WHITE, Enum.Material.Plastic)
	local jug = decor(parent, "CoolerJug", Vector3.new(1.8, 1.4, 1.4), cf * CFrame.new(0, 4.9, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(90, 140, 190), Enum.Material.Glass, Enum.PartType.Cylinder)
	jug.Transparency = 0.45
end

function Furnish.table(parent: Instance, cf: CFrame, size: Vector3, color: Color3, material: Enum.Material)
	solid(parent, "TableTop", Vector3.new(size.X, 0.3, size.Z), cf * CFrame.new(0, size.Y, 0), color, material)
	for _, x in { -size.X / 2 + 0.3, size.X / 2 - 0.3 } do
		for _, z in { -size.Z / 2 + 0.3, size.Z / 2 - 0.3 } do
			decor(parent, "TableLeg", Vector3.new(0.25, size.Y, 0.25), cf * CFrame.new(x, size.Y / 2, z), STEEL_DARK, Enum.Material.Metal)
		end
	end
end

-- A poster on a wall face. `cf` is the wall-hugging local frame.
function Furnish.poster(parent: Instance, cf: CFrame, text: string, background: Color3, ink: Color3, font: string)
	local board = decor(parent, "Poster", Vector3.new(3.4, 2.4, 0.1), cf * CFrame.new(0, 6.2, 3.92), background, Enum.Material.SmoothPlastic)
	Build.sign(board, Enum.NormalId.Front, text, font, { TextColor = ink, LightInfluence = 0.9, PixelsPerStud = 36 })
end

----------------------------------------------------------------------------
-- Room dressing
----------------------------------------------------------------------------
local function at(map: Grid.Map, cx: number, cy: number): Vector3
	local x, z = Grid.cellCenter(map, cx, cy)
	return Vector3.new(x, ORIGIN.Y, z)
end

local function isOpen(map: Grid.Map, cx: number, cy: number): boolean
	return Grid.inBounds(map, cx, cy) and map.Floor[Grid.index(map, cx, cy)] ~= ""
end

-- A plain floor cell with no marker on it and no door beside it.
local function free(map: Grid.Map, cx: number, cy: number): boolean
	if not Grid.inBounds(map, cx, cy) or not Grid.isFloorChar(map.Cells[Grid.index(map, cx, cy)]) then
		return false
	end
	for _, d in Grid.Dirs do
		local ch = Grid.charAt(map, cx + d[1], cy + d[2])
		if Grid.isDoorChar(ch) then
			return false
		end
	end
	return true
end

-- Frame for a prop standing against a wall of this cell (nil if no wall touches it).
local function againstWall(map: Grid.Map, cx: number, cy: number): CFrame?
	for _, d in Grid.Dirs do
		if Grid.charAt(map, cx + d[1], cy + d[2]) == "#" then
			local base = at(map, cx, cy)
			return CFrame.lookAt(base, base - Vector3.new(d[1], 0, d[2]))
		end
	end
	return nil
end

local function dress(map: Grid.Map, parent: Instance, region: MapData.Region, rng: Random)
	local kind = region.Kind
	for cy = region.Y1, region.Y2 do
		for cx = region.X1, region.X2 do
			if not free(map, cx, cy) then
				continue
			end
			local center = CFrame.new(at(map, cx, cy))
			local wall = againstWall(map, cx, cy)
			local edge = wall ~= nil
			local roll = rng:NextNumber()
			if kind == "Ward" then
				-- beds head-to-wall down both sides, a curtain between neighbours
				local west = Grid.charAt(map, cx - 1, cy) == "#"
				local east = Grid.charAt(map, cx + 1, cy) == "#"
				if (west or east) and cy % 2 == 0 then
					local side = if west then -1 else 1
					local cf = center * CFrame.Angles(0, math.rad(if west then -90 else 90), 0) -- headboard (+Z) to the wall
					Furnish.bed(parent, cf * CFrame.new(0, 0, 0.2), roll < 0.55)
					Furnish.ivStand(parent, cf * CFrame.new(2.6, 0, 2.6))
					if free(map, cx, cy + 1) then
						Furnish.curtain(parent, CFrame.new(at(map, cx, cy) + Vector3.new(side * -0.5, 0, CELL / 2)), 7)
					end
				elseif not edge and roll < 0.12 then
					Furnish.wheelchair(parent, center * CFrame.Angles(0, rng:NextNumber(0, 6), 0))
				end
			elseif kind == "Waiting" then
				if not edge and cy % 2 == 0 and cx % 4 ~= 0 then
					Furnish.waitingChairs(parent, center * CFrame.Angles(0, if cy % 4 == 0 then math.pi else 0, 0), 3)
				elseif wall and roll < 0.18 then
					Furnish.plant(parent, wall * CFrame.new(0, 0, 2.6))
				elseif wall and roll < 0.26 then
					Furnish.waterCooler(parent, wall * CFrame.new(0, 0, 2.9))
				elseif wall and roll < 0.4 then
					Furnish.poster(parent, wall, "QUIET PLEASE\nPATIENTS ARE RESTING", Color3.fromRGB(206, 200, 180), Color3.fromRGB(40, 60, 90), Config.Fonts.Sign)
				end
			elseif kind == "Station" then
				-- the counter is built once by the caller; here: desks behind it, shelves on the walls
				if wall and cx % 2 == 0 then
					Furnish.shelf(parent, wall * CFrame.new(0, 0, 3), rng)
				elseif not edge and cx % 3 == 0 and cy % 3 == 0 then
					Furnish.desk(parent, center, true)
				end
			elseif kind == "Office" then
				if wall and cx % 2 == 1 then
					Furnish.shelf(parent, wall * CFrame.new(0, 0, 3), rng)
				elseif not edge and cx % 3 == 1 and cy % 2 == 0 then
					Furnish.desk(parent, center * CFrame.Angles(0, if roll < 0.5 then 0 else math.pi, 0), roll < 0.7)
				elseif wall and roll < 0.2 then
					Furnish.boxes(parent, wall * CFrame.new(0, 0, 1.2), rng)
				end
			elseif kind == "Storage" then
				if not edge and cx % 3 == 0 then
					Furnish.shelf(parent, center * CFrame.Angles(0, math.rad(90), 0), rng)
				elseif wall and roll < 0.45 then
					Furnish.boxes(parent, wall * CFrame.new(0, 0, 1.2), rng)
				end
			elseif kind == "Lab" then
				if not edge and cx % 3 == 1 and cy % 3 == 1 then
					Furnish.table(parent, center, Vector3.new(3, 3, 6.6), STEEL, Enum.Material.Metal)
					-- the big lamp over the table, long dead
					decor(parent, "SurgicalLamp", Vector3.new(0.6, 3.2, 3.2), center * CFrame.new(0, 9.4, 0) * CFrame.Angles(0, 0, math.rad(90)), WHITE, Enum.Material.Metal, Enum.PartType.Cylinder)
					decor(parent, "LampArm", Vector3.new(0.3, 2.4, 0.3), center * CFrame.new(0, 10.8, 0), STEEL_DARK, Enum.Material.Metal)
				elseif wall and roll < 0.2 then
					-- an x-ray lightbox that still hums
					local box = decor(parent, "Lightbox", Vector3.new(3.4, 2.6, 0.2), wall * CFrame.new(0, 6, 3.85), Color3.fromRGB(206, 226, 236), Enum.Material.Neon)
					Build.pointLight(box, Color3.fromRGB(190, 220, 240), 0.7, 14)
					decor(parent, "Xray", Vector3.new(1.3, 2, 0.05), wall * CFrame.new(-0.8, 6, 3.72), Color3.fromRGB(20, 26, 30), Enum.Material.Glass)
				elseif wall and roll < 0.4 then
					Furnish.gurney(parent, wall * CFrame.new(0, 0, 2.2) * CFrame.Angles(0, math.rad(90), 0))
				end
			elseif kind == "Morgue" then
				if not edge and cy % 2 == 0 then
					Furnish.table(parent, center, Vector3.new(3, 3, 6.8), STEEL, Enum.Material.Metal)
					if roll < 0.5 then
						decor(parent, "Shroud", Vector3.new(2.6, 0.9, 6), center * CFrame.new(0, 3.6, 0), SHEET, Enum.Material.Fabric)
					end
				elseif Grid.charAt(map, cx + 1, cy) == "#" then
					-- cold drawers along the east wall
					for row = 0, 1 do
						decor(parent, "ColdDrawer", Vector3.new(0.3, 2.6, 3.2), center * CFrame.new(3.69, 2 + row * 3, 0), STEEL, Enum.Material.Metal)
						decor(parent, "ColdHandle", Vector3.new(0.3, 0.2, 1.2), center * CFrame.new(3.39, 2.6 + row * 3, 0), STEEL_DARK, Enum.Material.Metal)
					end
				end
			elseif kind == "Lobby" then
				if wall and roll < 0.35 then
					Furnish.plant(parent, wall * CFrame.new(0, 0, 2.6))
				end
			end
		end
	end

	if kind == "Station" then
		-- the nurse station itself: an island counter in the middle of the room
		local midX, midY = (region.X1 + region.X2) / 2, (region.Y1 + region.Y2) / 2
		local a = at(map, math.floor(midX), math.floor(midY))
		local b = at(map, math.ceil(midX), math.ceil(midY))
		local mid = CFrame.new((a + b) / 2) * CFrame.Angles(0, math.pi, 0) -- counter and sign face the south door
		solid(parent, "Counter", Vector3.new(22, 3.6, 1.6), mid * CFrame.new(0, 1.8, -5), Color3.fromRGB(108, 112, 108), Enum.Material.Marble)
		solid(parent, "Counter", Vector3.new(1.6, 3.6, 10), mid * CFrame.new(-10.2, 1.8, 0.8), Color3.fromRGB(108, 112, 108), Enum.Material.Marble)
		solid(parent, "Counter", Vector3.new(1.6, 3.6, 10), mid * CFrame.new(10.2, 1.8, 0.8), Color3.fromRGB(108, 112, 108), Enum.Material.Marble)
		local glass = decor(parent, "CounterGlass", Vector3.new(22, 2.6, 0.15), mid * CFrame.new(0, 4.9, -5), Color3.fromRGB(150, 170, 170), Enum.Material.Glass)
		glass.Transparency = 0.6
		local sign = decor(parent, "StationSign", Vector3.new(10, 1.4, 0.2), mid * CFrame.new(0, 9.6, -5), Color3.fromRGB(20, 30, 30), Enum.Material.Metal)
		Build.sign(sign, Enum.NormalId.Front, "NURSE STATION — WARD C", Config.Fonts.Sign, { TextColor = Color3.fromRGB(190, 220, 210), LightInfluence = 0.5 })
		local lamp = decor(parent, "DeskLamp", Vector3.new(0.8, 0.4, 0.8), mid * CFrame.new(6, 3.9, -5), Color3.fromRGB(255, 220, 160), Enum.Material.Neon)
		Build.pointLight(lamp, Color3.fromRGB(255, 210, 150), 0.9, 16, true)
	end
end

-- Things abandoned in the corridors.
local function dressCorridors(map: Grid.Map, parent: Instance, rng: Random)
	for idx, ch in map.Cells do
		if ch ~= "." then
			continue
		end
		local cx, cy = Grid.coords(map, idx)
		if not free(map, cx, cy) or Grid.regionAt(MapData.Regions, cx, cy) then
			continue
		end
		-- only straight runs: a wall on one side, open ahead and behind
		local wall = againstWall(map, cx, cy)
		local straight = (isOpen(map, cx - 1, cy) and isOpen(map, cx + 1, cy)) ~= (isOpen(map, cx, cy - 1) and isOpen(map, cx, cy + 1))
		if not wall or not straight then
			continue
		end
		local roll = rng:NextNumber()
		if roll < 0.07 then
			Furnish.gurney(parent, wall * CFrame.new(0, 0, 2.3) * CFrame.Angles(0, math.rad(90) + rng:NextNumber(-0.15, 0.15), 0))
		elseif roll < 0.12 then
			Furnish.wheelchair(parent, wall * CFrame.new(rng:NextNumber(-1, 1), 0, 1.8) * CFrame.Angles(0, rng:NextNumber(0, 6), 0))
		elseif roll < 0.2 then
			Furnish.poster(parent, wall, "QUIET PLEASE", Color3.fromRGB(206, 200, 180), Color3.fromRGB(40, 60, 90), Config.Fonts.Sign)
		elseif roll < 0.24 then
			Furnish.poster(parent, wall, "it is not asking", Color3.fromRGB(150, 152, 148), Color3.fromRGB(120, 16, 16), Config.Fonts.Scrawl)
		end
	end
end

function Furnish.all(map: Grid.Map, parent: Instance)
	local folder = Build.folder(parent, "Furniture")
	local rng = Random.new(1994)
	for _, region in MapData.Regions do
		dress(map, folder, region, rng)
	end
	dressCorridors(map, folder, rng)
end

return Furnish
