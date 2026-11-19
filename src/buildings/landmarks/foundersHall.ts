// #5 Founders' Hall (CLAUDE.md §10): Georgian, 3 floors, columned portico, cupola. Interior: central stair
// hall with a curved staircase, double-loaded office floors in both wings, end stairs, attic.
import { C, boxC } from '../../kits/common';
import { spiralStair, solveRisers } from '../../kits/stair';
import { customPlan, stackStairs, uStairSize } from '../../interiors/floorplan';
import { CORRIDOR, SHAFT } from '../../interiors/finishes';
import { defaultFacade } from '../facades';
import { LANDMARK_HOOKS } from '../manager';
import { LANDMARKS } from '../../world/layout';
import { centered, portico } from './common';
import type { BuildingSpec, Rect, RoomType } from '../../interiors/types';

const W = 5200, D = 1800, HALL = 1000, CURVE_R = 260;

export function specs(): BuildingSpec[] {
  const site = LANDMARKS.find((l) => l.id === 'founders_hall')!;
  return [centered(site, W, D, {
    id: 'LM05_FOUNDERS_HALL', name: "Founders' Hall", district: 'founders_quad', floors: 3, basement: true, attic: true,
    typology: 'historic_academic', plan: 'custom', custom: 'founders_hall', facade: defaultFacade('historic_academic', { quoins: true, cornice: 'dentil' }),
    seed: 'founders', public: true, tags: ['landmark', 'cupola'],
  })];
}

const curveRect = (): Rect => ({ x0: W / 2 - CURVE_R, z0: D - 45 - 120 - 2 * CURVE_R, x1: W / 2 + CURVE_R, z1: D - 45 - 120 });

LANDMARK_HOOKS.set('founders_hall', {
  plan: (spec) => customPlan(spec, (pb, fl, Wd, Dd, t) => {
    const cw = CORRIDOR.academic, zc0 = Math.round((Dd - cw) / 2), zc1 = zc0 + cw;
    const sw = 112, SW = 2 * sw + 10 + 30;
    const hx0 = Wd / 2 - HALL / 2, hx1 = Wd / 2 + HALL / 2;
    for (const f of fl) {
      const F = f.floor, attic = F >= spec.floors, base = F < 0;
      const hall = pb.room(F, { x0: hx0, z0: t, x1: hx1, z1: Dd - t }, attic ? 'attic' : base ? 'mechanical' : 'hall', F === 0 ? 'Stair hall' : 'Upper hall');
      for (const side of [0, 1]) {
        const xs = side ? hx1 : t + SW, xe = side ? Wd - t - SW : hx0;
        const st = pb.room(F, side ? { x0: Wd - t - SW, z0: t, x1: Wd - t, z1: Dd - t } : { x0: t, z0: t, x1: t + SW, z1: Dd - t }, 'stair', side ? 'Stair B' : 'Stair A');
        pb.fireWall(st);
        const corr = pb.room(F, { x0: xs, z0: zc0, x1: xe, z1: zc1 }, attic ? 'attic' : 'corridor');
        pb.door(corr, st, 'mid', 91, 'interiorGlass');
        if (attic) pb.open(corr, hall); else pb.door(corr, hall, 'mid', 183, 'interiorGlass');
        const n = Math.max(1, Math.round((xe - xs) / 560));
        for (const [z0, z1, front] of [[t, zc0, true], [zc1, Dd - t, false]] as const) for (let i = 0; i < n; i++) {
          const x0 = Math.round(xs + ((xe - xs) * i) / n), x1 = Math.round(xs + ((xe - xs) * (i + 1)) / n);
          const ty: RoomType = attic ? 'attic' : base ? (i % 2 ? 'storage' : 'mechanical') : !front && i === (side ? 0 : n - 1) ? 'restroom' : F === 0 && front ? 'office' : i % 3 === 1 ? 'study' : 'office';
          const r = pb.room(F, { x0, z0, x1, z1 }, ty, F === 1 && front && i === 0 && side === 0 ? "President's office" : undefined);
          if (attic) pb.open(r, corr); else pb.door(corr, r, front ? 'start' : 'end');
        }
      }
      if (F > 0 && F < spec.floors) pb.hole(F, curveRect());
      if (F === 0) {
        pb.extDoors.push({ floor: 0, side: 'front', at: Wd / 2 - 91, w: 183, h: 244, style: 'colonial:DOOR_BLACK', y: 0 });
        pb.extDoors.push({ floor: 0, side: 'left', at: Dd / 2 - 45, w: 91, h: 213, style: 'steel', y: 0 });
        pb.extDoors.push({ floor: 0, side: 'right', at: Dd / 2 - 45, w: 91, h: 213, style: 'steel', y: 0 });
      }
    }
    const across = 2 * sw + 10;
    stackStairs(pb, fl, (rise) => ({ x0: t + 15, z0: zc1 + 10, x1: t + 15 + across, z1: zc1 + 10 + uStairSize(rise, sw).along }), 'z+', sw, 'A');
    stackStairs(pb, fl, (rise) => ({ x0: Wd - t - 15 - across, z0: zc0 - 10 - uStairSize(rise, sw).along, x1: Wd - t - 15, z1: zc0 - 10 }), 'z-', sw, 'B');
    // curved grand stair in the hall between floors 0..top
    const main = fl.filter((f) => f.floor >= 0 && f.floor < spec.floors);
    for (let i = 0; i < main.length - 1; i++) pb.stairs.push({ id: `C${i}`, floor: main[i].floor, toFloor: main[i + 1].floor, rect: curveRect(), kind: 'spiral', w: 200, dir: 'z+', rise: main[i].ftf });
    pb.shafts.push({ rect: { x0: Wd / 2 - (SHAFT.w + 40) / 2, z0: t + 20, x1: Wd / 2 + (SHAFT.w + 40) / 2, z1: t + 20 + SHAFT.d + 40 }, floors: fl.map((f) => f.floor), door: 'z1' });
  }),
  exterior: (spec, plan, out) => {
    // two-storey tetrastyle Doric portico at the center of the front
    portico(out.g, W / 2 - 750, 1500, 380, 860, 4, 'doric');
    void plan; void spec;
  },
  interior: (spec, plan, g) => {
    // the curved (helical) grand stair: 3 m treads swept around a 2.6 m radius well
    const main = plan.floors.filter((f) => f.floor >= 0 && f.floor < spec.floors);
    const r = curveRect();
    for (let i = 0; i < main.length - 1; i++) {
      g.push(); g.translate(C(r.x0), C(main[i].y), C(r.z0));
      const { n } = solveRisers(main[i].ftf);
      spiralStair(g, main[i].ftf, CURVE_R, 60, Math.max(14, Math.round(n * 1.15)), 'tex:marble');
      g.pop();
    }
    // walnut newel + rail at the well
    g.push(); g.translate(C(W / 2), 0, C((r.z0 + r.z1) / 2)); g.cylinder('tex:walnut', C(14), 0, C(110), 12, true); g.pop();
    boxC(g, 'satin:WALNUT_DARK', W / 2 - 500, 0, 45, W / 2 - 495, 1, 46);
  },
});
