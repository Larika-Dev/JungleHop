// #14 Ghoulgrave Keep (CLAUDE.md §10): fieldstone mini-castle — square tower + great hall. Interior: great
// hall with fireplace, tower spiral stair, cellar, parapet walk (crenellated tower roof).
import { Vector3 } from 'three';
import { C, boxC } from '../../kits/common';
import { wallWithOpenings } from '../../kits/brick';
import { gableRoof } from '../../kits/roof';
import { spiralStair, solveRisers } from '../../kits/stair';
import { doorFrame } from '../../kits/door';
import { customPlan } from '../../interiors/floorplan';
import { defaultFacade } from '../facades';
import { LANDMARK_HOOKS } from '../manager';
import { LANDMARKS } from '../../world/layout';
import { centered } from './common';
import { poly, rectMinus } from './carillonSpire';
import type { BuildingSpec, Rect } from '../../interiors/types';

const W = 2200, D = 2700, TW = 900, T = 60; // tower TW x TW at the front-left; hall behind/right
const STONE = 'tex:fieldstone';
const SPIRAL: Rect = { x0: T + 20, z0: T + 20, x1: T + 260, z1: T + 260 };
const HALL: Rect = { x0: T, z0: TW, x1: W - T, z1: D - T };
const lvl = (f: number) => (f < 0 ? -330 : f === 0 ? 0 : 480 + 420 * (f - 1));

export function specs(): BuildingSpec[] {
  const site = LANDMARKS.find((l) => l.id === 'ghoulgrave_keep')!;
  return [centered(site, W, D, {
    id: 'LM14_GHOULGRAVE_KEEP', name: 'Ghoulgrave Keep', district: 'toadstool', floors: 4, basement: true, attic: false,
    typology: 'historic_academic', plan: 'custom', custom: 'keep', facade: defaultFacade('historic_academic', { wall: STONE }), seed: 'keep', public: true, tags: ['landmark', 'exit-exception'],
  })];
}

LANDMARK_HOOKS.set('keep', {
  customShell: true,
  plan: (spec) => customPlan(spec, (pb, fl) => {
    for (const f of fl) {
      const F = f.floor;
      const tw = pb.room(F, { x0: T, z0: T, x1: TW, z1: TW }, F < 0 ? 'cellar' : F === 3 ? 'deck' : F === 0 ? 'hall' : 'study', F === 3 ? 'Parapet walk' : F === 0 ? 'Tower base' : `Tower room ${F}`);
      if (F <= 0) {
        const h = pb.room(F, HALL, F < 0 ? 'cellar' : 'great_hall', F < 0 ? 'Cellar' : 'Great hall');
        pb.door(tw, h, 'mid', 107);
        if (F === 0) pb.extDoors.push({ floor: 0, side: 'back', at: Math.round(W / 2) - 53, w: 107, h: 244, style: 'colonial:DOOR_BLACK', y: 0 });
      } else if (F === 1) {
        const gal = pb.room(F, { x0: HALL.x0, z0: HALL.z0, x1: HALL.x1, z1: HALL.z0 + 300 }, 'gallery', "Minstrels' gallery");
        pb.door(tw, gal, 'mid');
      }
      if (F > -1) pb.hole(F, SPIRAL);
      if (F === 0) pb.extDoors.push({ floor: 0, side: 'front', at: 400, w: 107, h: 244, style: 'colonial:DOOR_BLACK', y: 0 });
    }
    for (let i = 0; i < fl.length - 1; i++) pb.stairs.push({ id: `T${i}`, floor: fl[i].floor, toFloor: fl[i + 1].floor, rect: SPIRAL, kind: 'spiral', w: 108, dir: 'z+', rise: fl[i].ftf });
    pb.shafts.push({ rect: { x0: TW - T / 2 - 260, z0: TW - T / 2 - 250, x1: TW - T / 2 - 7, z1: TW - T / 2 - 7 }, floors: fl.filter((f) => f.floor <= 2).map((f) => f.floor), door: 'z0' });
  }),
  exterior: (spec, plan, out) => {
    const g = out.g;
    const towerTop = lvl(3), hallTop = lvl(2);
    const wall = (x0: number, z0: number, len: number, theta: number, h: number, ops: { x: number; y: number; w: number; h: number }[], yb = -330) => {
      g.push(); g.translate(C(x0), C(yb), C(z0)); g.rotateY(theta);
      wallWithOpenings(g, len, h - yb, T, ops.map((o) => ({ ...o, y: o.y - yb })), STONE, 'paint:PLASTER_CAMPUS', STONE);
      g.pop();
    };
    // tower (4 sides) with arrow-slit windows, crenellated parapet
    const slits = (n: number) => Array.from({ length: n }, (_, k) => ({ x: 400, y: lvl(k + 1) + 140, w: 30, h: 160 }));
    wall(0, 0, TW, 0, towerTop, [{ x: 400, y: 0, w: 107, h: 244 }, ...slits(2)]);
    wall(0, TW, TW, Math.PI / 2, towerTop, slits(2));
    wall(TW, 0, TW, -Math.PI / 2, towerTop, slits(2));
    for (let x = 0; x < TW; x += 120) for (const [ax, az, th] of [[0, 0, 0], [TW, TW, Math.PI], [0, TW, Math.PI / 2], [TW, 0, -Math.PI / 2]] as const) {
      g.push(); g.translate(C(ax), C(towerTop), C(az)); g.rotateY(th);
      boxC(g, STONE, x, 0, -10, x + 60, 140, T); // merlons
      boxC(g, STONE, x + 60, 0, -10, x + 120, 70, T); // crenel sill
      g.pop();
    }
    // great hall walls with tall lancet windows
    const lancets = (len: number) => Array.from({ length: Math.floor(len / 450) }, (_, k) => ({ x: 200 + k * 450, y: 150, w: 90, h: 380 }));
    wall(TW, 0, W - TW, 0, hallTop, lancets(W - TW).filter((o) => o.x + o.w < W - TW - 60));
    wall(W, 0, D, -Math.PI / 2, hallTop, lancets(D));
    wall(W, D, W, Math.PI, hallTop, [{ x: W / 2 - 53, y: 0, w: 107, h: 244 }, ...lancets(W).filter((o) => Math.abs(o.x + 45 - W / 2) > 150)]);
    wall(0, D, D - TW, Math.PI / 2, hallTop, lancets(D - TW));
    for (const d of [{ x: 400, z: 0, th: 0 }, { x: W - (W / 2 - 53), z: D, th: Math.PI }]) {
      g.push(); g.translate(C(d.x), 0, C(d.z)); g.rotateY(d.th); doorFrame(g, 107, 244, T, 'paint:WALNUT_DARK'); g.pop();
    }
    out.doors.push({ hinge: new Vector3(C(400), 0, C(14.25)), yaw: 0, style: 'colonial:DOOR_BLACK:107:244', w: 1.07, h: 2.44, swing: -1, ext: true });
    out.doors.push({ hinge: new Vector3(C(W / 2 + 53), 0, C(D - 14.25)), yaw: Math.PI, style: 'colonial:DOOR_BLACK:107:244', w: 1.07, h: 2.44, swing: -1, ext: true });
    // glazing for lancets (far shader)
    // steep slate roof over the hall
    g.push(); g.translate(C(TW - 30), C(hallTop), C(TW)); g.rotateY(Math.PI / 2); g.translate(C(-(D - TW)), 0, 0);
    gableRoof(g, D - TW, W - TW + 30, 52, 30, { top: 'tex:slate', under: 'tex:walnut', trim: 'paint:WALNUT_DARK' }, STONE);
    g.pop();
    // collision
    const P = (x: number, z: number) => [C(x), C(z)];
    const sw = (ax: number, az: number, bx: number, bz: number, y1: number) => out.walls.push([...P(ax, az), ...P(bx, bz), C(-330), C(y1), C(T)] as any);
    sw(0, 0, 400, 0, towerTop + 140); sw(507, 0, TW, 0, towerTop + 140); sw(0, 0, 0, D, hallTop); sw(TW, 0, W, 0, hallTop); sw(W, 0, W, D, hallTop); sw(0, D, W / 2 - 53, D, hallTop); sw(W / 2 + 54, D, W, D, hallTop);
    sw(TW, T, TW, TW, towerTop + 140);
    for (const fp of plan.floors) for (const r of fp.rooms) for (const q of rectMinus(r.cl, fp.floor > -1 ? [SPIRAL] : [])) out.floors.push(poly(q, lvl(fp.floor)));
    for (let k = 0; k < 4; k++) {
      const { n, riser } = solveRisers(lvl(k) - lvl(k - 1));
      const da = (Math.PI * 2) / 14, cx = SPIRAL.x0 + 120, cz = SPIRAL.z0 + 120;
      for (let i = 0; i < n; i++) {
        const a0 = i * da, a1 = a0 + da * 1.08, y = lvl(k - 1) + (i + 1) * riser;
        out.floors.push([new Vector3(C(cx + Math.sin(a0) * 12), C(y), C(cz + Math.cos(a0) * 12)), new Vector3(C(cx + Math.sin(a0) * 120), C(y), C(cz + Math.cos(a0) * 120)), new Vector3(C(cx + Math.sin(a1) * 120), C(y), C(cz + Math.cos(a1) * 120)), new Vector3(C(cx + Math.sin(a1) * 12), C(y), C(cz + Math.cos(a1) * 12))]);
      }
    }
  },
  interior: (spec, plan, g) => {
    for (const fp of plan.floors) {
      const y = lvl(fp.floor);
      for (const r of fp.rooms) for (const q of rectMinus(r.cl, fp.floor > -1 ? [SPIRAL] : [])) boxC(g, fp.floor < 0 ? 'tex:capstone' : r.type === 'deck' ? 'tex:capstone' : 'tex:heart_pine', q.x0, y - 2, q.z0, q.x1, y, q.z1, 4);
      if (fp.floor < 3) { g.push(); g.translate(C(SPIRAL.x0), C(y), C(SPIRAL.z0)); spiralStair(g, lvl(fp.floor + 1) - y, 120, 12, 14, 'tex:capstone'); g.pop(); }
    }
    // great-hall fireplace: stone chimney breast with hearth opening and oak mantel
    const fx = W - T - 80, fz = (HALL.z0 + HALL.z1) / 2;
    boxC(g, STONE, fx - 60, 0, fz - 200, fx, lvl(2), fz + 200);
    boxC(g, 'paint:SHADOW_INK', fx - 61, 0, fz - 90, fx - 59, 150, fz + 90);
    boxC(g, 'tex:walnut', fx - 80, 150, fz - 140, fx - 55, 175, fz + 140);
    boxC(g, 'tex:capstone', fx - 160, 0, fz - 150, fx - 60, 6, fz + 150);
    // hammer-beam trusses
    for (let z = HALL.z0 + 300; z < HALL.z1; z += 400) boxC(g, 'tex:walnut', HALL.x0, lvl(2) - 40, z - 15, HALL.x1, lvl(2), z + 15);
    void spec;
  },
});
