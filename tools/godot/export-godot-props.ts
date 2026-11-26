// Street props, parked cars, power lines, ground decals and shrub clusters for the Godot port.
// Placement reuses the three.js city's road network, terrain, parks and building data so every prop
// sits on the real sidewalk/curb/lawn surface, faces the street and stays out of buildings.
//
//   godot/data/props.json
//   {
//     props:     { model: [[x, y, z, rotY, variant], ...] }   instanced street furniture & clutter
//     lamps:     [[x, y, z, rotY, type], ...]                  type 0 acorn (LED), 1 lantern (campus), 2 cobra (sodium)
//     furniture: [[modelId, x, y, z, rotY], ...]               outdoor uses of the 100 furniture models (café seating)
//     poles:     [[x, y, z, rotY], ...]   wires: [[i, j], ...] utility poles + the spans strung between them
//     decals:    { kind: [[x, y, z, rotY, sx, sz, nx, nz, variant], ...] }  flat ground decals (normal = (nx, ?, nz))
//   }
// Usage: npx vite-node tools/godot/export-godot-props.ts
import fs from 'node:fs';
import { furnitureByTile } from '../../src/street/furniture';
import { roadPlan } from '../../src/roads/build';
import { polyAt, profileAt, CROSS_SLOPE, CURB_H, CURB_TOP, type Road } from '../../src/roads/network';
import { Terrain } from '../../src/terrain/terrain';
import { parks, pathDist, inPark, PARK_CELL } from '../../src/vegetation/parks';
import { canPlant } from '../../src/vegetation/placement';
import { CORE } from '../../src/core/tiles';
import { districtAt } from '../../src/world/layout';
import { Rng } from '../../src/core/rng';

const T = Terrain.get();
const P = roadPlan();
const rng = new Rng('godot-props');
const r3 = (v: number) => Math.round(v * 1000) / 1000;
const r2 = (v: number) => Math.round(v * 100) / 100;

const props: Record<string, number[][]> = {};
const decals: Record<string, number[][]> = {};
const lamps: number[][] = [];
const furniture: number[][] = [];
const poles: number[][] = [];
const wires: number[][] = [];
let dropped = 0;
const addProp = (m: string, x: number, y: number, z: number, rot: number, v = 0) => {
  if (inBuilding(x, z, -0.3)) { dropped++; return; }   // never inside a footprint (parks run up to some landmark pads)
  (props[m] ??= []).push([r3(x), r3(y), r3(z), r3(rot), v]);
};

// ------------------------------------------------------------------ buildings (oriented footprints)
type B = { id: string; x: number; z: number; y: number; c: number; s: number; w: number; d: number; typ: string; dist: string; biz: string | null };
const BLD: B[] = JSON.parse(fs.readFileSync('godot/data/buildings.json', 'utf8')).buildings.map((b: any) => ({
  id: b.id, x: b.transform.x, z: b.transform.z, y: b.transform.y, c: Math.cos(b.transform.rotY), s: Math.sin(b.transform.rotY),
  w: b.footprintCm[0] / 100, d: b.footprintCm[1] / 100, typ: b.typology, dist: b.district, biz: b.business?.type ?? null,
}));
const BH = new Map<number, B[]>();
const HK = (x: number, z: number) => Math.floor(x / 25) * 100003 + Math.floor(z / 25);
for (const b of BLD) {
  const r = Math.hypot(b.w, b.d) + 4;
  for (let x = b.x - r; x <= b.x + r + 25; x += 25) for (let z = b.z - r; z <= b.z + r + 25; z += 25) {
    const k = HK(x, z); let a = BH.get(k); if (!a) BH.set(k, (a = [])); if (!a.includes(b)) a.push(b);
  }
}
/** building world = R_y(rotY) * local + origin; local +x along frontage, +z into the building */
const toWorld = (b: B, lx: number, lz: number): [number, number] => [b.x + b.c * lx + b.s * lz, b.z - b.s * lx + b.c * lz];
const toLocal = (b: B, x: number, z: number): [number, number] => { const dx = x - b.x, dz = z - b.z; return [b.c * dx - b.s * dz, b.s * dx + b.c * dz]; };
function inBuilding(x: number, z: number, margin = 0.4): boolean {
  for (const b of BH.get(HK(x, z)) ?? []) {
    const [lx, lz] = toLocal(b, x, z);
    if (lx > -margin && lz > -margin && lx < b.w + margin && lz < b.d + margin) return true;
  }
  return false;
}

// ------------------------------------------------------------------ surfaces
const q = (x: number, z: number) => T.net.query(x, z);
const surf = (x: number, z: number) => T.surface(x, z);
const inCore = (x: number, z: number) => x > CORE.x0 + 2 && x < CORE.x1 - 2 && z > CORE.z0 + 2 && z < CORE.z1 - 2;
function walkY(r: Road, s: number, d: number) { return profileAt(r, s) - CROSS_SLOPE * r.half + CURB_H + CROSS_SLOPE * (Math.abs(d) - r.half - CURB_TOP); }
function laneY(r: Road, s: number, d: number) { return profileAt(r, s) - CROSS_SLOPE * Math.abs(d); }
/** ground normal xz from the walkable surface */
function nrm(x: number, z: number): [number, number] {
  const e = 0.6, hx = surf(x + e, z) - surf(x - e, z), hz = surf(x, z + e) - surf(x, z - e);
  const nx = -hx / (2 * e), nz = -hz / (2 * e);
  const L = Math.hypot(nx, 1, nz);
  return [r3(nx / L), r3(nz / L)];
}
/** sidewalk test: point on a curb road's sidewalk band (not asphalt, not inside a building) */
function onSidewalk(x: number, z: number): boolean {
  const h = q(x, z);
  return !!h && h.zone === 'sidewalk' && !inBuilding(x, z, 0.2);
}
const free = (x: number, z: number, r = 0.6) => !inBuilding(x, z, r) && !(q(x, z) && q(x, z)!.zone !== 'verge');
function addDecal(kind: string, x: number, y: number, z: number, rot: number, sx: number, sz: number, v = 0) {
  if (inBuilding(x, z, -0.3)) { dropped++; return; }
  const [nx, nz] = nrm(x, z);
  (decals[kind] ??= []).push([r3(x), r3(y), r3(z), r3(rot), r2(sx), r2(sz), nx, nz, v]);
}

// ------------------------------------------------------------------ 1) the three.js street furniture set
const LAMP_TYPE: Record<string, number> = { acorn: 0, lantern: 1, cobra: 2 };
const benches: number[][] = [], racks: number[][] = [], cans: number[][] = [];
for (const list of furnitureByTile().values()) for (const p of list) {
  if (p.model in LAMP_TYPE) { lamps.push([r3(p.x), r3(p.y), r3(p.z), r3(p.rot), LAMP_TYPE[p.model]]); continue; }
  if (!inCore(p.x, p.z) && p.model !== 'log' && p.model !== 'stump') continue;
  addProp(p.model, p.x, p.y, p.z, p.rot);
  if (p.model === 'bench') benches.push([p.x, p.y, p.z, p.rot]);
  if (p.model === 'bikerack') racks.push([p.x, p.y, p.z, p.rot]);
  if (p.model === 'trash' || p.model === 'recycle') cans.push([p.x, p.y, p.z, p.rot]);
}
// bicycles locked to the racks (0-3 per rack, along the rack plane)
for (const [x, y, z, rot] of racks) {
  const n = Math.floor(rng.next() * 3.4);
  for (let i = 0; i < n; i++) {
    const lx = (i - 1) * 0.42 + (rng.next() - 0.5) * 0.1, lz = (i % 2 ? 0.22 : -0.22);
    const wx = x + Math.cos(rot) * lx + Math.sin(rot) * lz, wz = z - Math.sin(rot) * lx + Math.cos(rot) * lz;
    addProp('bicycle', wx, y, wz, rot + Math.PI / 2 + (rng.next() - 0.5) * 0.12, Math.floor(rng.next() * 6));
  }
}
// tree grates in the Hamilton / main street tree pits that hold a tree
{
  const TR: Record<string, number[][]> = JSON.parse(fs.readFileSync('godot/data/trees.json', 'utf8'));
  const th = new Set<number>();
  for (const l of Object.values(TR)) for (const [x, , z] of l) th.add(Math.round(x * 2) * 100003 + Math.round(z * 2));
  const has = (x: number, z: number) => { for (let i = -1; i <= 1; i++) for (let j = -1; j <= 1; j++) if (th.has((Math.round(x * 2) + i) * 100003 + Math.round(z * 2) + j)) return true; return false; };
  for (const t of P.treePits) if (has(t.x, t.z)) addProp('tree_grate', t.x, t.y + 0.003, t.z, 0);
}

// ------------------------------------------------------------------ 2) roads: parked cars, signs, drains, decals
const CAR_KINDS = ['sedan', 'hatch', 'suv', 'pickup', 'van', 'wagon'];
const carKind = () => { const p = rng.next(); return p < 0.34 ? 'sedan' : p < 0.52 ? 'hatch' : p < 0.74 ? 'suv' : p < 0.84 ? 'pickup' : p < 0.92 ? 'wagon' : 'van'; };
const carColor = () => Math.floor(rng.next() * 14);
function addCar(x: number, y: number, z: number, heading: number) { addProp('car_' + carKind(), x, y, z, heading, carColor()); }
const residential = (x: number, z: number) => { const d = districtAt(x, z)?.id; return d === 'residential_north' || d === 'cameron_heights' || d === 'carrburg' || d === 'toadstool'; };

for (const r of P.net.roads) {
  if (r.kind === 'highway' || r.kind === 'rail') continue;
  for (const sp of r.spans) for (const side of [1, -1] as const) {
    const a = side > 0 ? sp.l0 : sp.r0, b = side > 0 ? sp.l1 : sp.r1;
    if (b - a < 8) continue;
    const mid = polyAt(r, (a + b) / 2).p;
    if (!inCore(mid[0], mid[1])) continue;
    const onBridge = (s: number) => r.bridges.some(([b0, b1]) => s > b0 - 4 && s < b1 + 4);
    const near = (s: number, m: number) => P.midblock.some((k) => k.road === r && Math.abs(k.s - s) < m);
    const frame = (s: number, d: number) => { const f = polyAt(r, s); return { x: f.p[0] + f.n[0] * d, z: f.p[1] + f.n[1] * d, t: f.t }; };
    // heading for a car parked on this side (right-hand traffic: +normal side drives -t)
    const head = (t: [number, number]) => side > 0 ? Math.atan2(-t[0], -t[1]) : Math.atan2(t[0], t[1]);

    // parked cars: Hamilton parking lanes (every stall), residential streets along the curb
    if (r.kind === 'hamilton') {
      for (let s = a + 6.7; s < b - 5; s += 6.7) {
        if (near(s, 8) || onBridge(s) || rng.next() > 0.74) continue;
        const d = side * (r.half - 1.2 + (rng.next() - 0.5) * 0.12);
        const f = frame(s + (rng.next() - 0.5) * 0.6, d);
        addCar(f.x, laneY(r, s, d), f.z, head(f.t) + (rng.next() - 0.5) * 0.03);
        if (rng.next() < 0.3) addDecal('oil', f.x, laneY(r, s, d) + 0.004, f.z, rng.next() * 6.28, 1.0 + rng.next(), 0.7 + rng.next() * 0.6);
      }
    } else if (r.kind === 'secondary' && r.sec.curb) {
      const dens = residential(mid[0], mid[1]) ? 0.3 : r.id === 'rosemary' ? 0.28 : 0.1;
      for (let s = a + 9; s < b - 9; s += 7.2) {
        if (onBridge(s) || rng.next() > dens) continue;
        const d = side * (r.half - 1.05);
        const f = frame(s, d);
        if (inBuilding(f.x, f.z, 0.5)) continue;
        addCar(f.x, laneY(r, s, d), f.z, head(f.t) + (rng.next() - 0.5) * 0.04);
      }
    }

    if (r.sec.curb && r.kind !== 'alley') {
      // storm drain inlets at both ends of every curb run
      for (const s of [a + 2.2, b - 2.2]) { const d = side * (r.half - 0.28); const f = frame(s, d); addProp('drain', f.x, laneY(r, s, d) + 0.002, f.z, head(f.t)); }
      // gutter litter and leaf drifts, sidewalk cracks / gum / stains
      const busy = r.kind === 'hamilton' || r.id === 'rosemary';
      const leafy = !busy && (r.kind === 'campus' || residential(mid[0], mid[1]));
      for (let s = a + 1; s < b - 1; s += 1.6) {
        if (onBridge(s)) continue;
        const u = rng.next();
        if (u < (busy ? 0.12 : 0.05)) {
          const d = side * (r.half - 0.12 - rng.next() * 0.35); const f = frame(s, d);
          addProp(pickLitter(), f.x, laneY(r, s, d), f.z, rng.next() * 6.28, Math.floor(rng.next() * 8));
        }
        if (rng.next() < (leafy ? 0.34 : 0.1)) {
          const d = side * (r.half - 0.25 - rng.next() * 0.25); const f = frame(s, d);
          addDecal('leaves', f.x, laneY(r, s, d) + 0.006, f.z, head(f.t) + (rng.next() - 0.5) * 0.5, 0.6 + rng.next() * 0.5, 1.6 + rng.next() * 2.2, Math.floor(rng.next() * 4));
        }
        if (rng.next() < 0.07) {
          // sidewalk wear
          const d = side * (r.half + CURB_TOP + 0.3 + rng.next() * Math.max(0.2, r.row - r.half - CURB_TOP - 0.6)); const f = frame(s, d);
          if (onSidewalk(f.x, f.z)) {
            const kind = busy && rng.next() < 0.6 ? 'gum' : rng.next() < 0.6 ? 'crack' : 'stain';
            const sz = kind === 'gum' ? 0.8 + rng.next() * 0.8 : 0.6 + rng.next() * 0.9;
            addDecal(kind, f.x, walkY(r, s, d) + 0.005, f.z, rng.next() * 6.28, sz, sz * (0.6 + rng.next() * 0.6), Math.floor(rng.next() * 4));
          }
        }
        if (rng.next() < (busy ? 0.045 : 0.03)) {
          // puddles collect in the gutter
          const d = side * (r.half - 0.35 - rng.next() * 0.3); const f = frame(s, d);
          addDecal('puddle', f.x, laneY(r, s, d) + 0.007, f.z, head(f.t), 0.7 + rng.next() * 0.7, 1.4 + rng.next() * 2.0, Math.floor(rng.next() * 4));
        }
      }
    }
    // asphalt cracks, patches, tar snakes in the lanes
    if (side > 0) for (let s = a + 3; s < b - 3; s += 3.5) {
      if (onBridge(s)) continue;
      const u = rng.next();
      if (u > (r.kind === 'alley' ? 0.4 : 0.22)) continue;
      const d = (rng.next() * 2 - 1) * (r.half - 0.8); const f = frame(s, d);
      const kind = u < 0.06 ? 'patch' : u < 0.15 ? 'crack' : 'tar';
      const sx = kind === 'patch' ? 1.2 + rng.next() * 2.5 : 1.0 + rng.next() * 2.0, sz = kind === 'patch' ? 1.0 + rng.next() * 2.0 : 1.5 + rng.next() * 3.0;
      addDecal(kind, f.x, laneY(r, s, d) + 0.005, f.z, head(f.t) + (kind === 'tar' ? (rng.next() - 0.5) * 3 : (rng.next() - 0.5) * 0.4), sx, sz, Math.floor(rng.next() * 4));
    }
    // alleys: dumpsters on pads, trash bags, cardboard, pallets, puddles, oil
    if (r.kind === 'alley' && side > 0) {
      let k = 0;
      for (let s = 6; s < r.length - 4; s += 9 + rng.next() * 6) {
        const sd = (k++ % 2 ? 1 : -1);
        const d = sd * (r.half - 0.95); const f = frame(s, d);
        if (inBuilding(f.x, f.z, 0.1)) continue;
        const y = laneY(r, s, d);
        const face = Math.atan2(-polyAt(r, s).n[0] * sd, -polyAt(r, s).n[1] * sd);
        const u = rng.next();
        if (u < 0.55) addProp('dumpster', f.x, y, f.z, face, Math.floor(rng.next() * 3));
        else if (u < 0.75) addProp('pallet_stack', f.x, y, f.z, face + (rng.next() - 0.5) * 0.4);
        const nb = 1 + Math.floor(rng.next() * 4);
        for (let i = 0; i < nb; i++) {
          const g = frame(s + 1.4 + rng.next() * 1.6, sd * (r.half - 0.35 - rng.next() * 0.5));
          addProp(rng.next() < 0.7 ? 'trash_bag' : 'cardboard', g.x, y, g.z, rng.next() * 6.28, Math.floor(rng.next() * 3));
        }
        if (rng.next() < 0.6) { const g = frame(s + (rng.next() - 0.5) * 4, (rng.next() - 0.5) * r.half); addDecal('puddle', g.x, laneY(r, s, 0) + 0.007, g.z, rng.next() * 6.28, 1.0 + rng.next() * 1.4, 1.2 + rng.next() * 1.8, Math.floor(rng.next() * 4)); }
        if (rng.next() < 0.5) { const g = frame(s, sd * (r.half - 1.0)); addDecal('stain', g.x, y + 0.005, g.z, rng.next() * 6.28, 1.6, 1.4, 1); }
        for (let i = 0; i < 3; i++) { const g = frame(s + (rng.next() - 0.5) * 6, (rng.next() * 2 - 1) * (r.half - 0.3)); addProp(pickLitter(), g.x, laneY(r, s, 0), g.z, rng.next() * 6.28, Math.floor(rng.next() * 8)); }
      }
    }
  }
}
function pickLitter(): string { const p = rng.next(); return p < 0.22 ? 'litter_cup' : p < 0.42 ? 'litter_can' : p < 0.62 ? 'litter_paper' : p < 0.74 ? 'litter_bottle' : p < 0.88 ? 'litter_wrapper' : 'litter_flyer'; }

// stop signs at every un-signalised 3/4-way junction (all-way stop); signal cabinets at signals
for (const n of P.net.nodes) {
  if (n.arms.length < 3 || !inCore(n.x, n.z)) continue;
  for (const a of n.arms) {
    if (!a.road.sec.curb || a.road.kind === 'alley') continue;
    const nx = -a.dir[1], nz = a.dir[0];
    const x = n.x + a.dir[0] * (a.cut + 1.6) + nx * (a.half + 0.7), z = n.z + a.dir[1] * (a.cut + 1.6) + nz * (a.half + 0.7);
    const y = n.y - CROSS_SLOPE * a.half + CURB_H;
    if (inBuilding(x, z, 0.2)) continue;
    if (!n.signal) addProp('stop_sign', x, y, z, Math.atan2(a.dir[0], a.dir[1]));
  }
  if (n.signal) {
    const a = n.arms[0], nx = -a.dir[1], nz = a.dir[0];
    const x = n.x + a.dir[0] * (a.cut + 3.2) - nx * (a.half + 1.6), z = n.z + a.dir[1] * (a.cut + 3.2) - nz * (a.half + 1.6);
    if (!inBuilding(x, z, 0.4)) addProp('signal_cabinet', x, n.y - CROSS_SLOPE * a.half + CURB_H, z, Math.atan2(nx, nz));
  }
}

// Hamilton & main streets: parking / bus signs, collection mailboxes, big planters at mid-block crossings
for (const r of P.net.roads) {
  if (r.kind !== 'hamilton' && r.kind !== 'main') continue;
  for (const sp of r.spans) for (const side of [1, -1] as const) {
    const a = side > 0 ? sp.l0 : sp.r0, b = side > 0 ? sp.l1 : sp.r1;
    for (let s = a + 11; s < b - 6; s += 26 + rng.next() * 14) {
      const f = polyAt(r, s), d = side * (r.half + CURB_TOP + 0.35);
      const x = f.p[0] + f.n[0] * d, z = f.p[1] + f.n[1] * d;
      if (!inCore(x, z) || !onSidewalk(x, z)) continue;
      const u = rng.next();
      const face = Math.atan2(f.t[0], f.t[1]);
      if (u < 0.5) addProp(r.kind === 'hamilton' ? 'parking_sign' : 'speed_sign', x, walkY(r, s, d), z, face + (side > 0 ? Math.PI : 0));
      else if (u < 0.62) addProp('mailbox_blue', x, walkY(r, s, d), z, Math.atan2(-f.n[0] * side, -f.n[1] * side));
      else if (u < 0.72) addProp('utility_box', f.p[0] + f.n[0] * side * (r.row - 0.5), walkY(r, s, r.row - 0.5), f.p[1] + f.n[1] * side * (r.row - 0.5), face);
    }
  }
}
for (const m of P.midblock) {
  const r = m.road;
  for (const ds of [-4.2, 4.2]) {
    const f = polyAt(r, m.s + ds), d = m.side * (r.half + CURB_TOP + 0.9);
    const x = f.p[0] + f.n[0] * d, z = f.p[1] + f.n[1] * d;
    if (onSidewalk(x, z)) addProp('planter_big', x, walkY(r, m.s + ds, d), z, Math.atan2(f.t[0], f.t[1]), Math.floor(rng.next() * 3));
  }
}
// bus stop poles beside the shelters
for (const sh of props['shelter'] ?? []) addProp('bus_sign', sh[0] + Math.cos(sh[3]) * 2.6, sh[1], sh[2] - Math.sin(sh[3]) * 2.6, sh[3]);
// litter around bins and benches
for (const [x, y, z] of [...cans, ...benches]) {
  const n = Math.floor(rng.next() * 3);
  for (let i = 0; i < n; i++) {
    const a = rng.next() * 6.28, d = 0.45 + rng.next() * 1.1, px = x + Math.cos(a) * d, pz = z + Math.sin(a) * d;
    if (!inBuilding(px, pz, 0.1)) addProp(pickLitter(), px, surf(px, pz), pz, rng.next() * 6.28, Math.floor(rng.next() * 8));
  }
}

// ------------------------------------------------------------------ 3) utility poles and wires (residential + side streets)
for (const r of P.net.roads) {
  if (r.kind !== 'secondary') continue;
  let prev = -1, prevS = -1e9;
  const side = 1;
  for (const sp of r.spans) {
    const a = sp.l0, b = sp.l1;
    for (let s = a + 18; s < b - 3; s += 34) {
      const f = polyAt(r, s), d = side * (r.half + CURB_TOP + 0.4);
      const x = f.p[0] + f.n[0] * d, z = f.p[1] + f.n[1] * d;
      if (!inCore(x, z) || inBuilding(x, z, 0.3)) { prev = -1; continue; }
      const y = walkY(r, s, d);
      poles.push([r3(x), r3(y), r3(z), r3(Math.atan2(-f.n[1], f.n[0]))]);
      const i = poles.length - 1;
      if (prev >= 0 && s - prevS < 75) wires.push([prev, i]);
      prev = i; prevS = s;
    }
  }
}

// ------------------------------------------------------------------ 4) buildings: café seating, planters, A-frames, houses, campus
const FOOD = new Set(['cafe', 'takeout', 'tacos', 'pizza', 'deli', 'bakery', 'bar', 'brewpub', 'diner', 'breakfast']);
const SHOP = new Set(['clothing', 'retail', 'gallery', 'salon', 'florist', 'optics', 'bookstore', 'records', 'hardware', 'tattoo']);
let cafes = 0;
for (const b of BLD) {
  const [fx, fz] = toWorld(b, b.w / 2, -0.2);
  if (!inCore(fx, fz)) continue;
  const o: [number, number] = [-b.s * 1 * 0 + toWorld(b, 0, -1)[0] - toWorld(b, 0, 0)[0], toWorld(b, 0, -1)[1] - toWorld(b, 0, 0)[1]]; // outward unit
  const faceOut = Math.atan2(o[0], o[1]);
  const at = (lx: number, lz: number) => toWorld(b, lx, lz);
  if (b.biz && (FOOD.has(b.biz) || SHOP.has(b.biz))) {
    // café seating: bistro table (#27) + two bentwood chairs (#69) per group, on the sidewalk in front
    if (FOOD.has(b.biz)) {
      let groups = 0;
      for (let lx = 1.4; lx < b.w - 1.3 && groups < 3; lx += 2.5) {
        if (Math.abs(lx - b.w / 2) < 1.5) continue;
        const [x, z] = at(lx, -1.25);
        const [x1, z1] = at(lx - 0.62, -1.25), [x2, z2] = at(lx + 0.62, -1.25);
        if (!onSidewalk(x, z) || !onSidewalk(x1, z1) || !onSidewalk(x2, z2) || !onSidewalk(...at(lx, -2.2))) continue;
        furniture.push([27, r3(x), r3(surf(x, z)), r3(z), r3(faceOut)]);
        furniture.push([69, r3(x1), r3(surf(x1, z1)), r3(z1), r3(faceOut - Math.PI / 2 + (rng.next() - 0.5) * 0.3)]);
        furniture.push([69, r3(x2), r3(surf(x2, z2)), r3(z2), r3(faceOut + Math.PI / 2 + (rng.next() - 0.5) * 0.3)]);
        groups++;
      }
      if (groups) cafes++;
    }
    // planters flanking the door, an A-frame sandwich board
    if (rng.next() < 0.55) for (const dx of [-1.25, 1.25]) {
      const [x, z] = at(b.w / 2 + dx, -0.4);
      if (onSidewalk(x, z)) addProp('planter', x, surf(x, z), z, faceOut, Math.floor(rng.next() * 4));
    }
    if (rng.next() < 0.45) {
      const [x, z] = at(b.w / 2 + 1.9, -1.9);
      if (onSidewalk(x, z)) addProp('aframe', x, surf(x, z), z, faceOut + (rng.next() - 0.5) * 0.5, Math.floor(rng.next() * 4));
    }
    continue;
  }
  if (b.typ === 'house') {
    // walk out from the front door to the street
    let curb: [number, number] | null = null;
    for (let k = 1.5; k < 26; k += 0.5) {
      const [x, z] = at(b.w / 2, -k);
      const h = q(x, z);
      if (h && h.zone !== 'verge') { curb = at(b.w / 2, -(k - 0.7)); break; }
      if (inBuilding(x, z, 0)) break;
    }
    if (curb) {
      const [cx, cz] = toLocal(b, curb[0], curb[1]);
      const [mx, mz] = at(cx + 1.6, cz);
      if (free(mx, mz, 0.3)) addProp('mailbox_post', mx, surf(mx, mz), mz, faceOut, Math.floor(rng.next() * 4));
      if (rng.next() < 0.35) {
        // trash day: roll carts at the curb
        for (const [dx, m] of [[2.6, 'rollcart_trash'], [3.4, 'rollcart_recycle']] as const) {
          const [x, z] = at(cx + dx, cz + 0.1);
          if (free(x, z, 0.3)) addProp(m, x, surf(x, z), z, faceOut + (rng.next() - 0.5) * 0.3);
        }
      }
      // car in the driveway beside the house
      if (rng.next() < 0.55) {
        const lx = b.w + 1.7, lz = -2.6;
        const pts = [at(lx, lz), at(lx, lz - 2.3), at(lx, lz + 2.3), at(lx - 0.95, lz), at(lx + 0.95, lz)];
        if (pts.every(([x, z]) => free(x, z, 0.3))) {
          const [x, z] = pts[0];
          addCar(x, surf(x, z), z, faceOut + (rng.next() < 0.5 ? Math.PI : 0));
          addDecal('oil', x, surf(x, z) + 0.01, z, faceOut, 1.2, 1.6, 2);
        }
      }
    }
    // foundation shrubs along the front
    for (let lx = 0.7; lx < b.w - 0.6; lx += 1.05 + rng.next() * 0.4) {
      if (Math.abs(lx - b.w / 2) < 1.2) continue;
      const [x, z] = at(lx, -0.75 - rng.next() * 0.2);
      if (!free(x, z, 0.05)) continue;
      addProp('shrub', x, surf(x, z), z, rng.next() * 6.28, Math.floor(rng.next() * 6));
    }
    if (rng.next() < 0.6) { const [x, z] = at(b.w / 2, -0.9); if (free(x, z, 0)) addDecal('mulch', x, surf(x, z) + 0.01, z, faceOut, b.w * 0.9, 1.6, 0); }
    continue;
  }
  if (['historic_academic', 'modern_academic', 'library', 'residence_historic', 'residence_highrise', 'office_lab', 'hospital', 'inn'].includes(b.typ)) {
    // boxwood hedge along the front, bike racks with bikes near the entrance
    for (let lx = 1.0; lx < b.w - 1.0; lx += 0.85) {
      if (Math.abs(lx - b.w / 2) < 2.4) continue;
      const [x, z] = at(lx, -0.85);
      if (free(x, z, 0.05)) addProp('hedge', x, surf(x, z), z, faceOut, Math.floor(rng.next() * 3));
    }
    const [rx, rz] = at(b.w / 2 + 4.2, -3.0);
    if (rng.next() < 0.7 && (free(rx, rz, 0.4) || onSidewalk(rx, rz))) {
      addProp('bikerack', rx, surf(rx, rz), rz, faceOut + Math.PI / 2);
      for (let i = 0; i < 1 + Math.floor(rng.next() * 3); i++) {
        const [x, z] = at(b.w / 2 + 4.2 + (i % 2 ? 0.22 : -0.22), -3.0 + (i - 1) * 0.42);
        addProp('bicycle', x, surf(x, z), z, faceOut, Math.floor(rng.next() * 6));
      }
    }
    for (const dx of [-3.2, 3.2]) { const [x, z] = at(b.w / 2 + dx, -2.2); if (rng.next() < 0.5 && free(x, z, 0.3)) addProp('trash', x, surf(x, z), z, 0); }
  }
}

// ------------------------------------------------------------------ 5) trees: leaf litter, mulch rings, fallen-leaf piles
const TREES: Record<string, number[][]> = JSON.parse(fs.readFileSync('godot/data/trees.json', 'utf8'));
for (const [species, list] of Object.entries(TREES)) {
  const pine = species === 'loblolly';
  for (const [x, y, z, , sxz] of list) {
    if (!inCore(x, z)) continue;
    const canopy = (pine ? 3.0 : 5.5) * sxz;
    const h = q(x, z);
    const pit = h && h.zone === 'sidewalk';
    if (!pit && !inPark(x, z) && rng.next() < 0.45 && !pine) addDecal('mulch', x, surf(x, z) + 0.012, z, rng.next() * 6.28, 2.2 + rng.next(), 2.2 + rng.next(), 1);
    const n = pine ? 1 : 2 + Math.floor(rng.next() * 3);
    for (let i = 0; i < n; i++) {
      const a = rng.next() * 6.28, d = rng.next() * canopy, px = x + Math.cos(a) * d, pz = z + Math.sin(a) * d;
      if (inBuilding(px, pz, 0.1)) continue;
      const sz = 1.6 + rng.next() * 2.4;
      addDecal(pine ? 'needles' : 'leaves', px, surf(px, pz) + 0.008, pz, rng.next() * 6.28, sz, sz * (0.7 + rng.next() * 0.5), Math.floor(rng.next() * 4));
    }
    if (!pine && !pit && rng.next() < 0.05) { const a = rng.next() * 6.28, px = x + Math.cos(a) * 2.5, pz = z + Math.sin(a) * 2.5; if (free(px, pz, 0.3)) addProp('leaf_pile', px, surf(px, pz), pz, rng.next() * 6.28, Math.floor(rng.next() * 3)); }
  }
}

// ------------------------------------------------------------------ 6) parks & lawns: shrub clusters, ferns, picnic tables, dirt
{
  const pk = parks(), NX = (CORE.x1 - CORE.x0) / PARK_CELL;
  for (let k = 0; k < pk.comp.length; k++) {
    if (!pk.comp[k]) continue;
    const i = k % NX, j = (k / NX) | 0;
    const edge = !pk.comp[k - 1] || !pk.comp[k + 1] || !pk.comp[k - NX] || !pk.comp[k + NX];
    const x = CORE.x0 + (i + rng.next()) * PARK_CELL, z = CORE.z0 + (j + rng.next()) * PARK_CELL;
    if (pathDist(x, z) < 0.8) { if (rng.next() < 0.05) addDecal('puddle', x, T.height(x, z) + 0.01, z, rng.next() * 6.28, 0.9 + rng.next(), 1.2 + rng.next() * 1.5, 2); continue; }
    const y = T.height(x, z);
    if (edge && rng.next() < 0.45) addProp('shrub_wild', x, y, z, rng.next() * 6.28, Math.floor(rng.next() * 4));
    else if (rng.next() < 0.16) addProp('fern', x, y, z, rng.next() * 6.28, Math.floor(rng.next() * 4));
    else if (rng.next() < 0.06) addProp('rock', x, y - 0.05, z, rng.next() * 6.28, Math.floor(rng.next() * 4));
  }
  // picnic tables beside some trail benches
  for (const [x, , z, rot] of benches) if (inPark(x, z) && rng.next() < 0.18) {
    const px = x + Math.cos(rot) * 3.2, pz = z - Math.sin(rot) * 3.2;
    if (pathDist(px, pz) > 1.2 && free(px, pz, 1)) addProp('picnic_table', px, T.height(px, pz), pz, rot + 0.3);
  }
}
// open lawns (not parks, not paved): shrub clumps, worn dirt patches, the odd weed tuft
for (let x = CORE.x0 + 4; x < CORE.x1 - 4; x += 9) for (let z = CORE.z0 + 4; z < CORE.z1 - 4; z += 9) {
  const px = x + (rng.next() - 0.5) * 8, pz = z + (rng.next() - 0.5) * 8;
  if (inPark(px, pz) || !canPlant(px, pz, 1.0)) continue;
  const u = rng.next();
  const y = T.height(px, pz);
  if (u < 0.05) addProp('shrub', px, y, pz, rng.next() * 6.28, Math.floor(rng.next() * 6));
  else if (u < 0.1) addDecal('dirt', px, y + 0.01, pz, rng.next() * 6.28, 2 + rng.next() * 3, 1.5 + rng.next() * 2.5, Math.floor(rng.next() * 4));
  else if (u < 0.16) addProp('weeds', px, y, pz, rng.next() * 6.28, Math.floor(rng.next() * 4));
}

// a couple of street works zones with cones and barricades on Rosemary St
for (const [rid, s0] of [['rosemary', 210], ['columbia_s', 160], ['pell', 330]] as const) {
  const r = P.net.roads.find((k) => k.id === rid)!;
  const d0 = -(r.half - 1.4);
  for (let s = s0; s < s0 + 12; s += 2) { const f = polyAt(r, s); addProp('cone', f.p[0] + f.n[0] * (d0 + 1.2), laneY(r, s, d0), f.p[1] + f.n[1] * (d0 + 1.2), 0); }
  const f = polyAt(r, s0 + 6);
  addDecal('patch', f.p[0] + f.n[0] * d0, laneY(r, s0 + 6, d0) + 0.006, f.p[1] + f.n[1] * d0, Math.atan2(f.t[0], f.t[1]), 2.0, 7.0, 3);
  addProp('barricade', f.p[0] + f.n[0] * d0, laneY(r, s0, d0), f.p[1] + f.n[1] * d0, Math.atan2(f.n[0], f.n[1]));
}

const out = { props, lamps, furniture, poles, wires, decals };
fs.writeFileSync('godot/data/props.json', JSON.stringify(out));
const count = (o: Record<string, unknown[]>) => Object.fromEntries(Object.entries(o).map(([k, v]) => [k, v.length]));
console.log('props', count(props));
console.log('decals', count(decals));
console.log(`lamps ${lamps.length}, café pieces ${furniture.length} (${cafes} cafés), poles ${poles.length}, wires ${wires.length}`);
console.log(`dropped inside footprints: ${dropped}`);
console.log(`props.json ${(fs.statSync('godot/data/props.json').size / 1e6).toFixed(2)} MB`);
void CAR_KINDS;
