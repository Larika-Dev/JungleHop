// Roof kit (CLAUDE.md §6): gable, hip, gambrel, flat with parapet, dome (radius param), cupola, belfry.
// Footprint w (along x) x d (along z) in cm at eave height y=0; overhang `oh`. Pitched roofs are
// 22 cm-thick slabs (slate/shingle on top, sheathing boards beneath — visible from attics).
import type { GeoBuilder, V3 } from '../core/geo';
import { C, boxC, registerKit } from './common';
import { parapetCoping } from './cornice';

export interface RoofKeys { top: string; under?: string; trim?: string; }
const DEF: RoofKeys = { top: 'tex:slate', under: 'tex:heart_pine', trim: 'satin:TRIM_WHITE' };
const SLAB = 22;

/** A sloped slab between 4 corner points (cm) with thickness downwards. */
function slab(g: GeoBuilder, k: RoofKeys, a: V3, b: V3, c: V3, d: V3, thick = SLAB) {
  const P = (p: V3, dy = 0): V3 => [C(p[0]), C(p[1] + dy), C(p[2])];
  g.quad(k.top, P(a), P(b), P(c), P(d));
  g.quad(k.under ?? k.top, P(d, -thick), P(c, -thick), P(b, -thick), P(a, -thick));
  // fascia on the eave edge (a-b assumed eave)
  g.quad(k.trim ?? k.top, P(b, -thick), P(a, -thick), P(a), P(b));
}
function tri(g: GeoBuilder, k: RoofKeys, a: V3, b: V3, c: V3, thick = SLAB) {
  const P = (p: V3, dy = 0): V3 => [C(p[0]), C(p[1] + dy), C(p[2])];
  g.tri(k.top, P(a), P(b), P(c));
  g.tri(k.under ?? k.top, P(c, -thick), P(b, -thick), P(a, -thick));
  g.quad(k.trim ?? k.top, P(b, -thick), P(a, -thick), P(a), P(b));
}

/** Gable: ridge along x. pitch in degrees. Returns ridge height (cm above eave). */
export function gableRoof(g: GeoBuilder, w: number, d: number, pitch = 40, oh = 30, k: RoofKeys = DEF, gableKey?: string): number {
  const rise = (d / 2) * Math.tan((pitch * Math.PI) / 180);
  const drop = oh * Math.tan((pitch * Math.PI) / 180);
  const x0 = -oh * 0.5, x1 = w + oh * 0.5;
  slab(g, k, [x1, -drop, -oh], [x0, -drop, -oh], [x0, rise, d / 2], [x1, rise, d / 2]);
  slab(g, k, [x0, -drop, d + oh], [x1, -drop, d + oh], [x1, rise, d / 2], [x0, rise, d / 2]);
  // ridge cap
  boxC(g, 'metal:COPPER_PATINA', x0, rise - 2, d / 2 - 8, x1, rise + 4, d / 2 + 8);
  if (gableKey) {
    // gable-end infill walls (triangles)
    for (const x of [0, w]) {
      const P = (y: number, z: number): V3 => [C(x), C(y), C(z)];
      if (x === 0) g.tri(gableKey, P(0, 0), P(0, d), P(rise - SLAB, d / 2)); else g.tri(gableKey, P(0, d), P(0, 0), P(rise - SLAB, d / 2));
    }
  }
  return rise;
}

/** Hip: four slopes, ridge along x (w ≥ d). */
export function hipRoof(g: GeoBuilder, w: number, d: number, pitch = 35, oh = 30, k: RoofKeys = DEF): number {
  const t = Math.tan((pitch * Math.PI) / 180);
  const rise = (d / 2) * t, drop = oh * t;
  const r0 = Math.min(w / 2, d / 2), r1 = Math.max(w / 2, w - d / 2);
  const E = (x: number, z: number): V3 => [x, -drop, z];
  slab(g, k, E(w + oh, -oh), E(-oh, -oh), [r0, rise, d / 2], [r1, rise, d / 2]);
  slab(g, k, E(-oh, d + oh), E(w + oh, d + oh), [r1, rise, d / 2], [r0, rise, d / 2]);
  tri(g, k, E(-oh, -oh), E(-oh, d + oh), [r0, rise, d / 2]);
  tri(g, k, E(w + oh, d + oh), E(w + oh, -oh), [r1, rise, d / 2]);
  if (r1 > r0) boxC(g, 'metal:COPPER_PATINA', r0, rise - 2, d / 2 - 8, r1, rise + 4, d / 2 + 8);
  return rise;
}

/** Gambrel: lower slopes 60°, upper 25° (barn / Dutch colonial), ridge along x. */
export function gambrelRoof(g: GeoBuilder, w: number, d: number, oh = 25, k: RoofKeys = { top: 'tex:shingle', under: 'tex:heart_pine', trim: 'satin:TRIM_WHITE' }, gableKey?: string): number {
  const kneeIn = d * 0.22, kneeY = kneeIn * Math.tan((60 * Math.PI) / 180);
  const rise = kneeY + (d / 2 - kneeIn) * Math.tan((25 * Math.PI) / 180);
  const x0 = -oh * 0.5, x1 = w + oh * 0.5;
  const drop = oh * Math.tan((60 * Math.PI) / 180);
  slab(g, k, [x1, -drop, -oh], [x0, -drop, -oh], [x0, kneeY, kneeIn], [x1, kneeY, kneeIn]);
  slab(g, k, [x1, kneeY, kneeIn], [x0, kneeY, kneeIn], [x0, rise, d / 2], [x1, rise, d / 2]);
  slab(g, k, [x0, -drop, d + oh], [x1, -drop, d + oh], [x1, kneeY, d - kneeIn], [x0, kneeY, d - kneeIn]);
  slab(g, k, [x0, kneeY, d - kneeIn], [x1, kneeY, d - kneeIn], [x1, rise, d / 2], [x0, rise, d / 2]);
  if (gableKey) for (const x of [0, w]) {
    const pts: V3[] = [[x, 0, 0], [x, kneeY - SLAB, kneeIn], [x, rise - SLAB, d / 2], [x, kneeY - SLAB, d - kneeIn], [x, 0, d]];
    for (let i = 1; i < pts.length - 1; i++) {
      const P = (p: V3): V3 => [C(p[0]), C(p[1]), C(p[2])];
      if (x === 0) g.tri(gableKey, P(pts[0]), P(pts[i + 1]), P(pts[i])); else g.tri(gableKey, P(pts[0]), P(pts[i]), P(pts[i + 1]));
    }
  }
  return rise;
}

/** Flat roof (TPO) with brick parapet h (cm), thickness t, metal coping. */
export function flatRoof(g: GeoBuilder, w: number, d: number, parapet = 90, t = 30, wallKey = 'brick:running:BRICK_DOWNTOWN_A', membrane = 'tex:tpo') {
  boxC(g, membrane, t, -2, t, w - t, 0, d - t, 4);
  // parapet walls (outer face brick, inner face too)
  boxC(g, wallKey, 0, 0, 0, w, parapet, t);
  boxC(g, wallKey, 0, 0, d - t, w, parapet, d);
  boxC(g, wallKey, 0, 0, t, t, parapet, d - t);
  boxC(g, wallKey, w - t, 0, t, w, parapet, d - t);
  // copings
  g.push(); g.translate(0, C(parapet), 0); parapetCoping(g, w, t); g.pop();
  g.push(); g.translate(C(w), C(parapet), C(d)); g.rotateY(Math.PI); parapetCoping(g, w, t); g.pop();
  g.push(); g.translate(0, C(parapet), C(d)); g.rotateY(Math.PI / 2); parapetCoping(g, d, t); g.pop();
  g.push(); g.translate(C(w), C(parapet), 0); g.rotateY(-Math.PI / 2); parapetCoping(g, d, t); g.pop();
}

/** Dome of radius r (cm) on a drum of height drumH; COPPER_PATINA, with lantern finial. Centered at (r, ?, r). */
export function dome(g: GeoBuilder, r: number, drumH = 0, key = 'tex:patina', drumKey = 'tex:limestone', inner = 'paint:PLASTER_IVORY', seg = 40) {
  g.push(); g.translate(C(r), 0, C(r));
  if (drumH > 0) {
    g.lathe(drumKey, [[C(r + 4), 0], [C(r + 4), C(drumH)]], seg);
    g.lathe(drumKey, [[C(r + 10), C(drumH)], [C(r + 10), C(drumH + 12)], [C(r), C(drumH + 12)]], seg);
  }
  const prof: [number, number][] = [];
  for (let i = 0; i <= 16; i++) { const a = (i / 16) * (Math.PI / 2); prof.push([C(r * Math.cos(a)), C(drumH + 12 * (drumH > 0 ? 1 : 0) + r * Math.sin(a))]); }
  g.lathe(key, prof, seg);
  // inner shell (seen from inside rotunda), reversed winding via negative profile direction
  const innerProf = prof.map(([pr, py]) => [Math.max(0.001, pr - C(25)), py - C(10)] as [number, number]).reverse();
  g.lathe(inner, innerProf, seg);
  // finial
  const top = drumH + (drumH > 0 ? 12 : 0) + r;
  g.lathe('metal:BRASS', [[C(8), C(top - 2)], [C(5), C(top + 10)], [C(9), C(top + 22)], [C(4), C(top + 34)], [C(0.5), C(top + 60)]], 12);
  g.pop();
}

/** Cupola: octagonal base w (cm) with louvers, copper ogee roof and finial. */
export function cupola(g: GeoBuilder, w = 200, h = 260, key = 'satin:TRIM_WHITE') {
  const r = w / 2 / Math.cos(Math.PI / 8);
  g.push(); g.translate(C(w / 2), 0, C(w / 2)); g.rotateY(Math.PI / 8);
  g.lathe(key, [[C(r), 0], [C(r), C(40)], [C(r - 6), C(40)]], 8, 0, Math.PI * 2, false);
  const body = h * 0.45;
  // posts and louvers on 8 faces
  for (let i = 0; i < 8; i++) {
    g.push(); g.rotateY((i / 8) * Math.PI * 2 + Math.PI / 8);
    const fw = 2 * (r - 6) * Math.sin(Math.PI / 8);
    const zf = (r - 6) * Math.cos(Math.PI / 8);
    for (let y = 50; y < 40 + body - 10; y += 6) g.box(key, -C(fw / 2 - 8), C(y), C(zf - 3), C(fw / 2 - 8), C(y + 3), C(zf));
    g.box(key, -C(fw / 2), C(40), C(zf - 6), -C(fw / 2 - 8), C(40 + body), C(zf + 1));
    g.box('satin:IRON_BLACK', -C(fw / 2 - 8), C(45), C(zf - 6), C(fw / 2 - 8), C(40 + body - 5), C(zf - 5));
    g.pop();
  }
  g.lathe(key, [[C(r + 8), C(40 + body)], [C(r + 8), C(52 + body)], [C(r), C(52 + body)]], 8, 0, Math.PI * 2, false);
  // ogee roof
  const rb = r + 4, y0 = 52 + body, hh = h - y0 - 25;
  const prof: [number, number][] = [];
  for (let i = 0; i <= 10; i++) { const t = i / 10; const s = t < 0.5 ? 2 * t * t : 1 - 2 * (1 - t) ** 2; prof.push([C(rb * (1 - s) + 1), C(y0 + hh * t)]); }
  g.lathe('tex:patina', prof, 8, 0, Math.PI * 2, false);
  g.lathe('metal:BRASS', [[C(6), C(h - 25)], [C(3), C(h - 10)], [C(7), C(h - 5)], [C(0.5), C(h)]], 10);
  g.pop();
}

/** Open belfry: square w with four arched openings per face, copper pyramidal roof. */
export function belfry(g: GeoBuilder, w = 600, h = 700, wallKey = 'brick:flemish:BRICK_CAMPUS_A', trim = 'tex:limestone') {
  const t = 45, open = w * 0.34, oh = h * 0.6;
  for (let side = 0; side < 4; side++) {
    g.push(); g.translate(C(w / 2), 0, C(w / 2)); g.rotateY((side * Math.PI) / 2); g.translate(C(-w / 2), 0, C(-w / 2));
    // pier segments around one arched opening centered on the face
    const ox = (w - open) / 2;
    boxC(g, wallKey, 0, 0, 0, ox, h, t);
    boxC(g, wallKey, ox + open, 0, 0, w, h, t);
    boxC(g, wallKey, ox, oh + open / 2, 0, ox + open, h, t);
    boxC(g, trim, ox, 0, 0, ox + open, 110, t + 0.5); // sill wall / parapet
    // louvers in the opening
    for (let y = 120; y < oh; y += 22) {
      const P = (x: number, yy: number, z: number): V3 => [C(x), C(yy), C(z)];
      g.quad('paint:COPPER_PATINA', P(ox, y, t * 0.3), P(ox, y + 14, t * 0.7), P(ox + open, y + 14, t * 0.7), P(ox + open, y, t * 0.3));
    }
    // semicircular arch head (voussoirs in limestone)
    for (let i = 0; i < 12; i++) {
      const a0 = Math.PI * (i / 12), a1 = Math.PI * ((i + 1) / 12);
      const cx = ox + open / 2, cy = oh, rr = open / 2;
      const P = (a: number, r: number, z: number): V3 => [C(cx + Math.cos(a) * r), C(cy + Math.sin(a) * r), C(z)];
      g.quad(trim, P(a0, rr, -1), P(a1, rr, -1), P(a1, rr + 25, -1), P(a0, rr + 25, -1));
      g.quad(wallKey, P(a1, rr, -1), P(a0, rr, -1), P(a0, rr, t), P(a1, rr, t));
      g.quad(wallKey, P(a0, rr + 25, -0.5), P(a1, rr + 25, -0.5), P(a1, open, -0.5), P(a0, open, -0.5));
    }
    g.pop();
  }
  // corner limestone quoins
  for (const [x, z] of [[0, 0], [w - 30, 0], [0, w - 30], [w - 30, w - 30]]) for (let y = 0; y < h; y += 60) boxC(g, trim, x - 1.5, y, z - 1.5, x + 31.5, y + 30, z + 31.5);
  boxC(g, trim, -20, h, -20, w + 20, h + 30, w + 20); // cornice band
  // pyramidal copper roof
  const P = (x: number, y: number, z: number): V3 => [C(x), C(y), C(z)];
  const top = h + 30 + w * 0.9;
  const k = 'tex:patina';
  g.tri(k, P(-20, h + 30, -20), P(w / 2, top, w / 2), P(w + 20, h + 30, -20));
  g.tri(k, P(w + 20, h + 30, -20), P(w / 2, top, w / 2), P(w + 20, h + 30, w + 20));
  g.tri(k, P(w + 20, h + 30, w + 20), P(w / 2, top, w / 2), P(-20, h + 30, w + 20));
  g.tri(k, P(-20, h + 30, w + 20), P(w / 2, top, w / 2), P(-20, h + 30, -20));
  g.cylinder('metal:BRASS', C(3), C(top), C(top + 150), 8, true, C(w / 2), C(w / 2));
}

registerKit({ kit: 'Roof', name: 'gable 800x600 40°', build: (g) => { gableRoof(g, 800, 600, 40, 30); }, bbox: [-15, -25.17 - 22, -30, 815, 251.73 + 4, 630] });
registerKit({ kit: 'Roof', name: 'hip 1000x600 35°', build: (g) => { hipRoof(g, 1000, 600, 35, 30); }, bbox: [-30, -21.01 - 22, -30, 1030, 210.06 + 4, 630] });
registerKit({ kit: 'Roof', name: 'gambrel 700x600', build: (g) => { gambrelRoof(g, 700, 600); }, bbox: [-12.5, -43.3 - 22, -25, 712.5, 306.97, 625] });
registerKit({ kit: 'Roof', name: 'flat + parapet 800x600', build: (g) => flatRoof(g, 800, 600), bbox: [-2.5, 0, -2.5, 802.5, 91.5, 602.5] });
registerKit({ kit: 'Roof', name: 'dome r400 drum 200', build: (g) => dome(g, 400, 200), bbox: [-10, 0, -10, 810, 672, 810] });
registerKit({ kit: 'Roof', name: 'cupola 200x260', build: (g) => cupola(g), bbox: [-7.39, 0, -7.39, 207.39, 260, 207.39], note: 'octagon' });
registerKit({ kit: 'Roof', name: 'belfry 600x700', build: (g) => belfry(g), bbox: [-20, 0, -20, 620, 1420, 620] });
