// Forest-park trails as geometry (tile plug-in): gravel trunk trails with 10 × 10 cm timber edging and
// narrow dirt side paths, draped on the terrain at 1 m steps. Trees, lanterns, benches and logs come
// from the vegetation & furniture placement (parks.ts drives both).
import { registerTileBuilder } from '../world/tileRegistry';
import { tileBounds } from '../core/tiles';
import { Terrain } from '../terrain/terrain';
import type { GeoBuilder } from '../core/geo';
import { parks, type ParkPath } from './parks';

const EDGE_W = 0.1, EDGE_H = 0.1, LIFT = 0.035;

function drape(p: ParkPath): { x: number; z: number; nx: number; nz: number }[] {
  const out: { x: number; z: number; nx: number; nz: number }[] = [];
  for (let i = 0; i < p.pts.length - 1; i++) {
    const [ax, az] = p.pts[i], [bx, bz] = p.pts[i + 1];
    const L = Math.hypot(bx - ax, bz - az);
    if (L < 1e-6) continue;
    const n = Math.max(1, Math.ceil(L));
    const tx = (bx - ax) / L, tz = (bz - az) / L;
    for (let k = 0; k < n; k++) out.push({ x: ax + (bx - ax) * (k / n), z: az + (bz - az) * (k / n), nx: -tz, nz: tx });
  }
  const last = p.pts[p.pts.length - 1];
  if (out.length) out.push({ x: last[0], z: last[1], nx: out[out.length - 1].nx, nz: out[out.length - 1].nz });
  // smooth the normals so the ribbon doesn't kink at polyline vertices
  for (let it = 0; it < 2; it++) for (let i = 1; i < out.length - 1; i++) {
    const a = out[i - 1], c = out[i + 1];
    const nx = a.nx + c.nx + out[i].nx * 2, nz = a.nz + c.nz + out[i].nz * 2, l = Math.hypot(nx, nz) || 1;
    out[i].nx = nx / l; out[i].nz = nz / l;
  }
  return out;
}

type V3 = [number, number, number];
/** Quad whose normal points along `want` (flips the winding when needed). */
function face(g: GeoBuilder, key: string, a: V3, b: V3, c: V3, d: V3, want: V3) {
  const ux = b[0] - a[0], uy = b[1] - a[1], uz = b[2] - a[2], vx = c[0] - a[0], vy = c[1] - a[1], vz = c[2] - a[2];
  const nx = uy * vz - uz * vy, ny = uz * vx - ux * vz, nz = ux * vy - uy * vx;
  if (nx * want[0] + ny * want[1] + nz * want[2] >= 0) g.quad(key, a, b, c, d); else g.quad(key, d, c, b, a);
}

function trail(g: GeoBuilder, p: ParkPath, inTile: (x: number, z: number) => boolean) {
  const T = Terrain.get();
  const s = drape(p);
  const key = p.kind === 'gravel' ? 'tex:gravel:DIRT_PATH' : 'tex:dirt'; // tan crushed-stone trunk trails
  const h = p.w / 2, UP: V3 = [0, 1, 0], k = 'paint:WALNUT_DARK', top = EDGE_H * 0.6;
  for (let i = 0; i < s.length - 1; i++) {
    const a = s[i], b = s[i + 1];
    if (!inTile((a.x + b.x) / 2, (a.z + b.z) / 2)) continue;
    const P = (q: typeof a, d: number, up = 0): V3 => { const x = q.x + q.nx * d, z = q.z + q.nz * d; return [x, T.height(x, z) + LIFT + up, z]; };
    face(g, key, P(a, -h), P(b, -h), P(b, h), P(a, h), UP);
    if (p.kind !== 'gravel') continue;
    for (const side of [-1, 1]) {
      const d0 = side * h, d1 = side * (h + EDGE_W);
      const out: V3 = [a.nx * side, 0, a.nz * side], inn: V3 = [-out[0], 0, -out[2]];
      face(g, k, P(a, d0, top), P(b, d0, top), P(b, d1, top), P(a, d1, top), UP);   // top of the timber
      face(g, k, P(a, d1, top), P(b, d1, top), P(b, d1, -0.03), P(a, d1, -0.03), out); // outer face
      face(g, k, P(a, d0, top), P(b, d0, top), P(b, d0, 0), P(a, d0, 0), inn);       // inner face (above the gravel)
    }
  }
}

registerTileBuilder({
  name: 'park-trails', order: 41,
  build: (ctx) => {
    const b = tileBounds(ctx.tile);
    const inTile = (x: number, z: number) => x >= b.x0 && x < b.x1 && z >= b.z0 && z < b.z1;
    for (const p of parks().paths) {
      if (!p.pts.some(([x, z]) => x > b.x0 - 4 && x < b.x1 + 4 && z > b.z0 - 4 && z < b.z1 + 4)) continue;
      trail(ctx.gNoShadow, p, inTile);
    }
  },
});
