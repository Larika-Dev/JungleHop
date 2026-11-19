// Stair kit (CLAUDE.md §5/§6): straight, L, U, spiral (tower), exterior stoop, stadium aisle steps.
// Interior: risers ≤ 17.8 cm, treads ≥ 28 cm, 2.5 cm nosing, landings ≥ stair width.
// Exterior: risers 15–17 cm, treads 30–35 cm. Every builder returns its geometry metrics + walkable
// ramp patches (local cm coords) so buildings can register collision.
import type { GeoBuilder } from '../core/geo';
import { C, boxC, registerKit } from './common';

export const STAIR = { maxRiserInt: 17.8, minTreadInt: 28, nosing: 2.5, extRiser: [15, 17] as [number, number], extTread: [30, 35] as [number, number], public: 112, residential: 91 };

export interface Walk { poly: [number, number][]; y0: number; y1: number; o: [number, number]; dir: [number, number]; run: number; } // cm
export interface StairInfo { risers: number; riser: number; tread: number; width: number; walks: Walk[]; landings: { x0: number; z0: number; x1: number; z1: number; y: number }[]; footprint: [number, number]; }

/** Riser count & height for a total rise (cm) under a max riser. */
export function solveRisers(rise: number, max: number = STAIR.maxRiserInt): { n: number; riser: number } {
  const n = Math.max(1, Math.ceil(rise / max - 1e-9));
  return { n, riser: rise / n };
}

/**
 * One flight rising along +z from (x0, y0, z0): n risers of height r, treads t (cm), width w.
 * Treads have a 2.5 cm nosing; solid stepped mass underneath (stringer-less, masonry/concrete look)
 * unless `open` (wood stair: thin treads + risers + stringers).
 */
export function flight(g: GeoBuilder, x0: number, y0: number, z0: number, w: number, n: number, r: number, t: number, treadKey: string, riserKey: string, open = false, sideKey = riserKey, dir: 1 | -1 = 1) {
  for (let i = 0; i < n; i++) {
    const y = y0 + r * (i + 1);
    const za = z0 + dir * t * i, zb = z0 + dir * t * (i + 1);
    const zn = za - dir * STAIR.nosing;
    const [zt0, zt1] = dir > 0 ? [zn, zb] : [zb, zn];
    // tread (4 cm) with nosing
    boxC(g, treadKey, x0, y - 4, Math.min(zt0, zt1), x0 + w, y, Math.max(zt0, zt1));
    // riser face
    const [zr0, zr1] = dir > 0 ? [za, za + 2] : [za - 2, za];
    boxC(g, riserKey, x0, y - r, zr0, x0 + w, y - 4, zr1, dir > 0 ? 32 : 16);
    if (!open) {
      // mass below the step
      const [zm0, zm1] = dir > 0 ? [za, zb] : [zb, za];
      boxC(g, sideKey, x0, y0, zm0, x0 + w, y - 4, zm1, 1 | 2 | 8);
    }
  }
  if (open) {
    // two 4 cm x 28 cm stringers following the pitch
    const L = t * n, H = r * n;
    for (const sx of [x0, x0 + w - 4]) {
      const P = (zz: number, yy: number): [number, number, number][] => [[C(sx), C(yy), C(zz)], [C(sx + 4), C(yy), C(zz)]];
      const a = P(z0, y0), b = P(z0 + dir * L, y0 + H);
      const a2 = P(z0, y0 + 28), b2 = P(z0 + dir * L, y0 + H + 28);
      g.quad(sideKey, a[0], a2[0], b2[0], b[0]); g.quad(sideKey, b[1], b2[1], a2[1], a[1]);
      g.quad(sideKey, a2[0], a2[1], b2[1], b2[0]); g.quad(sideKey, b[0], b[1], a[1], a[0]);
    }
  }
}

function walkFor(x0: number, y0: number, z0: number, w: number, run: number, rise: number, dir: 1 | -1): Walk {
  const z1 = z0 + dir * run;
  return { poly: [[x0, Math.min(z0, z1)], [x0 + w, Math.min(z0, z1)], [x0 + w, Math.max(z0, z1)], [x0, Math.max(z0, z1)]], y0, y1: y0 + rise, o: [x0, z0], dir: [0, dir], run };
}

/** Straight stair: total rise (cm), width, tread (cm). */
export function straightStair(g: GeoBuilder, rise: number, w = STAIR.public, t = 28, keys = { tread: 'tex:oak_floor', riser: 'satin:TRIM_WHITE' }, open = false): StairInfo {
  const { n, riser } = solveRisers(rise);
  flight(g, 0, 0, 0, w, n, riser, t, keys.tread, keys.riser, open);
  return { risers: n, riser, tread: t, width: w, walks: [walkFor(0, 0, 0, w, n * t, rise, 1)], landings: [], footprint: [w, n * t] };
}

/** L stair: first flight along +z, landing (w x w), second flight along +x. */
export function lStair(g: GeoBuilder, rise: number, w = STAIR.public, t = 28, keys = { tread: 'tex:oak_floor', riser: 'satin:TRIM_WHITE' }): StairInfo {
  const { n, riser } = solveRisers(rise);
  const n1 = Math.ceil(n / 2), n2 = n - n1 - 1; // one riser onto the landing counted in n1
  flight(g, 0, 0, 0, w, n1, riser, t, keys.tread, keys.riser);
  const ly = riser * n1, lz0 = n1 * t;
  boxC(g, keys.tread, 0, 0, lz0, w, ly, lz0 + w, 63 & ~32);
  // second flight along +x: build rotated
  g.push(); g.translate(C(w), C(ly), C(lz0 + w)); g.rotateY(Math.PI / 2);
  flight(g, 0, 0, 0, w, n2 + 1, riser, t, keys.tread, keys.riser);
  g.pop();
  return {
    risers: n, riser, tread: t, width: w,
    walks: [walkFor(0, 0, 0, w, n1 * t, n1 * riser, 1)], landings: [{ x0: 0, z0: lz0, x1: w, z1: lz0 + w, y: ly }],
    footprint: [w + (n2 + 1) * t, lz0 + w],
  };
}

/** U (switchback) stair: flight up +z, half landing, flight back −z beside it. gap = well (cm). */
export function uStair(g: GeoBuilder, rise: number, w = STAIR.public, t = 28, keys = { tread: 'tex:terrazzo', riser: 'tex:terrazzo' }, gap = 10): StairInfo {
  const { n, riser } = solveRisers(rise);
  const n1 = Math.ceil(n / 2), n2 = n - n1;
  const run1 = n1 * t;
  flight(g, 0, 0, 0, w, n1, riser, t, keys.tread, keys.riser);
  const ly = n1 * riser;
  const W = 2 * w + gap;
  boxC(g, keys.tread, 0, 0, run1, W, ly, run1 + w, 63 & ~32);
  const x2 = w + gap;
  // second flight descends in z (rises going toward −z)
  flight(g, x2, ly, run1, w, n2, riser, t, keys.tread, keys.riser, false, keys.riser, -1);
  return {
    risers: n, riser, tread: t, width: w,
    walks: [walkFor(0, 0, 0, w, run1, ly, 1), walkFor(x2, ly, run1, w, n2 * t, n2 * riser, -1)],
    landings: [{ x0: 0, z0: run1, x1: W, z1: run1 + w, y: ly }],
    footprint: [W, run1 + w],
  };
}

/** Spiral stair around a central post (tower): inner r0, outer R (cm), rise per tread ≤ 17.8. */
export function spiralStair(g: GeoBuilder, rise: number, R = 120, r0 = 12, treadsPerTurn = 14, key = 'tex:capstone'): StairInfo {
  const { n, riser } = solveRisers(rise);
  g.push(); g.translate(C(R), 0, C(R));
  g.cylinder(key, C(r0), 0, C(rise + 100), 16, true);
  const da = (Math.PI * 2) / treadsPerTurn;
  for (let i = 0; i < n; i++) {
    const a0 = i * da, a1 = a0 + da * 1.08;
    const y = (i + 1) * riser;
    const P = (a: number, r: number, yy: number): [number, number, number] => [Math.sin(a) * C(r), C(yy), Math.cos(a) * C(r)];
    g.quad(key, P(a0, r0, y), P(a1, r0, y), P(a1, R, y), P(a0, R, y));
    g.quad(key, P(a0, R, y - 6), P(a1, R, y - 6), P(a1, r0, y - 6), P(a0, r0, y - 6));
    g.quad(key, P(a0, r0, y - riser), P(a0, R, y - riser), P(a0, R, y), P(a0, r0, y));
    g.quad(key, P(a1, R, y - 6), P(a1, R, y), P(a1, r0, y), P(a1, r0, y - 6));
    g.quad(key, P(a0, R, y - 6), P(a0, R, y), P(a1, R, y), P(a1, R, y - 6));
  }
  g.pop();
  const midTread = (R + r0) / 2 * da; // walk-line tread
  return { risers: n, riser, tread: midTread, width: R - r0, walks: [], landings: [], footprint: [2 * R, 2 * R] };
}

/** Exterior stoop: n steps (risers 15–17, treads 30–35) + top landing (depth ld) with cheek walls. */
export function stoop(g: GeoBuilder, rise: number, w = 180, t = 33, ld = 150, key = 'tex:limestone', cheek = 'brick:running:BRICK_DOWNTOWN_A'): StairInfo {
  const { n, riser } = solveRisers(rise, STAIR.extRiser[1]);
  // steps descend toward −z from the landing at z ∈ [0, ld]; each step is a full block from grade
  for (let i = 0; i < n; i++) {
    const top = riser * (i + 1);
    const zf = -t * (n - 1 - i);
    boxC(g, key, 0, 0, zf - t, w, top, i === n - 1 ? ld : zf);
    // wear dips 0.3–0.8 cm at tread centre (CLAUDE.md §5): shallow inset strip
    boxC(g, 'tex:capstone', w * 0.3, top - 0.5, zf - t + 3, w * 0.7, top + 0.001, zf - 3, 4);
  }
  // cheek walls
  for (const x of [-35, w]) boxC(g, cheek, x, 0, -t * n, x + 35, riser * n + 30, ld);
  return { risers: n, riser, tread: t, width: w, walks: [{ poly: [[0, -t * n], [w, -t * n], [w, 0], [0, 0]], y0: 0, y1: rise, o: [0, -t * n], dir: [0, 1], run: t * n }], landings: [{ x0: 0, z0: 0, x1: w, z1: ld, y: rise }], footprint: [w + 70, t * n + ld] };
}

/** Stadium aisle steps between seating tiers: tier rise 35.6 = 2 x 17.8, tier depth 80 = 2 x 40. */
export function aisleSteps(g: GeoBuilder, tiers: number, w = 110, tierRise = 35.6, tierDepth = 80, key = 'tex:concrete_new'): StairInfo {
  const per = 2;
  const r = tierRise / per, t = tierDepth / per;
  flight(g, 0, 0, 0, w, tiers * per, r, t, key, key);
  // yellow nosing stripes (painted)
  for (let i = 0; i < tiers * per; i++) boxC(g, 'paint:MARKING_YELLOW', 0, r * (i + 1), t * i - STAIR.nosing, w, r * (i + 1) + 0.15, t * i + 3);
  return { risers: tiers * per, riser: r, tread: t, width: w, walks: [walkFor(0, 0, 0, w, tiers * tierDepth, tiers * tierRise, 1)], landings: [], footprint: [w, tiers * tierDepth] };
}

// ------------------------------------------------------------------------------------------ registry (+ metrics for tests)
export const STAIR_SPECS: { name: string; interior: boolean; info: (g: GeoBuilder) => StairInfo }[] = [
  { name: 'straight 420 rise', interior: true, info: (g) => straightStair(g, 420) },
  { name: 'L 330 rise', interior: true, info: (g) => lStair(g, 330) },
  { name: 'U 430 rise', interior: true, info: (g) => uStair(g, 430) },
  { name: 'spiral 520 rise', interior: true, info: (g) => spiralStair(g, 520) },
  { name: 'stoop 64 rise', interior: false, info: (g) => stoop(g, 64) },
  { name: 'stadium aisle 10 tiers', interior: false, info: (g) => aisleSteps(g, 10) },
];

registerKit({ kit: 'Stair', name: 'straight 420 rise', build: (g) => { straightStair(g, 420); }, bbox: [0, 0, -2.5, 112, 420, 24 * 28] });
registerKit({ kit: 'Stair', name: 'L 330 rise', build: (g) => { lStair(g, 330); }, bbox: [0, 0, -2.5, 112 + 9 * 28, 330, 10 * 28 + 112], note: '19 risers: 10 + landing + 9' });
registerKit({ kit: 'Stair', name: 'U 430 rise (w112)', build: (g) => { uStair(g, 430); }, bbox: [0, 0, -2.5, 234, 430, 13 * 28 + 112] });
registerKit({ kit: 'Stair', name: 'spiral R120 520 rise', build: (g) => { spiralStair(g, 520); }, bbox: [0, 0, 0, 240, 620, 240], note: 'approx: post rises 1 m above top tread; polygonal' });
registerKit({ kit: 'Stair', name: 'exterior stoop 64 rise', build: (g) => { stoop(g, 64); }, bbox: [-35, 0, -132, 215, 94, 150] });
registerKit({ kit: 'Stair', name: 'stadium aisle 10 tiers', build: (g) => { aisleSteps(g, 10); }, bbox: [0, 0, -2.5, 110, 356.15, 800] });
