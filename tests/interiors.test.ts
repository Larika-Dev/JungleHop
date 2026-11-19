// CLAUDE.md §7.3 / §19 interior rules over a randomized battery of buildings in every typology:
// ≥ 1 room per floor, every room reachable from an exterior door, all floors reachable by stairs,
// elevators where required, two exits per floor over two floors, no door swinging into a stair,
// every room carries itemSlots: [] and metadata; stairs obey riser/tread limits.
import { describe, expect, it } from 'vitest';
import { generatePlan } from '../src/interiors/floorplan';
import { validatePlan } from '../src/interiors/validate';
import { allRoomMeta } from '../src/interiors/roomMeta';
import { solveRisers } from '../src/kits/stair';
import { defaultFacade } from '../src/buildings/facades';
import { Rng } from '../src/core/rng';
import type { BuildingSpec, PlanKind, Typology } from '../src/interiors/types';

const KINDS: [Typology, PlanKind, [number, number], [number, number], [number, number]][] = [
  ['historic_academic', 'double_loaded', [3000, 5000], [1550, 1800], [2, 4]],
  ['residence_historic', 'double_loaded', [3000, 4200], [1150, 1300], [3, 4]],
  ['residence_highrise', 'double_loaded', [4000, 5200], [1400, 1600], [9, 11]],
  ['hospital', 'double_loaded', [4400, 5600], [1900, 2200], [8, 12]],
  ['inn', 'double_loaded', [3600, 4800], [1600, 1800], [3, 4]],
  ['downtown_commercial', 'shotgun', [600, 1200], [2000, 3000], [2, 4]],
  ['bar', 'shotgun', [600, 900], [1800, 2600], [2, 3]],
  ['house', 'center_hall', [1000, 1400], [850, 1200], [1, 2]],
  ['office_lab', 'open_core', [2600, 4000], [2000, 2800], [3, 7]],
  ['modern_academic', 'open_core', [1800, 3000], [1600, 2400], [2, 4]],
  ['modern_academic', 'single_loaded', [2600, 3600], [1050, 1250], [2, 4]],
  ['library', 'atrium', [3000, 4200], [2600, 3400], [2, 4]],
  ['parking', 'parking', [6000, 7200], [3000, 3400], [4, 6]],
];

const specs: BuildingSpec[] = [];
const rng = new Rng('interiors-test');
let n = 0;
for (const [t, p, W, D, F] of KINDS) for (let k = 0; k < 4; k++) {
  specs.push({
    id: `X${n++}`, district: 'campus_generic', x: 0, z: 0, rotY: 0, y: 0,
    w: rng.int(W[0], W[1]), d: rng.int(D[0], D[1]), floors: rng.int(F[0], F[1]),
    basement: rng.chance(0.5), attic: t === 'house' || t === 'historic_academic' ? rng.chance(0.5) : false,
    typology: t, plan: p, facade: defaultFacade(t), seed: `x${n}`,
    public: ['historic_academic', 'modern_academic', 'hospital', 'library', 'inn', 'parking', 'office_lab'].includes(t),
  });
}

describe('interior plans', () => {
  for (const s of specs) {
    it(`${s.id} ${s.typology}/${s.plan} ${s.w}x${s.d} F${s.floors}${s.basement ? '+B' : ''}${s.attic ? '+A' : ''}`, () => {
      const plan = generatePlan(s);
      const v = validatePlan(plan);
      expect(v.errors).toEqual([]);
      for (const fp of plan.floors) expect(fp.rooms.length, `floor ${fp.floor}`).toBeGreaterThan(0);
      for (const st of plan.stairs) {
        const { riser } = solveRisers(st.rise);
        expect(riser).toBeLessThanOrEqual(17.8 + 1e-9);
      }
      const metas = allRoomMeta(plan);
      for (const m of metas) {
        expect(m.itemSlots).toEqual([]);
        expect(m.roomId).toMatch(/^CM_X\d+_F-?\d+_R\d+$/);
        expect(m.areaM2).toBeGreaterThan(0.5);
        expect(['INTERIOR_WARM', 'INTERIOR_COOL']).toContain(m.lightingKey);
      }
      // interior doors at least 91 cm (except historic exceptions: none in generated plans)
      for (const fp of plan.floors) for (const w of fp.walls) for (const o of w.openings) if (o.kind === 'door') expect(o.w).toBeGreaterThanOrEqual(91);
      for (const d of plan.extDoors) { expect(d.w).toBeGreaterThanOrEqual(91); expect(d.h).toBeGreaterThanOrEqual(213); }
    });
  }
});
