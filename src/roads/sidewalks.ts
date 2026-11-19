// Sidewalk details (CLAUDE.md §5): brick-paver / concrete walks, tree pits with 120 x 120 cm grates,
// ADA curb ramps (1:12) with truncated-dome panels 61 cm deep (domes 2.3 cm dia, 0.5 cm high, 5.5 cm o.c.).
import type { GeoBuilder, V3 } from '../core/geo';
import type { P2 } from '../world/layout';
import { registerDomes } from '../kits/nearDetail';

export const DOME_KEY = 'paint:TRUNCATED_DOME';
export const GRATE_KEY = 'satin:IRON_BLACK';

/** Truncated-dome detectable warning panel lying on a surface. dir = toward the street. */
export function domePanel(g: GeoBuilder, center: P2, dir: P2, yBack: number, yFront: number, width = 1.22, depth = 0.61, domes = false) {
  // individual domes are near-detail instances (kits/nearDetail.ts) unless explicitly baked
  registerDomes({ x: center[0], z: center[1], dx: dir[0], dz: dir[1], yBack, yFront, w: width, d: depth });
  const nx = -dir[1], nz = dir[0];
  const P = (u: number, v: number, lift = 0.002): V3 => {
    const t = (v + depth / 2) / depth;
    return [center[0] + nx * u + dir[0] * v, yBack + (yFront - yBack) * t + lift, center[1] + nz * u + dir[1] * v];
  };
  g.quad(DOME_KEY, P(-width / 2, -depth / 2), P(width / 2, -depth / 2), P(width / 2, depth / 2), P(-width / 2, depth / 2));
  if (!domes) return;
  const sp = 0.055, rb = 0.0115, rt = 0.006, h = 0.005;
  const nu = Math.floor(width / sp), nv = Math.floor(depth / sp);
  for (let i = 0; i < nu; i++) for (let j = 0; j < nv; j++) {
    const u = -((nu - 1) * sp) / 2 + i * sp, v = -((nv - 1) * sp) / 2 + j * sp;
    const [x, y, z] = P(u, v, 0.002);
    const seg = 6;
    for (let k = 0; k < seg; k++) {
      const a0 = (k / seg) * Math.PI * 2, a1 = ((k + 1) / seg) * Math.PI * 2;
      const b0: V3 = [x + Math.cos(a0) * rb, y, z + Math.sin(a0) * rb], b1: V3 = [x + Math.cos(a1) * rb, y, z + Math.sin(a1) * rb];
      const t0: V3 = [x + Math.cos(a0) * rt, y + h, z + Math.sin(a0) * rt], t1: V3 = [x + Math.cos(a1) * rt, y + h, z + Math.sin(a1) * rt];
      g.quad(DOME_KEY, b0, t0, t1, b1);
      g.tri(DOME_KEY, [x, y + h, z], t1, t0);
    }
  }
}

/** Cast-iron tree grate 120 x 120 cm with a 45 cm trunk opening, over a mulch bed. Axis-aligned to `along`. */
export function treeGrate(g: GeoBuilder, c: P2, along: P2, y: number) {
  const nx = -along[1], nz = along[0];
  const P = (u: number, v: number, yy: number): V3 => [c[0] + along[0] * u + nx * v, yy, c[1] + along[1] * u + nz * v];
  const S = 0.6;
  // mulch bed visible between the bars (PINE_STRAW) 3 cm below the grate
  g.quad('tex:pinestraw', P(-S, -S, y - 0.03), P(-S, S, y - 0.03), P(S, S, y - 0.03), P(S, -S, y - 0.03));
  // frame (angle iron) 4 cm
  const bar = (u0: number, v0: number, u1: number, v1: number, h = 0.012) => {
    const pts = [P(u0, v0, y + h), P(u1, v0, y + h), P(u1, v1, y + h), P(u0, v1, y + h)];
    g.quad(GRATE_KEY, pts[0], pts[3], pts[2], pts[1]);
    // sides
    g.quad(GRATE_KEY, P(u0, v0, y - 0.02), P(u1, v0, y - 0.02), pts[1], pts[0]);
    g.quad(GRATE_KEY, P(u1, v1, y - 0.02), P(u0, v1, y - 0.02), pts[3], pts[2]);
  };
  bar(-S, -S, S, -S + 0.04); bar(-S, S - 0.04, S, S); bar(-S, -S, -S + 0.04, S); bar(S - 0.04, -S, S, S);
  // radial/concentric pattern: square rings + slats, leaving a 45 cm opening for the trunk
  for (const r of [0.23, 0.36, 0.48]) {
    bar(-r - 0.015, -r - 0.015, r + 0.015, -r + 0.015); bar(-r - 0.015, r - 0.015, r + 0.015, r + 0.015);
    bar(-r - 0.015, -r, -r + 0.015, r); bar(r - 0.015, -r, r + 0.015, r);
  }
  for (let k = -5; k <= 5; k++) {
    const u = k * 0.1;
    if (Math.abs(u) < 0.24) { bar(u - 0.008, -S, u + 0.008, -0.24); bar(u - 0.008, 0.24, u + 0.008, S); }
    else bar(u - 0.008, -S, u + 0.008, S);
  }
}

/** Height dip (m) that forms a curb ramp: 15 cm at the curb line, 0 at 1.8 m back (1:12), across ±0.9 m. */
export function rampDip(alongDist: number, backFromCurb: number): number {
  const a = Math.max(0, 1 - Math.max(0, Math.abs(alongDist) - 0.61) / 0.6); // flat 1.22 m + flares
  const b = Math.max(0, 1 - backFromCurb / 1.8);
  return 0.15 * a * b;
}
