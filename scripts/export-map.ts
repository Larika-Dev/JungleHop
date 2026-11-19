// Map model export (CLAUDE.md §12 Export / §20 city map): one GLB of the whole city at map detail —
// terrain (4 m core / 20 m outer ring), road ribbons with sidewalks & centerlines, every building as a
// massing block (landmarks with their full hand-authored exteriors), and simplified trees.
// Vertex colors only (palette.ts); normals are left to the viewer (flat shading) to keep the file small.
// Usage: npx vite-node scripts/export-map.ts [outFile]
import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname } from 'node:path';
import { BufferAttribute, BufferGeometry, Color, Group, InstancedMesh, Matrix4, Mesh, MeshStandardMaterial, Quaternion, Scene, Vector3 } from 'three';
import { GLTFExporter } from 'three/examples/jsm/exporters/GLTFExporter.js';
import { pc, type PaletteKey } from '../src/core/palette';
import { paletteKeyOf, isPaletteKey } from '../src/core/materials';
import { CORE, TOTAL, allTiles } from '../src/core/tiles';
import { Terrain } from '../src/terrain/terrain';
import { splatAt } from '../src/terrain/terrainMesh';
import { polyAt, profileAt } from '../src/roads/network';
import { cityPlan } from '../src/world/cityPlan';
import { buildImpostors } from '../src/buildings/impostors';
import { planFor, LANDMARK_HOOKS } from '../src/buildings/manager';
import { buildExterior, buildingMatrix, type ExteriorOut } from '../src/buildings/exterior';
import { GeoBuilder } from '../src/core/geo';
import { treesForTile } from '../src/vegetation/placement';
import { SPECIES } from '../src/vegetation/trees';
import { Rng } from '../src/core/rng';

// GLTFExporter (binary) needs FileReader, which Node lacks.
(globalThis as any).FileReader ??= class {
  result: ArrayBuffer | string | null = null; onloadend: (() => void) | null = null; onload: (() => void) | null = null;
  readAsArrayBuffer(b: Blob) { b.arrayBuffer().then((a) => { this.result = a; this.onload?.(); this.onloadend?.(); }); }
  readAsDataURL(b: Blob) { b.arrayBuffer().then((a) => { this.result = `data:${b.type};base64,` + Buffer.from(a).toString('base64'); this.onload?.(); this.onloadend?.(); }); }
};

const out = process.argv[2] ?? 'export/cathedral-mount-map.glb';
const T = Terrain.get();
const city = cityPlan();

/** Simple indexed accumulator: positions + linear vertex colors. */
class Acc {
  pos: number[] = []; col: number[] = []; idx: number[] = [];
  v(x: number, y: number, z: number, c: Color) { this.pos.push(x, y, z); this.col.push(c.r, c.g, c.b); return this.pos.length / 3 - 1; }
  tri(a: number, b: number, c: number) { this.idx.push(a, b, c); }
  quad(a: number, b: number, c: number, d: number) { this.idx.push(a, b, c, a, c, d); }
  mesh(name: string) {
    const g = new BufferGeometry();
    g.setAttribute('position', new BufferAttribute(new Float32Array(this.pos), 3));
    g.setAttribute('color', new BufferAttribute(new Float32Array(this.col), 3));
    g.setIndex(this.pos.length / 3 > 65535 ? new BufferAttribute(new Uint32Array(this.idx), 1) : new BufferAttribute(new Uint16Array(this.idx), 1));
    const m = new Mesh(g, new MeshStandardMaterial({ vertexColors: true, roughness: 0.9, name }));
    m.name = name;
    return m;
  }
  get tris() { return this.idx.length / 3; }
}

// ------------------------------------------------------------------------------------------ terrain
const GRASS = pc('GRASS_OCT'), WORN = pc('GRASS_WORN'), CLAY = pc('RED_CLAY'), FOREST = pc('PINE_STRAW').clone().lerp(pc('LOBLOLLY_NEEDLE'), 0.55);
function groundColor(x: number, z: number): Color {
  const hit = T.net.query(x, z);
  if (hit && hit.zone === 'asphalt') return pc(hit.road.sec.surface === 'concrete_new' ? 'CONCRETE_NEW' : 'ASPHALT_AGED');
  if (hit && (hit.zone === 'sidewalk' || hit.zone === 'curb')) return pc('CONCRETE_AGED');
  const [g, w, c, f] = splatAt(x, z, T);
  return new Color().setRGB(GRASS.r * g + WORN.r * w + CLAY.r * c + FOREST.r * f, GRASS.g * g + WORN.g * w + CLAY.g * c + FOREST.g * f, GRASS.b * g + WORN.b * w + CLAY.b * c + FOREST.b * f);
}
function grid(acc: Acc, x0: number, z0: number, x1: number, z1: number, step: number, skip?: (cx: number, cz: number) => boolean, dy = 0) {
  const nx = Math.round((x1 - x0) / step), nz = Math.round((z1 - z0) / step);
  const base = acc.pos.length / 3;
  for (let j = 0; j <= nz; j++) for (let i = 0; i <= nx; i++) {
    const x = x0 + i * step, z = z0 + j * step;
    acc.v(x, T.height(x, z) + dy, z, groundColor(x, z));
  }
  for (let j = 0; j < nz; j++) for (let i = 0; i < nx; i++) {
    if (skip?.(x0 + (i + 0.5) * step, z0 + (j + 0.5) * step)) continue;
    const a = base + j * (nx + 1) + i, b = a + 1, c = a + nx + 1, d = c + 1;
    acc.tri(a, c, b); acc.tri(b, c, d);
  }
}
console.time('terrain');
const terrainChunks: Acc[] = [];
for (let cx = CORE.x0; cx < CORE.x1; cx += 400) for (let cz = CORE.z0; cz < CORE.z1; cz += 350) {
  const a = new Acc(); grid(a, cx, cz, Math.min(CORE.x1, cx + 400), Math.min(CORE.z1, cz + 350), 5); terrainChunks.push(a);
}
const terrainOuter = new Acc();
grid(terrainOuter, TOTAL.x0, TOTAL.z0, TOTAL.x1, TOTAL.z1, 20, (x, z) => x > CORE.x0 && x < CORE.x1 && z > CORE.z0 && z < CORE.z1, -0.15);
console.timeEnd('terrain');

// ------------------------------------------------------------------------------------------ roads
console.time('roads');
const roads = new Acc();
function ribbon(r: import('../src/roads/network').Road, s0: number, s1: number, d0: number, d1: number, dy: number, c: Color, step = 3) {
  if (s1 - s0 < 0.5) return;
  const n = Math.max(1, Math.ceil((s1 - s0) / step));
  let pa = -1, pb = -1;
  for (let k = 0; k <= n; k++) {
    const s = s0 + ((s1 - s0) * k) / n;
    const f = polyAt(r, s), y = profileAt(r, s) + dy;
    const a = roads.v(f.p[0] + f.n[0] * d0, y, f.p[1] + f.n[1] * d0, c);
    const b = roads.v(f.p[0] + f.n[0] * d1, y, f.p[1] + f.n[1] * d1, c);
    if (pa >= 0) { roads.tri(pa, pb, a); roads.tri(pb, b, a); }
    pa = a; pb = b;
  }
}
for (const r of T.net.roads) {
  if (r.kind === 'rail') continue;
  const asphalt = pc(r.sec.surface === 'concrete_new' ? 'CONCRETE_NEW' : r.kind === 'highway' ? 'ASPHALT_FRESH' : 'ASPHALT_AGED');
  ribbon(r, 0, r.length, -r.half, r.half, 0.08, asphalt);
  const walk = r.sec.walk.startsWith('pavers') ? pc('BRICK_PAVER_A') : pc('CONCRETE_AGED');
  for (const sp of r.spans) {
    if (r.sec.curb && r.sec.sidewalkCm > 0) {
      const w = r.sec.sidewalkCm / 100;
      ribbon(r, sp.l0, sp.l1, r.half, r.half + 0.15 + w, 0.23, walk);
      ribbon(r, sp.r0, sp.r1, -r.half - 0.15 - w, -r.half, 0.23, walk);
    }
    if (r.sec.centerline !== 'none') {
      const y = pc('MARKING_YELLOW');
      if (r.sec.centerline === 'double_yellow') { ribbon(r, sp.s0, sp.s1, -0.2, -0.1, 0.1, y); ribbon(r, sp.s0, sp.s1, 0.1, 0.2, 0.1, y); }
      else for (let s = sp.s0 + 2; s < sp.s1 - 3; s += 9) ribbon(r, s, s + 3, -0.06, 0.06, 0.1, y, 3);
    }
  }
}
console.timeEnd('roads');

// ------------------------------------------------------------------------------------------ buildings
console.time('buildings');
const impostors = buildImpostors(city, { trees: false });
const blocks = new Acc();
const landmarks = new Acc();
const isLandmark = (s: (typeof city.buildings)[number]) => !!s.spec.custom && s.spec.custom !== 'business' && s.spec.custom !== 'cinema';
const landmarkIds = new Set(city.buildings.filter(isLandmark).map((s) => s.spec.id));
function appendGeometry(acc: Acc, g: BufferGeometry, tint: Color) {
  const p = g.getAttribute('position'), c = g.getAttribute('color'), ix = g.getIndex();
  const base = acc.pos.length / 3;
  for (let i = 0; i < p.count; i++) {
    acc.pos.push(p.getX(i), p.getY(i), p.getZ(i));
    const cr = c ? c.getX(i) : 1, cg = c ? c.getY(i) : 1, cb = c ? c.getZ(i) : 1;
    acc.col.push(cr * tint.r, cg * tint.g, cb * tint.b);
  }
  if (ix) for (let i = 0; i < ix.count; i++) acc.idx.push(base + ix.getX(i));
  else for (let i = 0; i < p.count; i++) acc.idx.push(base + i);
}
/** Append only triangles of at least minArea m² (map detail), compacting vertices. */
function appendCoarse(acc: Acc, g: BufferGeometry, tint: Color, minArea: number) {
  const p = g.getAttribute('position'), c = g.getAttribute('color'), ix = g.getIndex();
  const n = ix ? ix.count : p.count, at = (i: number) => (ix ? ix.getX(i) : i);
  const remap = new Map<number, number>();
  const A = new Vector3(), B = new Vector3(), C = new Vector3();
  const vid = (i: number) => {
    let r = remap.get(i);
    if (r === undefined) {
      r = acc.pos.length / 3; remap.set(i, r);
      acc.pos.push(p.getX(i), p.getY(i), p.getZ(i));
      acc.col.push((c ? c.getX(i) : 1) * tint.r, (c ? c.getY(i) : 1) * tint.g, (c ? c.getZ(i) : 1) * tint.b);
    }
    return r;
  };
  for (let t = 0; t < n; t += 3) {
    const i0 = at(t), i1 = at(t + 1), i2 = at(t + 2);
    A.fromBufferAttribute(p, i0); B.fromBufferAttribute(p, i1); C.fromBufferAttribute(p, i2);
    if (B.clone().sub(A).cross(C.clone().sub(A)).length() / 2 < minArea) continue;
    acc.idx.push(vid(i0), vid(i1), vid(i2));
  }
}
// massing blocks for everything except landmarks: rebuild from impostor meshes per spec is not separable,
// so regenerate impostors with landmarks skipped
const nonLandmark = { ...city, byTile: new Map([...city.byTile].map(([t, l]) => [t, l.filter((s) => !landmarkIds.has(s.spec.id))])) } as typeof city;
void impostors;
for (const [, grp] of buildImpostors(nonLandmark, { trees: false })) grp.traverse((o) => { if ((o as Mesh).isMesh) appendGeometry(blocks, (o as Mesh).geometry, new Color(1, 1, 1)); });

const WHITE = new Color(1, 1, 1);
function keyColor(key: string): Color {
  if (key.startsWith('glass')) return pc('GLASS_DARK');
  if (key === 'water') return pc('PUDDLE_TINT');
  const k = paletteKeyOf(key);
  if (isPaletteKey(k)) return pc(k as PaletteKey);
  if (key.includes('boardform')) return pc('CONCRETE_BOARDFORM');
  if (key.includes('concrete')) return pc('CONCRETE_NEW');
  if (key.includes('fieldstone') || key.includes('rubble')) return pc('FIELDSTONE_A');
  if (key.includes('slate')) return pc('SLATE_A');
  if (key.includes('marble')) return pc('MARBLE_WHITE');
  if (key.includes('granite')) return pc('GRANITE_CURB');
  if (key.includes('turf')) return pc('FIELD_TURF');
  if (key.includes('asphalt')) return pc('ASPHALT_AGED');
  if (key.includes('copper')) return pc('COPPER_PATINA');
  if (key.includes('limestone')) return pc('LIMESTONE_TRIM');
  return WHITE;
}
for (const s of city.buildings) {
  if (!landmarkIds.has(s.spec.id)) continue;
  const spec = s.spec, plan = planFor(spec);
  const hooks = LANDMARK_HOOKS.get(spec.custom!);
  const ext: ExteriorOut = hooks?.customShell ? { g: new GeoBuilder(), doors: [], walls: [], floors: [], glass: [] } : buildExterior(spec, plan, { frontGrade: s.grades.front, lowGrade: s.grades.low, bIndex: 0 });
  hooks?.exterior?.(spec, plan, ext);
  const g = new GeoBuilder();
  g.merge(ext.g, buildingMatrix(spec));
  for (const key of g.buckets.keys()) {
    if (key.startsWith('glassFar')) continue;
    const geo = (g as any).geometryFor(key) as BufferGeometry | null;
    if (geo) appendCoarse(landmarks, geo, keyColor(key), 0.45);
  }
}
console.timeEnd('buildings');

// ------------------------------------------------------------------------------------------ trees
console.time('trees');
// two unit shapes (pine cone, broadleaf crown, each with a trunk) instanced per species via EXT_mesh_gpu_instancing
function unitTree(pine: boolean): BufferGeometry {
  const a = new Acc(), W = new Color(1, 1, 1), bark = new Color(0.55, 0.5, 0.45);
  const yb = pine ? 0.45 : 0.32, r = pine ? 0.2 : 0.36, ym = pine ? yb : (yb + 1) / 2;
  const top = a.v(0, 1, 0, W);
  const rv = [0, 1, 2, 3, 4, 5].map((k) => { const t = (k / 6) * Math.PI * 2; return a.v(Math.cos(t) * r, ym, Math.sin(t) * r, W); });
  for (let k = 0; k < 6; k++) a.tri(top, rv[(k + 1) % 6], rv[k]);
  const bot = a.v(0, pine ? yb : yb - 0.08, 0, W);
  for (let k = 0; k < 6; k++) a.tri(bot, rv[k], rv[(k + 1) % 6]);
  const tw = 0.025;
  const tb = [[-tw, -tw], [tw, -tw], [tw, tw], [-tw, tw]].map(([x, z]) => [a.v(x, 0, z, bark), a.v(x, yb, z, bark)]);
  for (let k = 0; k < 4; k++) { const [p0, p1] = tb[k], [q0, q1] = tb[(k + 1) % 4]; a.quad(p0, q0, q1, p1); }
  return a.mesh('u').geometry;
}
const unit = { pine: unitTree(true), broad: unitTree(false) };
const bySpecies = new Map<string, Matrix4[]>();
const rng = new Rng('map-trees');
const q = new Quaternion(), up = new Vector3(0, 1, 0);
let treeCount = 0;
for (const t of allTiles()) {
  for (const tr of treesForTile(t)) {
    const inCore = tr.x > CORE.x0 - 150 && tr.x < CORE.x1 + 150 && tr.z > CORE.z0 - 150 && tr.z < CORE.z1 + 150;
    if (!inCore && rng.next() > 0.3) continue; // thin the outer-ring forest
    const d = SPECIES[tr.sp];
    const h = ((d.h[0] + d.h[1]) / 2) * tr.scale;
    q.setFromAxisAngle(up, tr.rot);
    const m = new Matrix4().compose(new Vector3(tr.x, tr.y, tr.z), q, new Vector3(h, h, h));
    if (!bySpecies.has(tr.sp)) bySpecies.set(tr.sp, []);
    bySpecies.get(tr.sp)!.push(m); treeCount++;
  }
}
const treeMeshes: Mesh[] = [];
for (const [sp, ms] of bySpecies) {
  const im = new InstancedMesh(sp === 'loblolly' ? unit.pine : unit.broad, new MeshStandardMaterial({ vertexColors: true, color: pc(SPECIES[sp as keyof typeof SPECIES].leaf), roughness: 0.9, name: `tree_${sp}` }), ms.length);
  ms.forEach((m, i) => im.setMatrixAt(i, m));
  im.name = `trees_${sp}`;
  treeMeshes.push(im);
}
console.log(`trees: ${treeCount} instances, ${bySpecies.size} species`);
console.timeEnd('trees');

// ------------------------------------------------------------------------------------------ export
const scene = new Scene();
const root = new Group();
root.name = 'CathedralMount';
root.userData = { seed: 1795, units: 'meters', axes: '+X east, -Z north, +Y up; origin = The Summit', buildings: city.buildings.length };
for (const [acc, name] of [...terrainChunks.map((a, i) => [a, `terrain_core_${i}`] as const), [terrainOuter, 'terrain_outer'], [roads, 'roads'], [blocks, 'buildings'], [landmarks, 'landmarks']] as const) {
  console.log(`${name}: ${acc.pos.length / 3} verts, ${acc.tris} tris`);
  root.add(acc.mesh(name));
}
for (const t of treeMeshes) root.add(t);
scene.add(root);
const glb = await new GLTFExporter().parseAsync(scene, { binary: true }) as ArrayBuffer;
mkdirSync(dirname(out), { recursive: true });
writeFileSync(out, Buffer.from(glb));
console.log(`wrote ${out} (${(glb.byteLength / 1e6).toFixed(1)} MB)`);

// labels for map viewers: districts + landmarks with terrain height
const { DISTRICTS, LANDMARKS } = await import('../src/world/layout');
const labels = {
  districts: DISTRICTS.filter((d) => d.id !== 'campus_generic' || true).map((d) => ({ name: d.name, x: d.label[0], z: d.label[1], y: +T.height(d.label[0], d.label[1]).toFixed(1) })),
  landmarks: LANDMARKS.map((l) => ({ n: l.n, name: l.name, x: l.x, z: l.z, y: +T.height(l.x, l.z).toFixed(1) })),
};
writeFileSync(out.replace(/\.glb$/, '-labels.json'), JSON.stringify(labels));
console.log('wrote labels', labels.districts.length, labels.landmarks.length);
