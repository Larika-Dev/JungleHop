// Ornament & services (CLAUDE.md §5): quoins 30 x 20 alternating, keystones +1.5 cm, K-style gutters 13 cm,
// downspouts 7.6 x 10 cm with straps every 180 cm and splash blocks, utility clutter (≥4 per facade side):
// gas meter, electric meter, hose bib, conduit with straps, dryer vent, HVAC condenser with fins,
// security camera, fire department connection, address numerals.
import type { GeoBuilder } from '../core/geo';
import { Rng } from '../core/rng';
import { C, bar, boxC, registerKit } from './common';

/** Quoins up a corner: alternating 30 x 20 and 20 x 20 face blocks, projecting 2 cm (both faces). */
export function quoins(g: GeoBuilder, h: number, key = 'tex:limestone', block = 30) {
  let y = 0, i = 0;
  while (y + 20 <= h) {
    const long = i % 2 === 0 ? block : 20, short = i % 2 === 0 ? 20 : block;
    boxC(g, key, 0, y + 0.5, -2, long, y + 19.5, 0); // face A (z=0 plane)
    boxC(g, key, -2, y + 0.5, 0, 0, y + 19.5, short); // face B (x=0 plane)
    y += 20; i++;
  }
}

/** K-style gutter (13 cm) along +x with end caps. Mounted to fascia at z=0, hangs toward −z. */
export function gutter(g: GeoBuilder, L: number, key = 'metal:GALV_STEEL') {
  const P = (x: number, y: number, z: number): [number, number, number] => [C(x), C(y), C(z)];
  // K profile: back 9 high, bottom 9 deep, ogee front 13 high
  const prof: [number, number][] = [[0, 9], [0, 0], [-9, 0], [-11, 3], [-10, 6], [-12, 9], [-13, 13]];
  for (let i = 0; i < prof.length - 1; i++) {
    const [z0, y0] = prof[i], [z1, y1] = prof[i + 1];
    g.quad(key, P(0, y0, z0), P(L, y0, z0), P(L, y1, z1), P(0, y1, z1));
    g.quad(key, P(0, y1, z1), P(L, y1, z1), P(L, y0, z0), P(0, y0, z0));
  }
  for (const x of [0, L]) boxC(g, key, x - 0.1, 0, -13, x + 0.1, 9, 0);
}

/** Downspout 7.6 x 10 cm, height h, straps every 180 cm, elbow + concrete splash block. */
export function downspout(g: GeoBuilder, h: number, key = 'metal:GALV_STEEL') {
  boxC(g, key, 0, 25, -10, 7.6, h, 0);
  for (let y = 120; y < h; y += 180) boxC(g, key, -2, y, -10.6, 9.6, y + 3, 0);
  // elbow kicking out
  boxC(g, key, 0, 12, -32, 7.6, 25, -2);
  boxC(g, 'tex:concrete_aged', -10, 0, -92, 17.6, 6, -32); // splash block 60 cm
}

/** Gas meter with regulator & pipe. */
export function gasMeter(g: GeoBuilder) {
  const k = 'metal:GALV_STEEL';
  boxC(g, k, 0, 60, -25, 30, 95, 0);
  bar(g, k, [C(5), 0, C(-12)], [C(5), C(60), C(-12)], C(3.3));
  bar(g, k, [C(25), C(95), C(-12)], [C(25), C(120), C(-12)], C(3.3));
  bar(g, k, [C(25), C(120), C(-12)], [C(25), C(120), 0], C(3.3));
  g.cylinder('paint:MARKING_YELLOW', C(5), C(100), C(108), 10, true, C(25), C(-12));
}
/** Electric meter (socket + glass dome) with conduit to the eave. */
export function electricMeter(g: GeoBuilder, conduitTop = 300) {
  boxC(g, 'metal:GALV_STEEL', 0, 140, -14, 28, 182, 0);
  g.push(); g.translate(C(14), C(161), C(-14)); g.rotateX(-Math.PI / 2); g.lathe('glass', [[C(8), 0], [C(8), C(8)], [C(6), C(11)], [C(0.1), C(12)]], 16); g.pop();
  conduit(g, [14, 182, -6], conduitTop - 182);
}
/** Vertical EMT conduit with straps every 120 cm. */
export function conduit(g: GeoBuilder, at: [number, number, number], len: number) {
  bar(g, 'metal:GALV_STEEL', [C(at[0]), C(at[1]), C(at[2])], [C(at[0]), C(at[1] + len), C(at[2])], C(2.5));
  for (let y = 30; y < len; y += 120) boxC(g, 'metal:GALV_STEEL', at[0] - 2.5, at[1] + y, at[2] - 1.5, at[0] + 2.5, at[1] + y + 2, -0.2);
}
export function hoseBib(g: GeoBuilder) {
  bar(g, 'metal:BRASS', [0, C(50), 0], [0, C(50), C(-8)], C(2));
  bar(g, 'metal:BRASS', [0, C(50), C(-8)], [0, C(44), C(-9)], C(2));
  g.push(); g.translate(0, C(56), C(-6)); g.cylinder('metal:BRASS', C(3), 0, C(1), 8); g.pop();
}
export function dryerVent(g: GeoBuilder) {
  boxC(g, 'satin:TRIM_WHITE', 0, 0, -3, 15, 15, 0);
  const P = (x: number, y: number, z: number): [number, number, number] => [C(x), C(y), C(z)];
  g.quad('satin:TRIM_WHITE', P(2, 13, -3), P(13, 13, -3), P(13, 5, -9), P(2, 5, -9));
}
/** HVAC condenser 90 x 90 x 80 with fin coil faces and a top fan grille. */
export function hvacCondenser(g: GeoBuilder) {
  const k = 'satin:GALV_STEEL';
  boxC(g, 'tex:concrete_aged', -5, 0, -5, 95, 8, 95); // pad
  boxC(g, k, 0, 8, 0, 90, 12, 90); boxC(g, k, 0, 80, 0, 90, 88, 90);
  for (const [x, z] of [[0, 0], [86, 0], [0, 86], [86, 86]]) boxC(g, k, x, 12, z, x + 4, 80, z + 4);
  // fins: thin vertical plates every 1.5 cm on each face
  for (let i = 4; i < 86; i += 1.5) {
    boxC(g, 'metal:GALV_STEEL', i, 12, 1, i + 0.2, 80, 3); boxC(g, 'metal:GALV_STEEL', i, 12, 87, i + 0.2, 80, 89);
    boxC(g, 'metal:GALV_STEEL', 1, 12, i, 3, 80, i + 0.2); boxC(g, 'metal:GALV_STEEL', 87, 12, i, 89, 80, i + 0.2);
  }
  g.cylinder('satin:IRON_BLACK', C(35), C(88), C(89), 20, true, C(45), C(45));
  g.push(); g.translate(C(45), 0, C(45));
  for (let r = 10; r <= 34; r += 6) g.disc('metal:GALV_STEEL', C(r), C(89.5), 24, true, C(r - 0.6));
  g.pop();
}
export function securityCamera(g: GeoBuilder) {
  boxC(g, 'satin:TRIM_WHITE', 0, 0, -4, 8, 8, 0);
  bar(g, 'satin:TRIM_WHITE', [C(4), C(4), C(-4)], [C(4), C(2), C(-14)], C(2));
  g.push(); g.translate(C(4), C(0), C(-18)); g.rotateX(0.35); boxC(g, 'satin:TRIM_WHITE', -4, -4, -12, 4, 4, 6); boxC(g, 'paint:SHADOW_INK', -2.5, -2.5, -12.2, 2.5, 2.5, -12); g.pop();
}
/** Fire department connection: siamese inlet (two 6.5 cm caps) + sign plate. */
export function fdc(g: GeoBuilder) {
  boxC(g, 'metal:BRASS', 0, 70, -6, 40, 90, 0);
  for (const x of [8, 32]) { g.push(); g.translate(C(x), C(80), C(-6)); g.rotateX(-Math.PI / 2); g.cylinder('metal:BRASS', C(6.5), 0, C(10), 12); g.pop(); }
  boxC(g, 'paint:HYDRANT_RED', 5, 100, -1, 35, 120, 0);
}
/** Address numerals: cast brass digits 15 cm tall, 1.5 cm deep (block glyph approximation). */
export function addressNumerals(g: GeoBuilder, text: string, key = 'metal:BRASS') {
  const seg: Record<string, number[]> = { // 7-segment-ish strokes: a b c d e f g
    '0': [1, 1, 1, 1, 1, 1, 0], '1': [0, 1, 1, 0, 0, 0, 0], '2': [1, 1, 0, 1, 1, 0, 1], '3': [1, 1, 1, 1, 0, 0, 1], '4': [0, 1, 1, 0, 0, 1, 1],
    '5': [1, 0, 1, 1, 0, 1, 1], '6': [1, 0, 1, 1, 1, 1, 1], '7': [1, 1, 1, 0, 0, 0, 0], '8': [1, 1, 1, 1, 1, 1, 1], '9': [1, 1, 1, 1, 0, 1, 1],
  };
  [...text].forEach((ch, i) => {
    const s = seg[ch]; if (!s) return;
    const x = i * 11, w = 8, h = 15, t = 1.6;
    const R = (on: number, x0: number, y0: number, x1: number, y1: number) => on && boxC(g, key, x + x0, y0, -1.5 - 2.5, x + x1, y1, -2.5);
    R(s[0], 0, h - t, w, h); R(s[1], w - t, h / 2, w, h); R(s[2], w - t, 0, w, h / 2); R(s[3], 0, 0, w, t);
    R(s[4], 0, 0, t, h / 2); R(s[5], 0, h / 2, t, h); R(s[6], 0, h / 2 - t / 2, w, h / 2 + t / 2);
    boxC(g, key, x + w / 2 - 0.5, h / 2 - 0.5, -2.5, x + w / 2 + 0.5, h / 2 + 0.5, 0); // 2.5 cm standoff
  });
}

/** Scatter ≥ 4 utility items along a facade side of length L (cm), deterministic by seed. */
export function utilityClutter(g: GeoBuilder, L: number, seed: string, opts: { address?: string; commercial?: boolean; topY?: number } = {}) {
  const rng = new Rng(seed);
  const items = ['gas', 'elec', 'hose', 'dryer', 'cam', 'conduit'];
  if (opts.commercial) items.push('fdc', 'hvac');
  rng.shuffle(items);
  const n = Math.max(4, Math.min(items.length, Math.floor(L / 250) + 3));
  for (let i = 0; i < n; i++) {
    const x = 40 + ((L - 120) * (i + rng.next() * 0.6)) / n;
    g.push(); g.translate(C(x), 0, 0);
    switch (items[i % items.length]) {
      case 'gas': gasMeter(g); break;
      case 'elec': electricMeter(g, opts.topY ?? 300); break;
      case 'hose': hoseBib(g); break;
      case 'dryer': g.translate(0, C(40), 0); dryerVent(g); break;
      case 'cam': g.translate(0, C(300), 0); securityCamera(g); break;
      case 'conduit': conduit(g, [0, 20, -3], (opts.topY ?? 300) - 20); break;
      case 'fdc': fdc(g); break;
      case 'hvac': g.translate(0, 0, C(-110)); hvacCondenser(g); break;
    }
    g.pop();
  }
  if (opts.address) { g.push(); g.translate(C(L - 60), C(230), 0); addressNumerals(g, opts.address); g.pop(); }
  return n;
}

registerKit({ kit: 'Ornament', name: 'quoins h300', build: (g) => quoins(g, 300), bbox: [-2, 0.5, -2, 30, 299.5, 30] });
registerKit({ kit: 'Ornament', name: 'K-gutter 13 cm x 300', build: (g) => gutter(g, 300), bbox: [-0.1, 0, -13, 300.1, 13, 0] });
registerKit({ kit: 'Ornament', name: 'downspout 7.6x10 h600', build: (g) => downspout(g, 600), bbox: [-10, 0, -92, 17.6, 600, 0] });
registerKit({ kit: 'Services', name: 'gas meter', build: (g) => gasMeter(g), bbox: [0, 0, -25, 30, 121.65, 0] });
registerKit({ kit: 'Services', name: 'HVAC condenser 90', build: (g) => hvacCondenser(g), bbox: [-5, 0, -5, 95, 89.5, 95] });
registerKit({ kit: 'Services', name: 'fire dept connection', build: (g) => fdc(g), bbox: [0, 70, -16, 40, 120, 0] });
registerKit({ kit: 'Services', name: 'address numerals 1795', build: (g) => addressNumerals(g, '1795'), bbox: [3.5, 0, -4, 41, 15, 0] });
