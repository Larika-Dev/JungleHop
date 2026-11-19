// Storefront kit (CLAUDE.md §5/§6): 1-bay, 2-bay, 3-bay, corner-entry, recessed entry. Bulkhead 30–45 cm,
// glass to 270 cm, 45–60 cm transom band, recessed entry 90–150 cm deep with a tile floor.
// Spans x∈[0,w] across the ground-floor opening; street face at z=0, interior toward +z.
import type { GeoBuilder, V3 } from '../core/geo';
import { C, boxC, registerKit } from './common';
import { castIronColumn } from './column';
import { DOOR } from './door';
import { modernFixed } from './window';

export interface StorefrontOpts {
  w: number; bays: 1 | 2 | 3; entry: 'center' | 'left' | 'right' | 'corner' | 'none';
  recess?: number; bulk?: number; glassTop?: number; transom?: number;
  frameKey?: string; bulkKey?: string; glass?: string; floorKey?: string; columns?: boolean;
}
export interface DoorSlot { x: number; z: number; yaw: number; w: number; h: number; style: string; swing: 1 | -1; }

/** Builds a storefront; returns door slots (hinge positions in local cm) for the DoorSystem. */
export function storefront(g: GeoBuilder, o: StorefrontOpts): DoorSlot[] {
  const frame = o.frameKey ?? 'metal:ALUMINUM_STOREFRONT';
  const bulkKey = o.bulkKey ?? 'satin:ALUMINUM_STOREFRONT';
  const glass = o.glass ?? 'glassShop';
  const floor = o.floorKey ?? 'tex:hextile';
  const bulk = o.bulk ?? 40, top = o.glassTop ?? 270, tr = o.transom ?? 55, rec = o.recess ?? 120;
  const doors: DoorSlot[] = [];
  const colW = o.columns === false ? 0 : 32;
  if (colW) { castIronColumn(g, top + tr); g.push(); g.translate(C(o.w - colW), 0, 0); castIronColumn(g, top + tr); g.pop(); }
  const inner0 = colW, inner1 = o.w - colW;
  const entryW = DOOR.w + 2 * 15; // door + side frames
  let ex0 = -1, ex1 = -1;
  if (o.entry === 'center') { ex0 = (inner0 + inner1) / 2 - entryW / 2; ex1 = ex0 + entryW; }
  if (o.entry === 'left') { ex0 = inner0; ex1 = ex0 + entryW; }
  if (o.entry === 'right') { ex1 = inner1; ex0 = ex1 - entryW; }
  const glazed = (x0: number, x1: number, z = 0) => {
    if (x1 - x0 < 20) return;
    g.push(); g.translate(C(x0), 0, C(z));
    boxC(g, bulkKey, 0, 0, 0, x1 - x0, bulk, 12);
    // bulkhead raised panel
    boxC(g, bulkKey, 8, 8, -1, x1 - x0 - 8, bulk - 8, 0);
    g.translate(0, C(bulk), 0);
    modernFixed(g, x1 - x0, top - bulk, Math.max(1, Math.round((x1 - x0) / 170)), 1, glass, frame);
    g.pop();
  };
  if (o.entry === 'corner') {
    // chamfered corner entry at the right end: door on a 45° splay
    const c = 160;
    glazed(inner0, inner1 - c);
    const P = (x: number, y: number, z: number): V3 => [C(x), C(y), C(z)];
    // splay floor (tile) and door slot
    g.quad(floor, P(inner1 - c, 0.5, 0), P(inner1 - c, 0.5, c), P(inner1, 0.5, c), P(inner1, 0.5, 0));
    doors.push({ x: inner1 - c + 20, z: 20, yaw: -Math.PI / 4, w: DOOR.w, h: DOOR.h, style: 'storefront', swing: -1 });
  } else if (ex0 >= 0) {
    glazed(inner0, ex0); glazed(ex1, inner1);
    // recessed entry: angled return glazing + tile floor + door at the back
    const P = (x: number, y: number, z: number): V3 => [C(x), C(y), C(z)];
    g.quad(floor, P(ex0, 0.5, 0), P(ex0, 0.5, rec), P(ex1, 0.5, rec), P(ex1, 0.5, 0));
    for (const [xa, side] of [[ex0, 1], [ex1, -1]] as const) {
      g.push(); g.translate(C(xa), 0, 0); g.rotateY(-Math.PI / 2); void side;
      boxC(g, bulkKey, 0, 0, -6, rec, bulk, 6);
      g.translate(0, C(bulk), 0);
      g.quad(glass, P(0, 0, 0), P(0, top - bulk, 0), P(rec, top - bulk, 0), P(rec, 0, 0));
      boxC(g, frame, rec - 5, 0, -5, rec, top - bulk, 5);
      boxC(g, frame, 0, 0, -5, 5, top - bulk, 5);
      boxC(g, frame, 0, top - bulk - 5, -5, rec, top - bulk, 5);
      g.pop();
    }
    // door frame at the back of the recess
    boxC(g, frame, ex0, 0, rec - 5, ex0 + 15, top, rec + 10);
    boxC(g, frame, ex1 - 15, 0, rec - 5, ex1, top, rec + 10);
    boxC(g, frame, ex0 + 15, DOOR.h, rec - 5, ex1 - 15, top, rec + 10);
    g.quad(glass, P(ex0 + 15, DOOR.h + 5, rec + 2), P(ex0 + 15, top, rec + 2), P(ex1 - 15, top, rec + 2), P(ex1 - 15, DOOR.h + 5, rec + 2));
    // recess ceiling (beadboard)
    g.quad('satin:TRIM_WHITE_AGED', P(ex0, top, 0), P(ex1, top, 0), P(ex1, top, rec), P(ex0, top, rec));
    doors.push({ x: ex0 + 15, z: rec, yaw: 0, w: DOOR.w, h: DOOR.h, style: 'storefront', swing: -1 });
  } else glazed(inner0, inner1);
  // transom band across the full width
  g.push(); g.translate(C(inner0), C(top), 0);
  modernFixed(g, inner1 - inner0, tr, Math.max(2, o.bays * 3), 1, glass, frame);
  g.pop();
  // mullions dividing bays
  for (let i = 1; i < o.bays; i++) { const x = inner0 + ((inner1 - inner0) * i) / o.bays; if (ex0 >= 0 && x > ex0 - 10 && x < ex1 + 10) continue; boxC(g, frame, x - 4, 0, -2, x + 4, top + tr, 14); }
  return doors;
}

registerKit({ kit: 'Storefront', name: '1-bay 360 center entry', build: (g) => { storefront(g, { w: 360, bays: 1, entry: 'center' }); }, bbox: [-5, 0, -5, 365, 325, 130] });
registerKit({ kit: 'Storefront', name: '2-bay 600 left entry', build: (g) => { storefront(g, { w: 600, bays: 2, entry: 'left' }); }, bbox: [-5, 0, -5, 605, 325, 130] });
registerKit({ kit: 'Storefront', name: '3-bay 900 center', build: (g) => { storefront(g, { w: 900, bays: 3, entry: 'center' }); }, bbox: [-5, 0, -5, 905, 325, 130] });
registerKit({ kit: 'Storefront', name: 'corner-entry 600', build: (g) => { storefront(g, { w: 600, bays: 2, entry: 'corner' }); }, bbox: [-5, 0, -5, 605, 325, 160] });
registerKit({ kit: 'Storefront', name: 'recessed entry 450 r150', build: (g) => { storefront(g, { w: 450, bays: 1, entry: 'center', recess: 150 }); }, bbox: [-5, 0, -5, 455, 325, 160] });
