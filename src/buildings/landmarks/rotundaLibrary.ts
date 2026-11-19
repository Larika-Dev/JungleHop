// Shared plan/geometry for the domed classical libraries (#3 Wilberforce, #8 Ashgrove): temple-front
// portico, rotunda reading room open to a coffered dome, stack wings, basement vault, staff stairs.
import { C, boxC } from '../../kits/common';
import { customPlan, stackStairs, uStairSize, type PB } from '../../interiors/floorplan';
import { SHAFT } from '../../interiors/finishes';
import type { BuildingSpec, Plan, Rect } from '../../interiors/types';
import type { ExteriorOut } from '../exterior';
import { cofferedDome, drumDome, portico } from './common';

export interface RotundaOpts { rot: number; vest: number; columns: number; order: 'ionic' | 'doric'; domeR: number; drumH: number; porticoW: number; porticoDepth: number; colH: number; }

export function rotundaRect(spec: BuildingSpec, o: RotundaOpts): Rect {
  const cx = spec.w / 2, cz = 45 + o.vest + o.rot / 2;
  return { x0: cx - o.rot / 2, z0: cz - o.rot / 2, x1: cx + o.rot / 2, z1: cz + o.rot / 2 };
}

export function rotundaPlan(spec: BuildingSpec, o: RotundaOpts): Plan {
  return customPlan(spec, (pb: PB, fl, W, D, t) => {
    const R = rotundaRect(spec, o);
    const sw = 112, across = 2 * sw + 10;
    const sd = uStairSize(Math.max(...fl.map((f) => f.ftf)), sw).along + sw + 30;
    const svcZ0 = D - t - sd;
    for (const f of fl) {
      const F = f.floor;
      const wingL = pb.room(F, { x0: t, z0: t, x1: R.x0, z1: svcZ0 }, F < 0 ? 'vault' : 'stacks', F < 0 ? 'Special collections vault' : 'Stacks (west)');
      const wingR = pb.room(F, { x0: R.x1, z0: t, x1: W - t, z1: svcZ0 }, F < 0 ? 'storage' : 'stacks', F < 0 ? undefined : 'Stacks (east)');
      const vest = pb.room(F, { x0: R.x0, z0: t, x1: R.x1, z1: R.z0 }, F === 0 ? 'lobby' : F < 0 ? 'mechanical' : 'gallery', F === 0 ? 'Vestibule' : undefined);
      const rot = pb.room(F, { x0: R.x0, z0: R.z0, x1: R.x1, z1: R.z1 }, F < 0 ? 'storage' : F === 0 ? 'reading_room' : 'gallery', F === 0 ? 'Rotunda reading room' : 'Rotunda gallery');
      const back = pb.room(F, { x0: R.x0, z0: R.z1, x1: R.x1, z1: svcZ0 }, F < 0 ? 'storage' : 'office');
      const sA = pb.room(F, { x0: t, z0: svcZ0, x1: t + across + 30, z1: D - t }, 'stair', 'Staff stair A');
      const el = pb.room(F, { x0: t + across + 30, z0: svcZ0, x1: W - t - across - 30, z1: D - t }, 'hall', 'Staff hall');
      const sB = pb.room(F, { x0: W - t - across - 30, z0: svcZ0, x1: W - t, z1: D - t }, 'stair', 'Staff stair B');
      pb.fireWall(sA); pb.fireWall(sB);
      pb.door(el, sA, 'start'); pb.door(el, sB, 'start');
      pb.door(wingL, el, 'end'); pb.door(wingR, el, 'start'); pb.door(back, el, 'mid');
      if (F >= 0) { pb.open(vest, rot); pb.door(rot, wingL, 'mid', 183); pb.door(rot, wingR, 'mid', 183); pb.door(rot, back, 'mid'); pb.door(vest, wingL, 'mid'); }
      else { pb.door(vest, rot, 'mid'); pb.door(rot, wingL, 'mid'); pb.door(rot, wingR, 'mid'); pb.door(rot, back, 'mid'); }
      if (F > 0) pb.hole(F, { x0: R.x0 + 150, z0: R.z0 + 150, x1: R.x1 - 150, z1: R.z1 - 150 });
      if (F === 0) {
        pb.extDoors.push({ floor: 0, side: 'front', at: Math.round(W / 2) - 91, w: 183, h: 244, style: spec.facade.doorStyle, y: 0 });
        pb.extDoors.push({ floor: 0, side: 'back', at: Math.round(W / 2) - 45, w: 91, h: 213, style: 'steel', y: 0 });
      }
    }
    stackStairs(pb, fl, (rise) => ({ x0: t + 15, z0: D - t - 15 - uStairSize(rise, sw).along, x1: t + 15 + across, z1: D - t - 15 }), 'z+', sw, 'A');
    stackStairs(pb, fl, (rise) => ({ x0: W - t - 15 - across, z0: D - t - 15 - uStairSize(rise, sw).along, x1: W - t - 15, z1: D - t - 15 }), 'z+', sw, 'B');
    const ex = Math.round(W / 2 - (SHAFT.w + 40) / 2);
    pb.shafts.push({ rect: { x0: ex, z0: D - t - SHAFT.d - 50, x1: ex + SHAFT.w + 40, z1: D - t - 10 }, floors: fl.map((f) => f.floor), door: 'z0' });
  });
}

/** Rotunda opens to the dome: ceiling cut-out on the top floor. */
export function openRotunda(plan: Plan, o: RotundaOpts) {
  const R = rotundaRect(plan.spec, o);
  const top = plan.floors.filter((f) => f.floor < plan.spec.floors).slice(-1)[0];
  top.openCeiling = [{ x0: R.x0 + 150, z0: R.z0 + 150, x1: R.x1 - 150, z1: R.z1 - 150 }];
  const g0 = plan.floors.find((f) => f.floor === 0)!;
  g0.openCeiling = [{ x0: R.x0 + 150, z0: R.z0 + 150, x1: R.x1 - 150, z1: R.z1 - 150 }];
  for (const f of plan.floors) if (f.floor > 0 && f.floor < plan.spec.floors) f.openCeiling = [{ x0: R.x0 + 150, z0: R.z0 + 150, x1: R.x1 - 150, z1: R.z1 - 150 }];
}

export function rotundaExterior(spec: BuildingSpec, plan: Plan, out: ExteriorOut, o: RotundaOpts) {
  const g = out.g;
  const R = rotundaRect(spec, o);
  const cx = (R.x0 + R.x1) / 2, cz = (R.z0 + R.z1) / 2;
  portico(g, cx - o.porticoW / 2, o.porticoW, o.porticoDepth, o.colH, o.columns, o.order, 0, { tympanum: 'tex:limestone' });
  drumDome(g, cx, cz, o.domeR, o.drumH, plan.roofY + (spec.facade.parapetH ?? 90));
}

export function rotundaInterior(spec: BuildingSpec, plan: Plan, g: import('../../core/geo').GeoBuilder, o: RotundaOpts) {
  const R = rotundaRect(spec, o);
  const cx = (R.x0 + R.x1) / 2, cz = (R.z0 + R.z1) / 2;
  const y = plan.roofY + (spec.facade.parapetH ?? 90) + o.drumH + 12;
  cofferedDome(g, cx, cz, o.domeR - 30, y);
  // drum interior wall (ivory plaster) from roof to dome springing
  g.push(); g.translate(C(cx), 0, C(cz));
  g.lathe('paint:PLASTER_IVORY', [[C(o.domeR - 30), C(y)], [C(o.domeR - 30), C(plan.roofY - 10)]], 40);
  g.pop();
  // marble rotunda floor inlay + Ionic-ish pilasters around the open well
  boxC(g, 'tex:marble', R.x0 + 2, 0.2, R.z0 + 2, R.x1 - 2, 0.5, R.z1 - 2, 4);
  // walnut circulation desk (built-in service counter)
  boxC(g, 'tex:walnut', cx - 250, 0, cz + 200, cx + 250, 105, cz + 270);
  boxC(g, 'tex:marble', cx - 260, 105, cz + 195, cx + 260, 110, cz + 275);
}
