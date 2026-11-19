// #3 Wilberforce Library (CLAUDE.md §10): classical temple front with 6 Ionic columns, central COPPER_PATINA
// dome; MARBLE_WHITE rotunda reading room with coffered dome, two stack wings over 3 floors, basement
// special-collections vault, staff stairs.
import { defaultFacade } from '../facades';
import { LANDMARK_HOOKS } from '../manager';
import { LANDMARKS } from '../../world/layout';
import { centered } from './common';
import { openRotunda, rotundaExterior, rotundaInterior, rotundaPlan, type RotundaOpts } from './rotundaLibrary';
import type { BuildingSpec } from '../../interiors/types';

const O: RotundaOpts = { rot: 1500, vest: 500, columns: 6, order: 'ionic', domeR: 650, drumH: 260, porticoW: 1500, porticoDepth: 420, colH: 720 };

export function specs(): BuildingSpec[] {
  const site = LANDMARKS.find((l) => l.id === 'wilberforce_library')!;
  return [centered(site, 4200, 4600, {
    id: 'LM03_WILBERFORCE', name: 'Wilberforce Library', district: 'north_quad', floors: 3, basement: true, attic: false,
    typology: 'library', plan: 'custom', custom: 'wilberforce', facade: defaultFacade('library', { wall: 'brick:flemish:BRICK_CAMPUS_A', bay: 420, window: '9/9', winW: 120, winH: 280 }),
    seed: 'wilberforce', public: true, tags: ['landmark'],
  })];
}
LANDMARK_HOOKS.set('wilberforce', {
  plan: (spec) => { const p = rotundaPlan(spec, O); openRotunda(p, O); return p; },
  exterior: (spec, plan, out) => rotundaExterior(spec, plan, out, O),
  interior: (spec, plan, g) => rotundaInterior(spec, plan, g, O),
});
