// Compress every export/tiles/*.glb (meshopt + quantization) and wrap it as JSON for static hosts that
// serve text only: <outDir>/tiles/T_c_r.json = { tile, glb: base64 } + <outDir>/tiles/index.json.
// Usage: node scripts/pack-tiles.mjs <outDir>
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
const out = path.resolve(process.argv[2] ?? 'dist-model');
fs.mkdirSync(path.join(out, 'tiles'), { recursive: true });
const tmp = path.join(out, '.tmp'); fs.mkdirSync(tmp, { recursive: true });
const index = [];
let total = 0;
for (const f of fs.readdirSync('export/tiles').filter((f) => f.endsWith('.glb')).sort()) {
  const name = f.replace('.glb', '');
  const c = path.join(tmp, f);
  execFileSync('node', ['scripts/compress-glb.mjs', path.join('export/tiles', f), c], { stdio: 'pipe' });
  const b64 = fs.readFileSync(c).toString('base64');
  const json = JSON.stringify({ tile: name, glb: b64 });
  fs.writeFileSync(path.join(out, 'tiles', `${name}.json`), json);
  total += json.length;
  index.push({ tile: name, bytes: json.length });
  console.log(`${name}: ${(json.length / 1e6).toFixed(2)} MB`);
}
fs.writeFileSync(path.join(out, 'tiles', 'index.json'), JSON.stringify(index));
fs.rmSync(tmp, { recursive: true, force: true });
console.log(`packed ${index.length} tiles, ${(total / 1e6).toFixed(1)} MB`);
