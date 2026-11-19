// Renders docs/phase-1/concept-map.svg + concept-layout.json from layout.mjs.
// Usage: node tools/concept-map/render.mjs
import { writeFileSync, mkdirSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import * as L from './layout.mjs';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const outDir = resolve(root, 'docs/phase-1');
mkdirSync(outDir, { recursive: true });

// Hex values copied from CLAUDE.md §4 (map overlay only; runtime code must use src/core/palette.ts).
const P = {
  GRASS_OCT: '#5E7F3A', BRICK_PAINTED_WHITE: '#E9E4D8', CONCRETE_AGED: '#A6A29A', BRICK_DOWNTOWN_A: '#9C5038',
  BRICK_PAVER_A: '#9A4F3A', LOBLOLLY_NEEDLE: '#3E5A2F', PAINT_HOSPITAL_ACCENT: '#9CC7C2', RED_CLAY: '#9B4A2C',
  WILLOW_OAK_LEAF: '#6B7A35', ASPHALT_AGED: '#4A4B4D', MARKING_WHITE: '#EDEDE6', MARKING_YELLOW: '#E8B923',
  FIELDSTONE_A: '#8A8478', CAPSTONE: '#9A958B', ONSU_NAVY: '#142B4E', HEAVEN_BLUE: '#80B4D9', TRIM_WHITE: '#F3F0E8',
  BRICK_CAMPUS_A: '#8E3B2E', CONCRETE_NEW: '#BDB9B0', IRON_BLACK: '#1A1A1A', COPPER_PATINA: '#5E9C8C',
  PINE_BARK: '#5B4636', EARL_BLUE: '#0A2A8A', DIRT_PATH: '#8A7B5E', LIMESTONE_TRIM: '#D8D0BE', GALV_STEEL: '#8E9396',
};

const M = 60; // margin around core
const vx0 = L.CORE.x0 - M, vz0 = L.CORE.z0 - 100, vx1 = L.CORE.x1 + M, vz1 = L.CORE.z1 + M;
const panelW = 470;
const W = vx1 - vx0 + panelW, H = vz1 - vz0;
const f = (n) => Math.round(n * 10) / 10;
const pts = (a) => a.map(([x, z]) => `${f(x)},${f(z)}`).join(' ');
const pathD = (a) => 'M' + a.map(([x, z]) => `${f(x)} ${f(z)}`).join(' L');
const esc = (s) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/'/g, '&#39;');
const out = [];
const push = (s) => out.push(s);

push(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="${vx0} ${vz0} ${W} ${H}" width="${W}" height="${H}" font-family="'DejaVu Serif', Georgia, serif">`);
push(`<rect x="${vx0}" y="${vz0}" width="${W}" height="${H}" fill="${P.BRICK_PAINTED_WHITE}"/>`);
push(`<rect x="${L.CORE.x0}" y="${L.CORE.z0}" width="${L.CORE.x1 - L.CORE.x0}" height="${L.CORE.z1 - L.CORE.z0}" fill="#DCD6C4"/>`);

// --- districts
push('<g id="districts">');
for (const d of [...L.districts].sort((a, b) => a.order - b.order)) {
  const op = d.id === 'campus_generic' ? 0.28 : 0.5;
  push(`<polygon points="${pts(d.poly)}" fill="${P[d.palette]}" fill-opacity="${op}" stroke="${P[d.palette]}" stroke-width="2" stroke-opacity="0.9"/>`);
}
push('</g>');

// --- contours (marching squares on 10 m grid)
const step = 10;
const nx = Math.round((L.CORE.x1 - L.CORE.x0) / step), nz = Math.round((L.CORE.z1 - L.CORE.z0) / step);
const g = [];
for (let j = 0; j <= nz; j++) { g[j] = []; for (let i = 0; i <= nx; i++) g[j][i] = L.elevation(L.CORE.x0 + i * step, L.CORE.z0 + j * step); }
const contour = (lvl) => {
  const segs = [];
  for (let j = 0; j < nz; j++) for (let i = 0; i < nx; i++) {
    const c = [g[j][i], g[j][i + 1], g[j + 1][i + 1], g[j + 1][i]];
    const x0 = L.CORE.x0 + i * step, z0 = L.CORE.z0 + j * step;
    const corners = [[x0, z0], [x0 + step, z0], [x0 + step, z0 + step], [x0, z0 + step]];
    const hits = [];
    for (let k = 0; k < 4; k++) {
      const a = c[k], b = c[(k + 1) % 4];
      if ((a < lvl) !== (b < lvl)) {
        const t = (lvl - a) / (b - a); const [ax, az] = corners[k], [bx, bz] = corners[(k + 1) % 4];
        hits.push([ax + t * (bx - ax), az + t * (bz - az)]);
      }
    }
    if (hits.length === 2) segs.push(hits);
    if (hits.length === 4) { segs.push([hits[0], hits[1]]); segs.push([hits[2], hits[3]]); }
  }
  return segs.map(([a, b]) => `M${f(a[0])} ${f(a[1])}L${f(b[0])} ${f(b[1])}`).join('');
};
push('<g id="contours" fill="none">');
for (let lvl = -28; lvl <= 4; lvl += 2) {
  const major = lvl % 10 === 0;
  push(`<path d="${contour(lvl + 0.001)}" stroke="${P.PINE_BARK}" stroke-opacity="${major ? 0.55 : 0.25}" stroke-width="${major ? 1.4 : 0.7}"/>`);
}
push('</g>');

// --- rail
push(`<path d="${pathD(L.rail.pts)}" fill="none" stroke="${P.IRON_BLACK}" stroke-width="4"/>`);
push(`<path d="${pathD(L.rail.pts)}" fill="none" stroke="${P.TRIM_WHITE}" stroke-width="2.4" stroke-dasharray="8 8"/>`);

// --- streets
push('<g id="streets" fill="none" stroke-linecap="round" stroke-linejoin="round">');
const casing = { main: 1, secondary: 1, campus: 1, lane: 1, alley: 1 };
for (const s of L.streets) push(`<path d="${pathD(s.pts)}" stroke="${P.IRON_BLACK}" stroke-opacity="0.55" stroke-width="${s.row + 3}"/>`);
for (const s of L.streets) {
  const col = s.cls === 'alley' ? P.DIRT_PATH : s.cls === 'campus' || s.cls === 'lane' ? P.CONCRETE_NEW : P.ASPHALT_AGED;
  push(`<path d="${pathD(s.pts)}" stroke="${col}" stroke-width="${s.row}"/>`);
  if (s.cls === 'main') push(`<path d="${pathD(s.pts)}" stroke="${P.MARKING_YELLOW}" stroke-width="0.8" stroke-dasharray="6 6"/>`);
}
push('</g>');
void casing;

// --- fieldstone walls
for (const w of L.walls) push(`<path d="${pathD(w.pts)}" fill="none" stroke="${P.FIELDSTONE_A}" stroke-width="3.2" stroke-dasharray="3 1.2"/>`);

// --- features
push('<g id="features">');
const kindFill = { hero_shop: P.BRICK_DOWNTOWN_A, deck: P.CONCRETE_NEW, hospital: P.TRIM_WHITE, campus: P.BRICK_CAMPUS_A, dorm: P.BRICK_CAMPUS_A,
  mill: P.BRICK_DOWNTOWN_A, lawn: P.GRASS_OCT, plaza: P.BRICK_PAVER_A, bridge: P.FIELDSTONE_A };
for (const ft of L.features) {
  const fill = kindFill[ft.kind];
  if (ft.rect) { const [a, b, c, d] = ft.rect; push(`<rect x="${a}" y="${b}" width="${c - a}" height="${d - b}" fill="${fill}" stroke="${P.IRON_BLACK}" stroke-width="0.8"/>`); }
  if (ft.circle) { const [cx, cz, r] = ft.circle; push(`<circle cx="${cx}" cy="${cz}" r="${r}" fill="${fill}" stroke="${P.IRON_BLACK}" stroke-width="0.8"/>`); }
}
push('</g>');

// --- landmarks
push('<g id="landmarks">');
const centers = [];
for (const lm of L.landmarks) {
  let cx, cz;
  if (lm.rect) {
    const [a, b, c, d] = lm.rect; cx = (a + c) / 2; cz = (b + d) / 2;
    push(`<rect x="${a}" y="${b}" width="${c - a}" height="${d - b}" fill="${P.BRICK_CAMPUS_A}" fill-opacity="${lm.n === 10 ? 0.45 : 1}" stroke="${P.ONSU_NAVY}" stroke-width="2"/>`);
  } else {
    const [x, z, r] = lm.circle; cx = x; cz = z;
    push(`<circle cx="${x}" cy="${z}" r="${r}" fill="${lm.n === 11 ? P.TRIM_WHITE : P.COPPER_PATINA}" stroke="${lm.n === 11 ? P.HEAVEN_BLUE : P.ONSU_NAVY}" stroke-width="${lm.n === 11 ? 6 : 2}"/>`);
  }
  if (lm.n === 10) { // field
    push(`<rect x="${360 - 55}" y="${810 - 24.4}" width="110" height="48.8" fill="#3D7A3A" stroke="${P.MARKING_WHITE}" stroke-width="1"/>`);
    push(`<rect x="305" y="785.6" width="9.1" height="48.8" fill="${P.HEAVEN_BLUE}"/><rect x="405.9" y="785.6" width="9.1" height="48.8" fill="${P.HEAVEN_BLUE}"/>`);
  }
  if (lm.n === 11) push(`<rect x="-14" y="862.5" width="28.7" height="15.2" fill="#D8B07A"/>`);
  centers.push([lm.n, cx, cz]);
}
for (const [n, cx, cz] of centers) {
  push(`<circle cx="${cx}" cy="${cz}" r="11" fill="${P.ONSU_NAVY}" stroke="${P.TRIM_WHITE}" stroke-width="2"/>`);
  push(`<text x="${cx}" y="${cz + 4.5}" font-size="13" font-weight="bold" text-anchor="middle" fill="${P.TRIM_WHITE}" font-family="'DejaVu Sans', Arial, sans-serif">${n}</text>`);
}
push('</g>');

// --- labels
push('<g id="labels">');
for (const d of L.districts) {
  if (d.id === 'campus_generic') continue;
  push(`<text x="${d.label[0]}" y="${d.label[1]}" font-size="19" font-weight="bold" letter-spacing="1.5" text-anchor="middle" fill="${P.IRON_BLACK}" stroke="${P.BRICK_PAINTED_WHITE}" stroke-width="4" paint-order="stroke">${esc(d.name.toUpperCase())}</text>`);
  if (d.elev) push(`<text x="${d.label[0]}" y="${d.label[1] + 18}" font-size="12" font-style="italic" text-anchor="middle" fill="${P.IRON_BLACK}" stroke="${P.BRICK_PAINTED_WHITE}" stroke-width="3" paint-order="stroke">${esc(d.elev)}</text>`);
}
const g0 = L.districts.find((d) => d.id === 'campus_generic');
push(`<text x="${g0.label[0]}" y="${g0.label[1]}" font-size="13" font-style="italic" text-anchor="middle" fill="${P.IRON_BLACK}" opacity="0.75">ONSU east campus</text>`);
push(`<text x="${g0.label[0]}" y="${g0.label[1] + 16}" font-size="13" font-style="italic" text-anchor="middle" fill="${P.IRON_BLACK}" opacity="0.75">(generic halls &amp; labs)</text>`);
L.streets.forEach((s, i) => {
  push(`<path id="st${i}" d="${pathD(s.pts)}" fill="none"/>`);
  const fs = s.cls === 'alley' || s.cls === 'lane' ? 8 : 11;
  push(`<text font-size="${fs}" font-family="'DejaVu Sans', Arial, sans-serif" fill="${P.TRIM_WHITE}" stroke="${P.IRON_BLACK}" stroke-width="2.4" paint-order="stroke" dy="3.5"><textPath href="#st${i}" startOffset="${s.cls === 'alley' ? '50%' : '22%'}" text-anchor="middle">${esc(s.name)}</textPath></text>`);
});
// Summit marker
push(`<circle cx="0" cy="0" r="16" fill="none" stroke="${P.MARKING_YELLOW}" stroke-width="3"/>`);
push(`<text x="22" y="-18" font-size="14" font-weight="bold" fill="${P.ONSU_NAVY}" stroke="${P.BRICK_PAINTED_WHITE}" stroke-width="3" paint-order="stroke">THE SUMMIT (0,0,0)</text>`);
push(`<text x="-690" y="${L.rail.pts[1][1] - 160}" font-size="10" fill="${P.IRON_BLACK}" transform="rotate(86 -690 ${L.rail.pts[1][1] - 160})">${esc(L.rail.name)}</text>`);
push('</g>');

// --- grid ticks
push('<g id="grid" font-family="DejaVu Sans, Arial, sans-serif" font-size="10" fill="' + P.IRON_BLACK + '">');
for (let x = L.CORE.x0; x <= L.CORE.x1; x += 100) {
  push(`<line x1="${x}" y1="${L.CORE.z0}" x2="${x}" y2="${L.CORE.z0 - 8}" stroke="${P.IRON_BLACK}"/><text x="${x}" y="${L.CORE.z0 - 12}" text-anchor="middle">${x}</text>`);
}
for (let z = L.CORE.z0 + 50; z <= L.CORE.z1; z += 100) {
  push(`<line x1="${L.CORE.x0}" y1="${z}" x2="${L.CORE.x0 - 8}" y2="${z}" stroke="${P.IRON_BLACK}"/><text x="${L.CORE.x0 - 11}" y="${z + 3}" text-anchor="end">${z}</text>`);
}
push(`<rect x="${L.CORE.x0}" y="${L.CORE.z0}" width="${L.CORE.x1 - L.CORE.x0}" height="${L.CORE.z1 - L.CORE.z0}" fill="none" stroke="${P.IRON_BLACK}" stroke-width="2"/>`);
push('</g>');

// --- title block
push(`<text x="${L.CORE.x0}" y="${vz0 + 36}" font-size="34" font-weight="bold" letter-spacing="4" fill="${P.ONSU_NAVY}">CATHEDRAL MOUNT</text>`);
push(`<text x="${L.CORE.x0}" y="${vz0 + 60}" font-size="15" font-style="italic" fill="${P.IRON_BLACK}">State of Pamlico · Phase 1 concept map · dense core 1,600 × 1,400 m · x = east (m), z = south (m), Three.js −Z = north</text>`);

// --- side panel
const px = vx1 + 10; let py = vz0 + 70;
push(`<rect x="${vx1 - 10}" y="${vz0}" width="${panelW + 10}" height="${H}" fill="${P.TRIM_WHITE}"/>`);
push(`<g font-family="'DejaVu Sans', Arial, sans-serif" fill="${P.IRON_BLACK}">`);
push(`<text x="${px}" y="${py}" font-size="18" font-weight="bold" fill="${P.ONSU_NAVY}">LANDMARKS (§10)</text>`); py += 24;
const seen = new Map();
for (const lm of L.landmarks) { const k = lm.n; seen.set(k, seen.has(k) ? seen.get(k) + ' / ' + lm.name.replace(/^Med\. Center /, '') : lm.name); }
for (const [n, name] of seen) {
  const nm = n === 13 ? 'ONSU Medical Center (4 towers, skybridges F3)' : name;
  push(`<circle cx="${px + 10}" cy="${py - 4}" r="9" fill="${P.ONSU_NAVY}"/><text x="${px + 10}" y="${py}" font-size="11" font-weight="bold" fill="${P.TRIM_WHITE}" text-anchor="middle">${n}</text>`);
  push(`<text x="${px + 26}" y="${py}" font-size="13">${esc(nm)}</text>`); py += 22;
}
py += 12;
push(`<text x="${px}" y="${py}" font-size="18" font-weight="bold" fill="${P.ONSU_NAVY}">KEY</text>`); py += 22;
const key = [
  ['line', P.ASPHALT_AGED, 'Street (width = right-of-way)'], ['line', P.CONCRETE_NEW, 'Campus road / lane'], ['line', P.DIRT_PATH, 'Invented alley'],
  ['dash', P.FIELDSTONE_A, 'Fieldstone wall'], ['rail', P.IRON_BLACK, 'Rail line on embankment'], ['contour', P.PINE_BARK, 'Contour 2 m (bold 10 m), schematic'],
  ['box', P.BRICK_CAMPUS_A, 'Landmark / hero building'], ['box', P.CONCRETE_NEW, 'Parking deck'],
];
for (const [t, c, label] of key) {
  if (t === 'box') push(`<rect x="${px}" y="${py - 11}" width="22" height="13" fill="${c}" stroke="${P.IRON_BLACK}" stroke-width="0.8"/>`);
  else if (t === 'dash') push(`<line x1="${px}" y1="${py - 4}" x2="${px + 22}" y2="${py - 4}" stroke="${c}" stroke-width="3.2" stroke-dasharray="3 1.2"/>`);
  else if (t === 'rail') push(`<line x1="${px}" y1="${py - 4}" x2="${px + 22}" y2="${py - 4}" stroke="${c}" stroke-width="4"/><line x1="${px}" y1="${py - 4}" x2="${px + 22}" y2="${py - 4}" stroke="${P.TRIM_WHITE}" stroke-width="2.4" stroke-dasharray="4 4"/>`);
  else if (t === 'contour') push(`<line x1="${px}" y1="${py - 4}" x2="${px + 22}" y2="${py - 4}" stroke="${c}" stroke-width="1.4" stroke-opacity="0.6"/>`);
  else push(`<line x1="${px}" y1="${py - 4}" x2="${px + 22}" y2="${py - 4}" stroke="${c}" stroke-width="7"/>`);
  push(`<text x="${px + 30}" y="${py}" font-size="13">${esc(label)}</text>`); py += 20;
}
// scale bar
py += 16;
push(`<text x="${px}" y="${py}" font-size="13" font-weight="bold">0</text>`);
for (let i = 0; i < 4; i++) push(`<rect x="${px + i * 50}" y="${py + 6}" width="50" height="8" fill="${i % 2 ? P.TRIM_WHITE : P.IRON_BLACK}" stroke="${P.IRON_BLACK}"/>`);
push(`<text x="${px + 200}" y="${py}" font-size="13" font-weight="bold" text-anchor="middle">200 m</text>`);
// north arrow
push(`<g transform="translate(${px + 380} ${py - 10})"><path d="M0 -26 L12 14 L0 6 L-12 14 Z" fill="${P.ONSU_NAVY}"/><text y="32" font-size="15" font-weight="bold" text-anchor="middle">N (−Z)</text></g>`);
py += 70;

// inset: total map + tiles
push(`<text x="${px}" y="${py}" font-size="18" font-weight="bold" fill="${P.ONSU_NAVY}">FULL MAP 3.6 × 3.4 km · 200 m TILES</text>`); py += 14;
const s = 0.118; const ix = px, iz = py;
const tx = (x) => ix + (x - L.TOTAL.x0) * s, tz = (z) => iz + (z - L.TOTAL.z0) * s;
push(`<rect x="${tx(L.TOTAL.x0)}" y="${tz(L.TOTAL.z0)}" width="${(L.TOTAL.x1 - L.TOTAL.x0) * s}" height="${(L.TOTAL.z1 - L.TOTAL.z0) * s}" fill="${P.LOBLOLLY_NEEDLE}" fill-opacity="0.55"/>`);
push(`<rect x="${tx(L.CORE.x0)}" y="${tz(L.CORE.z0)}" width="${(L.CORE.x1 - L.CORE.x0) * s}" height="${(L.CORE.z1 - L.CORE.z0) * s}" fill="#DCD6C4" stroke="${P.ONSU_NAVY}" stroke-width="2"/>`);
// bypass loop ~600 m outside core
const by = [[-1500, -1050], [1300, -1050], [1400, -300], [1350, 1550], [-1500, 1550], [-1550, 300]];
push(`<polygon points="${by.map(([x, z]) => `${f(tx(x))},${f(tz(z))}`).join(' ')}" fill="none" stroke="${P.MARKING_YELLOW}" stroke-width="3.5" stroke-linejoin="round"/>`);
for (let c = 0; c <= (L.TOTAL.x1 - L.TOTAL.x0) / L.TILE; c++) push(`<line x1="${f(tx(L.TOTAL.x0 + c * L.TILE))}" y1="${tz(L.TOTAL.z0)}" x2="${f(tx(L.TOTAL.x0 + c * L.TILE))}" y2="${tz(L.TOTAL.z1)}" stroke="${P.IRON_BLACK}" stroke-opacity="0.3" stroke-width="0.6"/>`);
for (let r = 0; r <= (L.TOTAL.z1 - L.TOTAL.z0) / L.TILE; r++) push(`<line x1="${tx(L.TOTAL.x0)}" y1="${f(tz(L.TOTAL.z0 + r * L.TILE))}" x2="${tx(L.TOTAL.x1)}" y2="${f(tz(L.TOTAL.z0 + r * L.TILE))}" stroke="${P.IRON_BLACK}" stroke-opacity="0.3" stroke-width="0.6"/>`);
push(`<circle cx="${tx(0)}" cy="${tz(0)}" r="3.5" fill="${P.MARKING_YELLOW}" stroke="${P.IRON_BLACK}"/>`);
push(`<text x="${tx(0) + 6}" y="${tz(0) - 5}" font-size="10" font-weight="bold">${L.tileOf(0, 0)}</text>`);
push(`<text x="${tx(-1880)}" y="${tz(-1380)}" font-size="9" fill="${P.TRIM_WHITE}">T_0_0</text>`);
push(`<text x="${tx(L.CORE.x0) + 4}" y="${tz(L.CORE.z1) - 5}" font-size="10" font-weight="bold" fill="${P.ONSU_NAVY}">DENSE CORE</text>`);
push(`<text x="${tx(-1450)}" y="${tz(-1100)}" font-size="10" fill="${P.TRIM_WHITE}">Pamlico Bypass (4-lane)</text>`);
push(`<text x="${tx(-1700)}" y="${tz(1850)}" font-size="10" fill="${P.TRIM_WHITE}">OUTER RING · pine forest · suburban roofs · no interiors</text>`);
push(`<path d="M${tx(1500)} ${tz(250)} l-18 -10 v20 z" fill="${P.EARL_BLUE}"/><text x="${tx(1450)}" y="${tz(120)}" font-size="10" font-weight="bold" fill="${P.TRIM_WHITE}" text-anchor="end">→ Steer City / Earl U</text>`);
py += (L.TOTAL.z1 - L.TOTAL.z0) * s + 24;
push(`<text x="${px}" y="${py}" font-size="11" font-style="italic">Seed 1795. All positions concept-level (±10 m); Phase 3 snaps to 1 cm.</text>`);
push('</g>');
push('</svg>');

writeFileSync(resolve(outDir, 'concept-map.svg'), out.join('\n'));
const json = {
  seed: L.SEED, units: 'meters', axes: { x: 'east', z: 'south (+z); Three.js -Z is north', y: 'up' }, origin: 'The Summit: Hamilton St x Columbia St, street crown',
  core: L.CORE, total: L.TOTAL, tileSize: L.TILE, originTile: L.tileOf(0, 0),
  districts: L.districts.map((d) => ({ ...d, tiles: [...new Set(d.poly.map(([x, z]) => L.tileOf(x, z)))] })),
  streets: L.streets, rail: L.rail, landmarks: L.landmarks.map((l) => ({ ...l, tile: L.tileOf(...(l.rect ? [(l.rect[0] + l.rect[2]) / 2, (l.rect[1] + l.rect[3]) / 2] : l.circle)) })),
  features: L.features, walls: L.walls, spotElevations: L.spots, ravine: L.ravine, bowl: L.bowl,
};
writeFileSync(resolve(outDir, 'concept-layout.json'), JSON.stringify(json, null, 2));
console.log('wrote concept-map.svg', W, 'x', H, '+ concept-layout.json; origin tile', L.tileOf(0, 0));
