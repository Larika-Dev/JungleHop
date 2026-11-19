// Renders the illustrated city map to screenshots/city-map.png (CLAUDE.md §20).
// Prereq: npm run export (writes export/cathedral-mount-map.glb + labels). Usage: node tools/city-map/render.cjs
const { chromium } = require('playwright');
const http = require('http'), fs = require('fs'), path = require('path');
const root = path.resolve(__dirname, '..', '..');
const TYPES = { '.html': 'text/html', '.js': 'text/javascript', '.json': 'application/json', '.glb': 'model/gltf-binary', '.woff2': 'font/woff2' };
const srv = http.createServer((q, r) => {
  const u = decodeURIComponent(q.url.split('?')[0]);
  const file = u === '/' ? path.join(__dirname, 'map.html')
    : u.startsWith('/three/') ? path.join(root, 'node_modules/three', u.slice(7))
    : u.startsWith('/fonts/') ? path.join(root, 'public/fonts', u.slice(7))
    : path.join(root, u);
  if (!file.startsWith(root) || !fs.existsSync(file)) { r.statusCode = 404; return r.end(); }
  r.setHeader('content-type', TYPES[path.extname(file)] ?? 'application/octet-stream');
  fs.createReadStream(file).pipe(r);
}).listen(0, async () => {
  const port = srv.address().port;
  const b = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
  const pg = await b.newPage({ viewport: { width: 1200, height: 900 } });
  pg.on('pageerror', (e) => console.log('pageerror', e.message));
  pg.on('console', (m) => { if (m.type() === 'error') console.log('console', m.text()); });
  await pg.goto(`http://127.0.0.1:${port}/`);
  await pg.waitForFunction(() => window.__done === true, null, { timeout: 900000, polling: 1000 });
  const data = await pg.evaluate(() => window.__png);
  const out = path.join(root, 'screenshots', 'city-map.png');
  fs.writeFileSync(out, Buffer.from(data.split(',')[1], 'base64'));
  console.log('wrote', out);
  await b.close(); srv.close();
});
