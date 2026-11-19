// #4 Davies Stacks (CLAUDE.md §10): Brutalist, 8 floors of CONCRETE_BOARDFORM (15 cm boards, 1 cm seams,
// 0.2 cm grain relief). Interior: central atrium, open stack plates on 7 floors, study-room rings, two
// stair cores, 4 elevators.
import { C, boxC } from '../../kits/common';
import { generatePlan } from '../../interiors/floorplan';
import { SHAFT } from '../../interiors/finishes';
import { defaultFacade } from '../facades';
import { LANDMARK_HOOKS } from '../manager';
import { LANDMARKS } from '../../world/layout';
import { centered } from './common';
import type { BuildingSpec } from '../../interiors/types';

export function specs(): BuildingSpec[] {
  const site = LANDMARKS.find((l) => l.id === 'davies_stacks')!;
  return [centered(site, 8200, 3800, {
    id: 'LM04_DAVIES_STACKS', name: 'Davies Stacks', district: 'quarry', floors: 8, basement: false, attic: false,
    typology: 'library', plan: 'atrium', custom: 'davies', facade: defaultFacade('office_lab', { wall: 'tex:boardform', window: 'modern', winW: 180, winH: 120, bay: 420, cornice: 'none', parapetH: 120 }),
    seed: 'davies', public: true, tags: ['landmark'],
  })];
}
LANDMARK_HOOKS.set('davies', {
  plan: (spec) => {
    const p = generatePlan({ ...spec, custom: undefined });
    // three more elevators beside the first (4 total)
    const s0 = p.shafts[0];
    for (let i = 1; i < 4; i++) p.shafts.push({ ...s0, rect: { ...s0.rect, z0: s0.rect.z0 - i * (SHAFT.d + 60), z1: s0.rect.z1 - i * (SHAFT.d + 60) } });
    return p;
  },
  exterior: (spec, plan, out) => {
    // deep projecting concrete fins + cantilevered top band (brutalist)
    const g = out.g;
    for (let x = 210; x < spec.w; x += 420) boxC(g, 'tex:boardform', x - 30, 0, -90, x + 30, plan.roofY + 120, 0);
    boxC(g, 'tex:boardform', -90, plan.roofY - 300, -150, spec.w + 90, plan.roofY + 120, 0);
    void C;
  },
});
