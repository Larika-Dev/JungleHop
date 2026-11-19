// Brick wall kit (CLAUDE.md §5/§6): straight, corner (in/out), opening frame, soldier course, rowlock sill,
// jack arch, segmental arch, pilaster, chimney stack. US modular brick 19.4 x 5.7 x 9.2 cm, 1 cm joints.
import { Color } from 'three';
import type { GeoBuilder } from '../core/geo';
import { jitter, pc, type PaletteKey } from '../core/palette';
import { Rng } from '../core/rng';
import { C, boxC, registerKit } from './common';

export const BRICK_CM = { L: 19.4, H: 5.7, D: 9.2, J: 1.0 } as const;
export const COURSE_CM = 6.7;

const _c = new Color();
/** Vertex-color multiplier giving one brick its jittered tint (value ±6 %, hue ±3°). */
export function brickTint(key: PaletteKey, rng: Rng): Color {
  jitter(key, rng.next(), rng.next(), 0.06, 3, _c);
  const b = pc(key);
  return new Color(_c.r / Math.max(1e-4, b.r), _c.g / Math.max(1e-4, b.g), _c.b / Math.max(1e-4, b.b));
}

export interface Opening { x: number; y: number; w: number; h: number; } // cm, relative to wall origin

/**
 * Solid wall slab w x h x t (cm) with rectangular openings cut through (reveals are the box sides).
 * `frontKey` faces −z, `backKey` (interior) faces +z, `coreKey` reveals/top. Faces split per opening.
 */
export function wallWithOpenings(g: GeoBuilder, w: number, h: number, t: number, openings: Opening[], frontKey: string, backKey = frontKey, revealKey = frontKey) {
  const ops = [...openings].sort((a, b) => a.x - b.x);
  // vertical strips between opening x-edges
  const xs = new Set<number>([0, w]);
  for (const o of ops) { xs.add(Math.max(0, o.x)); xs.add(Math.min(w, o.x + o.w)); }
  const X = [...xs].sort((a, b) => a - b);
  for (let i = 0; i < X.length - 1; i++) {
    const x0 = X[i], x1 = X[i + 1];
    if (x1 - x0 < 1e-6) continue;
    const cut = ops.filter((o) => o.x < x1 - 1e-6 && o.x + o.w > x0 + 1e-6).sort((a, b) => a.y - b.y);
    let y = 0;
    const solid = (y0: number, y1: number) => {
      if (y1 - y0 < 1e-6) return;
      // front, back
      boxC(g, frontKey, x0, y0, 0, x1, y1, 0.0001, 32);
      boxC(g, backKey, x0, y0, t - 0.0001, x1, y1, t, 16);
      // left/right only on wall ends; top/bottom always (reveals: sill & head)
      if (x0 === 0) boxC(g, revealKey, x0, y0, 0, x1, y1, t, 2);
      if (x1 === w) boxC(g, revealKey, x0, y0, 0, x1, y1, t, 1);
      if (y1 === h) boxC(g, revealKey, x0, y0, 0, x1, y1, t, 4); else boxC(g, revealKey, x0, y0, 0, x1, y1, t, 4);
      if (y0 > 0) boxC(g, revealKey, x0, y0, 0, x1, y1, t, 8);
    };
    for (const o of cut) { solid(y, Math.max(y, o.y)); y = Math.max(y, o.y + o.h); }
    solid(y, h);
  }
  // jamb reveals (sides of openings)
  for (const o of ops) {
    const x0 = Math.max(0, o.x), x1 = Math.min(w, o.x + o.w);
    const y0 = Math.max(0, o.y), y1 = Math.min(h, o.y + o.h);
    if (x0 > 0) boxC(g, revealKey, x0 - 1, y0, 0, x0, y1, t, 1);
    if (x1 < w) boxC(g, revealKey, x1, y0, 0, x1 + 1, y1, t, 2);
  }
}

/** Straight brick wall. */
export function brickWall(g: GeoBuilder, w: number, h: number, t: number, key: string, interiorKey = 'paint:PLASTER_CAMPUS') {
  wallWithOpenings(g, w, h, t, [], key, interiorKey, key);
}

/** Outside/inside corner: legA along +x (length a), legB along +z (length b). */
export function brickCorner(g: GeoBuilder, a: number, b: number, h: number, t: number, key: string, inside = false) {
  if (!inside) {
    boxC(g, key, 0, 0, 0, a, h, t);
    boxC(g, key, 0, 0, t, t, h, b);
  } else {
    boxC(g, key, 0, 0, b - t, a, h, b);
    boxC(g, key, a - t, 0, 0, a, h, b - t);
  }
}

/** Soldier course: bricks on end, 19.4 tall, faces flush at z=0 (proud of field by 0 — field sits 0.5 behind). */
export function soldierCourse(g: GeoBuilder, w: number, key: PaletteKey, seed = 'soldier') {
  const rng = new Rng(seed);
  const n = Math.max(1, Math.round((w + BRICK_CM.J) / (BRICK_CM.H + BRICK_CM.J)));
  const pitch = (w + BRICK_CM.J) / n;
  for (let i = 0; i < n; i++) {
    g.setColor(brickTint(key, rng));
    boxC(g, `paint:${key}`, i * pitch, 0, 0, i * pitch + pitch - BRICK_CM.J, BRICK_CM.L, BRICK_CM.D);
  }
  g.setColor(null);
}

/** Rowlock sill: bricks on edge, sloped 10°, projecting 2.5 cm in front of the wall face (z<0). */
export function rowlockSill(g: GeoBuilder, w: number, key: PaletteKey, seed = 'rowlock') {
  const rng = new Rng(seed);
  const n = Math.max(1, Math.round((w + BRICK_CM.J) / (BRICK_CM.H + BRICK_CM.J)));
  const pitch = (w + BRICK_CM.J) / n;
  const drop = Math.tan((10 * Math.PI) / 180) * BRICK_CM.L; // 3.42 cm fall over the brick length
  for (let i = 0; i < n; i++) {
    const x0 = C(i * pitch), x1 = C(i * pitch + pitch - BRICK_CM.J);
    const zf = C(-2.5), zb = C(BRICK_CM.L - 2.5);
    const yb = C(BRICK_CM.D), yf = C(BRICK_CM.D - drop);
    g.setColor(brickTint(key, rng));
    const k = `paint:${key}`;
    g.quad(k, [x0, 0, zf], [x0, yf, zf], [x1, yf, zf], [x1, 0, zf]); // front (−z)
    g.quad(k, [x0, yf, zf], [x0, yb, zb], [x1, yb, zb], [x1, yf, zf]); // sloped top
    g.quad(k, [x0, 0, zb], [x0, 0, zf], [x1, 0, zf], [x1, 0, zb]); // bottom
    g.quad(k, [x0, 0, zb], [x0, yb, zb], [x0, yf, zf], [x0, 0, zf]); // left
    g.quad(k, [x1, 0, zf], [x1, yf, zf], [x1, yb, zb], [x1, 0, zb]); // right
  }
  g.setColor(null);
}

/** Jack (flat) arch over an opening of width ow: 4 courses tall, voussoirs splayed 15°. */
export function jackArch(g: GeoBuilder, ow: number, key: PaletteKey, seed = 'jack') {
  const rng = new Rng(seed);
  const H = COURSE_CM * 4; // 26.8
  const skew = H * Math.tan((15 * Math.PI) / 180); // 7.18 cm per side at the top
  const n = Math.max(3, Math.round(ow / (BRICK_CM.H + BRICK_CM.J)) | 1);
  const k = `paint:${key}`;
  for (let i = 0; i < n; i++) {
    const b0 = (ow * i) / n, b1 = (ow * (i + 1)) / n - 0.5;
    const t0 = -skew + ((ow + 2 * skew) * i) / n, t1 = -skew + ((ow + 2 * skew) * (i + 1)) / n - 0.5;
    g.setColor(brickTint(key, rng));
    const P = (x: number, y: number, z: number): [number, number, number] => [C(x), C(y), C(z)];
    const D = BRICK_CM.D;
    g.quad(k, P(b0, 0, 0), P(t0, H, 0), P(t1, H, 0), P(b1, 0, 0));
    g.quad(k, P(b1, 0, D), P(t1, H, D), P(t0, H, D), P(b0, 0, D));
    g.quad(k, P(b0, 0, D), P(t0, H, D), P(t0, H, 0), P(b0, 0, 0));
    g.quad(k, P(b1, 0, 0), P(t1, H, 0), P(t1, H, D), P(b1, 0, D));
    g.quad(k, P(t0, H, 0), P(t0, H, D), P(t1, H, D), P(t1, H, 0));
    g.quad(k, P(b0, 0, D), P(b0, 0, 0), P(b1, 0, 0), P(b1, 0, D));
  }
  g.setColor(null);
}
export const jackArchSkew = () => COURSE_CM * 4 * Math.tan((15 * Math.PI) / 180);

/** Segmental arch: rise = span/6, ring = one brick length (19.4) of rowlock voussoirs. */
export function segmentalArch(g: GeoBuilder, ow: number, key: PaletteKey, seed = 'seg') {
  const rng = new Rng(seed);
  const rise = ow / 6;
  const R = (ow * ow / 4 + rise * rise) / (2 * rise);
  const half = Math.asin(ow / 2 / R);
  const ring = BRICK_CM.L;
  const cy = rise - R;
  const nv = Math.max(5, Math.round((R * 2 * half) / (BRICK_CM.H + BRICK_CM.J)));
  const k = `paint:${key}`;
  const D = BRICK_CM.D;
  for (let i = 0; i < nv; i++) {
    const a0 = -half + (2 * half * i) / nv, a1 = -half + (2 * half * (i + 1)) / nv - 0.004;
    const pt = (a: number, r: number, z: number): [number, number, number] => [C(ow / 2 + Math.sin(a) * r), C(cy + Math.cos(a) * r), C(z)];
    g.setColor(brickTint(key, rng));
    g.quad(k, pt(a0, R, 0), pt(a0, R + ring, 0), pt(a1, R + ring, 0), pt(a1, R, 0));
    g.quad(k, pt(a1, R, D), pt(a1, R + ring, D), pt(a0, R + ring, D), pt(a0, R, D));
    g.quad(k, pt(a0, R + ring, 0), pt(a0, R + ring, D), pt(a1, R + ring, D), pt(a1, R + ring, 0));
    g.quad(k, pt(a1, R, 0), pt(a1, R, D), pt(a0, R, D), pt(a0, R, 0));
    g.quad(k, pt(a0, R, D), pt(a0, R + ring, D), pt(a0, R + ring, 0), pt(a0, R, 0));
    g.quad(k, pt(a1, R, 0), pt(a1, R + ring, 0), pt(a1, R + ring, D), pt(a1, R, D));
  }
  g.setColor(null);
}
export function segmentalArchBox(ow: number): [number, number, number, number, number, number] {
  const rise = ow / 6, R = (ow * ow / 4 + rise * rise) / (2 * rise), half = Math.asin(ow / 2 / R), ring = BRICK_CM.L;
  const cy = rise - R;
  const xo = Math.sin(half) * (R + ring);
  return [ow / 2 - xo, cy + Math.cos(half) * R, 0, ow / 2 + xo, cy + R + ring, BRICK_CM.D];
}

/** Pilaster projecting p cm in front of the wall face. */
export function pilaster(g: GeoBuilder, w: number, h: number, p: number, key: string, capKey = 'tex:limestone') {
  boxC(g, key, 0, 0, -p, w, h - 15, 0);
  boxC(g, capKey, -3, h - 15, -p - 3, w + 3, h, 0); // stone cap
}

/** Chimney stack w x d x h with a 2-course corbel cap and 15 cm clay flue pots. */
export function chimney(g: GeoBuilder, w: number, d: number, h: number, key: string) {
  boxC(g, key, 0, 0, 0, w, h - COURSE_CM * 2, d);
  boxC(g, key, -2.5, h - COURSE_CM * 2, -2.5, w + 2.5, h, d + 2.5);
  const flues = Math.max(1, Math.floor(w / 40));
  for (let i = 0; i < flues; i++) {
    const cx = (w * (i + 0.5)) / flues;
    g.cylinder('paint:RED_CLAY', C(9), C(h), C(h + 15), 10, true, C(cx), C(d / 2));
  }
}

// ------------------------------------------------------------------------------------------ registry
const BK = 'brick:flemish:BRICK_CAMPUS_A';
registerKit({ kit: 'Brick wall', name: 'straight 300x300x35', build: (g) => brickWall(g, 300, 300, 35, BK), bbox: [0, 0, 0, 300, 300, 35] });
registerKit({ kit: 'Brick wall', name: 'corner out 120x120', build: (g) => brickCorner(g, 120, 120, 300, 35, BK), bbox: [0, 0, 0, 120, 300, 120] });
registerKit({ kit: 'Brick wall', name: 'corner in 120x120', build: (g) => brickCorner(g, 120, 120, 300, 35, BK, true), bbox: [0, 0, 0, 120, 300, 120] });
registerKit({ kit: 'Brick wall', name: 'opening frame 91x183', build: (g) => wallWithOpenings(g, 250, 300, 35, [{ x: 79.5, y: 76, w: 91, h: 183 }], BK, 'paint:PLASTER_CAMPUS', BK), bbox: [0, 0, 0, 250, 300, 35] });
registerKit({ kit: 'Brick wall', name: 'soldier course 101.3', build: (g) => soldierCourse(g, 101.3, 'BRICK_CAMPUS_A'), bbox: [0, 0, 0, 101.3, 19.4, 9.2] });
registerKit({ kit: 'Brick wall', name: 'rowlock sill 100', build: (g) => rowlockSill(g, 100.5, 'BRICK_CAMPUS_A'), bbox: [0, 0, -2.5, 100.5, 9.2, 16.9] });
registerKit({ kit: 'Brick wall', name: 'jack arch 91', build: (g) => jackArch(g, 91, 'BRICK_CAMPUS_A'), bbox: [-jackArchSkew(), 0, 0, 91 + jackArchSkew() - 0.5, 26.8, 9.2] });
registerKit({ kit: 'Brick wall', name: 'segmental arch 120', build: (g) => segmentalArch(g, 120, 'BRICK_DOWNTOWN_A'), bbox: segmentalArchBox(120) });
registerKit({ kit: 'Brick wall', name: 'pilaster 50x300 p12', build: (g) => pilaster(g, 50, 300, 12, BK), bbox: [-3, 0, -15, 53, 300, 0] });
registerKit({ kit: 'Brick wall', name: 'chimney stack 80x50x200', build: (g) => chimney(g, 80, 50, 200, BK), bbox: [-2.5, 0, -2.5, 82.5, 215, 52.5] });
