// Proves the HUD layout: at every screen size below, no two elements that can be
// visible together overlap, nothing is off-screen, and (on touch) nothing sits
// under a touch button. Runs src/client/UI/Layout.luau in a real Luau VM.
import { Lua } from '@luau-rs/luau';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const here = path.dirname(fileURLToPath(import.meta.url));
const source = fs.readFileSync(path.resolve(here, '../../src/client/UI/Layout.luau'), 'utf8');

const SCREENS = [
  ['desktop 1920x1080', 1920, 1080, false], ['desktop 2560x1440', 2560, 1440, false], ['laptop 1366x768', 1366, 768, false],
  ['laptop 1280x720', 1280, 720, false], ['desktop 1024x768', 1024, 768, false], ['ultrawide 3440x1440', 3440, 1440, false],
  ['phone 844x390', 844, 390, true], ['phone 667x375', 667, 375, true], ['phone 932x430', 932, 430, true], ['phone 640x360', 640, 360, true],
  ['tablet 1180x820', 1180, 820, true], ['tablet 1024x768', 1024, 768, true],
];

const lua = await Lua.create({});
const dump = `
local Layout = (function()\n${source}\nend)()
local function enc(v)
  if type(v) == "table" then
    local parts, isArray = {}, #v > 0
    for k, x in v do table.insert(parts, isArray and enc(x) or ('"' .. tostring(k) .. '":' .. enc(x))) end
    return (isArray and "[" or "{") .. table.concat(parts, ",") .. (isArray and "]" or "}")
  elseif type(v) == "string" then return '"' .. v .. '"' end
  return tostring(v)
end
local out = {}
for _, s in SCREENS do
  local scale = Layout.scale(s[3])
  table.insert(out, { name = s[1], scale = scale, w = s[2] / scale, h = s[3] / scale, touch = s[4], rects = Layout.rects(s[2] / scale, s[3] / scale, s[4]) })
end
return enc({ screens = out, states = Layout.States, inside = Layout.Inside, buttons = Layout.TouchButtons, buttonSize = Layout.TouchButtonSize, text = Layout.Text })
`.replace('for _, s in SCREENS do', `for _, s in {${SCREENS.map(([n, w, h, t]) => `{"${n}",${w},${h},${t}}`).join(',')}} do`);
const data = JSON.parse(lua.execute(dump)[0]);
if (process.argv.includes('--json')) { console.log(JSON.stringify(data)); process.exit(0); }

const hit = (a, b) => a.X < b.X + b.W && b.X < a.X + a.W && a.Y < b.Y + b.H && b.Y < a.Y + a.H;
let problems = 0, checks = 0;
for (const screen of data.screens) {
  const buttons = screen.touch ? Object.entries(data.buttons).map(([name, b]) => [
    'touch:' + name, { X: screen.w - b.OX / screen.scale, Y: screen.h - b.OY / screen.scale, W: data.buttonSize / screen.scale, H: data.buttonSize / screen.scale },
  ]) : [];
  for (const [state, names] of Object.entries(data.states)) {
    const items = names.filter((n) => screen.rects[n]).map((n) => [n, screen.rects[n]]).concat(state === 'Lobby' ? [] : buttons);
    for (const [name, r] of items) {
      checks++;
      if (r.X < 0 || r.Y < 0 || r.X + r.W > screen.w + 0.01 || r.Y + r.H > screen.h + 0.01 || r.W <= 0 || r.H <= 0) {
        problems++; console.log(`OFF-SCREEN  ${screen.name}  [${state}]  ${name}`);
      }
    }
    for (let i = 0; i < items.length; i++) for (let j = i + 1; j < items.length; j++) {
      const [a, ra] = items[i], [b, rb] = items[j];
      if (data.inside[a] === b || data.inside[b] === a) continue;
      checks++;
      if (hit(ra, rb)) { problems++; console.log(`OVERLAP  ${screen.name}  [${state}]  ${a}  x  ${b}`); }
    }
  }
}
console.log(`${data.screens.length} screen sizes x ${Object.keys(data.states).length} states, ${checks} checks, ${problems} problem(s)`);
process.exit(problems ? 1 : 0);
