// #15 Grove Amphitheatre (CLAUDE.md §10): stone-terraced outdoor theater in the ravine — fieldstone tiers,
// stage, and a small stone backstage building with interior (the building is the spec; tiers & stage are
// its exterior hero geometry).
import { Vector3 } from 'three';
import { C, boxC } from '../../kits/common';
import { stoneWall } from '../../kits/stone';
import { customPlan } from '../../interiors/floorplan';
import { defaultFacade } from '../facades';
import { LANDMARK_HOOKS } from '../manager';
import { LANDMARKS } from '../../world/layout';
import { arcTiers, centered } from './common';
import type { BuildingSpec } from '../../interiors/types';

const W = 1200, D = 700; // backstage building
export function specs(): BuildingSpec[] {
  const site = LANDMARKS.find((l) => l.id === 'grove_amphitheatre')!;
  return [centered({ ...site, x: site.x + 18, z: site.z }, W, D, {
    id: 'LM15_GROVE_AMPHITHEATRE', name: 'Grove Amphitheatre (backstage)', district: 'battle_ravine', floors: 1, basement: false, attic: false,
    typology: 'house', plan: 'custom', custom: 'grove', facade: defaultFacade('house', { wall: 'tex:fieldstone', roof: 'gable', roofKey: 'tex:slate', shutters: null, window: '6/6' }), seed: 'grove', public: true, tags: ['landmark'],
  })];
}

LANDMARK_HOOKS.set('grove', {
  plan: (spec) => customPlan(spec, (pb, fl, Wd, Dd, t) => {
    const back = pb.room(0, { x0: t, z0: t, x1: Wd / 2, z1: Dd - t }, 'backstage', 'Backstage');
    const d1 = pb.room(0, { x0: Wd / 2, z0: t, x1: Wd - t, z1: Dd / 2 }, 'dressing', 'Dressing room A');
    const d2 = pb.room(0, { x0: Wd / 2, z0: Dd / 2, x1: Wd - t, z1: Dd - t }, 'dressing', 'Dressing room B');
    pb.door(back, d1, 'mid'); pb.door(back, d2, 'mid');
    pb.extDoors.push({ floor: 0, side: 'front', at: 200, w: 183, h: 244, style: 'colonial:DOOR_GREEN', y: 0 });
    pb.extDoors.push({ floor: 0, side: 'back', at: Wd - 300, w: 91, h: 213, style: 'colonial:DOOR_GREEN', y: 0 });
    void fl;
  }),
  exterior: (spec, plan, out) => {
    // stage in front of the building (toward −z local), fieldstone tiers in a half-circle beyond it
    const g = out.g;
    boxC(g, 'tex:oak_floor', -200, -10, -900, W + 200, 0, 0, 4); // stage deck at FFL
    g.push(); g.translate(C(-200), C(-110), C(-940)); stoneWall(g, W + 400, 110, 40, 'grove-stagefront'); g.pop();
    const cx = W / 2, cz = -900 - 300;
    // 14 tiers, 90 cm deep, 45 cm rise, fanned 160° facing the stage, cut into the slope
    arcTiers(g, cx, cz, 700, 14, 90, 45, Math.PI - 1.4, Math.PI + 1.4, -100, 'tex:fieldstone');
    for (let k = 0; k < 14; k++) {
      // fill under each tier down to grade
      const r0 = 700 + k * 90;
      for (let i = 0; i < 16; i++) {
        const a = Math.PI - 1.4 + (2.8 * (i + 0.5)) / 16;
        boxC(g, 'tex:fieldstone', cx + Math.sin(a) * (r0 + 45) - 40, -400, cz + Math.cos(a) * (r0 + 45) - 40, cx + Math.sin(a) * (r0 + 45) + 40, -100 + k * 45, cz + Math.cos(a) * (r0 + 45) + 40, 4);
      }
    }
    for (let k = 0; k < 14; k++) {
      const r = 700 + k * 90, y = -100 + (k + 1) * 45, pts: Vector3[] = [];
      for (let i = 0; i <= 8; i++) { const a = Math.PI - 1.4 + (2.8 * i) / 8; pts.push(new Vector3(C(cx + Math.sin(a) * (r + 88)), C(y), C(cz + Math.cos(a) * (r + 88)))); }
      for (let i = 8; i >= 0; i--) { const a = Math.PI - 1.4 + (2.8 * i) / 8; pts.push(new Vector3(C(cx + Math.sin(a) * r), C(y), C(cz + Math.cos(a) * r))); }
      // convex pieces per wedge
      for (let i = 0; i < 8; i++) out.floors.push([pts[i], pts[i + 1], pts[16 - i - 1], pts[16 - i]]);
    }
    out.floors.push([new Vector3(C(-200), 0, C(-900)), new Vector3(C(W + 200), 0, C(-900)), new Vector3(C(W + 200), 0, 0), new Vector3(C(-200), 0, 0)]);
    void spec; void plan;
  },
});
