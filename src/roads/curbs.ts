// Curbs (CLAUDE.md §5): 15 cm high, 15 cm top, 2 cm chamfer. GRANITE_CURB on campus, CONCRETE_AGED downtown.
import type { GeoBuilder } from '../core/geo';
import type { P2 } from '../world/layout';

/** Curb cross-section [out, up] relative to the gutter line; out = away from the street. */
export const CURB_PROFILE: [number, number][] = [
  [0, -0.02], [0, 0.13], [0.02, 0.15], [0.15, 0.15], [0.15, 0.10],
];

/** Sweep a curb along a polyline of [x, z, gutterY] points. side=+1 sidewalk on the left of travel. */
export function sweepCurb(g: GeoBuilder, matKey: string, pts: [number, number, number][], side: 1 | -1) {
  if (pts.length < 2) return;
  const n = pts.length;
  const normals: P2[] = [];
  for (let i = 0; i < n; i++) {
    const a = pts[Math.max(0, i - 1)], b = pts[Math.min(n - 1, i + 1)];
    let tx = b[0] - a[0], tz = b[1] - a[1];
    const l = Math.hypot(tx, tz) || 1; tx /= l; tz /= l;
    normals.push([-tz * side, tx * side]);
  }
  for (let i = 0; i < n - 1; i++) {
    const A = pts[i], B = pts[i + 1], nA = normals[i], nB = normals[i + 1];
    for (let k = 0; k < CURB_PROFILE.length - 1; k++) {
      const [o0, u0] = CURB_PROFILE[k], [o1, u1] = CURB_PROFILE[k + 1];
      const p00: [number, number, number] = [A[0] + nA[0] * o0, A[2] + u0, A[1] + nA[1] * o0];
      const p10: [number, number, number] = [B[0] + nB[0] * o0, B[2] + u0, B[1] + nB[1] * o0];
      const p11: [number, number, number] = [B[0] + nB[0] * o1, B[2] + u1, B[1] + nB[1] * o1];
      const p01: [number, number, number] = [A[0] + nA[0] * o1, A[2] + u1, A[1] + nA[1] * o1];
      if (side > 0) g.quad(matKey, p00, p01, p11, p10); else g.quad(matKey, p00, p10, p11, p01);
    }
  }
}
