// Runs the pure map/pathfinding logic in a real Luau VM: every objective must be
// reachable, and lockers/effigies must face open floor.
import { Lua } from '@luau-rs/luau';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const here = path.dirname(fileURLToPath(import.meta.url));
const read = (f) => fs.readFileSync(path.resolve(here, '../../src/shared', f), 'utf8');
const wrap = (name, src) => `local ${name} = (function()\n${src}\nend)()\n`;
const test = `
local map = Grid.parse(MapData.Rows, 8, 0, 0)
local out = {}
local function log(s) table.insert(out, s) end
log(("map %dx%d"):format(map.Width, map.Height))
local e = map.Markers["E"][1]
local ex, ey = Grid.coords(map, e)
-- before power: only D doors passable
local function reach(label, chars, expectAll)
  local ok, total = 0, 0
  for _, ch in chars do
    for _, idx in map.Markers[ch] or {} do
      total += 1
      local cx, cy = Grid.coords(map, idx)
      local p = Grid.findPath(map, ex, ey, cx, cy)
      if p then ok += 1 else log("  UNREACHABLE " .. ch .. " at " .. cx .. "," .. cy) end
    end
  end
  log(label .. ": " .. ok .. "/" .. total .. " reachable")
  if expectAll then assert(ok == total, label .. " not fully reachable") end
end
reach("everything", {"b","S","m","E"}, true)
-- furniture is not walkable itself: the cell in front of it must be reachable
for _, ch in {"F","R"} do
  for _, idx in map.Markers[ch] or {} do
    local cx, cy = Grid.coords(map, idx)
    local ok = false
    for _, d in Grid.Dirs do
      if Grid.isPassable(map, cx + d[1], cy + d[2]) and Grid.findPath(map, ex, ey, cx + d[1], cy + d[2]) then ok = true end
    end
    assert(ok, ch .. " not reachable at " .. cx .. "," .. cy)
  end
end
log("furniture reachable")
for _, ch in {"H","P","1","2","3","4"} do
  for _, idx in map.Markers[ch] or {} do
    local cx, cy = Grid.coords(map, idx)
    local dx, dy = Grid.mountFacing(map, idx)
    local fx, fy = cx + dx, cy + dy
    local f = Grid.charAt(map, fx, fy)
    assert(map.Floor[Grid.index(map, fx, fy)] ~= "", "mount " .. ch .. " faces solid at " .. cx .. "," .. cy)
    log(("mount %s (%d,%d) alcove=%s faces (%d,%d) '%s'"):format(ch, cx, cy, tostring(Grid.isAlcove(map, idx)), dx, dy, f))
  end
end
-- line of sight (cell size 8, origin 0): centre of cell (cx, cy) is (cx*8-4, cy*8-4)
local function c(cx, cy) return cx * 8 - 4, cy * 8 - 4 end
local function los(ax, ay, bx, by) local x1, z1 = c(ax, ay); local x2, z2 = c(bx, by); return Grid.lineOfSight(map, x1, z1, x2, z2) end
assert(los(10, 5, 36, 5) == true, "should see along the north corridor")
assert(los(10, 5, 10, 9) == false, "should not see through the wall into the waiting room")
-- someone standing in a tube-station alcove (a wall cell) is visible from the corridor it faces...
local px, py = Grid.coords(map, map.Markers["P"][1])
local dx, dy = Grid.mountFacing(map, map.Markers["P"][1])
assert(los(px + dx, py + dy, px, py) == true, "should see a player standing at a tube station")
assert(los(px, py, px + dx, py + dy) == true, "and they should see out")
-- ...but not from the room behind it
for _, ch in {"P", "H", "1", "2", "3", "4"} do
  for _, idx in map.Markers[ch] do
    if Grid.isAlcove(map, idx) then
      local qx, qy = Grid.coords(map, idx)
      local fx, fy = Grid.mountFacing(map, idx)
      assert(los(qx + fx, qy + fy, qx, qy) == true, "alcove " .. ch .. " must be visible from the side it faces")
      assert(los(qx - fx, qy - fy, qx, qy) == false, "alcove " .. ch .. " must not be a window into what is behind it")
      assert(los(qx, qy, qx - fx, qy - fy) == false, "alcove " .. ch .. " must not see out of its back")
    end
  end
end
-- a shut door: blocks across it, not for two people on the same side of the panel
local door = map.Markers["D"][1]
local ddx, ddy = Grid.coords(map, door)
local alongX = Grid.isWalkable(map, ddx - 1, ddy) and Grid.isWalkable(map, ddx + 1, ddy)
local ax, ay = (alongX and ddx - 1 or ddx), (alongX and ddy or ddy - 1)
local bx, by = (alongX and ddx + 1 or ddx), (alongX and ddy or ddy + 1)
assert(los(ax, ay, bx, by) == false, "a shut door must block sight across it")
local cx0, cz0 = c(ddx, ddy)
local ox, oz = (alongX and 3 or 0), (alongX and 0 or 3)
local x1, z1 = c(ax, ay)
assert(Grid.lineOfSight(map, x1, z1, cx0 - ox, cz0 - oz) == true, "should see someone in the doorway on your side of a shut door")
assert(Grid.lineOfSight(map, x1, z1, cx0 + ox, cz0 + oz) == false, "should not see someone on the far side of a shut door")
map.Closed[door] = nil
assert(los(ax, ay, bx, by) == true, "an open door must not block sight")
map.Closed[door] = true
log("line of sight: corridors, walls, every alcove (front and back), shut and open doors: all correct")
local lights = 0
for idx, f in map.Floor do
  if f ~= "" then local x, y = Grid.coords(map, idx); if (f == "." and (x + y) % 4 == 0) or (f ~= "." and x % 3 == 0 and y % 3 == 0) then lights += 1 end end
end
log("light fixtures: " .. lights)
return table.concat(out, "\\n")
`;
const lua = await Lua.create({});
const src = wrap('MapData', read('MapData.luau')) + wrap('Grid', read('Grid.luau')) + test;
console.log(lua.execute(src)[0]);
