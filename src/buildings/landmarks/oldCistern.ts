// #1 The Old Cistern (CLAUDE.md §10): open rotunda — 8 COLUMN_WHITE Doric columns on a circular stone
// platform with 3 steps, COPPER_PATINA dome with finial; built-in well curb over a 4 m-deep hollow shaft.
// No enclosed interior: one 'court' room record for metadata.
import { Vector3 } from 'three';
import { C, boxC } from '../../kits/common';
import { doricColumn } from '../../kits/column';
import { customPlan } from '../../interiors/floorplan';
import { defaultFacade } from '../facades';
import { LANDMARK_HOOKS } from '../manager';
import { LANDMARKS } from '../../world/layout';
import { centered } from './common';
import type { BuildingSpec } from '../../interiors/types';

const R_PLAT = 470, STEP = 16, STEP_D = 35, R_COL = 330, COL_D = 42, COL_H = 400, R_DOME = 400;

export function specs(): BuildingSpec[] {
  const site = LANDMARKS.find((l) => l.id === 'old_cistern')!;
  return [centered(site, 2 * R_PLAT, 2 * R_PLAT, {
    id: 'LM01_OLD_CISTERN', name: 'The Old Cistern', district: 'north_quad', floors: 1, basement: false, attic: false,
    typology: 'library', plan: 'custom', custom: 'old_cistern', facade: defaultFacade('library', { window: 'none' }), seed: 'cistern', public: true, tags: ['landmark'],
  })];
}

LANDMARK_HOOKS.set('old_cistern', {
  customShell: true,
  plan: (spec) => customPlan(spec, (pb, _fl, Wd, Dd, t) => {
    const c = R_PLAT;
    pb.room(0, { x0: t, z0: t, x1: Wd - t, z1: Dd - t }, 'court', 'Rotunda');
    pb.extDoors.push({ floor: 0, side: 'front', at: c - 100, w: 200, h: 300, style: 'none', y: 0 });
  }),
  exterior: (spec, _plan, out) => {
    const g = out.g, cx = R_PLAT, cz = R_PLAT;
    const top = 3 * STEP;
    g.push(); g.translate(C(cx), 0, C(cz));
    // three circular steps (worn centre dips are part of the tread texture)
    for (let i = 0; i < 3; i++) {
      const r = R_PLAT - i * STEP_D, y0 = -1.5 + i * STEP, y1 = (i + 1) * STEP;
      g.lathe('tex:limestone', [[C(r), C(y0 - 30)], [C(r), C(y1)], [C(r - 2.5), C(y1)]].map(([a, b]) => [a, b] as [number, number]), 48);
      g.disc('tex:limestone', C(r - 2.5), C(y1), 48, true, C(i < 2 ? R_PLAT - (i + 1) * STEP_D - 3 : 75));
      out.floors.push(circlePoly(r, y1, spec));
    }
    // 8 Doric columns
    for (let i = 0; i < 8; i++) {
      const a = (i / 8) * Math.PI * 2 + Math.PI / 8;
      g.push(); g.translate(C(Math.sin(a) * R_COL - COL_D * 0.65), C(top), C(Math.cos(a) * R_COL - COL_D * 0.65));
      doricColumn(g, COL_D, COL_H);
      g.pop();
      const p = new Vector3(Math.sin(a) * R_COL, 0, Math.cos(a) * R_COL);
      out.walls.push([C(cx + p.x - 15), C(cz + p.z), C(cx + p.x + 15), C(cz + p.z), C(top), C(top + COL_H), 0.3]);
    }
    // entablature ring
    const ey = top + COL_H;
    g.lathe('satin:TRIM_WHITE', [[C(R_COL - 40), C(ey)], [C(R_COL + 40), C(ey)], [C(R_COL + 40), C(ey + 55)], [C(R_COL + 55), C(ey + 62)], [C(R_COL + 58), C(ey + 72)], [C(R_COL - 40), C(ey + 72)], [C(R_COL - 40), C(ey)]], 48);
    // copper dome + lantern finial
    const prof: [number, number][] = [];
    for (let i = 0; i <= 14; i++) { const e = (i / 14) * (Math.PI / 2); prof.push([C(R_DOME * Math.cos(e)), C(ey + 72 + R_DOME * 0.62 * Math.sin(e))]); }
    g.lathe('tex:patina', prof, 48);
    g.lathe('paint:CEILING_WHITE', [...prof].reverse().map(([r, y]) => [Math.max(0.01, r - 0.12), y - 0.12] as [number, number]), 48);
    const dt = ey + 72 + R_DOME * 0.62;
    g.lathe('tex:patina', [[C(45), C(dt - 5)], [C(45), C(dt + 40)], [C(55), C(dt + 45)], [C(10), C(dt + 80)]], 12);
    g.lathe('metal:BRASS', [[C(6), C(dt + 80)], [C(12), C(dt + 95)], [C(4), C(dt + 115)], [C(9), C(dt + 125)], [C(0.5), C(dt + 160)]], 12);
    // well curb (built-in) and 4 m hollow shaft below
    g.lathe('tex:capstone', [[C(55), C(top)], [C(55), C(top + 72)], [C(78), C(top + 72)], [C(78), C(top + 80)], [C(52), C(top + 80)], [C(52), C(top - 400)]], 32);
    g.lathe('tex:fieldstone', [[C(78), C(top + 70)], [C(78), C(top)]], 32);
    g.disc('water', C(52), C(top - 380), 24, true);
    boxC(g, 'satin:IRON_BLACK', -60, top + 80, -2, 60, top + 82, 2); // windlass bar
    g.pop();
    for (let i = 0; i < 16; i++) {
      const a0 = (i / 16) * Math.PI * 2, a1 = ((i + 1) / 16) * Math.PI * 2;
      out.walls.push([C(cx + Math.sin(a0) * 78), C(cz + Math.cos(a0) * 78), C(cx + Math.sin(a1) * 78), C(cz + Math.cos(a1) * 78), C(top), C(top + 80), 0.1]);
    }
  },
});

function circlePoly(r: number, y: number, _spec: BuildingSpec): Vector3[] {
  const pts: Vector3[] = [];
  for (let i = 0; i < 16; i++) { const a = (i / 16) * Math.PI * 2; pts.push(new Vector3(C(R_PLAT + Math.sin(a) * r), C(y), C(R_PLAT + Math.cos(a) * r))); }
  return pts;
}
