// #10 Benefactor Memorial Stadium (CLAUDE.md §10): bowl set into the pine hillside — lower bowl all round,
// upper deck on the home (south) side, BRICK_CAMPUS_A facade. Interior: concourse ring with concession
// counters, locker rooms, tunnel, press box (4 floors), suites corridor. Field turf FIELD_TURF with
// MARKING_WHITE lines, end zones HEAVEN_BLUE with ONSU_NAVY lettering. Tiers are stepped platforms only.
import { Vector3 } from 'three';
import type { GeoBuilder, V3 } from '../../core/geo';
import { C, boxC } from '../../kits/common';
import { aisleSteps } from '../../kits/stair';
import { modernFixed } from '../../kits/window';
import { ironPicket } from '../../kits/railing';
import { customPlan, stackStairs, uStairSize } from '../../interiors/floorplan';
import { SHAFT } from '../../interiors/finishes';
import { defaultFacade } from '../facades';
import { LANDMARK_HOOKS } from '../manager';
import { STADIUM } from '../../world/layout';
import type { BuildingSpec, Rect } from '../../interiors/types';

const S = STADIUM;
const W = 23000, D = 19600; // local footprint (cm)
const CX = W / 2, CZ = D / 2;
const HX = S.hx * 100, HZ = S.hz * 100, R0 = S.r * 100;
const TIERS = 28, TD = 80, TR = 35.6; // tier depth / rise (aisle steps 2 x 17.8)
const BOWL_H = TIERS * TR; // 997
const CONC = 650; // concourse width
const UP0 = BOWL_H + 470, UP_T = 18; // upper deck (home side)

export function specs(): BuildingSpec[] {
  return [{
    id: 'LM10_BENEFACTOR_STADIUM', name: 'Benefactor Memorial Stadium', district: 'carillon_south', x: S.cx - W / 200, z: S.cz - D / 200, rotY: 0, y: S.floor + 0.05,
    w: W, d: D, floors: 8, basement: false, attic: false, typology: 'arena', plan: 'custom', custom: 'stadium',
    facade: defaultFacade('arena', { wall: 'brick:running:BRICK_CAMPUS_A' }), seed: 'stadium', public: true, tags: ['landmark'],
  }];
}

/** Closed rounded-rect path (local cm) offset `o` outward from the inner edge. */
function ring(o: number, segPerCorner = 8): [number, number][] {
  const hx = HX - R0, hz = HZ - R0, r = R0 + o, pts: [number, number][] = [];
  const corners: [number, number, number][] = [[hx, hz, 0], [-hx, hz, Math.PI / 2], [-hx, -hz, Math.PI], [hx, -hz, Math.PI * 1.5]];
  for (const [cx, cz, a0] of corners) for (let i = 0; i <= segPerCorner; i++) { const a = a0 + (i / segPerCorner) * (Math.PI / 2); pts.push([CX + cx + Math.cos(a) * r, CZ + cz + Math.sin(a) * r]); }
  return pts;
}

function band(g: GeoBuilder, key: string, inner: [number, number][], outer: [number, number][], y: number, riser: number, riserKey = key) {
  const n = inner.length;
  for (let i = 0; i < n; i++) {
    const a = inner[i], b = inner[(i + 1) % n], c = outer[(i + 1) % n], d = outer[i];
    const P = (p: [number, number], yy: number): V3 => [C(p[0]), C(yy), C(p[1])];
    g.quad(key, P(a, y), P(d, y), P(c, y), P(b, y));
    if (riser > 0) g.quad(riserKey, P(a, y - riser), P(a, y), P(b, y), P(b, y - riser));
  }
}

const homeBlock = (): Rect => ({ x0: CX - 6000, z0: CZ + HZ + 200, x1: CX + 6000, z1: CZ + HZ + 200 + 1800 });

LANDMARK_HOOKS.set('stadium', {
  customShell: true,
  pads: () => [{ cx: S.cx, cz: S.cz, hw: S.hx - 2, hd: S.hz - 2, y: S.floor + 0.05 }],
  fixedY: S.floor + 0.05,
  plan: (spec) => customPlan(spec, (pb, fl) => {
    const hb = homeBlock();
    const sw = 112, across = 2 * sw + 10, sd = uStairSize(600, sw).along + sw + 40;
    for (const f of fl) {
      const F = f.floor;
      const sA = pb.room(F, { x0: hb.x0, z0: hb.z0, x1: hb.x0 + across + 40, z1: hb.z0 + sd }, 'stair', 'Stair A');
      const sB = pb.room(F, { x0: hb.x1 - across - 40, z0: hb.z0, x1: hb.x1, z1: hb.z0 + sd }, 'stair', 'Stair B');
      const el = pb.room(F, { x0: hb.x0 + across + 40, z0: hb.z0, x1: hb.x0 + across + 40 + SHAFT.w + 80, z1: hb.z0 + sd }, 'elevator_lobby', 'Elevator');
      pb.fireWall(sA); pb.fireWall(sB);
      const mid = { x0: el.rect.x1, z0: hb.z0, x1: sB.rect.x0, z1: hb.z0 + sd };
      if (F === 0) {
        const field = pb.room(F, { x0: CX - HX, z0: CZ - HZ, x1: CX + HX, z1: CZ + HZ }, 'court', 'Field');
        const tun = pb.room(F, { x0: CX - 300, z0: CZ + HZ, x1: CX + 300, z1: hb.z0 }, 'corridor', 'Players tunnel');
        const hall = pb.room(F, mid, 'hall', 'Locker corridor');
        pb.open(field, tun); pb.open(tun, hall); pb.door(hall, sA, 'start'); pb.open(hall, el); pb.door(hall, sB, 'start');
        const z1 = hb.z1;
        const home = pb.room(F, { x0: hb.x0, z0: hb.z0 + sd, x1: CX, z1 }, 'locker', 'Home locker room');
        const vis = pb.room(F, { x0: CX, z0: hb.z0 + sd, x1: hb.x1, z1 }, 'locker', 'Visitor locker room');
        pb.door(hall, home, 'mid', 183); pb.door(hall, vis, 'mid', 183); pb.door(home, vis, 'end');
      } else if (F === 1) {
        const svc = pb.room(F, mid, 'corridor', 'Service ring'); pb.door(svc, sA, 'start'); pb.open(svc, el); pb.door(svc, sB, 'start');
        const st = pb.room(F, { x0: hb.x0, z0: hb.z0 + sd, x1: hb.x1, z1: hb.z1 }, 'storage', 'Equipment'); pb.door(svc, st, 'mid', 183);
      } else if (F === 2) {
        // concourse ring: 4 segments around the bowl top
        const c0 = HZ + TIERS * TD, cw = CONC;
        const north = pb.room(F, { x0: CX - HX - 2000, z0: 50, x1: CX + HX + 2000, z1: CZ - c0 }, 'concourse', 'North concourse');
        const west = pb.room(F, { x0: CX - HX - 2000 - cw, z0: CZ - c0 - cw, x1: CX - HX - 2000, z1: hb.z0 }, 'concourse', 'West concourse');
        const east = pb.room(F, { x0: CX + HX + 2000, z0: CZ - c0 - cw, x1: CX + HX + 2000 + cw, z1: hb.z0 }, 'concourse', 'East concourse');
        const south = pb.room(F, mid, 'concourse', 'Home concourse');
        pb.open(north, west); pb.open(north, east);
        const sw2 = pb.room(F, { x0: CX - HX - 2000 - cw, z0: hb.z0, x1: hb.x0, z1: hb.z0 + sd }, 'concourse'), se2 = pb.room(F, { x0: hb.x1, z0: hb.z0, x1: CX + HX + 2000 + cw, z1: hb.z0 + sd }, 'concourse');
        pb.open(west, sw2); pb.open(east, se2); pb.door(sw2, sA, 'start'); pb.door(se2, sB, 'start');
        pb.door(south, sA, 'start'); pb.open(south, el); pb.door(south, sB, 'start');
        const conc = pb.room(F, { x0: hb.x0, z0: hb.z0 + sd, x1: CX, z1: hb.z1 }, 'food_court', 'Concessions');
        const rr = pb.room(F, { x0: CX, z0: hb.z0 + sd, x1: hb.x1, z1: hb.z1 }, 'restroom');
        pb.open(south, conc); pb.door(south, rr, 'mid');
        pb.extDoors.push({ floor: 2, side: 'front', at: CX - 300, w: 600, h: 400, style: 'none', y: f.y });
      } else if (F === 3) {
        const corr = pb.room(F, mid, 'corridor', 'Suites corridor'); pb.door(corr, sA, 'start'); pb.open(corr, el); pb.door(corr, sB, 'start');
        const n = 6;
        for (let i = 0; i < n; i++) { const x0 = hb.x0 + ((hb.x1 - hb.x0) * i) / n, x1 = hb.x0 + ((hb.x1 - hb.x0) * (i + 1)) / n; const s = pb.room(F, { x0, z0: hb.z0 + sd, x1, z1: hb.z1 }, 'suite', `Suite ${i + 1}`); pb.door(corr, s, 'mid'); }
      } else {
        const corr = pb.room(F, mid, 'corridor'); pb.door(corr, sA, 'start'); pb.open(corr, el); pb.door(corr, sB, 'start');
        const pbx = pb.room(F, { x0: hb.x0, z0: hb.z0 + sd, x1: hb.x1, z1: hb.z1 }, 'press_box', `Press box level ${F - 3}`); pb.door(corr, pbx, 'mid', 183);
      }
    }
    stackStairs(pb, fl, (rise) => ({ x0: hb.x0 + 20, z0: hb.z0 + sd - 15 - uStairSize(rise, sw).along, x1: hb.x0 + 20 + across, z1: hb.z0 + sd - 15 }), 'z+', sw, 'A');
    stackStairs(pb, fl, (rise) => ({ x0: hb.x1 - 20 - across, z0: hb.z0 + sd - 15 - uStairSize(rise, sw).along, x1: hb.x1 - 20, z1: hb.z0 + sd - 15 }), 'z+', sw, 'B');
    pb.shafts.push({ rect: { x0: hb.x0 + across + 60, z0: hb.z0 + 20, x1: hb.x0 + across + 60 + SHAFT.w + 40, z1: hb.z0 + 20 + SHAFT.d + 40 }, floors: fl.map((f) => f.floor), door: 'z1' });
    void D;
  }),
  exterior: (spec, plan, out) => {
    const g = out.g;
    // field: turf, apron, end zones, lines
    boxC(g, 'tex:turf', CX - HX, -5, CZ - HZ, CX + HX, 0, CZ + HZ, 4);
    const fx = 5486, fz = 2438; // half field incl. end zones (120 yd x 53.3 yd)
    boxC(g, 'tex:turf', CX - fx, 0, CZ - fz, CX + fx, 0.5, CZ + fz, 4);
    for (const s of [-1, 1]) boxC(g, 'paint:HEAVEN_BLUE', s < 0 ? CX - fx : CX + fx - 914, 0.5, CZ - fz, s < 0 ? CX - fx + 914 : CX + fx, 0.7, CZ + fz, 4);
    for (const s of [-1, 1]) for (let i = 0; i < 4; i++) boxC(g, 'paint:ONSU_NAVY', (s < 0 ? CX - fx + 150 : CX + fx - 764) + 0, 0.75, CZ - 900 + i * 480, (s < 0 ? CX - fx + 764 : CX + fx - 150), 0.8, CZ - 560 + i * 480, 4);
    const L = (x0: number, z0: number, x1: number, z1: number) => boxC(g, 'mark:MARKING_WHITE', x0, 0.75, z0, x1, 0.85, z1, 4);
    L(CX - fx, CZ - fz, CX + fx, CZ - fz + 10); L(CX - fx, CZ + fz - 10, CX + fx, CZ + fz); L(CX - fx, CZ - fz, CX - fx + 10, CZ + fz); L(CX + fx - 10, CZ - fz, CX + fx, CZ + fz);
    for (let yd = 0; yd <= 100; yd += 5) { const x = CX - 4572 + yd * 91.44; L(x - 5, CZ - fz, x + 5, CZ + fz); }
    for (let yd = 1; yd < 100; yd++) { const x = CX - 4572 + yd * 91.44; for (const zz of [-fz + 30, -280, 280 - 60, fz - 90]) L(x - 5, CZ + zz, x + 5, CZ + zz + 60); }
    // lower bowl: 28 tiers of stepped platforms all round
    for (let k = 0; k < TIERS; k++) band(g, 'tex:concrete_new', ring(k * TD), ring((k + 1) * TD), (k + 1) * TR, TR);
    band(g, 'tex:concrete_new', ring(-50), ring(0), 120, 120, 'brick:running:BRICK_CAMPUS_A'); // field wall
    // concourse ring + outer brick facade
    band(g, 'tex:concrete_aged', ring(TIERS * TD), ring(TIERS * TD + CONC), BOWL_H, 0);
    const outer = ring(TIERS * TD + CONC), outer2 = ring(TIERS * TD + CONC + 45);
    const n = outer.length;
    for (let i = 0; i < n; i++) {
      const a = outer[i], b = outer[(i + 1) % n], a2 = outer2[i], b2 = outer2[(i + 1) % n];
      const P = (p: [number, number], yy: number): V3 => [C(p[0]), C(yy), C(p[1])];
      g.quad('brick:running:BRICK_CAMPUS_A', P(a2, 300), P(b2, 300), P(b2, BOWL_H + 420), P(a2, BOWL_H + 420));
      g.quad('tex:limestone', P(a, BOWL_H + 420), P(a2, BOWL_H + 420), P(b2, BOWL_H + 420), P(b, BOWL_H + 420));
      g.quad('paint:PLASTER_CAMPUS', P(b, BOWL_H), P(a, BOWL_H), P(a, BOWL_H + 420), P(b, BOWL_H + 420));
    }
    // aisle steps on the long sides every ~18 m
    for (const side of [-1, 1]) for (let x = CX - HX + 1200; x < CX + HX - 1200; x += 1800) {
      g.push(); g.translate(C(x - 55), 0, C(side < 0 ? CZ - HZ : CZ + HZ)); if (side < 0) { g.rotateY(Math.PI); g.translate(C(-110), 0, 0); } aisleSteps(g, TIERS, 110, TR, TD); g.pop();
    }
    // upper deck on the home side (cantilevered, columns behind)
    const ux0 = CX - HX + 800, ux1 = CX + HX - 800, uz0 = CZ + HZ + TIERS * TD + 200;
    for (let k = 0; k < UP_T; k++) {
      const y = UP0 + (k + 1) * 44, z = uz0 + k * 85;
      boxC(g, 'tex:concrete_new', ux0, y - 44, z, ux1, y, z + 85);
    }
    boxC(g, 'tex:concrete_aged', ux0, UP0 - 60, uz0, ux1, UP0, uz0 + UP_T * 85, 8); // soffit
    for (let x = ux0 + 200; x < ux1; x += 1200) boxC(g, 'tex:concrete_new', x - 60, BOWL_H, uz0 + UP_T * 85 - 200, x + 60, UP0 + UP_T * 44 + 60, uz0 + UP_T * 85 - 80);
    g.push(); g.translate(C(ux0), C(UP0 + 4), C(uz0 - 10)); ironPicket(g, ux1 - ux0); g.pop();
    // press box (4 floors) + suites on top of the upper deck, glazed toward the field
    const pz = uz0 + UP_T * 85, py = UP0 + UP_T * 44;
    boxC(g, 'paint:BRICK_CAMPUS_A', CX - 4500, py, pz - 900, CX + 4500, py + 4 * 330 + 60, pz, 1 | 2 | 4 | 16);
    for (let k = 0; k < 4; k++) { g.push(); g.translate(C(CX - 4500), C(py + k * 330 + 40), C(pz - 900)); modernFixed(g, 9000, 260, 30, 1, 'glassFar'); g.pop(); }
    boxC(g, 'satin:ONSU_NAVY', CX - 4520, py + 4 * 330 + 60, pz - 920, CX + 4520, py + 4 * 330 + 130, pz + 20);
    // light towers (4)
    for (const [sx, sz] of [[-1, -1], [1, -1], [-1, 1], [1, 1]]) {
      const lx = CX + sx * (HX + 2600), lz = CZ + sz * (HZ + 2600);
      g.cylinder('satin:GALV_STEEL', C(60), C(300), C(4200), 12, true, C(lx), C(lz));
      boxC(g, 'satin:GALV_STEEL', lx - 600, 4200, lz - 50, lx + 600, 4700, lz + 50);
      for (let i = 0; i < 12; i++) boxC(g, 'glow:LAMP_LED', lx - 560 + i * 95, 4250, lz - 60 * sz, lx - 480 + i * 95, 4650, lz - 50 * sz);
    }
    // collision: field, tiers (as ramps per side band), concourse
    out.floors.push(rp(CX - HX, CZ - HZ, CX + HX, CZ + HZ, 0));
    for (let k = 0; k < TIERS; k++) { const o0 = k * TD, o1 = o0 + TD, y = (k + 1) * TR; for (const r of tierRects(o0, o1)) out.floors.push(rp(r[0], r[1], r[2], r[3], y)); }
    for (const r of tierRects(TIERS * TD, TIERS * TD + CONC)) out.floors.push(rp(r[0], r[1], r[2], r[3], BOWL_H));
    void spec; void plan;
  },
  interior: (spec, plan, g) => {
    // home-block rooms under the stands: floors/ceilings, tunnel, concession counters
    for (const fp of plan.floors) for (const r of fp.rooms) {
      if (r.type === 'court' || r.type === 'concourse' && fp.floor === 2 && !r.label?.startsWith('Home')) continue;
      boxC(g, r.finish.floor, r.cl.x0, fp.y - 2, r.cl.z0, r.cl.x1, fp.y, r.cl.z1, 4);
      boxC(g, 'tex:concrete_aged', r.cl.x0, fp.y + fp.ftf - 40, r.cl.z0, r.cl.x1, fp.y + fp.ftf - 38, r.cl.z1, 8);
      if (r.type === 'food_court') for (let x = r.rect.x0 + 200; x < r.rect.x1 - 600; x += 800) boxC(g, 'satin:ALUMINUM_STOREFRONT', x, fp.y, r.rect.z0 + 100, x + 600, fp.y + 105, r.rect.z0 + 170);
      if (r.type === 'locker') boxC(g, 'tex:rubber', r.cl.x0, fp.y, r.cl.z0, r.cl.x1, fp.y + 0.5, r.cl.z1, 4);
    }
    const hb = homeBlock();
    boxC(g, 'tex:concrete_aged', CX - 300, 0, CZ + HZ, CX + 300, 400, hb.z0, 1 | 2 | 8); // tunnel walls+ceiling
    void spec;
  },
});

function tierRects(o0: number, o1: number): [number, number, number, number][] {
  return [
    [CX - HX + R0, CZ - HZ - o1, CX + HX - R0, CZ - HZ - o0], [CX - HX + R0, CZ + HZ + o0, CX + HX - R0, CZ + HZ + o1],
    [CX - HX - o1, CZ - HZ + R0, CX - HX - o0, CZ + HZ - R0], [CX + HX + o0, CZ - HZ + R0, CX + HX + o1, CZ + HZ - R0],
  ];
}
function rp(x0: number, z0: number, x1: number, z1: number, y: number) { return [new Vector3(C(x0), C(y), C(z0)), new Vector3(C(x1), C(y), C(z0)), new Vector3(C(x1), C(y), C(z1)), new Vector3(C(x0), C(y), C(z1))]; }
