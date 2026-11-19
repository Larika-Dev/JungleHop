// Heightfield (CLAUDE.md §8). Natural ground = IDW of spot elevations on a cached 5 m grid,
// carved by Battle Ravine, the Benefactor bowl and the Quarry plaza, plus fine value noise.
// The road network then flattens corridors (see roads/network.ts) -> `Terrain.height()`.
import { hash01 } from '../core/rng';
import { TOTAL } from '../core/tiles';
import { smoothstep } from '../core/units';
import { BOWL, QUARRY_PLAZA, SPOTS } from '../world/layout';
import { ravineCarve } from './ravine';

const STEP = 5;
const NX = (TOTAL.x1 - TOTAL.x0) / STEP + 1;
const NZ = (TOTAL.z1 - TOTAL.z0) / STEP + 1;
let grid: Float32Array | null = null;

function idw(x: number, z: number): number {
  let num = 0, den = 0;
  for (const [sx, sz, e] of SPOTS) {
    const d2 = (x - sx) ** 2 + (z - sz) ** 2;
    if (d2 < 1) return e;
    const w = 1 / (d2 * Math.sqrt(Math.sqrt(d2)));
    num += w * e; den += w;
  }
  return num / den;
}

function buildGrid(): Float32Array {
  const g = new Float32Array(NX * NZ);
  for (let j = 0; j < NZ; j++) for (let i = 0; i < NX; i++) g[j * NX + i] = idw(TOTAL.x0 + i * STEP, TOTAL.z0 + j * STEP);
  return g;
}

/** Smooth value noise (deterministic) for micro relief. */
function vnoise(x: number, z: number, scale: number): number {
  const fx = x / scale, fz = z / scale;
  const ix = Math.floor(fx), iz = Math.floor(fz);
  const tx = fx - ix, tz = fz - iz;
  const sx = tx * tx * (3 - 2 * tx), sz = tz * tz * (3 - 2 * tz);
  const a = hash01(ix, iz, scale), b = hash01(ix + 1, iz, scale), c = hash01(ix, iz + 1, scale), d = hash01(ix + 1, iz + 1, scale);
  return (a + (b - a) * sx) * (1 - sz) + (c + (d - c) * sx) * sz;
}

/** Base IDW elevation (bilinear on the cached grid). */
export function baseElevation(x: number, z: number): number {
  if (!grid) grid = buildGrid();
  const fx = Math.max(0, Math.min(NX - 1.001, (x - TOTAL.x0) / STEP));
  const fz = Math.max(0, Math.min(NZ - 1.001, (z - TOTAL.z0) / STEP));
  const i = Math.floor(fx), j = Math.floor(fz), tx = fx - i, tz = fz - j;
  const g = grid;
  const a = g[j * NX + i], b = g[j * NX + i + 1], c = g[(j + 1) * NX + i], d = g[(j + 1) * NX + i + 1];
  return (a + (b - a) * tx) * (1 - tz) + (c + (d - c) * tx) * tz;
}

/** Benefactor bowl carve: elliptical floor at -28 m with smooth falloff to the rim. */
export function bowlCarve(x: number, z: number, e: number): number {
  const q = Math.hypot((x - BOWL.cx) / BOWL.rx, (z - BOWL.cz) / BOWL.rz);
  const r = Math.max(0, q - 1) * Math.min(BOWL.rx, BOWL.rz);
  return Math.min(e, BOWL.floor + (e - BOWL.floor) * smoothstep(0, BOWL.falloff, r));
}

/** Natural ground (no roads): base + carves + micro relief (fades out near the ridge/streets). */
export function naturalHeight(x: number, z: number): number {
  let e = baseElevation(x, z);
  e = ravineCarve(x, z, e);
  e = bowlCarve(x, z, e);
  // micro relief: 4-level value noise, ±0.6 m at 40 m + ±0.15 m at 8 m
  e += (vnoise(x, z, 40) - 0.5) * 1.2 + (vnoise(x, z, 8) - 0.5) * 0.3 + (vnoise(x, z, 160) - 0.5) * 2.0 * outerness(x, z);
  // Quarry plaza: sunk 2.5 m below grade (stepped seating walls are landmark geometry)
  const P = QUARRY_PLAZA;
  if (x > P.x0 - 6 && x < P.x1 + 6 && z > P.z0 - 6 && z < P.z1 + 6) {
    const dIn = Math.min(x - P.x0, P.x1 - x, z - P.z0, P.z1 - z);
    const k = smoothstep(-6, 0, dIn);
    e -= P.depth * k;
  }
  return e;
}

/** 0 in the dense core, ramping to 1 in the outer ring (bigger rolling hills outside). */
export function outerness(x: number, z: number): number {
  const dx = Math.max(-900 - x, x - 700, 0), dz = Math.max(-450 - z, z - 950, 0);
  return smoothstep(0, 400, Math.hypot(dx, dz));
}

/** Slope magnitude (rise/run) of natural ground. */
export function naturalSlope(x: number, z: number): number {
  const h = 1.0;
  const dx = naturalHeight(x + h, z) - naturalHeight(x - h, z);
  const dz = naturalHeight(x, z + h) - naturalHeight(x, z - h);
  return Math.hypot(dx, dz) / (2 * h);
}
