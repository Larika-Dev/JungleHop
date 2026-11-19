// #11 The Coach's Dome (CLAUDE.md §10): round arena, 120 m diameter dome, white membrane roof over a
// HEAVEN_BLUE ring band. Interior: concourse ring, seating-bowl tiers, SPORTS_MAPLE court with the parody
// center logo, locker rooms, practice gym, banners zone (items later).
import { Vector3 } from 'three';
import { C, boxC } from '../../kits/common';
import { customPlan, stackStairs, uStairSize } from '../../interiors/floorplan';
import { SHAFT } from '../../interiors/finishes';
import { defaultFacade } from '../facades';
import { LANDMARK_HOOKS } from '../manager';
import { LANDMARKS } from '../../world/layout';
import { arcTiers, centered, ringWall } from './common';
import type { BuildingSpec } from '../../interiors/types';

const R = 6000, W = 2 * R; // cm
const COURT = { w: 2865, d: 1524 };
const BOWL0 = 2200, TIERS = 30, TD = 85, TR = 35.6, Y0 = 0; // court at y=0, concourse at top of bowl
const CONC_Y = TIERS * TR; // 1068

export function specs(): BuildingSpec[] {
  const site = LANDMARKS.find((l) => l.id === 'coachs_dome')!;
  return [centered(site, W, W, {
    id: 'LM11_COACHS_DOME', name: "The Coach's Dome", district: 'carillon_south', floors: 3, basement: false, attic: false,
    typology: 'arena', plan: 'custom', custom: 'coachs_dome', facade: defaultFacade('arena'), seed: 'dome', public: true, tags: ['landmark'],
  })];
}

LANDMARK_HOOKS.set('coachs_dome', {
  customShell: true,
  siteY: (grade) => grade - 6.0, // court sunk one storey; concourse ring at grade
  pads: (spec) => [{ cx: spec.x + R / 100, cz: spec.z + R / 100, hw: 38, hd: 38, y: spec.y }],
  plan: (spec) => customPlan(spec, (pb, fl) => {
    const c = R, sw = 112, across = 2 * sw + 10;
    const sd = uStairSize(600, sw).along + sw + 40;
    for (const f of fl) {
      const F = f.floor;
      const sA = pb.room(F, { x0: c - 3000, z0: c + 3800, x1: c - 3000 + across + 40, z1: c + 3800 + sd }, 'stair', 'Stair A');
      const sB = pb.room(F, { x0: c + 3000 - across - 40, z0: c + 3800, x1: c + 3000, z1: c + 3800 + sd }, 'stair', 'Stair B');
      const hall = pb.room(F, { x0: c - 3000 + across + 40, z0: c + 3800, x1: c + 3000 - across - 40, z1: c + 3800 + sd }, F === 1 ? 'concourse' : 'corridor', F === 1 ? 'Concourse (south)' : 'Service corridor');
      pb.fireWall(sA); pb.fireWall(sB);
      pb.door(hall, sA, 'start'); pb.door(hall, sB, 'start');
      if (F === 0) {
        const court = pb.room(F, { x0: c - BOWL0, z0: c - BOWL0, x1: c + BOWL0, z1: c + BOWL0 }, 'court', 'Court');
        const tun = pb.room(F, { x0: c - 250, z0: c + BOWL0, x1: c + 250, z1: c + 3800 }, 'corridor', 'Team tunnel');
        pb.open(court, tun); pb.open(tun, hall);
        const lk1 = pb.room(F, { x0: c - 3000, z0: c + 3800 + sd, x1: c, z1: c + 5500 }, 'locker', 'Home locker room');
        const lk2 = pb.room(F, { x0: c, z0: c + 3800 + sd, x1: c + 3000, z1: c + 5500 }, 'locker', 'Visitor locker room');
        pb.door(hall, lk1, 'start'); pb.door(hall, lk2, 'end');
        const gym = pb.room(F, { x0: c - 2400, z0: c - 5500, x1: c + 2400, z1: c - 3600 }, 'gym', 'Practice gym');
        const gt = pb.room(F, { x0: c - 250, z0: c - 3600, x1: c + 250, z1: c - BOWL0 }, 'corridor', 'North tunnel');
        pb.open(court, gt); pb.door(gt, gym, 'mid', 183);
      } else if (F === 1) {
        // concourse ring as four arcs approximated by rects (N, E, W) + the south hall
        const n = pb.room(F, { x0: c - 3800, z0: c - 5950, x1: c + 3800, z1: c - 4400 }, 'concourse', 'Concourse (north)');
        const w = pb.room(F, { x0: c - 5600, z0: c - 4400, x1: c - 4400, z1: c + 3800 }, 'concourse', 'Concourse (west)');
        const e = pb.room(F, { x0: c + 4400, z0: c - 4400, x1: c + 5600, z1: c + 3800 }, 'concourse', 'Concourse (east)');
        const swc = pb.room(F, { x0: c - 5600, z0: c + 3800, x1: c - 3000, z1: c + 3800 + sd }, 'concourse'), sec = pb.room(F, { x0: c + 3000, z0: c + 3800, x1: c + 5600, z1: c + 3800 + sd }, 'concourse');
        const nw = pb.room(F, { x0: c - 5600, z0: c - 5950, x1: c - 3800, z1: c - 4400 }, 'food_court', 'Concessions NW'), ne = pb.room(F, { x0: c + 3800, z0: c - 5950, x1: c + 5600, z1: c - 4400 }, 'food_court', 'Concessions NE');
        pb.open(n, nw); pb.open(n, ne); pb.open(nw, w); pb.open(ne, e); pb.open(w, swc); pb.open(e, sec); pb.door(swc, sA, 'start'); pb.door(sec, sB, 'start');
        pb.extDoors.push({ floor: 1, side: 'front', at: R - 300, w: 600, h: 300, style: 'none', y: f.y });
      } else {
        const off = pb.room(F, { x0: c - 3000, z0: c + 3800 + sd, x1: c + 3000, z1: c + 5300 }, 'office', 'Athletics offices'); pb.door(hall, off, 'mid');
      }
      void fl;
    }
    stackStairs(pb, fl, (rise) => ({ x0: c - 2980, z0: c + 3800 + sd - 15 - uStairSize(rise, sw).along, x1: c - 2980 + across, z1: c + 3800 + sd - 15 }), 'z+', sw, 'A');
    stackStairs(pb, fl, (rise) => ({ x0: c + 2980 - across, z0: c + 3800 + sd - 15 - uStairSize(rise, sw).along, x1: c + 2980, z1: c + 3800 + sd - 15 }), 'z+', sw, 'B');
    pb.shafts.push({ rect: { x0: c - 200, z0: c + 3800 + sd - SHAFT.d - 50, x1: c - 200 + SHAFT.w + 40, z1: c + 3800 + sd - 10 }, floors: fl.map((f) => f.floor), door: 'z0' });
  }),
  exterior: (spec, plan, out) => {
    const g = out.g, c = R;
    const wallTop = CONC_Y + 650;
    // outer ring wall: brick lower storey, glazed clerestory band, blue ring band, membrane dome
    ringWall(g, c, c, R, -50, 450, 40, 'brick:running:BRICK_CAMPUS_A', 'paint:PAINT_OFFICE', [[Math.PI, 700]], 96);
    ringWall(g, c, c, R, 450, wallTop - 120, 40, 'glassFar', 'glass', [], 96);
    ringWall(g, c, c, R + 20, wallTop - 120, wallTop, 60, 'paint:HEAVEN_BLUE', 'paint:HEAVEN_BLUE', [], 96);
    g.push(); g.translate(C(c), C(wallTop), C(c));
    const prof: [number, number][] = [];
    for (let i = 0; i <= 18; i++) { const a = (i / 18) * (Math.PI / 2); prof.push([C((R + 30) * Math.cos(a)), C(R * 0.32 * Math.sin(a))]); }
    g.lathe('paint:MEMBRANE_WHITE', prof, 96);
    g.lathe('paint:CEILING_WHITE', [...prof].reverse().map(([r, y]) => [Math.max(0.01, r - 0.3), y - 0.3] as [number, number]), 96);
    // cable ribs
    for (let i = 0; i < 24; i++) { g.push(); g.rotateY((i / 24) * Math.PI * 2); for (let k = 0; k < 18; k++) { const a0 = (k / 18) * (Math.PI / 2), a1 = ((k + 1) / 18) * (Math.PI / 2); g.quad('satin:GALV_STEEL', [-0.05, C(R * 0.32 * Math.sin(a0)) + 0.02, C((R + 30) * Math.cos(a0))], [0.05, C(R * 0.32 * Math.sin(a0)) + 0.02, C((R + 30) * Math.cos(a0))], [0.05, C(R * 0.32 * Math.sin(a1)) + 0.02, C((R + 30) * Math.cos(a1))], [-0.05, C(R * 0.32 * Math.sin(a1)) + 0.02, C((R + 30) * Math.cos(a1))]); } g.pop(); }
    g.pop();
    // entry canopy at the north gate
    boxC(g, 'satin:ALUMINUM_STOREFRONT', c - 700, 400, -500, c + 700, 440, 200);
    // collision: ring wall (polygon), court floor, concourse ring floor
    for (let i = 0; i < 48; i++) {
      const a0 = (i / 48) * Math.PI * 2, a1 = ((i + 1) / 48) * Math.PI * 2, am = (a0 + a1) / 2;
      if (Math.abs(am - Math.PI) < 0.06) continue;
      out.walls.push([C(c + Math.sin(a0) * R), C(c + Math.cos(a0) * R), C(c + Math.sin(a1) * R), C(c + Math.cos(a1) * R), C(-50), C(wallTop), 0.4]);
    }
    const sq = (x0: number, z0: number, x1: number, z1: number, y: number) => [new Vector3(C(x0), C(y), C(z0)), new Vector3(C(x1), C(y), C(z0)), new Vector3(C(x1), C(y), C(z1)), new Vector3(C(x0), C(y), C(z1))];
    out.floors.push(sq(c - BOWL0, c - BOWL0, c + BOWL0, c + BOWL0, 0));
    for (let k = 0; k < TIERS; k++) {
      const r0 = BOWL0 + k * TD, r1 = r0 + TD, y = (k + 1) * TR;
      for (let i = 0; i < 32; i++) {
        const a0 = (i / 32) * Math.PI * 2, a1 = ((i + 1) / 32) * Math.PI * 2;
        out.floors.push([new Vector3(C(c + Math.sin(a0) * r0), C(y), C(c + Math.cos(a0) * r0)), new Vector3(C(c + Math.sin(a0) * r1), C(y), C(c + Math.cos(a0) * r1)), new Vector3(C(c + Math.sin(a1) * r1), C(y), C(c + Math.cos(a1) * r1)), new Vector3(C(c + Math.sin(a1) * r0), C(y), C(c + Math.cos(a1) * r0))]);
      }
    }
    for (let i = 0; i < 32; i++) {
      const a0 = (i / 32) * Math.PI * 2, a1 = ((i + 1) / 32) * Math.PI * 2, r0 = BOWL0 + TIERS * TD, r1 = R - 40;
      out.floors.push([new Vector3(C(c + Math.sin(a0) * r0), C(CONC_Y), C(c + Math.cos(a0) * r0)), new Vector3(C(c + Math.sin(a0) * r1), C(CONC_Y), C(c + Math.cos(a0) * r1)), new Vector3(C(c + Math.sin(a1) * r1), C(CONC_Y), C(c + Math.cos(a1) * r1)), new Vector3(C(c + Math.sin(a1) * r0), C(CONC_Y), C(c + Math.cos(a1) * r0))]);
    }
    // ground-level apron outside the north gate up to the concourse via ramps is handled by terrain (site at grade = concourse)
    void spec; void plan;
  },
  interior: (spec, plan, g) => {
    const c = R;
    boxC(g, 'tex:rubber', c - BOWL0, -2, c - BOWL0, c + BOWL0, 0, c + BOWL0, 4);
    boxC(g, 'tex:maple_court', c - COURT.w / 2, 0, c - COURT.d / 2, c + COURT.w / 2, 1.5, c + COURT.d / 2, 4);
    // court markings + center logo ring (parody logo artwork applied in the signage pass)
    const k = 'mark:ONSU_NAVY';
    boxC(g, k, c - COURT.w / 2, 1.5, c - COURT.d / 2, c + COURT.w / 2, 1.6, c - COURT.d / 2 + 5, 4);
    boxC(g, k, c - COURT.w / 2, 1.5, c + COURT.d / 2 - 5, c + COURT.w / 2, 1.6, c + COURT.d / 2, 4);
    boxC(g, k, c - 2.5, 1.5, c - COURT.d / 2, c + 2.5, 1.6, c + COURT.d / 2, 4);
    g.push(); g.translate(C(c), C(1.55), C(c)); g.disc('mark:HEAVEN_BLUE', C(183), 0, 48, true, C(120)); g.disc('mark:ONSU_NAVY', C(120), 0.001, 48, true); g.pop();
    for (const s of [-1, 1]) { g.push(); g.translate(C(c + s * (COURT.w / 2 - 580)), C(1.55), C(c)); boxC(g, 'mark:HEAVEN_BLUE', -s * 0, 0, -244, s * 580, 0.1, 244); g.pop(); }
    // seating bowl tiers (stepped platforms, full circle) and the concourse floor
    arcTiers(g, c, c, BOWL0, TIERS, TD, TR, 0, Math.PI * 2, Y0, 'tex:concrete_new');
    g.push(); g.translate(C(c), C(CONC_Y), C(c)); g.disc('tex:terrazzo', C(R - 40), 0, 96, true, C(BOWL0 + TIERS * TD)); g.pop();
    // practice gym floor + locker rubber floors
    for (const fp of plan.floors) for (const r of fp.rooms) {
      if (r.type === 'court' || r.type === 'concourse') continue;
      boxC(g, r.type === 'gym' ? 'tex:maple_court' : r.finish.floor, r.cl.x0, fp.y - 2, r.cl.z0, r.cl.x1, fp.y, r.cl.z1, 4);
    }
    // banner rail zone (items later): catwalk ring under the dome
    g.push(); g.translate(C(c), C(CONC_Y + 1700), C(c)); g.disc('satin:GALV_STEEL', C(2600), 0, 48, false, C(2500)); g.pop();
    void spec;
  },
});
