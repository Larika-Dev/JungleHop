// Old-growth forest parks (land use between buildings). Green space that is at least 10 m from any
// building, off roads/sidewalks, and outside the protected open spaces that make the town recognizable
// (North & Founders' quads, the Quarry plaza, the stadium) becomes forest park: an old-growth canopy of
// willow & white oaks, maples and loblolly pines over dogwood/holly understory and leaf litter, threaded
// with routed paths (gravel trunk trails with timber edging, narrow dirt side paths) joining the
// surrounding sidewalks, with campus lanterns, benches, trash cans and fallen logs along the way.
// Everything is deterministic (seed 1795) and computed once over the dense core on a 4 m grid.
import { CORE } from '../core/tiles';
import { Rng, hash01 } from '../core/rng';
import { Terrain } from '../terrain/terrain';
import { districtAt } from '../world/layout';
import { inPad } from '../world/sites';
import { canPlant } from './placement';

export const PARK_CELL = 4;
const NX = (CORE.x1 - CORE.x0) / PARK_CELL, NZ = (CORE.z1 - CORE.z0) / PARK_CELL;
const PROTECTED = new Set(['hamilton_strip', 'rosemary_row', 'summit', 'north_quad', 'founders_quad', 'quarry']);
const BUILDING_CLEAR = 10; // m of lawn/yard kept around every building
const MIN_CELLS = 100;     // 1,600 m²: smaller green slivers stay lawn

export interface ParkPath { pts: [number, number][]; w: number; kind: 'gravel' | 'dirt' }
export interface ParkData {
  /** component id per cell (0 = not park) */
  comp: Int32Array;
  paths: ParkPath[];
  /** spatial hash of path segments (8 m cells) for distance queries */
  segHash: Map<number, [number, number, number, number, number][]>;
  area: number;
}

const idx = (i: number, j: number) => j * NX + i;
const cx = (i: number) => CORE.x0 + (i + 0.5) * PARK_CELL, cz = (j: number) => CORE.z0 + (j + 0.5) * PARK_CELL;
const SK = (x: number, z: number) => Math.floor(x / 8) * 100003 + Math.floor(z / 8);

let data: ParkData | null = null;
export function parks(): ParkData {
  if (data) return data;
  const T = Terrain.get();
  // 1) classify cells
  const raw = new Uint8Array(NX * NZ);
  const paved = new Uint8Array(NX * NZ);
  for (let j = 0; j < NZ; j++) for (let i = 0; i < NX; i++) {
    const x = cx(i), z = cz(j);
    const hit = T.net.query(x, z);
    if (hit && hit.zone !== 'verge') { paved[idx(i, j)] = 1; continue; }
    const d = districtAt(x, z);
    if (d && PROTECTED.has(d.id)) continue;
    if (!canPlant(x, z, 0)) continue;
    if (inPad(x, z, BUILDING_CLEAR)) continue;
    raw[idx(i, j)] = 1;
  }
  // 2) open by one cell (erode then dilate) to drop ragged fringes, then label components
  const er = new Uint8Array(NX * NZ);
  for (let j = 1; j < NZ - 1; j++) for (let i = 1; i < NX - 1; i++) {
    const k = idx(i, j);
    er[k] = raw[k] && raw[k - 1] && raw[k + 1] && raw[k - NX] && raw[k + NX] ? 1 : 0;
  }
  const op = new Uint8Array(NX * NZ);
  for (let j = 1; j < NZ - 1; j++) for (let i = 1; i < NX - 1; i++) {
    const k = idx(i, j);
    op[k] = raw[k] && (er[k] || er[k - 1] || er[k + 1] || er[k - NX] || er[k + NX]) ? 1 : 0;
  }
  const comp = new Int32Array(NX * NZ);
  const comps: number[][] = [];
  for (let k0 = 0; k0 < op.length; k0++) {
    if (!op[k0] || comp[k0]) continue;
    const id = comps.length + 1, cells: number[] = [k0];
    comp[k0] = id;
    for (let q = 0; q < cells.length; q++) {
      const k = cells[q], i = k % NX, j = (k / NX) | 0;
      for (const [di, dj] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
        const ii = i + di, jj = j + dj;
        if (ii < 0 || jj < 0 || ii >= NX || jj >= NZ) continue;
        const kk = idx(ii, jj);
        if (op[kk] && !comp[kk]) { comp[kk] = id; cells.push(kk); }
      }
    }
    comps.push(cells);
  }
  // drop small patches
  let area = 0;
  comps.forEach((cells, n) => {
    if (cells.length < MIN_CELLS) for (const k of cells) comp[k] = 0;
    else area += cells.length * PARK_CELL * PARK_CELL;
    void n;
  });
  // 3) paths per park
  const paths: ParkPath[] = [];
  const used = new Uint8Array(NX * NZ);
  comps.forEach((cells, n) => {
    if (cells.length < MIN_CELLS) return;
    routeParkPaths(n + 1, cells, comp, paved, used, paths);
  });
  const segHash = new Map<number, [number, number, number, number, number][]>();
  for (const p of paths) for (let s = 0; s < p.pts.length - 1; s++) {
    const [ax, az] = p.pts[s], [bx, bz] = p.pts[s + 1];
    const seg: [number, number, number, number, number] = [ax, az, bx, bz, p.w];
    const x0 = Math.min(ax, bx) - 8, x1 = Math.max(ax, bx) + 8, z0 = Math.min(az, bz) - 8, z1 = Math.max(az, bz) + 8;
    for (let x = x0; x <= x1 + 8; x += 8) for (let z = z0; z <= z1 + 8; z += 8) {
      const k = SK(x, z); let a = segHash.get(k); if (!a) segHash.set(k, (a = [])); if (!a.includes(seg)) a.push(seg);
    }
  }
  data = { comp, paths, segHash, area };
  return data;
}

/** Is this point inside an old-growth forest park? */
export function inPark(x: number, z: number): boolean {
  if (x < CORE.x0 || x >= CORE.x1 || z < CORE.z0 || z >= CORE.z1) return false;
  const i = Math.floor((x - CORE.x0) / PARK_CELL), j = Math.floor((z - CORE.z0) / PARK_CELL);
  return parks().comp[idx(i, j)] > 0;
}
/** Distance to the nearest park path edge (negative = on the path) and that path's width; Infinity if none near. */
export function pathDist(x: number, z: number): number {
  const a = parks().segHash.get(SK(x, z));
  if (!a) return Infinity;
  let best = Infinity;
  for (const [ax, az, bx, bz, w] of a) {
    const dx = bx - ax, dz = bz - az, L2 = dx * dx + dz * dz || 1e-9;
    const t = Math.max(0, Math.min(1, ((x - ax) * dx + (z - az) * dz) / L2));
    const d = Math.hypot(x - ax - dx * t, z - az - dz * t) - w / 2;
    if (d < best) best = d;
  }
  return best;
}

// ------------------------------------------------------------------------------------------ path routing
function routeParkPaths(id: number, cells: number[], comp: Int32Array, paved: Uint8Array, used: Uint8Array, out: ParkPath[]) {
  void 0;
  const rng = new Rng(`park:${id}:${cells[0]}`);
  // distance (in cells) from the park edge: paths keep away from backyards and building lawns
  const edge = new Map<number, number>();
  const q: number[] = [];
  for (const k of cells) {
    const i = k % NX, j = (k / NX) | 0;
    let border = false;
    for (const [di, dj] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) { const kk = idx(i + di, j + dj); if (comp[kk] !== id) border = true; }
    if (border) { edge.set(k, 0); q.push(k); }
  }
  for (let h = 0; h < q.length; h++) {
    const k = q[h], d = edge.get(k)!, i = k % NX, j = (k / NX) | 0;
    for (const [di, dj] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
      const kk = idx(i + di, j + dj);
      if (comp[kk] === id && !edge.has(kk)) { edge.set(kk, d + 1); q.push(kk); }
    }
  }
  // entrances: park edge cells touching pavement within 2 cells, spaced ≥ 70 m apart
  const cand: number[] = [];
  for (const [k, d] of edge) {
    if (d !== 0) continue;
    const i = k % NX, j = (k / NX) | 0;
    let touch = false;
    for (let dj = -2; dj <= 2 && !touch; dj++) for (let di = -2; di <= 2; di++) { const ii = i + di, jj = j + dj; if (ii >= 0 && jj >= 0 && ii < NX && jj < NZ && paved[idx(ii, jj)]) { touch = true; break; } }
    if (touch) cand.push(k);
  }
  cand.sort((a, b) => hash01(a, id, 3) - hash01(b, id, 3));
  const entries: number[] = [];
  const maxE = Math.min(10, Math.max(2, Math.round(cells.length / 450)));
  for (const k of cand) {
    if (entries.length >= maxE) break;
    if (entries.every((e) => Math.hypot(cx(e % NX) - cx(k % NX), cz((e / NX) | 0) - cz((k / NX) | 0)) > 70)) entries.push(k);
  }
  if (entries.length < 2) {
    // an interior woodland with no street frontage: a loop between its two most distant deep cells
    const deep = cells.filter((k) => (edge.get(k) ?? 0) >= 2);
    if (deep.length < 20) return;
    const a = deep[0];
    let b = a, bd = 0;
    for (const k of deep) { const d = Math.hypot(cx(k % NX) - cx(a % NX), cz((k / NX) | 0) - cz((a / NX) | 0)); if (d > bd) { bd = d; b = k; } }
    entries.length = 0; entries.push(a, b);
  }
  // minimum spanning tree over the entrances, plus a loop edge for larger parks
  const inTree = [0], edges: [number, number][] = [];
  while (inTree.length < entries.length) {
    let best: [number, number, number] | null = null;
    for (const a of inTree) for (let b = 0; b < entries.length; b++) {
      if (inTree.includes(b)) continue;
      const d = Math.hypot(cx(entries[a] % NX) - cx(entries[b] % NX), cz((entries[a] / NX) | 0) - cz((entries[b] / NX) | 0));
      if (!best || d < best[2]) best = [a, b, d];
    }
    edges.push([best![0], best![1]]); inTree.push(best![1]);
  }
  if (entries.length >= 4) edges.push([edges[edges.length - 1][1], 0]);
  edges.forEach(([a, b], n) => {
    const route = astar(entries[a], entries[b], id, comp, edge, used, rng);
    if (!route || route.length < 4) return;
    for (const k of route) used[k] = 1;
    let pts: [number, number][] = route.map((k) => [cx(k % NX) + (hash01(k, 1, id) - 0.5) * 1.6, cz((k / NX) | 0) + (hash01(k, 2, id) - 0.5) * 1.6]);
    // run each end out to the nearest pavement so trails meet the sidewalk
    const reach = (k: number): [number, number] | null => {
      const i = k % NX, j = (k / NX) | 0;
      let best: [number, number] | null = null, bd = Infinity;
      for (let dj = -3; dj <= 3; dj++) for (let di = -3; di <= 3; di++) {
        const ii = i + di, jj = j + dj;
        if (ii < 0 || jj < 0 || ii >= NX || jj >= NZ || !paved[idx(ii, jj)]) continue;
        const d = di * di + dj * dj; if (d < bd) { bd = d; best = [cx(ii), cz(jj)]; }
      }
      return best;
    };
    const ra = reach(route[0]), rb = reach(route[route.length - 1]);
    if (ra) pts.unshift(ra);
    if (rb) pts.push(rb);
    pts = pts.filter((_, i) => i % 2 === 0 || i === pts.length - 1);
    for (let it = 0; it < 3; it++) pts = chaikin(pts);
    const len = pts.reduce((s, p, i) => (i ? s + Math.hypot(p[0] - pts[i - 1][0], p[1] - pts[i - 1][1]) : 0), 0);
    const trunk = n === 0 || len > 160;
    out.push({ pts, w: trunk ? 2.4 : 1.4, kind: trunk ? 'gravel' : 'dirt' });
  });
}

function astar(s: number, t: number, id: number, comp: Int32Array, edge: Map<number, number>, used: Uint8Array, rng: Rng): number[] | null {
  void rng;
  const tx = t % NX, tz = (t / NX) | 0;
  const g = new Map<number, number>([[s, 0]]), from = new Map<number, number>();
  const open: [number, number][] = [[s, 0]];
  const H = (k: number) => Math.hypot((k % NX) - tx, ((k / NX) | 0) - tz) * 0.8;
  let guard = 0;
  while (open.length && guard++ < 60000) {
    // binary-heap-free: pop the min (parks are small enough)
    let bi = 0; for (let i = 1; i < open.length; i++) if (open[i][1] < open[bi][1]) bi = i;
    const [k] = open[bi]; open[bi] = open[open.length - 1]; open.pop();
    if (k === t) { const path = [k]; let c = k; while (from.has(c)) { c = from.get(c)!; path.push(c); } return path.reverse(); }
    const i = k % NX, j = (k / NX) | 0, gk = g.get(k)!;
    for (const [di, dj] of [[1, 0], [-1, 0], [0, 1], [0, -1], [1, 1], [1, -1], [-1, 1], [-1, -1]]) {
      const ii = i + di, jj = j + dj;
      if (ii < 0 || jj < 0 || ii >= NX || jj >= NZ) continue;
      const kk = idx(ii, jj);
      if (comp[kk] !== id) continue;
      const ed = edge.get(kk) ?? 0;
      // meander: low-frequency noise field + keep off the park edge; reuse existing trails
      const noise = hash01(Math.floor(ii / 6), Math.floor(jj / 6), id) * 0.9 + hash01(ii, jj, id + 7) * 0.25;
      const cost = Math.hypot(di, dj) * (1 + noise + (ed < 2 && kk !== t ? 1.6 : 0)) * (used[kk] ? 0.45 : 1);
      const ng = gk + cost;
      if (ng < (g.get(kk) ?? Infinity)) { g.set(kk, ng); from.set(kk, k); open.push([kk, ng + H(kk)]); }
    }
  }
  return null;
}

function chaikin(p: [number, number][]): [number, number][] {
  if (p.length < 3) return p;
  const o: [number, number][] = [p[0]];
  for (let i = 0; i < p.length - 1; i++) {
    const [ax, az] = p[i], [bx, bz] = p[i + 1];
    o.push([ax * 0.75 + bx * 0.25, az * 0.75 + bz * 0.25], [ax * 0.25 + bx * 0.75, az * 0.25 + bz * 0.75]);
  }
  o.push(p[p.length - 1]);
  return o;
}
