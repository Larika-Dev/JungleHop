// #8 Founders' Quad library — "Ashgrove Library" (CLAUDE.md §10, Phase-1 naming): domed, faces Founders'
// Hall across the lawn; 2-floor reading room under a tall drum dome, stack wings, basement stacks.
import { defaultFacade } from '../facades';
import { LANDMARK_HOOKS } from '../manager';
import { LANDMARKS } from '../../world/layout';
import { centered } from './common';
import { openRotunda, rotundaExterior, rotundaInterior, rotundaPlan, type RotundaOpts } from './rotundaLibrary';
import type { BuildingSpec } from '../../interiors/types';

const O: RotundaOpts = { rot: 1900, vest: 600, columns: 6, order: 'ionic', domeR: 850, drumH: 520, porticoW: 1800, porticoDepth: 480, colH: 860 };

export function specs(): BuildingSpec[] {
  const site = LANDMARKS.find((l) => l.id === 'ashgrove_library')!;
  return [centered(site, 5600, 4000, {
    id: 'LM08_ASHGROVE', name: 'Ashgrove Library', district: 'founders_quad', floors: 2, basement: true, attic: false,
    typology: 'library', plan: 'custom', custom: 'ashgrove', facade: defaultFacade('library', { wall: 'brick:flemish:BRICK_CAMPUS_B', bay: 400, quoins: true }),
    seed: 'ashgrove', public: true, tags: ['landmark'],
  })];
}
LANDMARK_HOOKS.set('ashgrove', {
  plan: (spec) => { const p = rotundaPlan(spec, O); openRotunda(p, O); return p; },
  exterior: (spec, plan, out) => rotundaExterior(spec, plan, out, O),
  interior: (spec, plan, g) => rotundaInterior(spec, plan, g, O),
});
