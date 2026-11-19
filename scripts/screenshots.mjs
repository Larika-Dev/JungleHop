// Playwright screenshot harness (CLAUDE.md §18).
// Usage: node scripts/screenshots.mjs <phase> [shotNameFilter]
// Reads scripts/shots/phase-<N>.json: [{ name, params, view?: [x,y,z,yawDeg,pitchDeg], ortho?: [cx,cz,w,h?], preset?, eval? }]
import { createRequire } from 'node:module';
import { readFileSync, mkdirSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { build, preview } from 'vite';

const require = createRequire(import.meta.url);
const { chromium } = require('playwright');
const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const phase = process.argv[2] ?? '2';
const filter = process.argv[3];
const shots = JSON.parse(readFileSync(resolve(root, `scripts/shots/phase-${phase}.json`), 'utf8'));
const outDir = resolve(root, `screenshots/phase-${phase}`);
mkdirSync(outDir, { recursive: true });

// production build into a private dir: immune to source edits during long render runs
const outBuild = resolve(root, `node_modules/.shots-build-${phase}-${process.pid}`);
await build({ root, logLevel: 'error', build: { outDir: outBuild, emptyOutDir: true } });
const server = await preview({ root, logLevel: 'error', build: { outDir: outBuild }, preview: { port: 5200 + (process.pid % 500), strictPort: false, host: '127.0.0.1' } });
const url = server.resolvedUrls?.local?.[0];
const browser = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist', '--enable-webgl'] });
const W = Number(process.env.SHOT_W ?? 1600), H = Number(process.env.SHOT_H ?? 900);
let failed = 0;
for (const s of shots) {
  if (filter && !s.name.includes(filter)) continue;
  const page = await browser.newPage({ viewport: { width: W, height: H }, deviceScaleFactor: 1 });
  const logs = [];
  page.on('console', (m) => { if (m.type() === 'error' || m.type() === 'warning') logs.push(`${m.type()}: ${m.text()}`); });
  page.on('pageerror', (e) => logs.push('pageerror: ' + e.message));
  const q = new URLSearchParams({ shot: '1', ...(s.params ?? {}) });
  if (s.view) { q.set('x', s.view[0]); q.set('z', s.view[2]); }
  const t0 = Date.now();
  try {
    await page.goto(`${url}?${q}`, { timeout: 300000 });
    await page.waitForFunction(() => window.__cmReady === true, null, { timeout: 600000, polling: 500 });
    await page.evaluate(async (s) => {
      const cm = window.__cm;
      if (s.preset) cm.preset(s.preset);
      if (s.view) cm.view(s.view[0], s.view[1], s.view[2], (s.view[3] ?? 0) * Math.PI / 180, (s.view[4] ?? 0) * Math.PI / 180, s.fly ?? true);
      if (s.ortho) cm.ortho(...s.ortho);
      if (s.eval) await (0, eval)(s.eval)(cm);
      await cm.ready();
      await cm.frames(s.frames ?? 4);
    }, s);
    await page.screenshot({ path: resolve(outDir, `${s.name}.png`), timeout: 300000 });
    const stats = await page.evaluate(() => window.__cm.stats());
    console.log(`✓ ${s.name}  ${((Date.now() - t0) / 1000).toFixed(1)}s  calls=${stats.calls} tris=${(stats.tris / 1e6).toFixed(2)}M tile=${stats.tile}`);
  } catch (e) {
    failed++;
    console.log(`✗ ${s.name}: ${e.message.split('\n')[0]}`);
  }
  if (logs.length) console.log('   ' + logs.slice(0, 6).join('\n   '));
  await page.close();
}
await browser.close();
await server.close();
(await import('node:fs')).rmSync(outBuild, { recursive: true, force: true });
process.exit(failed ? 1 : 0);
