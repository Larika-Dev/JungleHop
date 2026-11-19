// #6 Elder East / Elder West (CLAUDE.md §10): oldest dormitories, 4 floors, BRICK_CAMPUS_C with stucco end
// walls; double-loaded corridors, dorm doubles 3.4 x 4.6 m, floor restrooms, end stairs.
import { defaultFacade } from '../facades';
import { LANDMARKS } from '../../world/layout';
import { centered } from './common';
import type { BuildingSpec } from '../../interiors/types';

export function specs(): BuildingSpec[] {
  return (['elder_west', 'elder_east'] as const).map((id, i) => {
    const site = LANDMARKS.find((l) => l.id === id)!;
    // dorm doubles 340 wide x 460 deep: depth = 2 x 460 + 152 corridor + 2 x 45 walls + partitions
    return centered(site, 6000, 1200, {
      id: i ? 'LM06_ELDER_EAST' : 'LM06_ELDER_WEST', name: i ? 'Elder East' : 'Elder West', district: 'north_quad', floors: 4, basement: true, attic: true,
      typology: 'residence_historic', plan: 'double_loaded', facade: defaultFacade('residence_historic', { wall: 'brick:flemish:BRICK_CAMPUS_C', sideWall: 'tex:stucco', roof: 'gable', pitch: 40 }),
      seed: id, public: true, tags: ['landmark'],
    });
  });
}
