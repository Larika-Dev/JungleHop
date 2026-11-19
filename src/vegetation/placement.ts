// Deterministic vegetation placement per tile (CLAUDE.md §12): district densities, street trees in the
// Hamilton/main-street tree pits, giant willow oaks on the quads, loblolly forest around the stadium bowl,
// Toadstool Hill, Battle Ravine and the outer ring, ginkgo accents. Avoids pavement, buildings, rails.
import { hash01, Rng } from '../core/rng';
import { tileBounds, type TileId } from '../core/tiles';
import { Terrain } from '../terrain/terrain';
import { stadiumDist } from '../terrain/heightfield';
import { roadPlan } from '../roads/build';
import { districtAt, QUARRY_PLAZA, STADIUM } from '../world/layout';
import { inPad } from '../world/sites';
import type { Species, TreeInst } from './trees';
import { inPark, pathDist } from './parks';

const GINKGOS: [number, number][] = [[238, 205], [130, 345], [250, 590]];

export function canPlant(x: number, z: number, clear = 1.5): boolean {
  const T = Terrain.get();
  const hit = T.net.query(x, z);
  if (hit && (hit.zone !== 'verge' || hit.blend > 0.6)) return false;
  if (inPad(x, z, clear)) return false;
  if (stadiumDist(x, z) < STADIUM.rim + 8) return false;
  const P = QUARRY_PLAZA;
  if (x > P.x0 - 8 && x < P.x1 + 8 && z > P.z0 - 8 && z < P.z1 + 8) return false;
  if (x < -560 && x > -900 && Math.abs(T.rail.project(x, z).d) < 9) return false;
  return true;
}

function pickSpecies(x: number, z: number, r: Rng): Species | null {
  const d = districtAt(x, z);
  const id = d?.id;
  const p = r.next();
  const sd = stadiumDist(x, z);
  if (sd > STADIUM.rim + 6 && sd < STADIUM.rim + 70) return p < 0.24 ? 'loblolly' : p < 0.27 ? 'holly' : null;
  switch (id) {
    case 'north_quad': return p < 0.04 ? 'willow_oak' : p < 0.045 ? 'dogwood' : null;
    case 'founders_quad': return p < 0.032 ? 'willow_oak' : p < 0.038 ? 'magnolia' : p < 0.042 ? 'dogwood' : null;
    case 'campus_generic': case 'quarry': return p < 0.018 ? 'willow_oak' : p < 0.03 ? 'dogwood' : p < 0.036 ? 'magnolia' : null;
    case 'carillon_south': return p < 0.015 ? 'willow_oak' : p < 0.03 ? 'loblolly' : null;
    case 'residential_north': case 'cameron_heights': return p < 0.02 ? 'white_oak' : p < 0.035 ? 'red_maple' : p < 0.05 ? 'dogwood' : p < 0.055 ? 'magnolia' : p < 0.06 ? 'willow_oak' : null;
    case 'toadstool': return p < 0.22 ? 'loblolly' : p < 0.33 ? 'holly' : p < 0.36 ? 'dogwood' : null;
    case 'battle_ravine': return p < 0.17 ? 'loblolly' : p < 0.22 ? 'white_oak' : p < 0.29 ? 'holly' : p < 0.33 ? 'dogwood' : null;
    case 'carrburg': return p < 0.015 ? 'white_oak' : p < 0.025 ? 'loblolly' : null;
    case 'medical': return p < 0.01 ? 'red_maple' : null;
    case 'hamilton_strip': case 'rosemary_row': case 'summit': return null;
    default: return p < 0.16 ? 'loblolly' : p < 0.19 ? 'white_oak' : p < 0.21 ? 'holly' : null; // outer ring forest
  }
}

const cache = new Map<string, TreeInst[]>();
export function treesForTile(t: TileId): TreeInst[] {
  const key = `${t.col}_${t.row}`;
  const c = cache.get(key);
  if (c) return c;
  const T = Terrain.get();
  const b = tileBounds(t);
  const out: TreeInst[] = [];
  const r = new Rng(`trees:${key}`);
  const cell = 6;
  for (let x = b.x0; x < b.x1; x += cell) for (let z = b.z0; z < b.z1; z += cell) {
    if (inPark(x + 3, z + 3)) { r.next(); r.next(); r.next(); continue; } // forest parks are planted below
    const sp = pickSpecies(x + 3, z + 3, r);
    const jx = x + r.next() * cell, jz = z + r.next() * cell;
    if (!sp) continue;
    if (inPark(jx, jz) || pathDist(jx, jz) < 1.2) continue; // jittered into a forest park: planted there instead
    const clearance = sp === 'willow_oak' ? 6 : sp === 'loblolly' ? 2.5 : 2;
    if (!canPlant(jx, jz, clearance)) continue;
    out.push({ sp, x: jx, y: T.height(jx, jz) - 0.05, z: jz, rot: r.next() * Math.PI * 2, scale: 0.85 + r.next() * 0.3 });
  }
  forestTrees(t, out);
  // street trees in grated pits (red/sugar maple, white oak)
  for (const p of roadPlan().treePits) {
    if (p.x < b.x0 || p.x >= b.x1 || p.z < b.z0 || p.z >= b.z1) continue;
    const h = hash01(Math.round(p.x), Math.round(p.z), 11);
    out.push({ sp: h < 0.4 ? 'red_maple' : h < 0.75 ? 'sugar_maple' : 'white_oak', x: p.x, y: p.y - 0.02, z: p.z, rot: h * 6.28, scale: 0.9 + h * 0.2 });
  }
  for (const [gx, gz] of GINKGOS) if (gx >= b.x0 && gx < b.x1 && gz >= b.z0 && gz < b.z1) out.push({ sp: 'ginkgo', x: gx, y: T.height(gx, gz), z: gz, rot: 0, scale: 1 });
  cache.set(key, out);
  return out;
}

// ------------------------------------------------------------------------------------------ old-growth parks
/** Canopy species for a forest park: pine-heavy on the ravine, stadium bowl and Toadstool Hill. */
function canopySpecies(x: number, z: number, p: number): Species | null {
  const id = districtAt(x, z)?.id;
  const sd = stadiumDist(x, z);
  const piney = id === 'toadstool' || id === 'battle_ravine' || (sd > STADIUM.rim && sd < STADIUM.rim + 90);
  if (piney) return p < 0.42 ? 'loblolly' : p < 0.66 ? 'white_oak' : p < 0.78 ? 'willow_oak' : p < 0.9 ? 'red_maple' : p < 0.95 ? 'sugar_maple' : null;
  return p < 0.26 ? 'white_oak' : p < 0.48 ? 'willow_oak' : p < 0.62 ? 'loblolly' : p < 0.74 ? 'red_maple' : p < 0.86 ? 'sugar_maple' : p < 0.9 ? 'magnolia' : null;
}
/** Old-growth stand: canopy on a jittered 8 m grid (larger, older trees), dogwood/holly understory on 4.5 m. */
function forestTrees(t: TileId, out: TreeInst[]) {
  const T = Terrain.get();
  const b = tileBounds(t);
  const r = new Rng(`forest:${t.col}_${t.row}`);
  for (let x = b.x0; x < b.x1; x += 8) for (let z = b.z0; z < b.z1; z += 8) {
    const jx = x + 1 + r.next() * 6, jz = z + 1 + r.next() * 6, p = r.next(), rot = r.next() * Math.PI * 2, sc = r.next();
    if (!inPark(jx, jz)) continue;
    const sp = canopySpecies(jx, jz, p);
    if (!sp || pathDist(jx, jz) < 1.6 || !canPlant(jx, jz, sp === 'willow_oak' ? 4 : 2.5)) continue;
    // old growth: big trees, wide spread of ages
    const scale = sp === 'willow_oak' ? 0.95 + sc * 0.3 : 1.0 + sc * 0.4;
    out.push({ sp, x: jx, y: T.height(jx, jz) - 0.08, z: jz, rot, scale });
  }
  for (let x = b.x0; x < b.x1; x += 4.5) for (let z = b.z0; z < b.z1; z += 4.5) {
    const jx = x + r.next() * 4.5, jz = z + r.next() * 4.5, p = r.next(), rot = r.next() * Math.PI * 2, sc = r.next();
    if (p > 0.3 || !inPark(jx, jz) || pathDist(jx, jz) < 0.9 || !canPlant(jx, jz, 1.5)) continue;
    out.push({ sp: p < 0.17 ? 'dogwood' : 'holly', x: jx, y: T.height(jx, jz) - 0.04, z: jz, rot, scale: 0.75 + sc * 0.5 });
  }
}
