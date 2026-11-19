// Pavement markings (CLAUDE.md §4.5/§9.1): double/dashed yellow centerlines, parking edge lines + stall
// ticks, bike lanes, ladder crosswalks (60 cm bars / 60 cm gaps), stop bars. All 10 cm lines, 4 mm proud.
import type { GeoBuilder } from '../core/geo';
import type { P2 } from '../world/layout';

export const MARK_LIFT = 0.004;
export const MARK_W = 'mark:MARKING_WHITE';
export const MARK_Y = 'mark:MARKING_YELLOW';
export const MARK_BIKE = 'mark:BIKE_LANE_GREEN';

export type Frame = { p: P2; t: P2; n: P2; y: number; s: number };

/** Ribbon strip at lateral offsets [d0, d1] along frames (y from callback). */
export function strip(g: GeoBuilder, key: string, frames: Frame[], d0: number, d1: number, yAt: (f: Frame, d: number) => number, lift = MARK_LIFT) {
  for (let i = 0; i < frames.length - 1; i++) {
    const A = frames[i], B = frames[i + 1];
    const a0: [number, number, number] = [A.p[0] + A.n[0] * d0, yAt(A, d0) + lift, A.p[1] + A.n[1] * d0];
    const a1: [number, number, number] = [A.p[0] + A.n[0] * d1, yAt(A, d1) + lift, A.p[1] + A.n[1] * d1];
    const b0: [number, number, number] = [B.p[0] + B.n[0] * d0, yAt(B, d0) + lift, B.p[1] + B.n[1] * d0];
    const b1: [number, number, number] = [B.p[0] + B.n[0] * d1, yAt(B, d1) + lift, B.p[1] + B.n[1] * d1];
    // left normal n = (-tz, tx); ensure upward winding
    if (d1 > d0) g.quad(key, a0, a1, b1, b0); else g.quad(key, a0, b0, b1, a1);
  }
}

/** Dashed line: dash/gap lengths along s. */
export function dashed(g: GeoBuilder, key: string, frames: Frame[], d: number, w: number, dash: number, gap: number, yAt: (f: Frame, d: number) => number) {
  if (frames.length < 2) return;
  const s0 = frames[0].s, s1 = frames[frames.length - 1].s;
  const period = dash + gap;
  const start = Math.ceil(s0 / period) * period;
  for (let s = start; s + dash <= s1; s += period) {
    const fr = frames.filter((f) => f.s > s && f.s < s + dash);
    const a = interp(frames, s), b = interp(frames, s + dash);
    strip(g, key, [a, ...fr, b], d - w / 2, d + w / 2, yAt);
  }
}

export function interp(frames: Frame[], s: number): Frame {
  let i = 1;
  while (i < frames.length - 1 && frames[i].s < s) i++;
  const A = frames[i - 1], B = frames[i];
  const k = Math.max(0, Math.min(1, (s - A.s) / (B.s - A.s || 1)));
  return { p: [A.p[0] + (B.p[0] - A.p[0]) * k, A.p[1] + (B.p[1] - A.p[1]) * k], t: A.t, n: A.n, y: A.y + (B.y - A.y) * k, s };
}

/**
 * Ladder crosswalk across a roadway: bars 60 cm wide (parallel to traffic), 60 cm gaps,
 * spanning the full curb-to-curb width; `len` = crossing width along the road.
 */
export function ladderCrosswalk(g: GeoBuilder, center: P2, along: P2, half: number, len: number, y: number) {
  const nx = -along[1], nz = along[0];
  const bars = Math.floor((half * 2 + 0.6) / 1.2);
  const total = bars * 1.2 - 0.6;
  for (let i = 0; i < bars; i++) {
    const off = -total / 2 + i * 1.2;
    const c0 = off, c1 = off + 0.6;
    const p = (u: number, v: number): [number, number, number] => [center[0] + nx * u + along[0] * v, y + MARK_LIFT + 0.001, center[1] + nz * u + along[1] * v];
    g.quad(MARK_W, p(c0, -len / 2), p(c1, -len / 2), p(c1, len / 2), p(c0, len / 2));
  }
  // outline lines 20 cm (ladder rails)
  for (const v of [-len / 2, len / 2 - 0.2]) {
    const p = (u: number, vv: number): [number, number, number] => [center[0] + nx * u + along[0] * vv, y + MARK_LIFT, center[1] + nz * u + along[1] * vv];
    g.quad(MARK_W, p(-half, v), p(half, v), p(half, v + 0.2), p(-half, v + 0.2));
  }
}

/** Solid bar across part of the road (stop bar), from lateral d0..d1, depth `w` along the road. */
export function stopBar(g: GeoBuilder, center: P2, along: P2, d0: number, d1: number, w: number, y: number) {
  const nx = -along[1], nz = along[0];
  const p = (u: number, v: number): [number, number, number] => [center[0] + nx * u + along[0] * v, y + MARK_LIFT, center[1] + nz * u + along[1] * v];
  g.quad(MARK_W, p(d0, 0), p(d1, 0), p(d1, w), p(d0, w));
}
