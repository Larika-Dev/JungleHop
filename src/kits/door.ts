// Door kit (CLAUDE.md §5/§6): colonial 6-panel, double colonial with fanlight, storefront glass, service
// steel, garage roll-up, interior panel, interior glass. Exterior 91 x 213 (double 183 x 213, historic
// 107 x 244), 1.5 cm panel recess, frame 11 cm, 1.2 cm threshold, 25 cm kick plate, BRASS hardware with
// BRASS_WORN wear. Interior: 91 x 213, 4.5 cm leaf, casing 9 cm with 2 cm relief.
// LEAVES are built hinge-at-origin (x: 0..w, y: 0..h, z: ±t/2) for the instanced DoorSystem.
import { GeoBuilder } from '../core/geo';
import { C, boxC, registerKit } from './common';
import { fanlight } from './window';

export const DOOR: Record<"w" | "h" | "t" | "dw" | "hw" | "hh" | "frame" | "threshold" | "kick" | "casing", number> = { w: 91, h: 213, t: 4.5, dw: 183, hw: 107, hh: 244, frame: 11, threshold: 1.2, kick: 25, casing: 9 };

function hinges(g: GeoBuilder, h: number, t: number, key = 'metal:BRASS') {
  for (const y of [23, h / 2, h - 28]) boxC(g, key, -0.6, y, -t / 2 - 0.2, 0.4, y + 10, t / 2 + 0.2);
}
function lever(g: GeoBuilder, w: number, t: number, worn: boolean) {
  for (const side of [-1, 1]) {
    const z0 = side < 0 ? -t / 2 : t / 2;
    // rose + lever (worn on the grip)
    g.push(); g.translate(C(w - 7), C(96), C(z0)); g.rotateX(side * Math.PI / 2);
    g.cylinder('metal:BRASS', C(3.2), 0, C(1.2), 12, true);
    g.cylinder('metal:BRASS', C(1.1), C(1.2), C(5.5), 8, true);
    g.pop();
    boxC(g, worn ? 'metal:BRASS_WORN' : 'metal:BRASS', w - 7 - 12, 95, side < 0 ? z0 - 6.5 : z0 + 4.5, w - 7 + 1, 97.2, side < 0 ? z0 - 4.5 : z0 + 6.5);
  }
}

/** Raised-panel leaf: stiles/rails proud, panels recessed 1.5 cm on both faces. layout = rows of panel heights (cm). */
function panelLeaf(g: GeoBuilder, w: number, h: number, t: number, key: string, cols: number, rows: number[], glassRows: number[] = [], glass = 'glass') {
  const stile = 11.4, rail = 11.4, bottom = 25, recess = 1.5;
  boxC(g, key, 0, 0, -t / 2 + recess, w, h, t / 2 - recess); // core
  // frame members, full thickness
  boxC(g, key, 0, 0, -t / 2, stile, h, t / 2);
  boxC(g, key, w - stile, 0, -t / 2, w, h, t / 2);
  boxC(g, key, stile, 0, -t / 2, w - stile, bottom, t / 2);
  boxC(g, key, stile, h - rail, -t / 2, w - stile, h, t / 2);
  const inner = h - rail - bottom - rail * (rows.length - 1);
  const total = rows.reduce((a, b) => a + b, 0);
  let y = bottom;
  rows.forEach((rh, i) => {
    const ph = (rh / total) * inner;
    if (i > 0) boxC(g, key, stile, y - rail, -t / 2, w - stile, y, t / 2);
    // muntin (center stile) between panel columns
    for (let c = 1; c < cols; c++) { const x = stile + ((w - 2 * stile) * c) / cols; boxC(g, key, x - 5, y, -t / 2, x + 5, y + ph, t / 2); }
    if (glassRows.includes(i)) {
      for (let c = 0; c < cols; c++) {
        const x0 = stile + ((w - 2 * stile) * c) / cols + (c ? 5 : 0), x1 = stile + ((w - 2 * stile) * (c + 1)) / cols - (c < cols - 1 ? 5 : 0);
        g.quad(glass, [C(x0), C(y), 0], [C(x0), C(y + ph), 0], [C(x1), C(y + ph), 0], [C(x1), C(y), 0]);
      }
    } else {
      // raised field (bevelled): a thin raised slab inside each panel
      for (let c = 0; c < cols; c++) {
        const x0 = stile + ((w - 2 * stile) * c) / cols + (c ? 5 : 0) + 4, x1 = stile + ((w - 2 * stile) * (c + 1)) / cols - (c < cols - 1 ? 5 : 0) - 4;
        boxC(g, key, x0, y + 4, -t / 2 + 0.6, x1, y + ph - 4, t / 2 - 0.6);
      }
    }
    y += ph + rail;
  });
}

/** Exterior colonial 6-panel leaf with kick plate, lever, hinges. */
export function colonialLeaf(w = DOOR.w, h = DOOR.h, key = 'satin:DOOR_RED'): GeoBuilder {
  const g = new GeoBuilder();
  const t = DOOR.t;
  panelLeaf(g, w, h, t, key, 2, [36, 40, 18]);
  boxC(g, 'metal:BRASS', 1, 0.5, -t / 2 - 0.15, w - 1, DOOR.kick, -t / 2); // kick plate (exterior face)
  hinges(g, h, t);
  lever(g, w, t, true);
  // brass knocker on historic doors
  if (h >= 240) { g.push(); g.translate(C(w / 2), C(150), C(-t / 2 - 0.5)); g.rotateX(-Math.PI / 2); g.lathe('metal:BRASS', [[0, 0], [6, 0], [6.5, 1], [5.5, 1.5]].map(([r, y]) => [C(r), C(y)] as [number, number]), 16); g.pop(); }
  return g;
}

/** Storefront glass leaf: 10 cm aluminum stiles, 25 cm bottom rail, push bar. */
export function storefrontLeaf(w = DOOR.w, h = DOOR.h): GeoBuilder {
  const g = new GeoBuilder(), k = 'metal:ALUMINUM_STOREFRONT', t = 4.5;
  boxC(g, k, 0, 0, -t / 2, 10, h, t / 2); boxC(g, k, w - 10, 0, -t / 2, w, h, t / 2);
  boxC(g, k, 10, 0, -t / 2, w - 10, 25, t / 2); boxC(g, k, 10, h - 10, -t / 2, w - 10, h, t / 2);
  g.quad('glassShop', [C(10), C(25), 0], [C(10), C(h - 10), 0], [C(w - 10), C(h - 10), 0], [C(w - 10), C(25), 0]);
  for (const s of [-1, 1]) {
    boxC(g, 'metal:GALV_STEEL', 14, 100, s * t / 2 + (s < 0 ? -7 : 5), w - 14, 103.5, s * t / 2 + (s < 0 ? -5 : 7));
    for (const x of [16, w - 16]) boxC(g, 'metal:GALV_STEEL', x - 1, 100, s < 0 ? -t / 2 - 5 : t / 2, x + 1, 103.5, s < 0 ? -t / 2 : t / 2 + 5);
  }
  hinges(g, h, t, 'metal:GALV_STEEL');
  return g;
}

/** Service steel leaf: flush, gray, lever + closer arm. */
export function steelLeaf(w = DOOR.w, h = DOOR.h): GeoBuilder {
  const g = new GeoBuilder(), t = 4.5;
  boxC(g, 'satin:STEEL_DOOR_GRAY', 0, 0, -t / 2, w, h, t / 2);
  // vertical stiffener seams
  for (const x of [w / 3, (2 * w) / 3]) boxC(g, 'satin:STEEL_DOOR_GRAY', x - 0.2, 2, -t / 2 - 0.1, x + 0.2, h - 2, -t / 2);
  hinges(g, h, t, 'metal:GALV_STEEL');
  lever(g, w, t, false);
  boxC(g, 'metal:GALV_STEEL', 5, h - 12, t / 2, 35, h - 6, t / 2 + 6); // closer body (interior)
  return g;
}

/** Interior panel leaf (2-panel shaker) or interior glass leaf. */
export function interiorLeaf(w = DOOR.w, h = DOOR.h, key = 'satin:TRIM_WHITE', glazed = false): GeoBuilder {
  const g = new GeoBuilder();
  panelLeaf(g, w, h, DOOR.t, key, 1, glazed ? [55, 45] : [40, 60], glazed ? [1] : []);
  hinges(g, h, DOOR.t);
  lever(g, w, DOOR.t, false);
  return g;
}

/** Leaf builder for a DoorSystem style id. */
export function doorStyleBuilder(style: string): { g: GeoBuilder; w: number; h: number } {
  const [kind, arg, wArg, hArg] = style.split(':');
  const w = wArg ? Number(wArg) : DOOR.w, h = hArg ? Number(hArg) : DOOR.h;
  switch (kind) {
    case 'colonial': return { g: colonialLeaf(w, h, `satin:${arg ?? 'DOOR_RED'}`), w, h };
    case 'storefront': return { g: storefrontLeaf(w, h), w, h };
    case 'steel': return { g: steelLeaf(w, h), w, h };
    case 'interiorGlass': return { g: interiorLeaf(w, h, `satin:${arg || 'TRIM_WHITE'}`, true), w, h };
    default: return { g: interiorLeaf(w, h, `satin:${arg || 'TRIM_WHITE'}`), w, h };
  }
}

/**
 * Exterior door frame in a wall opening (cm). Opening x∈[0, w+2*frame? no: clear w], frame members 11 cm
 * inside the masonry reveal, 1.2 cm threshold, 2 cm-relief casing on the interior face.
 */
export function doorFrame(g: GeoBuilder, w: number, h: number, wallT: number, key = 'satin:TRIM_WHITE', setback = 10, interiorCasing = true) {
  const f = DOOR.frame;
  // jambs & head (stop) occupy setback..setback+f; clear opening stays w x h
  boxC(g, key, -f, 0, setback - 2, 0, h + f, setback + f);
  boxC(g, key, w, 0, setback - 2, w + f, h + f, setback + f);
  boxC(g, key, 0, h, setback - 2, w, h + f, setback + f);
  boxC(g, 'metal:BRASS', -2, 0, setback - 4, w + 2, DOOR.threshold, setback + f); // threshold 1.2 cm
  // stone step/landing in the reveal
  boxC(g, 'tex:limestone', -f, -1, 0, w + f, 0, setback - 2);
  if (interiorCasing) {
    const c = DOOR.casing, z1 = wallT, z2 = wallT + 2;
    boxC(g, key, -f - c, 0, z1, -f, h + f + c, z2);
    boxC(g, key, w + f, 0, z1, w + f + c, h + f + c, z2);
    boxC(g, key, -f, h + f, z1, w + f, h + f + c, z2);
  }
}

/** Interior door casing on both faces of a partition (opening clear w x h, wall thickness t). */
export function interiorCasing(g: GeoBuilder, w: number, h: number, t: number, key = 'satin:TRIM_WHITE') {
  const c = DOOR.casing;
  for (const [z1, z2] of [[-2, 0], [t, t + 2]]) {
    boxC(g, key, -c, 0, z1, 0, h + c, z2);
    boxC(g, key, w, 0, z1, w + c, h + c, z2);
    boxC(g, key, 0, h, z1, w, h + c, z2);
  }
  // jamb liner
  boxC(g, key, -1.9, 0, 0, 0, h, t, 1); boxC(g, key, w, 0, 0, w + 1.9, h, t, 2); boxC(g, key, 0, h, 0, w, h + 1.9, t, 8);
}

/** Double colonial doors with fanlight (frame + fanlight static; leaves via DoorSystem). Opening 183 x 213. */
export function doubleColonialFrame(g: GeoBuilder, wallT: number) {
  doorFrame(g, DOOR.dw, DOOR.h, wallT);
  g.push(); g.translate(0, C(DOOR.h + DOOR.frame), 0); fanlight(g, DOOR.dw / 2); g.pop();
}

/** Garage roll-up (static slatted curtain, closed) with steel guides and hood. Opening w x h. */
export function garageRollup(g: GeoBuilder, w = 274, h = 244) {
  for (let y = 0; y < h; y += 7.6) {
    const P = (x: number, yy: number, z: number): [number, number, number] => [C(x), C(yy), C(z)];
    g.quad('satin:GALV_STEEL', P(0, y, 8), P(0, y + 4.2, 7), P(w, y + 4.2, 7), P(w, y, 8));
    g.quad('satin:GALV_STEEL', P(0, y + 4.2, 7), P(0, Math.min(h, y + 7.6), 8), P(w, Math.min(h, y + 7.6), 8), P(w, y + 4.2, 7));
  }
  boxC(g, 'metal:GALV_STEEL', -8, 0, 4, 0, h, 14); boxC(g, 'metal:GALV_STEEL', w, 0, 4, w + 8, h, 14);
  boxC(g, 'satin:STEEL_DOOR_GRAY', -8, h, 4, w + 8, h + 46, 50); // hood
  boxC(g, 'metal:IRON_BLACK', w / 2 - 15, 2, 6, w / 2 + 15, 6, 8); // bottom handle
}

registerKit({ kit: 'Door', name: 'colonial 6-panel 91x213', build: (g) => g.merge(colonialLeaf()), bbox: [-0.6, 0, -8.75, 91, 213, 8.75], note: 'leaf incl. lever (6.5 cm proud)' });
registerKit({ kit: 'Door', name: 'historic colonial 107x244', build: (g) => g.merge(colonialLeaf(107, 244, 'satin:DOOR_GREEN')), bbox: [-0.6, 0, -8.75, 107, 244, 8.75] });
registerKit({ kit: 'Door', name: 'double colonial frame + fanlight', build: (g) => doubleColonialFrame(g, 45), bbox: [-20, -1, 0, 203, 315.5, 47], note: 'frame/fanlight static; leaves via DoorSystem' });
registerKit({ kit: 'Door', name: 'storefront glass 91x213', build: (g) => g.merge(storefrontLeaf()), bbox: [-0.6, 0, -9.25, 91, 213, 9.25] });
registerKit({ kit: 'Door', name: 'service steel 91x213', build: (g) => g.merge(steelLeaf()), bbox: [-0.6, 0, -8.75, 91, 213, 8.75] });
registerKit({ kit: 'Door', name: 'garage roll-up 274x244', build: (g) => garageRollup(g), bbox: [-8, 0, 4, 282, 290, 50] });
registerKit({ kit: 'Door', name: 'interior panel 91x213', build: (g) => g.merge(interiorLeaf()), bbox: [-0.6, 0, -8.75, 91, 213, 8.75] });
registerKit({ kit: 'Door', name: 'interior glass 91x213', build: (g) => g.merge(interiorLeaf(91, 213, 'satin:TRIM_WHITE', true)), bbox: [-0.6, 0, -8.75, 91, 213, 8.75] });
registerKit({ kit: 'Door', name: 'exterior frame 91x213', build: (g) => doorFrame(g, 91, 213, 45), bbox: [-20, -1, 0, 111, 233, 47] });
