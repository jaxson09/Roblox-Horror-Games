// Type-checks every .luau file in src/ with the Luau analyzer (WASM) against
// Roblox's API definitions. Usage: npm install && npm run defs && npm run check
import { Analysis } from '@luau-rs/luau/analysis';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const srcRoot = path.resolve(here, '../../src');
const defsPath = process.argv[2] || path.join(here, 'roblox.d.luau');
const showLint = !process.argv.includes('--no-lint');

function walk(dir) {
  return fs.readdirSync(dir, { withFileTypes: true }).flatMap((e) => {
    const p = path.join(dir, e.name);
    return e.isDirectory() ? walk(p) : p.endsWith('.luau') ? [p] : [];
  });
}

// Instance path of a file, mirroring default.project.json.
const ROOTS = { 'ReplicatedStorage.Shared': 'shared', 'ServerScriptService.Server': 'server' };
const moduleName = (file) => path.relative(srcRoot, file).replace(/\\/g, '/').replace(/\.(server|client)?\.?luau$/, '').replace(/\.$/, '');

function resolveRequire(expr, fromModule) {
  for (const [prefix, dir] of Object.entries(ROOTS)) {
    if (expr.startsWith(prefix + '.')) return dir + '/' + expr.slice(prefix.length + 1).split('.').join('/');
  }
  if (expr.startsWith('script')) {
    const parts = expr.split('.').slice(1);
    let cur = fromModule.split('/');
    for (const part of parts) {
      if (part === 'Parent') cur.pop();
      else cur.push(part);
    }
    return cur.join('/');
  }
  return null;
}

function preprocess(source, name) {
  return source
    .replace(/require\(([\w.]+)\)/g, (m, expr) => {
      const target = resolveRequire(expr, name);
      return target ? `require("${target}")` : m;
    })
    .replace(/\bEnum\.(\w+)(?![\w.:(])/g, 'Enum$1')
    .replace(/Instance\.new\("(\w+)"\)/g, '(Instance.new("$1") :: $1)')
    .replace(/([A-Za-z_][\w.]*):(FindFirstChildOfClass|FindFirstChildWhichIsA|FindFirstAncestorOfClass)\("(\w+)"\)/g, '($1:$2("$3") :: $3?)')
    .replace(/game:GetService\("(\w+)"\)/g, '(game:GetService("$1") :: $1)');
}

const analysis = await Analysis.create({ mode: 'strict', lint: true });
analysis.addDefinition('@roblox', fs.readFileSync(defsPath, 'utf8'));

const files = walk(srcRoot);
const names = new Map();
for (const file of files) {
  const name = moduleName(file);
  names.set(name, file);
  const kind = /\.(server|client)\.luau$/.test(file) ? 'script' : 'module';
  analysis.setModule(name, preprocess(fs.readFileSync(file, 'utf8'), name), kind);
}

let errors = 0;
let warnings = 0;
for (const [name, file] of names) {
  const result = analysis.check(name);
  for (const d of result.diagnostics) {
    if (d.module !== name) continue;
    if (d.kind === 'lint' && !showLint) continue;
    // service variables only used inside require() paths look unused after preprocessing
    const unused = /Variable '(\w+)' is never used/.exec(d.message);
    if (unused && new RegExp(`require\\(${unused[1]}\\.`).test(fs.readFileSync(file, 'utf8'))) continue;
    if (d.severity === 'error') errors++;
    else warnings++;
    console.log(`${path.relative(process.cwd(), file)}:${d.location.begin.line + 1}: ${d.severity}: ${d.message}`);
  }
}
console.log(`\n${files.length} files checked, ${errors} error(s), ${warnings} warning(s)`);
process.exit(errors > 0 ? 1 : 0);
