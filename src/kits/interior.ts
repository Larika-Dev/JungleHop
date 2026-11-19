// Interior kit (CLAUDE.md §6/§7): partition, door opening, corridor segment, stair core, elevator shaft,
// restroom block, ceiling grid. Partitions 12 cm, fire/party walls 20 cm, elevator shaft 213 x 203 cm
// interior with 107 x 213 doors, corridors 183 / 152 / 244 cm. Pieces run along +x from the origin.
import type { GeoBuilder } from '../core/geo';
import { C, boxC, registerKit } from './common';
import { interiorCasing } from './door';
import { uStair } from './stair';

export const PART = { t: 12, fire: 20, base: 13, crown: 15, shaftW: 213, shaftD: 203, shaftDoorW: 107, shaftDoorH: 213 } as const;

export interface WallKeys { a: string; b: string; base?: string; wainscot?: string; wainscotH?: number; tileH?: number; tile?: string; }

/** Face treatment for one side of a wall run (baseboard, wainscot, tile band). side=-1 face at z=0, +1 at z=t. */
function face(g: GeoBuilder, x0: number, x1: number, h: number, z: number, side: -1 | 1, key: string, k: WallKeys) {
  const f = side < 0 ? 32 : 16;
  let y = 0;
  if (k.tile && k.tileH) { boxC(g, k.tile, x0, 0, z, x1, k.tileH, z, f); y = k.tileH; }
  else if (k.wainscot && k.wainscotH) {
    boxC(g, k.wainscot, x0, 0, z + side * 1.5, x1, k.wainscotH, z, f | 4); // 1.5 cm proud panelling + cap
    y = k.wainscotH;
    boxC(g, k.wainscot, x0, k.wainscotH - 4, z + side * 2.5, x1, k.wainscotH, z, f | 4 | 8);
  }
  boxC(g, key, x0, y, z, x1, h, z, f);
  if (k.base) boxC(g, k.base, x0, 0, z + side * 1.5, x1, PART.base, z, f | 4);
}

/** Partition wall L x h, thickness t (cm). Face a at z=0 (−z), face b at z=t (+z). Openings: [x0,w,h]. */
export function partition(g: GeoBuilder, L: number, h: number, t: number = PART.t, k: WallKeys = { a: 'paint:PAINT_OFFICE', b: 'paint:PAINT_OFFICE', base: 'satin:TRIM_WHITE' }, openings: [number, number, number][] = []) {
  const ops = [...openings].sort((a, b) => a[0] - b[0]);
  let x = 0;
  const solid = (x0: number, x1: number, y0 = 0) => {
    if (x1 - x0 < 0.01) return;
    if (y0 === 0) { face(g, x0, x1, h, 0, -1, k.a, k); face(g, x0, x1, h, t, 1, k.b, k); }
    else { boxC(g, k.a, x0, y0, 0, x1, h, 0, 32); boxC(g, k.b, x0, y0, t, x1, h, t, 16); boxC(g, k.a, x0, y0, 0, x1, y0, t, 8); }
    boxC(g, k.a, x0, h, 0, x1, h, t, 4);
  };
  for (const [ox, ow, oh] of ops) {
    solid(x, ox);
    solid(ox, ox + ow, oh); // header above opening
    g.push(); g.translate(C(ox), 0, 0); interiorCasing(g, ow, oh, t); g.pop();
    x = ox + ow;
  }
  solid(x, L);
  if (!ops.length || ops[0][0] > 0) boxC(g, k.a, 0, 0, 0, 0, h, t, 2);
  boxC(g, k.a, L, 0, 0, L, h, t, 1);
}

/** Corridor segment: floor, ceiling, two walls (one with a door), w = 183 academic. */
export function corridorSegment(g: GeoBuilder, L: number, w = 183, h = 300, floor = 'tex:terrazzo', ceil = 'tex:acoustic', walls: WallKeys = { a: 'paint:PAINT_OFFICE', b: 'paint:PAINT_OFFICE', base: 'satin:WALNUT_DARK' }) {
  boxC(g, floor, 0, -5, 0, L, 0, w, 4);
  boxC(g, ceil, 0, h, 0, L, h + 2, w, 8);
  g.push(); g.translate(0, 0, C(-PART.t)); partition(g, L, h, PART.t, walls, [[L / 2 - 45.5, 91, 213]]); g.pop();
  g.push(); g.translate(0, 0, C(w)); partition(g, L, h, PART.t, walls); g.pop();
}

/** Enclosed U-stair core: stair width w, total rise, CMU walls 20 cm with a door on the ground floor. */
export function stairCore(g: GeoBuilder, rise: number, w = 112, wallKey = 'tex:cmu') {
  const t = PART.fire, gap = 10;
  g.push(); g.translate(C(t), 0, C(t));
  const info = uStair(g, rise, w, 28, { tread: 'tex:sealed_concrete', riser: 'tex:sealed_concrete' }, gap);
  g.pop();
  const W = info.footprint[0] + 2 * t, D = info.footprint[1] + 2 * t + 150; // +150 landing at the base/top
  boxC(g, wallKey, 0, 0, 0, W, rise + 300, t);
  boxC(g, wallKey, 0, 0, D - t, W, rise + 300, D);
  boxC(g, wallKey, 0, 0, t, t, rise + 300, D - t);
  // door wall side with 91 x 213 opening at grade
  boxC(g, wallKey, W - t, 0, t, W, rise + 300, D - t - 150);
  boxC(g, wallKey, W - t, 0, D - t - 150 + 101, W, rise + 300, D - t);
  boxC(g, wallKey, W - t, 213, D - t - 150 + 10, W, rise + 300, D - t - 150 + 101);
  boxC(g, 'tex:sealed_concrete', t, 0, info.footprint[1] + t, W - t, 1, D - t, 4);
  return { ...info, size: [W, D] as [number, number] };
}

/** Elevator shaft: interior 213 x 203, 20 cm walls, closed brushed-steel doors 107 x 213 on each floor. */
export function elevatorShaft(g: GeoBuilder, floorHeights: number[], wallKey = 'tex:cmu') {
  const t = PART.fire, W = PART.shaftW + 2 * t, D = PART.shaftD + 2 * t;
  const H = floorHeights[floorHeights.length - 1] + 400;
  boxC(g, wallKey, 0, -150, D - t, W, H, D); // back
  boxC(g, wallKey, 0, -150, t, t, H, D - t);
  boxC(g, wallKey, W - t, -150, t, W, H, D - t);
  // front wall with door openings per floor
  const dx0 = (W - PART.shaftDoorW) / 2, dx1 = dx0 + PART.shaftDoorW;
  boxC(g, wallKey, 0, -150, 0, dx0, H, t);
  boxC(g, wallKey, dx1, -150, 0, W, H, t);
  let y = -150;
  for (const fy of floorHeights) {
    boxC(g, wallKey, dx0, y, 0, dx1, fy, t);
    // closed doors (two leaves) + frame
    boxC(g, 'metal:GALV_STEEL', dx0, fy, t * 0.5, dx0 + PART.shaftDoorW / 2 - 0.3, fy + PART.shaftDoorH, t * 0.5 + 3);
    boxC(g, 'metal:GALV_STEEL', dx0 + PART.shaftDoorW / 2 + 0.3, fy, t * 0.5, dx1, fy + PART.shaftDoorH, t * 0.5 + 3);
    boxC(g, 'metal:GALV_STEEL', dx0 - 8, fy, -1.5, dx0, fy + PART.shaftDoorH + 8, 0);
    boxC(g, 'metal:GALV_STEEL', dx1, fy, -1.5, dx1 + 8, fy + PART.shaftDoorH + 8, 0);
    boxC(g, 'metal:GALV_STEEL', dx0, fy + PART.shaftDoorH, -1.5, dx1, fy + PART.shaftDoorH + 8, 0);
    boxC(g, 'emit:INTERIOR_COOL', dx1 + 18, fy + 100, -0.6, dx1 + 26, fy + 112, 0); // call button
    y = fy + PART.shaftDoorH;
  }
  boxC(g, wallKey, dx0, y, 0, dx1, H, t);
  boxC(g, 'tex:sealed_concrete', t, -150, t, W - t, -140, D - t, 4); // pit floor
  return { size: [W, D] as [number, number] };
}

/** Restroom block shell: tile to 150 cm, hex or porcelain floor, door opening on the front wall. */
export function restroomBlock(g: GeoBuilder, w = 300, d = 400, h = 300, historic = true) {
  const floor = historic ? 'tex:hextile' : 'tex:porcelain';
  boxC(g, floor, 0, -2, 0, w, 0, d, 4);
  boxC(g, 'paint:CEILING_WHITE', 0, h, 0, w, h + 2, d, 8);
  const k: WallKeys = { a: 'paint:PAINT_OFFICE', b: 'paint:PAINT_OFFICE', tile: 'tex:subway', tileH: 150 };
  g.push(); g.translate(0, 0, C(-PART.t)); partition(g, w, h, PART.t, { ...k, a: 'paint:PAINT_OFFICE', tile: undefined, base: 'satin:TRIM_WHITE' }, [[30, 91, 213]]); g.pop();
  g.push(); g.translate(0, 0, C(d)); partition(g, w, h, PART.t, k); g.pop();
  g.push(); g.translate(0, 0, C(d)); g.rotateY(Math.PI / 2); partition(g, d, h, PART.t, k); g.pop();
  g.push(); g.translate(C(w + PART.t), 0, C(d)); g.rotateY(Math.PI / 2); partition(g, d, h, PART.t, k); g.pop();
}

/** Suspended acoustic ceiling: 61 x 61 tiles in a T-bar grid, 61 x 122 emissive light panels. */
export function ceilingGrid(g: GeoBuilder, w: number, d: number, y = 0, lightKey = 'emit:INTERIOR_COOL') {
  boxC(g, 'tex:acoustic', 0, y, 0, w, y + 1.5, d, 8);
  for (let x = 122; x < w - 61; x += 244) for (let z = 122; z < d - 122; z += 244) boxC(g, lightKey, x, y - 0.4, z, x + 61, y, z + 122, 8);
}

registerKit({ kit: 'Interior', name: 'partition 400x300 t12', build: (g) => partition(g, 400, 300), bbox: [0, 0, -1.5, 400, 300, 13.5] });
registerKit({ kit: 'Interior', name: 'door opening 400 (91x213)', build: (g) => partition(g, 400, 300, 12, undefined, [[150, 91, 213]]), bbox: [-0, 0, -2, 400, 300, 14] });
registerKit({ kit: 'Interior', name: 'corridor segment 600 w183', build: (g) => corridorSegment(g, 600), bbox: [0, 0, -14, 600, 300, 196.5] });
registerKit({ kit: 'Interior', name: 'stair core U 420 rise', build: (g) => { stairCore(g, 420); }, bbox: [0, 0, 0, 274, 720, 638] });
registerKit({ kit: 'Interior', name: 'elevator shaft 3 floors', build: (g) => { elevatorShaft(g, [0, 420, 820]); }, bbox: [0, -150, -1.5, 253, 1220, 243] });
registerKit({ kit: 'Interior', name: 'restroom block 300x400', build: (g) => restroomBlock(g, 300, 400), bbox: [0, 0, -14, 324, 300, 412] });
registerKit({ kit: 'Interior', name: 'ceiling grid 610x488', build: (g) => ceilingGrid(g, 610, 488), bbox: [0, -0.4, 0, 610, 0, 488] });
