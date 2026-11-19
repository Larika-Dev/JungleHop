// Hamilton Strip & The Summit (CLAUDE.md §9.1/§9.2/§11): continuous 2–4 storey storefront blocks on the
// north side, storefronts on the south side west of The Summit and east of the North Quad wall, the §11
// roster around The Summit, 2–3 newer 6–9 storey mixed-use buildings set back above a 3-storey base,
// upper floors as apartments/offices, rear service zones on the alleys.
import { Rng } from '../core/rng';
import { defaultFacade } from '../buildings/facades';
import { rowHalf } from '../world/layout';
import { DISTRICT_GENERATORS } from '../world/districtRegistry';
import type { CityPlanBuilder } from '../world/cityPlan';
import type { BuildingSpec } from '../interiors/types';
import { ROSTER, bizSpec, generateBusiness, type Biz } from './businesses';
import './cinema';

const ROW = rowHalf('hamilton') + 0.05; // back of sidewalk (m) + 5 cm
export const HAMILTON_NAMES: { name: string; real?: string; type: string; id: string }[] = [];

DISTRICT_GENERATORS.push({
  name: 'hamilton', order: 10,
  run: (b: CityPlanBuilder) => {
    const rng = new Rng('hamilton-lots');
    const used = new Set<string>(ROSTER.map((r) => r.name));
    // roster placement: [business index, side, preferred x (west edge), width cm]
    const roster: [number, 'N' | 'S', number][] = [
      [1, 'N', 9.5], // Top of the Mount — NE corner of The Summit
      [11, 'N', -27.5], // Bluebird Savings Bank — NW corner
      [0, 'S', -26], // Sutter's — SW corner
      [2, 'N', 28], // Junior Varsity Cinema
      [3, 'N', 47], [4, 'N', 58], [5, 'N', 69], [12, 'N', 81], [7, 'N', 92], [9, 'N', 104],
      [6, 'S', -40], [8, 'S', -52], [10, 'S', -64], [13, 'S', -77], [14, 'N', -40], [15, 'N', -52], [16, 'N', -64], [17, 'N', -78],
    ];
    const placed = new Set<number>();
    let n = 0;
    const mk = (biz: Biz, side: 'N' | 'S', x0: number, w: number, d: number, floors: number, tags: string[] = []): BuildingSpec | null => {
      // north side faces south (rotY π, origin at the lot's east end); south side faces north (rotY 0)
      const base = {
        id: `HAM_${side}_${String(n).padStart(3, '0')}`, name: biz.name, district: 'hamilton_strip' as const,
        x: side === 'N' ? x0 + w / 100 : x0, z: side === 'N' ? -ROW : ROW, rotY: side === 'N' ? Math.PI : 0, y: 0,
        w, d, floors, basement: biz.type === 'diner' || biz.type === 'hardware' || biz.type === 'cafe' || rng.chance(0.25), attic: tags.includes('roofdeck'),
        seed: `ham-${n}`, party: { left: true, right: true }, tags,
      };
      const spec = bizSpec(biz, base, defaultFacade('downtown_commercial'));
      if (!b.clear(spec, 0.05)) return null;
      if (!b.add(spec, { check: false })) return null;
      n++;
      HAMILTON_NAMES.push({ name: biz.name, real: biz.real, type: biz.type, id: spec.id });
      return spec;
    };
    for (const [i, side, x] of roster) {
      const biz = ROSTER[i];
      const w = biz.width ?? rng.int(8, 12) * 100, d = biz.depth ?? rng.int(22, 28) * 100;
      const fl = biz.floors ?? (biz.upstairs ? 2 : rng.int(2, 3));
      const tags = biz.type === 'brewpub' ? ['roofdeck'] : [];
      for (const dx of [0, 1, -1, 2, -2, 3, -3, 4, -4, 6, -6, 8, -8, 10, -10, 13, -13]) if (mk(biz, side, x + dx, w, d, fl, tags)) { placed.add(i); break; }
    }
    // fill the remaining frontage with generated businesses (continuous blocks)
    const fill = (side: 'N' | 'S', xa: number, xb: number) => {
      let x = xa;
      let towers = 0;
      while (x < xb - 6) {
        const w = rng.int(7, 13) * 100;
        const tower = side === 'N' && towers < 3 && rng.chance(0.06) && x > -380 && x < 300;
        const biz = generateBusiness(rng, used);
        const spec = tower
          ? mk(biz, side, x, 1600, 2600, 3, ['mixed-base', 'roofdeck'])
          : mk(biz, side, x, w, rng.int(20, 28) * 100, rng.weighted([[2, 4], [3, 4], [4, 2]]));
        if (spec) {
          if (tower) { towers++; mixedTower(b, spec, n++); }
          x += spec.w / 100 + 0.02;
        } else x += 1.5;
      }
    };
    fill('N', -420, 380);
    fill('S', -420, -2);
    fill('S', 300, 380);
  },
});

/** Newer 6–9 storey mixed-use tower set back 6 m above its 3-storey base (sits on the base roof). */
function mixedTower(b: CityPlanBuilder, base: BuildingSpec, n: number) {
  const back = 600; // setback (cm)
  const floors = 3 + 3 + (n % 4); // 6..9 storeys including the base
  const c = Math.cos(base.rotY), s = Math.sin(base.rotY);
  const ox = base.x + (back / 100) * s, oz = base.z + (back / 100) * c;
  const spec: BuildingSpec = {
    id: `${base.id}_TWR`, name: `${base.name} Residences`, district: 'hamilton_strip', x: ox, z: oz, rotY: base.rotY, y: 0,
    w: base.w, d: base.d - back, floors: floors - 3, basement: false, attic: false, typology: 'office_lab', plan: 'open_core',
    facade: defaultFacade('office_lab', { wall: 'brick:running:BRICK_DOWNTOWN_B', window: 'modern' }), seed: `twr-${n}`, tags: ['onroof'], public: false,
  };
  b.reserveOnRoof(spec, base);
}
