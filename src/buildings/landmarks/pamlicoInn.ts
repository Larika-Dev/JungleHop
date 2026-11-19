// #12 Pamlico Inn (CLAUDE.md §10): colonial hotel, 4 floors, deep two-storey columned porch, cupola.
// Interior: lobby with front-desk counter, ballroom 14 x 28 m, restaurant, kitchen, 3 floors of guest
// rooms each with its own bath.
import { C, boxC } from '../../kits/common';
import { doricColumn } from '../../kits/column';
import { colonialBalustrade } from '../../kits/railing';
import { customPlan, stackStairs, uStairSize } from '../../interiors/floorplan';
import { CORRIDOR, SHAFT } from '../../interiors/finishes';
import { defaultFacade } from '../facades';
import { LANDMARK_HOOKS } from '../manager';
import { LANDMARKS } from '../../world/layout';
import { centered } from './common';
import type { BuildingSpec } from '../../interiors/types';

const W = 6400, D = 2400;
export function specs(): BuildingSpec[] {
  const site = { ...LANDMARKS.find((l) => l.id === 'pamlico_inn')!, rotY: -Math.PI / 2 };
  return [centered(site, W, D, {
    id: 'LM12_PAMLICO_INN', name: 'Pamlico Inn', district: 'cameron_heights', floors: 4, basement: true, attic: false,
    typology: 'inn', plan: 'custom', custom: 'inn', facade: defaultFacade('inn', { bay: 320 }), seed: 'inn', public: true, tags: ['landmark', 'cupola'],
  })];
}

LANDMARK_HOOKS.set('inn', {
  plan: (spec) => customPlan(spec, (pb, fl, Wd, Dd, t) => {
    const cw = CORRIDOR.residential, zc0 = 700, zc1 = zc0 + cw;
    const sw = 112, SW = 2 * sw + 10 + 30, xL = t + SW, xR = Wd - t - SW;
    for (const f of fl) {
      const F = f.floor;
      const stL = pb.room(F, { x0: t, z0: t, x1: xL, z1: Dd - t }, 'stair', 'Stair A'), stR = pb.room(F, { x0: xR, z0: t, x1: Wd - t, z1: Dd - t }, 'stair', 'Stair B');
      pb.fireWall(stL); pb.fireWall(stR);
      const corr = pb.room(F, { x0: xL, z0: zc0, x1: xR, z1: zc1 }, 'corridor', F === 0 ? 'Gallery' : undefined);
      pb.door(corr, stL, 'mid', 91, 'interiorGlass'); pb.door(corr, stR, 'mid', 91, 'interiorGlass');
      const xm = Wd / 2;
      if (F < 0) {
        for (const [z0, z1] of [[t, zc0], [zc1, Dd - t]]) { const r = pb.room(F, { x0: xL, z0, x1: xR, z1 }, z0 === t ? 'laundry' : 'mechanical'); pb.door(corr, r, 'mid'); }
      } else if (F === 0) {
        const lobby = pb.room(F, { x0: xm - 700, z0: t, x1: xm + 700, z1: zc0 }, 'lobby', 'Lobby');
        pb.open(lobby, corr);
        const rest = pb.room(F, { x0: xL, z0: t, x1: xm - 700, z1: zc0 }, 'dining', 'Restaurant');
        pb.door(corr, rest, 'mid', 183, 'interiorGlass');
        const off = pb.room(F, { x0: xm + 700, z0: t, x1: xR, z1: zc0 }, 'office', 'Front office');
        pb.door(corr, off, 'start');
        const ball = pb.room(F, { x0: xm - 1400, z0: zc1, x1: xm + 1400, z1: Dd - t }, 'ballroom', 'Ballroom');
        pb.door(corr, ball, 'start', 183, 'interiorGlass'); pb.door(corr, ball, 'end', 183, 'interiorGlass');
        const kit = pb.room(F, { x0: xL, z0: zc1, x1: xm - 1400, z1: Dd - t }, 'kitchen', 'Kitchen');
        pb.door(corr, kit, 'mid'); pb.door(kit, rest, 'start');
        const rr = pb.room(F, { x0: xm + 1400, z0: zc1, x1: xR, z1: Dd - t }, 'restroom');
        pb.door(corr, rr, 'mid');
        pb.extDoors.push({ floor: 0, side: 'front', at: xm - 91, w: 183, h: 244, style: 'colonial:DOOR_BLACK', y: 0 });
        pb.extDoors.push({ floor: 0, side: 'left', at: Dd / 2 - 45, w: 91, h: 213, style: 'steel', y: 0 });
        pb.extDoors.push({ floor: 0, side: 'right', at: Dd / 2 - 45, w: 91, h: 213, style: 'steel', y: 0 });
      } else {
        // guest rooms each with a bath on the corridor side
        for (const [z0, z1, front] of [[t, zc0, true], [zc1, Dd - t, false]] as const) {
          const n = Math.floor((xR - xL) / 420);
          for (let i = 0; i < n; i++) {
            const x0 = Math.round(xL + ((xR - xL) * i) / n), x1 = Math.round(xL + ((xR - xL) * (i + 1)) / n);
            const bz0 = front ? zc0 - 240 : zc1, bz1 = front ? zc0 : zc1 + 240;
            const entry = pb.room(F, { x0: x0 + 180, z0: bz0, x1, z1: bz1 }, 'guest_room', `Room ${F}${String(i + (front ? 0 : n) + 1).padStart(2, '0')}`);
            const bath = pb.room(F, { x0, z0: bz0, x1: x0 + 180, z1: bz1 }, 'guest_bath');
            const main = pb.room(F, front ? { x0, z0, x1, z1: bz0 } : { x0, z0: bz1, x1, z1 }, 'guest_room');
            pb.door(corr, entry, 'mid'); pb.door(entry, bath, 'mid'); pb.open(entry, main);
          }
        }
      }
    }
    const across = 2 * sw + 10;
    stackStairs(pb, fl, (rise) => ({ x0: t + 15, z0: zc1 + 10, x1: t + 15 + across, z1: zc1 + 10 + uStairSize(rise, sw).along }), 'z+', sw, 'A');
    stackStairs(pb, fl, (rise) => ({ x0: Wd - t - 15 - across, z0: zc1 + 10, x1: Wd - t - 15, z1: zc1 + 10 + uStairSize(rise, sw).along }), 'z+', sw, 'B');
    pb.shafts.push({ rect: { x0: xL + 20, z0: zc1 + 10, x1: xL + 20 + SHAFT.w + 40, z1: zc1 + 10 + SHAFT.d + 40 }, floors: fl.map((f) => f.floor), door: 'z0' });
  }),
  exterior: (spec, plan, out) => {
    // deep two-storey porch across the front: 10 Doric columns, upper gallery with balustrade
    const g = out.g, depth = 420, colH = 4 * 0 + 450 + 340 - 20;
    boxC(g, 'tex:limestone', 300, -48, -depth - 40, W - 300, 0, 0);
    for (let i = 0; i < 10; i++) { g.push(); g.translate(C(320 + i * ((W - 700) / 9)), 0, C(-depth)); doricColumn(g, 55, colH); g.pop(); }
    boxC(g, 'tex:oak_floor', 300, 440, -depth - 20, W - 300, 450, 0); // upper gallery floor
    boxC(g, 'paint:CEILING_WHITE', 300, 430, -depth - 20, W - 300, 440, 0, 8);
    g.push(); g.translate(C(300), C(450), C(-depth - 10)); colonialBalustrade(g, W - 600); g.pop();
    boxC(g, 'satin:TRIM_WHITE', 280, colH, -depth - 40, W - 280, colH + 60, 0);
    boxC(g, 'tex:slate', 260, colH + 60, -depth - 60, W - 260, colH + 64, 0);
    void plan;
  },
  interior: (spec, plan, g) => {
    const f0 = plan.floors.find((f) => f.floor === 0)!;
    const lob = f0.rooms.find((r) => r.type === 'lobby');
    if (lob) { // front-desk counter (built-in), walnut with marble top
      boxC(g, 'tex:walnut', lob.rect.x0 + 300, 0, lob.rect.z1 - 260, lob.rect.x1 - 300, 107, lob.rect.z1 - 190);
      boxC(g, 'tex:marble', lob.rect.x0 + 295, 107, lob.rect.z1 - 265, lob.rect.x1 - 295, 112, lob.rect.z1 - 185);
    }
    const ball = f0.rooms.find((r) => r.type === 'ballroom');
    if (ball) { boxC(g, 'tex:oak_floor', ball.rect.x0 + 600, 0, ball.rect.z1 - 400, ball.rect.x1 - 600, 60, ball.rect.z1 - 10); }
    void spec;
  },
});
