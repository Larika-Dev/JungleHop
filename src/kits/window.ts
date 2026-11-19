// Window kit (CLAUDE.md §5/§6): 6/6, 9/9, 2/2 double-hung, arched fanlight, oculus, dormer, modern fixed,
// storefront bay, transom, basement hopper. Historic: muntins 2.2 cm, sash rails 5 cm, glass set back
// 10 cm from the brick face, stone sill projecting 4.5 cm. Modern: mullions 5 x 15 cm, glass set back 6 cm.
// Rough opening spans x∈[0,w], y∈[0,h]; wall face at z=0, wall interior toward +z.
import type { GeoBuilder } from '../core/geo';
import { C, boxC, registerKit } from './common';

export interface SashOpts {
  w: number; h: number; // rough opening (cm)
  cols: number; rows: number; // lights per sash (6/6 -> 3 x 2)
  glass?: string; frame?: string;
  setback?: number; // glass setback from face (cm), default 10
  sill?: 'stone' | 'none';
  lintel?: 'keystone' | 'flat' | 'none';
  shutters?: string | null; // e.g. 'satin:SHUTTER_GREEN'
  singleSash?: boolean;
}

/** Muntin grid in a pane area (cm coords), depth range z0..z1. */
function muntins(g: GeoBuilder, key: string, x0: number, y0: number, x1: number, y1: number, cols: number, rows: number, z0: number, z1: number, mw = 2.2) {
  for (let i = 1; i < cols; i++) { const x = x0 + ((x1 - x0) * i) / cols; boxC(g, key, x - mw / 2, y0, z0, x + mw / 2, y1, z1); }
  for (let j = 1; j < rows; j++) { const y = y0 + ((y1 - y0) * j) / rows; boxC(g, key, x0, y - mw / 2, z0, x1, y + mw / 2, z1); }
}

/** One sash: stiles/rails 5 cm, glass at zGlass. */
function sash(g: GeoBuilder, frame: string, glass: string, x0: number, y0: number, x1: number, y1: number, zGlass: number, cols: number, rows: number, meetTop: boolean, meetBottom: boolean) {
  const st = 5, rail = 5, mr = 3.5; // meeting rail 3.5 cm
  const zf = zGlass - 2, zb = zGlass + 2.5;
  const top = meetTop ? mr : rail, bot = meetBottom ? mr : rail * 1.4;
  boxC(g, frame, x0, y0, zf, x0 + st, y1, zb);
  boxC(g, frame, x1 - st, y0, zf, x1, y1, zb);
  boxC(g, frame, x0 + st, y1 - top, zf, x1 - st, y1, zb);
  boxC(g, frame, x0 + st, y0, zf, x1 - st, y0 + bot, zb);
  g.quad(glass, [C(x0 + st), C(y0 + bot), C(zGlass)], [C(x0 + st), C(y1 - top), C(zGlass)], [C(x1 - st), C(y1 - top), C(zGlass)], [C(x1 - st), C(y0 + bot), C(zGlass)]);
  muntins(g, frame, x0 + st, y0 + bot, x1 - st, y1 - top, cols, rows, zGlass - 1.1, zGlass + 1.1);
}

/** Double-hung (or single) sash window in a masonry opening. */
export function sashWindow(g: GeoBuilder, o: SashOpts) {
  const frame = o.frame ?? 'satin:TRIM_WHITE';
  const glass = o.glass ?? 'glass';
  const sb = o.setback ?? 10;
  const { w, h } = o;
  const fw = 5; // frame (jamb/head) member width
  // frame jambs/head/sill board (blind stop) inside the reveal
  boxC(g, frame, 0, 0, sb - 3, fw, h, sb + 9);
  boxC(g, frame, w - fw, 0, sb - 3, w, h, sb + 9);
  boxC(g, frame, fw, h - fw, sb - 3, w - fw, h, sb + 9);
  boxC(g, frame, fw, 0, sb - 3, w - fw, 3, sb + 9);
  // brick-mould trim on the face (2 cm proud of reveal? flush with face recessed 1 cm)
  const ix0 = fw, ix1 = w - fw, iy0 = 3, iy1 = h - fw;
  if (o.singleSash) sash(g, frame, glass, ix0, iy0, ix1, iy1, sb, o.cols, o.rows, false, false);
  else {
    const mid = (iy0 + iy1) / 2;
    sash(g, frame, glass, ix0, mid - 1.75, ix1, iy1, sb + 3, o.cols, o.rows, false, true); // upper sash (outer track behind)
    sash(g, frame, glass, ix0, iy0, ix1, mid + 1.75, sb, o.cols, o.rows, true, false); // lower sash (inner... front)
  }
  // stone sill projecting 4.5 cm, sloped top
  if ((o.sill ?? 'stone') === 'stone') {
    const k = 'tex:limestone';
    const P = (x: number, y: number, z: number): [number, number, number] => [C(x), C(y), C(z)];
    const x0 = -6, x1 = w + 6, zf = -4.5, zb = sb + 2;
    boxC(g, k, x0, -10, zf, x1, -1.5, zb, 1 | 2 | 8 | 16 | 32);
    g.quad(k, P(x0, -1.5, zf), P(x0, 0, zb), P(x1, 0, zb), P(x1, -1.5, zf)); // wash
    g.quad(k, P(x0, -10, zf), P(x0, -1.5, zf), P(x0, 0, zb), P(x0, -10, zb));
    g.quad(k, P(x1, -10, zb), P(x1, 0, zb), P(x1, -1.5, zf), P(x1, -10, zf));
  }
  if (o.lintel === 'keystone' || o.lintel === 'flat') {
    boxC(g, 'tex:limestone', -10, h, -0.5, w + 10, h + 22, 12);
    if (o.lintel === 'keystone') {
      // keystone projects 1.5 cm, tapered, 26 cm tall
      const P = (x: number, y: number, z: number): [number, number, number] => [C(x), C(y), C(z)];
      const k = 'tex:limestone', cx = w / 2;
      g.quad(k, P(cx - 7, h - 2, -2), P(cx - 10, h + 26, -2), P(cx + 10, h + 26, -2), P(cx + 7, h - 2, -2));
      boxC(g, k, cx - 7, h - 2, -2, cx + 7, h + 26, 0, 2 | 1 | 4 | 8);
    }
  }
  if (o.shutters) {
    // louvered shutters hinged open against the wall (each w/2 wide, full height)
    for (const side of [-1, 1]) {
      const x0 = side < 0 ? -w / 2 - 2 : w + 2, x1 = side < 0 ? -2 : w + w / 2 + 2;
      boxC(g, o.shutters, x0, 0, -4, x0 + 4, h, -1.5); boxC(g, o.shutters, x1 - 4, 0, -4, x1, h, -1.5);
      boxC(g, o.shutters, x0 + 4, 0, -4, x1 - 4, 6, -1.5); boxC(g, o.shutters, x0 + 4, h - 6, -4, x1 - 4, h, -1.5); boxC(g, o.shutters, x0 + 4, h / 2 - 3, -4, x1 - 4, h / 2 + 3, -1.5);
      for (let y = 8; y < h - 8; y += 4.5) {
        if (Math.abs(y - h / 2) < 5) continue;
        const P = (x: number, yy: number, z: number): [number, number, number] => [C(x), C(yy), C(z)];
        g.quad(o.shutters, P(x0 + 4, y, -3.5), P(x0 + 4, y + 3.5, -1.8), P(x1 - 4, y + 3.5, -1.8), P(x1 - 4, y, -3.5));
      }
      // shutter dogs (iron)
      boxC(g, 'metal:IRON_BLACK', side < 0 ? x0 - 3 : x1, h * 0.35, -3, side < 0 ? x0 : x1 + 3, h * 0.35 + 4, -1);
    }
  }
}

/** Semicircular fanlight of radius r (cm) with radial muntins, sitting on y=0. */
export function fanlight(g: GeoBuilder, r: number, glass = 'glass', frame = 'satin:TRIM_WHITE', spokes = 7) {
  const sb = 10;
  const seg = 24;
  g.push(); g.translate(C(r), 0, C(sb));
  // glass half disc
  for (let i = 0; i < seg; i++) {
    const a0 = Math.PI * (i / seg), a1 = Math.PI * ((i + 1) / seg);
    g.tri(glass, [0, 0, 0], [Math.cos(a0) * C(r - 5), Math.sin(a0) * C(r - 5), 0], [Math.cos(a1) * C(r - 5), Math.sin(a1) * C(r - 5), 0]);
  }
  // frame ring
  for (let i = 0; i < seg; i++) {
    const a0 = Math.PI * (i / seg), a1 = Math.PI * ((i + 1) / seg);
    const p = (a: number, rr: number, z: number): [number, number, number] => [Math.cos(a) * C(rr), Math.sin(a) * C(rr), C(z)];
    g.quad(frame, p(a0, r - 5, -3), p(a1, r - 5, -3), p(a1, r, -3), p(a0, r, -3));
    g.quad(frame, p(a1, r - 5, -3), p(a0, r - 5, -3), p(a0, r - 5, 4), p(a1, r - 5, 4));
  }
  boxC(g, frame, -r, 0, -3, r, 4, 4);
  for (let i = 1; i < spokes; i++) {
    const a = Math.PI * (i / spokes);
    g.push(); g.rotateZ(a - Math.PI / 2);
    boxC(g, frame, -1.1, 8, -1.1, 1.1, r - 4, 1.1);
    g.pop();
  }
  // hub
  boxC(g, frame, -8, 0, -1.1, 8, 8, 1.1);
  g.pop();
}

/** Round oculus window, diameter d (cm), 4 muntins, stone surround 12 cm. */
export function oculus(g: GeoBuilder, d: number, glass = 'glass', frame = 'satin:TRIM_WHITE') {
  const r = d / 2, seg = 28, sb = 10;
  g.push(); g.translate(C(r), C(r), 0);
  for (let i = 0; i < seg; i++) {
    const a0 = (2 * Math.PI * i) / seg, a1 = (2 * Math.PI * (i + 1)) / seg;
    const p = (a: number, rr: number, z: number): [number, number, number] => [Math.cos(a) * C(rr), Math.sin(a) * C(rr), C(z)];
    g.tri(glass, [0, 0, C(sb)], p(a1, r - 4, sb), p(a0, r - 4, sb));
    g.quad(frame, p(a0, r - 4, sb - 3), p(a1, r - 4, sb - 3), p(a1, r, sb - 3), p(a0, r, sb - 3));
    g.quad('tex:limestone', p(a0, r, -1), p(a1, r, -1), p(a1, r + 12, -1), p(a0, r + 12, -1));
    g.quad('tex:limestone', p(a1, r, -1), p(a0, r, -1), p(a0, r, sb), p(a1, r, sb));
  }
  boxC(g, frame, -1.1, -r + 4, sb - 1.1, 1.1, r - 4, sb + 1.1);
  boxC(g, frame, -r + 4, -1.1, sb - 1.1, r - 4, 1.1, sb + 1.1);
  g.pop();
}

/** Dormer: 6/6 window w x h in a gabled box projecting `depth` from a roof (built at its own base). */
export function dormer(g: GeoBuilder, w: number, h: number, depth: number, roofKey = 'tex:slate', glass = 'glass') {
  const W = w + 30, H = h + 25;
  // cheek walls (painted trim boards) + front face
  boxC(g, 'satin:TRIM_WHITE', 0, 0, 0, 8, H, depth);
  boxC(g, 'satin:TRIM_WHITE', W - 8, 0, 0, W, H, depth);
  boxC(g, 'satin:TRIM_WHITE', 8, 0, 0, W - 8, 15, 3);
  boxC(g, 'satin:TRIM_WHITE', 8, H - 10, 0, W - 8, H, 3);
  g.push(); g.translate(C(15), C(15), 0);
  sashWindow(g, { w, h: H - 25, cols: 3, rows: 2, glass, sill: 'none', setback: 6 });
  g.pop();
  // gable roof, pitch 45°, overhang 8 cm front
  const P = (x: number, y: number, z: number): [number, number, number] => [C(x), C(y), C(z)];
  const ridge = H + W / 2;
  g.quad(roofKey, P(-6, H - 4, -8), P(W / 2, ridge, -8), P(W / 2, ridge, depth), P(-6, H - 4, depth));
  g.quad(roofKey, P(W + 6, H - 4, depth), P(W / 2, ridge, depth), P(W / 2, ridge, -8), P(W + 6, H - 4, -8));
  g.quad('satin:TRIM_WHITE', P(0, H, 0), P(W, H, 0), P(W / 2, ridge - 4, 0), P(W / 2, ridge - 4, 0));
  g.tri('satin:TRIM_WHITE', P(0, H, 0.5), P(W, H, 0.5), P(W / 2, ridge - 4, 0.5));
}
export const dormerBox = (w: number, h: number, depth: number): [number, number, number, number, number, number] => [-6, 0, -8, w + 36, h + 25 + (w + 30) / 2, depth];

/** Modern fixed window: ALUMINUM_STOREFRONT mullions 5 x 15 cm, glass set back 6 cm, `cols` lites. */
export function modernFixed(g: GeoBuilder, w: number, h: number, cols = 1, rows = 1, glass = 'glass', key = 'metal:ALUMINUM_STOREFRONT') {
  const sb = 6, mw = 5, md = 15;
  boxC(g, key, 0, 0, sb - 5, mw, h, sb - 5 + md);
  boxC(g, key, w - mw, 0, sb - 5, w, h, sb - 5 + md);
  boxC(g, key, mw, 0, sb - 5, w - mw, mw, sb - 5 + md);
  boxC(g, key, mw, h - mw, sb - 5, w - mw, h, sb - 5 + md);
  for (let i = 1; i < cols; i++) { const x = (w * i) / cols; boxC(g, key, x - mw / 2, mw, sb - 5, x + mw / 2, h - mw, sb - 5 + md); }
  for (let j = 1; j < rows; j++) { const y = (h * j) / rows; boxC(g, key, mw, y - mw / 2, sb - 5, w - mw, y + mw / 2, sb - 5 + md); }
  g.quad(glass, [C(mw), C(mw), C(sb)], [C(mw), C(h - mw), C(sb)], [C(w - mw), C(h - mw), C(sb)], [C(w - mw), C(mw), C(sb)]);
  // metal sill flashing
  boxC(g, key, -2, -3, -3, w + 2, 0, sb + 2);
}

/** Storefront bay: glass to 270 cm above a bulkhead, transom band above (see storefront kit). */
export function storefrontBay(g: GeoBuilder, w: number, bulk = 40, glassTop = 270, transom = 55, glass = 'glassShop', key = 'metal:ALUMINUM_STOREFRONT', bulkKey = 'satin:ALUMINUM_STOREFRONT') {
  boxC(g, bulkKey, 0, 0, 0, w, bulk, 15);
  g.push(); g.translate(0, C(bulk), 0);
  modernFixed(g, w, glassTop - bulk, Math.max(1, Math.round(w / 180)), 1, glass, key);
  g.pop();
  g.push(); g.translate(0, C(glassTop), 0);
  modernFixed(g, w, transom, Math.max(2, Math.round(w / 60)), 1, glass, key);
  g.pop();
}

/** Transom: horizontal multi-light window over a door (cm). */
export function transom(g: GeoBuilder, w: number, h: number, lights = 3, glass = 'glass', frame = 'satin:TRIM_WHITE') {
  boxC(g, frame, 0, 0, 7, w, 5, 18);
  boxC(g, frame, 0, h - 5, 7, w, h, 18);
  boxC(g, frame, 0, 5, 7, 5, h - 5, 18);
  boxC(g, frame, w - 5, 5, 7, w, h - 5, 18);
  g.quad(glass, [C(5), C(5), C(10)], [C(5), C(h - 5), C(10)], [C(w - 5), C(h - 5), C(10)], [C(w - 5), C(5), C(10)]);
  muntins(g, frame, 5, 5, w - 5, h - 5, lights, 1, 8.9, 11.1);
}

/** Basement hopper: steel-framed, hinged at the bottom, tipped in 15° (window-well style). */
export function basementHopper(g: GeoBuilder, w = 81, h = 46, glass = 'glass') {
  const k = 'paint:STEEL_DOOR_GRAY';
  boxC(g, k, 0, 0, 6, w, 4, 14); boxC(g, k, 0, h - 4, 6, w, h, 14);
  boxC(g, k, 0, 4, 6, 4, h - 4, 14); boxC(g, k, w - 4, 4, 6, w, h - 4, 14);
  g.push(); g.translate(C(4), C(4), C(10)); g.rotateX((15 * Math.PI) / 180);
  boxC(g, k, 0, 0, -1.5, w - 8, 3, 1.5); boxC(g, k, 0, h - 11, -1.5, w - 8, h - 8, 1.5);
  boxC(g, k, 0, 3, -1.5, 3, h - 11, 1.5); boxC(g, k, w - 11, 3, -1.5, w - 8, h - 11, 1.5);
  g.quad(glass, [C(3), C(3), 0], [C(3), C(h - 11), 0], [C(w - 11), C(h - 11), 0], [C(w - 11), C(3), 0]);
  g.pop();
  // steel security bars
  for (let x = 12; x < w - 6; x += 12) boxC(g, 'metal:IRON_BLACK', x - 0.8, 0, 2, x + 0.8, h, 3.6);
}

registerKit({ kit: 'Window', name: '6/6 double-hung 91x183', build: (g) => sashWindow(g, { w: 91, h: 183, cols: 3, rows: 2 }), bbox: [-6, -10, -4.5, 97, 183, 19] });
registerKit({ kit: 'Window', name: '9/9 double-hung 107x213', build: (g) => sashWindow(g, { w: 107, h: 213, cols: 3, rows: 3, lintel: 'keystone' }), bbox: [-10, -10, -4.5, 117, 239, 19] });
registerKit({ kit: 'Window', name: '2/2 double-hung 81x168', build: (g) => sashWindow(g, { w: 81, h: 168, cols: 2, rows: 1, sill: 'none' }), bbox: [0, 0, 7, 81, 168, 19] });
registerKit({ kit: 'Window', name: '6/6 with shutters', build: (g) => sashWindow(g, { w: 91, h: 183, cols: 3, rows: 2, shutters: 'satin:SHUTTER_GREEN' }), bbox: [-50.5, -10, -4.5, 141.5, 183, 19] });
registerKit({ kit: 'Window', name: 'arched fanlight r60', build: (g) => fanlight(g, 60), bbox: [0, 0, 7, 120, 60, 14] });
registerKit({ kit: 'Window', name: 'oculus d90', build: (g) => oculus(g, 90), bbox: [-12, -12, -1, 102, 102, 11.1] });
registerKit({ kit: 'Window', name: 'dormer 76x120 d150', build: (g) => dormer(g, 76, 120, 150), bbox: dormerBox(76, 120, 150) });
registerKit({ kit: 'Window', name: 'modern fixed 180x200 2-lite', build: (g) => modernFixed(g, 180, 200, 2), bbox: [-2, -3, -3, 182, 200, 16] });
registerKit({ kit: 'Window', name: 'storefront bay 360', build: (g) => storefrontBay(g, 360), bbox: [-2, 0, -3, 362, 325, 16] });
registerKit({ kit: 'Window', name: 'transom 107x45', build: (g) => transom(g, 107, 45), bbox: [0, 0, 7, 107, 45, 18] });
registerKit({ kit: 'Window', name: 'basement hopper 81x46', build: (g) => basementHopper(g), bbox: [0, 0, 2, 81, 46, 21.28], note: 'sash tipped in 15°' });
