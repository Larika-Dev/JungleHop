// Battle Ravine (CLAUDE.md §8): creek bed -18 m, steep wooded slopes, exposed red-clay banks.
import { smoothstep } from '../core/units';
import { RAVINE, type P2 } from '../world/layout';

export function segDist(px: number, pz: number, a: P2, b: P2): { d: number; t: number } {
  const dx = b[0] - a[0], dz = b[1] - a[1];
  const l2 = dx * dx + dz * dz || 1e-9;
  const t = Math.max(0, Math.min(1, ((px - a[0]) * dx + (pz - a[1]) * dz) / l2));
  return { d: Math.hypot(px - (a[0] + t * dx), pz - (a[1] + t * dz)), t };
}

/** Distance to the creek centerline (m). */
export function creekDistance(x: number, z: number): number {
  let d = Infinity;
  const c = RAVINE.creek;
  for (let i = 0; i < c.length - 1; i++) d = Math.min(d, segDist(x, z, c[i], c[i + 1]).d);
  return d;
}

/** Ravine profile: flat 3 m creek bed, steep banks (V-ish), easing into the rims. */
export function ravineCarve(x: number, z: number, e: number): number {
  const d = creekDistance(x, z);
  if (d > RAVINE.halfWidth + 5) return e;
  // bank profile: 0..3 m bed, 3..30 m steep (~45%), 30..75 m easing out
  const t = smoothstep(2.5, RAVINE.halfWidth, d);
  const shaped = Math.pow(t, 0.75);
  return Math.min(e, RAVINE.bed + (e - RAVINE.bed) * shaped);
}

/** Creek water surface height (30 cm above the bed) where the creek runs. */
export const CREEK_WATER = RAVINE.bed + 0.3;
