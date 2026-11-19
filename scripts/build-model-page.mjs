// Builds the orbit model viewer (the live city generator in ?view=orbit mode) as a self-contained
// static page with relative asset paths: <outDir>/page.html + assets/ + fonts/ and files.json
// (published-path → source map). Usage: node scripts/build-model-page.mjs <outDir>
import { build } from 'vite';
import { readFileSync, writeFileSync, readdirSync, statSync, rmSync } from 'node:fs';
import { resolve, join, relative } from 'node:path';

const outDir = resolve(process.argv[2] ?? 'dist-model');
process.env.VITE_DEFAULT_VIEW = 'orbit';
rmSync(join(outDir, 'assets'), { recursive: true, force: true }); // keep packed tiles/ (scripts/pack-tiles.mjs)
await build({ root: resolve('.'), base: './', logLevel: 'warn', build: { outDir, emptyOutDir: false } });

const html = readFileSync(join(outDir, 'index.html'), 'utf8');
const head = html.match(/<head>([\s\S]*?)<\/head>/)[1].replace(/<meta[^>]*>\s*/g, '').replace(/<title>[\s\S]*?<\/title>\s*/, '');
const body = html.match(/<body>([\s\S]*?)<\/body>/)[1];
const page = `<title>Cathedral Mount</title>
<style>:root { color-scheme: dark; } html, body { height: 100%; } body { margin: 0; overflow: hidden; background: #0B1424; }</style>
${head.trim()}
${body.trim()}
`;
writeFileSync(join(outDir, 'page.html'), page);
const files = {};
const walk = (d) => { for (const f of readdirSync(d)) { const p = join(d, f); if (statSync(p).isDirectory()) walk(p); else { const r = relative(outDir, p); if (r !== 'index.html' && r !== 'page.html' && !r.startsWith('files') && !r.endsWith('.txt') && !r.startsWith('tiles/') && !r.startsWith('.tmp')) files[r] = p; } } };
walk(outDir);
writeFileSync(join(outDir, 'files.json'), JSON.stringify(files, null, 1));
console.log(`built ${outDir}: page.html + ${Object.keys(files).length} files`);
