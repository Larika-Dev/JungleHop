// #9 Student Union & Dining Hall (CLAUDE.md §10): modern brick + glass. Union: 4 floors — food-court counters
// (built-in shells) on the ground floor, ballroom on 3, offices. Dining hall: 2 floors, servery counters,
// dining room, kitchen.
import { C, boxC } from '../../kits/common';
import { generatePlan } from '../../interiors/floorplan';
import { finishFor } from '../../interiors/finishes';
import { modernFixed } from '../../kits/window';
import { defaultFacade } from '../facades';
import { LANDMARK_HOOKS } from '../manager';
import { LANDMARKS } from '../../world/layout';
import { centered } from './common';
import type { BuildingSpec, Plan, RoomType } from '../../interiors/types';

export function specs(): BuildingSpec[] {
  const u = LANDMARKS.find((l) => l.id === 'student_union')!, d = LANDMARKS.find((l) => l.id === 'dining_hall')!;
  const fac = defaultFacade('modern_academic', { wall: 'brick:running:BRICK_CAMPUS_B', winW: 260, winH: 260, bay: 320 });
  return [
    centered(u, 4800, 4600, { id: 'LM09_STUDENT_UNION', name: 'Student Union', district: 'quarry', floors: 4, basement: false, attic: false, typology: 'modern_academic', plan: 'open_core', custom: 'union', facade: fac, seed: 'union', public: true, tags: ['landmark'] }),
    centered(d, 4800, 4000, { id: 'LM09_DINING_HALL', name: 'Dining Hall', district: 'quarry', floors: 2, basement: false, attic: false, typology: 'modern_academic', plan: 'open_core', custom: 'dining', facade: fac, seed: 'dining', public: true, tags: ['landmark'] }),
  ];
}

function retype(p: Plan, map: (floor: number, label: string | undefined, type: RoomType, i: number) => RoomType | null): Plan {
  for (const fp of p.floors) fp.rooms.forEach((r, i) => { const t = map(fp.floor, r.label, r.type, i); if (t && t !== r.type) { r.type = t; r.finish = finishFor(p.spec.typology, t); } });
  return p;
}
function curtainWall(spec: BuildingSpec, plan: Plan, g: import('../../core/geo').GeoBuilder) {
  // two-storey glass curtain wall band projecting from the ground-floor front
  g.push(); g.translate(C(spec.w * 0.25), 0, C(-60)); modernFixed(g, spec.w * 0.5, Math.min(plan.roofY, 820), 8, 2, 'glassFar'); g.pop();
  boxC(g, 'satin:ALUMINUM_STOREFRONT', spec.w * 0.25 - 20, Math.min(plan.roofY, 820), -80, spec.w * 0.75 + 20, Math.min(plan.roofY, 820) + 40, 0);
}

LANDMARK_HOOKS.set('union', {
  plan: (spec) => retype(generatePlan({ ...spec, custom: undefined }), (f, label, t) => (f === 0 && label === 'Lobby' ? 'food_court' : f === 2 && t === 'office' ? 'ballroom' : null)),
  exterior: (spec, plan, out) => curtainWall(spec, plan, out.g),
  interior: (spec, plan, g) => {
    // food-court counters (built-in service counter shells) along the front room
    const fp = plan.floors.find((f) => f.floor === 0)!;
    const fc = fp.rooms.find((r) => r.type === 'food_court');
    if (fc) for (let i = 0; i < 5; i++) {
      const x0 = fc.rect.x0 + 200 + i * ((fc.rect.x1 - fc.rect.x0 - 400) / 5);
      boxC(g, 'satin:ALUMINUM_STOREFRONT', x0, 0, fc.rect.z0 + 60, x0 + 480, 105, fc.rect.z0 + 140);
      boxC(g, 'tex:terrazzo', x0 - 5, 105, fc.rect.z0 + 55, x0 + 485, 109, fc.rect.z0 + 145);
      boxC(g, 'tex:subway', x0, 0, fc.rect.z0 + 2, x0 + 480, 240, fc.rect.z0 + 10, 16);
    }
    // ballroom stage platform on floor 2
    const f2 = plan.floors.find((f) => f.floor === 2);
    const br = f2?.rooms.find((r) => r.type === 'ballroom');
    if (f2 && br) boxC(g, 'tex:oak_floor', br.rect.x0 + 100, f2.y, br.rect.z1 - 500, br.rect.x0 + 900, f2.y + 76, br.rect.z1 - 20);
    void spec;
  },
});
LANDMARK_HOOKS.set('dining', {
  plan: (spec) => retype(generatePlan({ ...spec, custom: undefined }), (f, label, t, i) => (f === 0 && label === 'Lobby' ? 'dining' : f === 0 && t === 'dining' ? 'kitchen' : f === 1 && t === 'office' && i < 2 ? 'dining' : null)),
  exterior: (spec, plan, out) => curtainWall(spec, plan, out.g),
  interior: (spec, plan, g) => {
    const fp = plan.floors.find((f) => f.floor === 0)!;
    const din = fp.rooms.find((r) => r.type === 'dining');
    if (din) { // servery counters
      boxC(g, 'satin:GALV_STEEL', din.rect.x0 + 300, 0, din.rect.z1 - 220, din.rect.x1 - 300, 92, din.rect.z1 - 150);
      boxC(g, 'glass', din.rect.x0 + 300, 120, din.rect.z1 - 210, din.rect.x1 - 300, 121, din.rect.z1 - 160);
    }
    const k = fp.rooms.find((r) => r.type === 'kitchen');
    if (k) for (let x = k.rect.x0 + 150; x < k.rect.x1 - 300; x += 500) boxC(g, 'satin:GALV_STEEL', x, 0, k.rect.z0 + 200, x + 300, 90, k.rect.z0 + 290); // prep islands
    void spec;
  },
});
