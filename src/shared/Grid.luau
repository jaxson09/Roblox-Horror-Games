--!strict
--[[
	Grid — pure logic for the cell map: parsing, coordinate conversion, A*
	pathfinding and line of sight. No Roblox instances are touched here, so
	the monster's navigation is deterministic and independent of the navmesh.

	Cells are 1-based (cx, cy). idx = (cy - 1) * width + cx.
]]

local Grid = {}

export type Map = {
	Width: number,
	Height: number,
	Cells: { string }, -- idx -> character
	Floor: { string }, -- idx -> floor character ("" for solid cells)
	Markers: { [string]: { number } }, -- character -> list of idx
	Closed: { [number]: boolean }, -- idx -> true when a door cell is shut
	Sealed: { [number]: boolean }, -- idx -> true when HUSH may not pass (locked doors)
	CellSize: number,
	OriginX: number,
	OriginZ: number,
}

local FLOOR_CHARS: { [string]: boolean } = { ["."] = true, [","] = true, [":"] = true, ["="] = true }
local DOOR_CHARS: { [string]: boolean } = { D = true, L = true, B = true }
-- These never count as floor even though something stands in them.
local SOLID_CHARS: { [string]: boolean } = { ["#"] = true }
-- Wall-mounted markers: solid for navigation when they replace a wall cell.
local MOUNT_CHARS: { [string]: boolean } = { H = true, P = true, ["1"] = true, ["2"] = true, ["3"] = true, ["4"] = true }
-- Furniture markers that stand on a room floor and block movement.
local BLOCK_CHARS: { [string]: boolean } = { R = true, F = true }

local DIRS = { { 0, -1 }, { 1, 0 }, { 0, 1 }, { -1, 0 } } -- N E S W

Grid.Dirs = DIRS

function Grid.index(map: Map, cx: number, cy: number): number
	return (cy - 1) * map.Width + cx
end

function Grid.coords(map: Map, idx: number): (number, number)
	local cx = (idx - 1) % map.Width + 1
	local cy = (idx - 1) // map.Width + 1
	return cx, cy
end

function Grid.inBounds(map: Map, cx: number, cy: number): boolean
	return cx >= 1 and cy >= 1 and cx <= map.Width and cy <= map.Height
end

function Grid.charAt(map: Map, cx: number, cy: number): string
	if not Grid.inBounds(map, cx, cy) then
		return "#"
	end
	return map.Cells[Grid.index(map, cx, cy)]
end

function Grid.isFloorChar(ch: string): boolean
	return FLOOR_CHARS[ch] == true
end

function Grid.isDoorChar(ch: string): boolean
	return DOOR_CHARS[ch] == true
end

function Grid.parse(rows: { string }, cellSize: number, originX: number, originZ: number): Map
	local height = #rows
	local width = #rows[1]
	local map: Map = {
		Width = width,
		Height = height,
		Cells = table.create(width * height, "#"),
		Floor = table.create(width * height, ""),
		Markers = {},
		Closed = {},
		Sealed = {},
		CellSize = cellSize,
		OriginX = originX,
		OriginZ = originZ,
	}
	for cy = 1, height do
		local row = rows[cy]
		assert(#row == width, `map row {cy} has length {#row}, expected {width}`)
		for cx = 1, width do
			local ch = string.sub(row, cx, cx)
			local idx = Grid.index(map, cx, cy)
			map.Cells[idx] = ch
			if not FLOOR_CHARS[ch] and not SOLID_CHARS[ch] then
				local list = map.Markers[ch]
				if not list then
					list = {}
					map.Markers[ch] = list
				end
				table.insert(list, idx)
			end
		end
	end

	-- Resolve the floor type under every non-solid cell. Markers inherit the
	-- floor of a neighbouring room cell; wall-mounted markers surrounded by at
	-- most corridor/room on two opposite sides stay solid.
	local function neighbourFloor(cx: number, cy: number): string
		local best = ""
		for _, d in DIRS do
			local ch = Grid.charAt(map, cx + d[1], cy + d[2])
			if FLOOR_CHARS[ch] then
				if ch ~= "." then
					return ch
				end
				best = ch
			end
		end
		return best
	end

	local function isOpenChar(ch: string): boolean
		return ch ~= "#" and not MOUNT_CHARS[ch]
	end

	for cy = 1, height do
		for cx = 1, width do
			local idx = Grid.index(map, cx, cy)
			local ch = map.Cells[idx]
			if FLOOR_CHARS[ch] then
				map.Floor[idx] = ch
			elseif ch == "#" then
				map.Floor[idx] = ""
			elseif DOOR_CHARS[ch] then
				map.Floor[idx] = "."
				map.Closed[idx] = true
				if ch ~= "D" then
					map.Sealed[idx] = true
				end
			elseif MOUNT_CHARS[ch] then
				-- A mount on a room floor has 2+ open neighbours that are not
				-- opposite each other across a wall line; an alcove in a wall has
				-- solid cells on at least two opposite sides.
				local n = isOpenChar(Grid.charAt(map, cx, cy - 1))
				local s = isOpenChar(Grid.charAt(map, cx, cy + 1))
				local e = isOpenChar(Grid.charAt(map, cx + 1, cy))
				local w = isOpenChar(Grid.charAt(map, cx - 1, cy))
				local inWall = (not n and not s) or (not e and not w)
				map.Floor[idx] = if inWall then "" else neighbourFloor(cx, cy)
			else
				local f = neighbourFloor(cx, cy)
				map.Floor[idx] = if f == "" then "." else f
			end
		end
	end
	return map
end

-- True when a mount marker (locker, tube station, dispenser) replaced a wall cell.
function Grid.isAlcove(map: Map, idx: number): boolean
	return MOUNT_CHARS[map.Cells[idx]] == true and map.Floor[idx] == ""
end

-- Direction (dx, dy) a wall/floor mount should face: toward open floor with a
-- solid cell behind it; corridors win ties.
function Grid.mountFacing(map: Map, idx: number): (number, number)
	local cx, cy = Grid.coords(map, idx)
	local bestScore, bx, by = -1, 0, 1
	for _, d in DIRS do
		local front = Grid.charAt(map, cx + d[1], cy + d[2])
		local frontIdx = if Grid.inBounds(map, cx + d[1], cy + d[2]) then Grid.index(map, cx + d[1], cy + d[2]) else 0
		local frontOpen = frontIdx ~= 0 and map.Floor[frontIdx] ~= "" and not MOUNT_CHARS[front]
		if frontOpen then
			local back = Grid.charAt(map, cx - d[1], cy - d[2])
			local score = 1
			if back == "#" then
				score += 4
			end
			if front == "." or DOOR_CHARS[front] then
				score += 2
			end
			if score > bestScore then
				bestScore, bx, by = score, d[1], d[2]
			end
		end
	end
	return bx, by
end

-- World X/Z of a cell centre.
function Grid.cellCenter(map: Map, cx: number, cy: number): (number, number)
	return map.OriginX + (cx - 0.5) * map.CellSize, map.OriginZ + (cy - 0.5) * map.CellSize
end

function Grid.worldToCell(map: Map, x: number, z: number): (number, number)
	local cx = math.floor((x - map.OriginX) / map.CellSize) + 1
	local cy = math.floor((z - map.OriginZ) / map.CellSize) + 1
	return cx, cy
end

-- Can anything walk through this cell (ignoring door state)?
function Grid.isWalkable(map: Map, cx: number, cy: number): boolean
	if not Grid.inBounds(map, cx, cy) then
		return false
	end
	local idx = Grid.index(map, cx, cy)
	if map.Floor[idx] == "" then
		return false
	end
	local ch = map.Cells[idx]
	-- Furniture-like markers on room floors block movement.
	return not (MOUNT_CHARS[ch] or BLOCK_CHARS[ch])
end

-- Can HUSH route through this cell right now?
function Grid.isPassable(map: Map, cx: number, cy: number): boolean
	if not Grid.isWalkable(map, cx, cy) then
		return false
	end
	return not map.Sealed[Grid.index(map, cx, cy)]
end

-- Nearest walkable cell to a (possibly blocked) cell, searching outward.
function Grid.nearestPassable(map: Map, cx: number, cy: number): (number, number)
	if Grid.isPassable(map, cx, cy) then
		return cx, cy
	end
	for radius = 1, 6 do
		for dy = -radius, radius do
			for dx = -radius, radius do
				if math.max(math.abs(dx), math.abs(dy)) == radius and Grid.isPassable(map, cx + dx, cy + dy) then
					return cx + dx, cy + dy
				end
			end
		end
	end
	return cx, cy
end

-- A* over 4-connected cells. Returns a list of idx from start (exclusive) to
-- goal (inclusive), or nil when unreachable.
function Grid.findPath(map: Map, sx: number, sy: number, gx: number, gy: number): { number }?
	sx, sy = Grid.nearestPassable(map, sx, sy)
	gx, gy = Grid.nearestPassable(map, gx, gy)
	local start = Grid.index(map, sx, sy)
	local goal = Grid.index(map, gx, gy)
	if start == goal then
		return {}
	end

	local open = { start }
	local inOpen = { [start] = true }
	local came: { [number]: number } = {}
	local gScore = { [start] = 0 }
	local fScore = { [start] = math.abs(sx - gx) + math.abs(sy - gy) }
	local closed: { [number]: boolean } = {}

	while #open > 0 do
		-- Small maps: a linear scan for the best node is plenty fast.
		local bestI, bestF = 1, fScore[open[1]]
		for i = 2, #open do
			local f = fScore[open[i]]
			if f < bestF then
				bestI, bestF = i, f
			end
		end
		local current = open[bestI]
		open[bestI] = open[#open]
		open[#open] = nil
		inOpen[current] = nil

		if current == goal then
			local path = {}
			local node = current
			while node ~= start do
				table.insert(path, 1, node)
				node = came[node]
			end
			return path
		end
		closed[current] = true

		local cx, cy = Grid.coords(map, current)
		for _, d in DIRS do
			local nx, ny = cx + d[1], cy + d[2]
			if Grid.isPassable(map, nx, ny) then
				local nIdx = Grid.index(map, nx, ny)
				if not closed[nIdx] then
					-- Closed (but unlocked) doors cost a little extra: it has to open them.
					local step = if map.Closed[nIdx] then 2.5 else 1
					local tentative = gScore[current] + step
					if gScore[nIdx] == nil or tentative < gScore[nIdx] then
						came[nIdx] = current
						gScore[nIdx] = tentative
						fScore[nIdx] = tentative + math.abs(nx - gx) + math.abs(ny - gy)
						if not inOpen[nIdx] then
							inOpen[nIdx] = true
							table.insert(open, nIdx)
						end
					end
				end
			end
		end
	end
	return nil
end

-- Are two points on the same side of the door panel in this door cell?
local function sameSideOfDoor(map: Map, idx: number, x1: number, z1: number, x2: number, z2: number): boolean
	local cx, cy = Grid.coords(map, idx)
	local centerX, centerZ = Grid.cellCenter(map, cx, cy)
	-- the panel spans the doorway, so it is crossed along the axis people walk through it
	local alongX = Grid.isWalkable(map, cx - 1, cy) and Grid.isWalkable(map, cx + 1, cy)
	if alongX then
		return (x1 - centerX) * (x2 - centerX) > 0
	end
	return (z1 - centerZ) * (z2 - centerZ) > 0
end

-- Line of sight between two world points, sampled across the grid. Solid cells
-- and closed doors in between block it. The two end cells are special: that is
-- where the watcher and the watched are standing (possibly in a wall alcove
-- beside a tube station, or in a doorway), so they only block if a shut door
-- panel actually lies between the two points.
function Grid.lineOfSight(map: Map, x1: number, z1: number, x2: number, z2: number): boolean
	local sx, sy = Grid.worldToCell(map, x1, z1)
	local ex, ey = Grid.worldToCell(map, x2, z2)
	if not Grid.inBounds(map, sx, sy) or not Grid.inBounds(map, ex, ey) then
		return false
	end
	local startIdx, endIdx = Grid.index(map, sx, sy), Grid.index(map, ex, ey)
	local dx, dz = x2 - x1, z2 - z1
	local dist = math.sqrt(dx * dx + dz * dz)
	local steps = math.max(1, math.ceil(dist / (map.CellSize * 0.25)))
	for i = 0, steps do
		local t = i / steps
		local cx, cy = Grid.worldToCell(map, x1 + dx * t, z1 + dz * t)
		if not Grid.inBounds(map, cx, cy) then
			return false
		end
		local idx = Grid.index(map, cx, cy)
		if idx == startIdx or idx == endIdx then
			if map.Closed[idx] and not sameSideOfDoor(map, idx, x1, z1, x2, z2) then
				return false
			end
			if map.Floor[idx] == "" and startIdx ~= endIdx then
				-- A wall cell. Only an alcove can be stood in, and it is open on one side
				-- only: the other point has to be on that side, or the alcove would be a
				-- window into the room behind it.
				if not Grid.isAlcove(map, idx) then
					return false
				end
				local otherX, otherZ = x2, z2
				if idx == endIdx then
					otherX, otherZ = x1, z1
				end
				local cellX, cellY = Grid.coords(map, idx)
				local centerX, centerZ = Grid.cellCenter(map, cellX, cellY)
				local faceX, faceY = Grid.mountFacing(map, idx)
				if (otherX - centerX) * faceX + (otherZ - centerZ) * faceY <= 0 then
					return false
				end
			end
		elseif map.Floor[idx] == "" or map.Closed[idx] then
			return false
		end
	end
	return true
end

function Grid.regionAt(regions: { { Name: string, X1: number, Y1: number, X2: number, Y2: number, Kind: string } }, cx: number, cy: number): string?
	for _, r in regions do
		if cx >= r.X1 and cx <= r.X2 and cy >= r.Y1 and cy <= r.Y2 then
			return r.Name
		end
	end
	return nil
end

return Grid
