// Shared hero-asset helpers for landmarks (CLAUDE.md §10). Building-local cm unless noted.
import { GeoBuilder, type V3 } from '../../core/geo';
import { C, boxC } from '../../kits/common';
import { doricColumn, ionicColumn } from '../../kits/column';
import { corniceStraight, PROFILES, dentils } from '../../kits/cornice';
import { dome } from '../../kits/roof';
import type { BuildingSpec } from '../../interiors/types';
import type { LandmarkSite } from '../../world/layout';

/** Spec whose footprint (w x d cm) is centered on a landmark site with its rotation. */
export function centered(site: LandmarkSite, w: number, d: number, rest: Omit<BuildingSpec, 'x' | 'z' | 'rotY' | 'w' | 'd' | 'y'> & { y?: number }): BuildingSpec {
  const c = Math.cos(site.rotY), s = Math.sin(site.rotY);
  const hw = w / 200, hd = d / 200;
  return { ...rest, x: site.x - (hw * c + hd * s), z: site.z - (-hw * s + hd * c), rotY: site.rotY, w, d, y: rest.y ?? 0 } as BuildingSpec;
}

/**
 * Classical portico on the front face (z = 0, facing −z): 3-step stylobate, n columns of height colH,
 * entablature, triangular pediment with raking cornice, coffered ceiling. Returns depth used (cm).
 */
export function portico(g: GeoBuilder, x0: number, w: number, depth: number, colH: number, n: number, order: 'doric' | 'ionic', y = 0, opts: { colKey?: string; stoneKey?: string; tympanum?: string; steps?: number } = {}) {
  const col = opts.colKey ?? 'satin:COLUMN_WHITE', stone = opts.stoneKey ?? 'tex:limestone';
  const D = Math.max(50, Math.min(90, colH / 9));
  const steps = opts.steps ?? 3;
  for (let i = 0; i < steps; i++) boxC(g, stone, x0 - 30 - i * 33, y - (steps - i) * 16, -depth - (steps - 1 - i) * 33 - 30, x0 + w + 30 + i * 33, y - (steps - 1 - i) * 16, 0);
  const pitch = (w - D * 1.3) / (n - 1);
  for (let i = 0; i < n; i++) {
    g.push(); g.translate(C(x0 + i * pitch), C(y), C(-depth));
    if (order === 'ionic') ionicColumn(g, D, colH, col); else doricColumn(g, D, colH, col);
    g.pop();
  }
  const ey = y + colH, eh = 90;
  // entablature (architrave + frieze + cornice) wrapping the portico
  boxC(g, 'satin:TRIM_WHITE', x0 - 10, ey, -depth - 10, x0 + w + 10, ey + eh, 10);
  g.push(); g.translate(C(x0 - 10), C(ey + eh), C(-depth - 10)); corniceStraight(g, w + 20, PROFILES.box, 'satin:TRIM_WHITE'); g.pop();
  g.push(); g.translate(C(x0 - 10), C(ey + eh - 12), C(-depth - 10)); dentils(g, w + 20, 'satin:TRIM_WHITE', 0, 6); g.pop();
  // pediment: triangle 1:4.5 pitch
  const ph = (w + 20) / 4.5, pyb = ey + eh + 32, cx = x0 + w / 2;
  const P = (x: number, yy: number, z: number): V3 => [C(x), C(yy), C(z)];
  g.tri(opts.tympanum ?? 'satin:TRIM_WHITE', P(x0 - 5, pyb, -depth - 2), P(cx, pyb + ph - 10, -depth - 2), P(x0 + w + 5, pyb, -depth - 2));
  // raking cornices
  for (const sgn of [-1, 1]) {
    const xa = sgn < 0 ? x0 - 20 : x0 + w + 20;
    g.quad('satin:TRIM_WHITE', P(xa, pyb - 2, -depth - 22), P(cx, pyb + ph, -depth - 22), P(cx, pyb + ph + 24, -depth - 22), P(xa, pyb + 22, -depth - 22).map((v) => v) as V3);
    // roof over portico (slate)
    if (sgn < 0) g.quad('tex:slate', P(xa, pyb + 22, -depth - 22), P(xa, pyb + 22, 20), P(cx, pyb + ph + 24, 20), P(cx, pyb + ph + 24, -depth - 22));
    else g.quad('tex:slate', P(xa, pyb + 22, 20), P(xa, pyb + 22, -depth - 22), P(cx, pyb + ph + 24, -depth - 22), P(cx, pyb + ph + 24, 20));
  }
  // coffered ceiling
  boxC(g, 'paint:CEILING_WHITE', x0, ey - 1, -depth, x0 + w, ey, 0, 8);
  for (let x = x0 + 60; x < x0 + w - 60; x += 120) for (let z = -depth + 60; z < -40; z += 120) boxC(g, 'satin:TRIM_WHITE', x - 45, ey - 1, z - 45, x + 45, ey - 0.2, z + 45, 8);
  return depth;
}

/** Dome over a center point (cm local) at height y with an optional drum and inner coffered shell. */
export function drumDome(g: GeoBuilder, cx: number, cz: number, r: number, drumH: number, y: number, key = 'tex:patina') {
  g.push(); g.translate(C(cx - r), C(y), C(cz - r));
  dome(g, r, drumH, key, 'tex:limestone', 'paint:PLASTER_IVORY');
  g.pop();
  // drum windows (oculi ring)
  const n = Math.max(8, Math.round((2 * Math.PI * r) / 300));
  for (let i = 0; i < n; i++) {
    const a = (i / n) * Math.PI * 2;
    g.push(); g.translate(C(cx + Math.sin(a) * (r + 5)), C(y + drumH * 0.5), C(cz + Math.cos(a) * (r + 5))); g.rotateY(a);
    boxC(g, 'glassFar', -40, -70, -0.5, 40, 70, 0.5, 16);
    boxC(g, 'tex:limestone', -52, -82, -2, 52, -70, 3); boxC(g, 'tex:limestone', -52, 70, -2, 52, 82, 3);
    g.pop();
  }
}

/** Coffered hemispherical ceiling seen from inside (rings of coffers). */
export function cofferedDome(g: GeoBuilder, cx: number, cz: number, r: number, y: number, key = 'paint:PLASTER_IVORY') {
  const rings = 7, seg = 24;
  for (let j = 0; j < rings; j++) for (let i = 0; i < seg; i++) {
    const a0 = (i / seg) * Math.PI * 2, a1 = ((i + 0.85) / seg) * Math.PI * 2;
    const e0 = (j / rings) * (Math.PI / 2) * 0.9, e1 = ((j + 0.8) / rings) * (Math.PI / 2) * 0.9;
    const P = (a: number, e: number, rr: number): V3 => [C(cx + Math.sin(a) * Math.cos(e) * rr), C(y + Math.sin(e) * rr), C(cz + Math.cos(a) * Math.cos(e) * rr)];
    // recessed coffer panel (inside surface faces the center)
    g.quad(key, P(a0, e0, r - 12), P(a0, e1, r - 12), P(a1, e1, r - 12), P(a1, e0, r - 12));
  }
  // ribs
  g.push(); g.translate(C(cx), C(y), C(cz));
  const prof: [number, number][] = [];
  for (let i = 16; i >= 0; i--) { const e = (i / 16) * (Math.PI / 2); prof.push([C((r - 20) * Math.cos(e)), C((r - 20) * Math.sin(e))]); }
  g.lathe('satin:TRIM_WHITE', prof, 48);
  g.pop();
  // oculus ring
  g.push(); g.translate(C(cx), C(y + r * 0.98), C(cz)); g.disc('emit:SUN_NOON', C(r * 0.12), 0, 24, false); g.pop();
}

/** Round wall (polygon) with door gaps [angle center, width cm]. Exterior key outside, interior inside. */
export function ringWall(g: GeoBuilder, cx: number, cz: number, r: number, y0: number, y1: number, t: number, outKey: string, inKey: string, gaps: [number, number][] = [], seg = 64) {
  for (let i = 0; i < seg; i++) {
    const a0 = (i / seg) * Math.PI * 2, a1 = ((i + 1) / seg) * Math.PI * 2, am = (a0 + a1) / 2;
    if (gaps.some(([ga, gw]) => Math.abs(angDiff(am, ga)) < gw / 2 / r)) continue;
    const P = (a: number, rr: number, y: number): V3 => [C(cx + Math.sin(a) * rr), C(y), C(cz + Math.cos(a) * rr)];
    g.quad(outKey, P(a0, r, y0), P(a1, r, y0), P(a1, r, y1), P(a0, r, y1).map((v) => v) as V3);
    g.quad(inKey, P(a1, r - t, y0), P(a0, r - t, y0), P(a0, r - t, y1), P(a1, r - t, y1));
    g.quad(outKey, P(a0, r - t, y1), P(a0, r, y1), P(a1, r, y1), P(a1, r - t, y1));
  }
}
export const angDiff = (a: number, b: number) => { let d = a - b; while (d > Math.PI) d -= 2 * Math.PI; while (d < -Math.PI) d += 2 * Math.PI; return d; };

/** Concentric stepped seating tiers (platforms only, CLAUDE.md §7) on an arc. */
export function arcTiers(g: GeoBuilder, cx: number, cz: number, r0: number, n: number, tierD: number, tierH: number, a0: number, a1: number, y: number, key = 'tex:concrete_new', aisles = 0) {
  const seg = Math.max(8, Math.ceil(((a1 - a0) * (r0 + n * tierD)) / 200));
  for (let k = 0; k < n; k++) {
    const ri = r0 + k * tierD, ro = ri + tierD, top = y + (k + 1) * tierH;
    for (let i = 0; i < seg; i++) {
      const b0 = a0 + ((a1 - a0) * i) / seg, b1 = a0 + ((a1 - a0) * (i + 1)) / seg;
      const P = (a: number, rr: number, yy: number): V3 => [C(cx + Math.sin(a) * rr), C(yy), C(cz + Math.cos(a) * rr)];
      g.quad(key, P(b0, ri, top), P(b0, ro, top), P(b1, ro, top), P(b1, ri, top));
      g.quad(key, P(b1, ri, top - tierH), P(b1, ri, top), P(b0, ri, top), P(b0, ri, top - tierH));
    }
  }
  void aisles;
}

export function mkG() { return new GeoBuilder(); }
