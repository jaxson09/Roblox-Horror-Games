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
