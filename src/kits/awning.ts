// Awning kit (CLAUDE.md §6): fabric shed (color param), fabric dome, metal canopy. Mounted on the wall
// face (z = 0) at their bottom-left; projection toward −z.
import type { GeoBuilder, V3 } from '../core/geo';
import { C, bar, boxC, registerKit } from './common';

/** Fabric shed awning: projection p, drop h (slope), 25 cm valance; optional stripes (2nd color). */
export function shedAwning(g: GeoBuilder, w: number, p = 120, h = 90, colorKey = 'paint:AWNING_HARBOR_BLUE', stripeKey?: string, valance = 25) {
  const P = (x: number, y: number, z: number): V3 => [C(x), C(y), C(z)];
  const stripes = stripeKey ? Math.max(2, Math.round(w / 30)) : 1;
  for (let i = 0; i < stripes; i++) {
    const x0 = (w * i) / stripes, x1 = (w * (i + 1)) / stripes;
    const k = stripeKey && i % 2 ? stripeKey : colorKey;
    g.quad(k, P(x0, h, 0), P(x1, h, 0), P(x1, valance, -p), P(x0, valance, -p));
    g.quad(k, P(x0, valance, -p), P(x1, valance, -p), P(x1, h, 0), P(x0, h, 0)); // underside
    // scalloped valance
    g.quad(k, P(x0, 0, -p), P(x0, valance, -p), P(x1, valance, -p), P(x1, 0, -p));
    g.quad(k, P(x1, 0, -p + 0.3), P(x1, valance, -p + 0.3), P(x0, valance, -p + 0.3), P(x0, 0, -p + 0.3));
  }
  // side cheeks
  for (const x of [0, w]) {
    if (x === 0) { g.tri(colorKey, P(x, valance, -p), P(x, h, 0), P(x, valance, 0)); g.tri(colorKey, P(x, valance, 0), P(x, h, 0), P(x, valance, -p)); }
    else { g.tri(colorKey, P(x, valance, 0), P(x, h, 0), P(x, valance, -p)); g.tri(colorKey, P(x, valance, -p), P(x, h, 0), P(x, valance, 0)); }
  }
  // iron frame
  const k = 'satin:IRON_BLACK';
  bar(g, k, [0, C(h), C(-2)], [C(w), C(h), C(-2)], C(2.5));
  bar(g, k, [0, C(valance), C(-p + 2)], [C(w), C(valance), C(-p + 2)], C(2.5));
  for (let x = 0; x <= w; x += Math.max(60, w / Math.max(1, Math.round(w / 150)))) bar(g, k, [C(Math.min(x, w)), C(h - 2), C(-2)], [C(Math.min(x, w)), C(valance + 2), C(-p + 2)], C(2.5));
}

/** Fabric dome (quarter-barrel) awning. */
export function domeAwning(g: GeoBuilder, w: number, p = 90, colorKey = 'paint:CINEMA_MAROON') {
  const seg = 12;
  const P = (x: number, a: number): V3 => [C(x), C(p * Math.sin(a) + 10), C(-p * Math.cos(a))];
  for (let i = 0; i < seg; i++) {
    const a0 = (Math.PI / 2) * (i / seg), a1 = (Math.PI / 2) * ((i + 1) / seg);
    g.quad(colorKey, P(0, a0), P(w, a0), P(w, a1), P(0, a1));
    g.quad(colorKey, P(0, a1), P(w, a1), P(w, a0), P(0, a0));
  }
  // end fans
  for (const x of [0, w]) for (let i = 0; i < seg; i++) {
    const a0 = (Math.PI / 2) * (i / seg), a1 = (Math.PI / 2) * ((i + 1) / seg);
    g.tri(colorKey, [C(x), C(10), 0], P(x, a0), P(x, a1));
    g.tri(colorKey, [C(x), C(10), 0], P(x, a1), P(x, a0));
  }
  boxC(g, colorKey, 0, 0, -p, w, 10, -p + 0.5);
}

/** Flat metal canopy with fascia and two tie rods back to the wall. */
export function metalCanopy(g: GeoBuilder, w: number, p = 150, key = 'satin:ALUMINUM_STOREFRONT') {
  boxC(g, key, 0, 0, -p, w, 25, 0);
  boxC(g, 'emit:LAMP_LED', 20, -0.2, -p + 20, w - 20, 0, -p + 30); // downlight strip
  for (const x of [w * 0.2, w * 0.8]) bar(g, 'metal:GALV_STEEL', [C(x), C(20), C(-p + 10)], [C(x), C(140), 0], C(2.5));
}

registerKit({ kit: 'Awning', name: 'fabric shed 360 striped', build: (g) => shedAwning(g, 360, 120, 90, 'paint:AWNING_HARBOR_BLUE', 'paint:MARKING_WHITE'), bbox: [-1.25, 0, -120, 361.25, 91.25, 0] });
registerKit({ kit: 'Awning', name: 'fabric dome 300', build: (g) => domeAwning(g, 300), bbox: [0, 0, -90, 300, 100, 0] });
registerKit({ kit: 'Awning', name: 'metal canopy 400', build: (g) => metalCanopy(g, 400), bbox: [0, -0.2, -150, 400, 141.25, 1.25] });
