// #13 ONSU Medical Center (CLAUDE.md §9.8/§10): 4 towers (8–12 floors) linked by glass skybridges at
// floor 3, ER bay with canopy, helipad on the tallest tower roof, 2 parking decks. Hospital finish rules.
import { Vector3 } from 'three';
import { C, boxC, bar } from '../../kits/common';
import { generatePlan } from '../../interiors/floorplan';
import { defaultFacade } from '../facades';
import { LANDMARK_HOOKS } from '../manager';
import type { BuildingSpec, Plan } from '../../interiors/types';

const FAC = defaultFacade('hospital');
// floor 3 FFL above ground = 480 + 430 * 2
export const SKY_Y = 480 + 430 * 2;
const T = (id: string, name: string, x: number, z: number, w: number, d: number, floors: number, tags: string[] = []): BuildingSpec => ({
  id, name, district: 'medical', x, z, rotY: 0, y: 0, w, d, floors, basement: true, attic: false, typology: 'hospital', plan: 'double_loaded',
  custom: 'medical_tower', facade: FAC, seed: id, public: true, tags: ['landmark', ...tags],
});
export function specs(): BuildingSpec[] {
  return [
    T('LM13_MED_TOWER_A', 'Medical Tower A', -432, 602, 5400, 2200, 8, ['bridge-right', 'bridge-back']),
    T('LM13_MED_TOWER_B', 'Medical Tower B', -346, 602, 5400, 2200, 9, ['bridge-left', 'bridge-back']),
    T('LM13_MED_TOWER_C', 'Medical Tower C', -432, 690, 5400, 2200, 10, ['bridge-right', 'bridge-front']),
    T('LM13_MED_TOWER_D', 'Medical Tower D (ER, helipad)', -346, 690, 5400, 2200, 12, ['bridge-left', 'bridge-front', 'helipad', 'er']),
    { ...T('LM13_MED_DECK_1', 'Medical Deck 1', -440, 818, 8000, 3200, 5), typology: 'parking', plan: 'parking', custom: undefined, facade: defaultFacade('parking'), tags: ['landmark'] },
    { ...T('LM13_MED_DECK_2', 'Medical Deck 2', -330, 818, 8000, 3200, 5), typology: 'parking', plan: 'parking', custom: undefined, facade: defaultFacade('parking'), tags: ['landmark'] },
  ];
}

LANDMARK_HOOKS.set('medical_tower', {
  plan: (spec): Plan => {
    const p = generatePlan({ ...spec, custom: undefined });
    // bridge doors at floor 3 (stair rooms at the ends; elevator lobby at the back/front centre)
    const fl = p.floors.find((f) => f.floor === 2)!; // floor index 2 = third storey
    const tags = spec.tags ?? [];
    for (const side of ['left', 'right', 'front', 'back'] as const) if (tags.includes(`bridge-${side}`)) {
      const len = side === 'left' || side === 'right' ? spec.d : spec.w;
      p.extDoors.push({ floor: 2, side, at: Math.round(len / 2 - 91), w: 183, h: 213, style: 'interiorGlass', y: fl.y });
      p.windows = p.windows.filter((w) => !(w.floor === 2 && w.side === side && Math.abs(w.at + w.w / 2 - len / 2) < 200));
    }
    return p;
  },
  exterior: (spec, plan, out) => {
    const g = out.g, tags = spec.tags ?? [];
    // skybridges (glass corridor 350 wide x 350 tall) out to the neighbour (half length each side; neighbours meet mid-gap)
    const bridge = (side: string, len: number) => {
      const W = spec.w, D = spec.d;
      g.push();
      if (side === 'right') { g.translate(C(W), C(SKY_Y), C(D / 2 - 175)); }
      else if (side === 'left') { g.translate(C(-len), C(SKY_Y), C(D / 2 - 175)); }
      else if (side === 'back') { g.translate(C(W / 2 - 175), C(SKY_Y), C(D)); g.rotateY(-Math.PI / 2); g.translate(0, 0, C(-350)); }
      else { g.translate(C(W / 2 - 175), C(SKY_Y), C(-len)); g.rotateY(-Math.PI / 2); g.translate(0, 0, C(-350)); }
      boxC(g, 'satin:GALV_STEEL', 0, -60, -10, len, 0, 360); // deck
      boxC(g, 'tex:vct', 0, 0, 0, len, 1, 350, 4);
      boxC(g, 'satin:GALV_STEEL', 0, 350, -10, len, 380, 360); // roof
      for (const z of [-5, 355]) { g.quad('glass', [0, 0, C(z)], [C(len), 0, C(z)], [C(len), C(350), C(z)], [0, C(350), C(z)]); boxC(g, 'satin:GALV_STEEL', 0, 100, z - 3, len, 106, z + 3); }
      for (let x = 0; x <= len; x += 300) for (const z of [-8, 352]) boxC(g, 'satin:GALV_STEEL', x, 0, z, x + 8, 350, z + 8);
      g.pop();
      // walkable deck (local coords of this tower)
      const p = side === 'right' ? [W, D / 2 - 175, W + len, D / 2 + 175] : side === 'left' ? [-len, D / 2 - 175, 0, D / 2 + 175] : side === 'back' ? [W / 2 - 175, D, W / 2 + 175, D + len] : [W / 2 - 175, -len, W / 2 + 175, 0];
      out.floors.push([new Vector3(C(p[0]), C(SKY_Y), C(p[1])), new Vector3(C(p[2]), C(SKY_Y), C(p[1])), new Vector3(C(p[2]), C(SKY_Y), C(p[3])), new Vector3(C(p[0]), C(SKY_Y), C(p[3]))]);
      const isX = side === 'left' || side === 'right';
      for (const off of [-175, 175]) {
        if (isX) out.walls.push([C(p[0]), C(D / 2 + off), C(p[2]), C(D / 2 + off), C(SKY_Y), C(SKY_Y + 350), 0.1]);
        else out.walls.push([C(W / 2 + off), C(p[1]), C(W / 2 + off), C(p[3]), C(SKY_Y), C(SKY_Y + 350), 0.1]);
      }
    };
    const gapX = ((-346) - (-432 + 54)) * 100 / 2; // half of the 32 m gap between A|B and C|D
    const gapZ = (690 - (602 + 22)) * 100 / 2; // half of the 66 m gap between A|C and B|D
    if (tags.includes('bridge-right')) bridge('right', gapX);
    if (tags.includes('bridge-left')) bridge('left', gapX);
    if (tags.includes('bridge-back')) bridge('back', gapZ);
    if (tags.includes('bridge-front')) bridge('front', gapZ);
    if (tags.includes('helipad')) {
      const y = plan.roofY + 20, cx = spec.w / 2, cz = spec.d / 2;
      g.push(); g.translate(C(cx), C(y), C(cz));
      g.cylinder('tex:concrete_new', C(950), C(-20), C(0), 48, true);
      g.disc('mark:MARKING_YELLOW', C(940), C(0.4), 48, true, C(900));
      g.disc('mark:MARKING_WHITE', C(620), C(0.4), 48, true, C(580));
      boxC(g, 'mark:MARKING_WHITE', -200, 0.6, -300, -120, 1, 300); boxC(g, 'mark:MARKING_WHITE', 120, 0.6, -300, 200, 1, 300); boxC(g, 'mark:MARKING_WHITE', -120, 0.6, -40, 120, 1, 40);
      for (let i = 0; i < 16; i++) { const a = (i / 16) * Math.PI * 2; g.cylinder('glow:MARKING_YELLOW', C(8), C(0), C(12), 8, true, C(Math.sin(a) * 960), C(Math.cos(a) * 960)); }
      g.pop();
      out.floors.push([new Vector3(C(cx - 900), C(y), C(cz - 900)), new Vector3(C(cx + 900), C(y), C(cz - 900)), new Vector3(C(cx + 900), C(y), C(cz + 900)), new Vector3(C(cx - 900), C(y), C(cz + 900))]);
    }
    if (tags.includes('er')) {
      // ER bay canopy on the east side: steel columns, deep flat canopy with downlights
      const x0 = spec.w, z0 = 300, w = 1400, d = 1100, h = 520;
      boxC(g, 'satin:ALUMINUM_STOREFRONT', x0, h, z0, x0 + w, h + 90, z0 + d);
      boxC(g, 'paint:NEON_RED', x0 + w - 2, h + 10, z0 + 200, x0 + w + 2, h + 80, z0 + d - 200); // EMERGENCY band (letters in signage pass)
      for (const [x, z] of [[x0 + w - 60, z0 + 60], [x0 + w - 60, z0 + d - 60]]) boxC(g, 'satin:GALV_STEEL', x - 20, 0, z - 20, x + 20, h, z + 20);
      for (let x = x0 + 150; x < x0 + w; x += 300) for (let z = z0 + 150; z < z0 + d; z += 300) boxC(g, 'emit:LAMP_LED', x - 30, h - 1, z - 30, x + 30, h, z + 30, 8);
      boxC(g, 'tex:concrete_new', x0, -2, z0 - 200, x0 + w + 400, 2, z0 + d + 200, 4);
      bar(g, 'satin:MARKING_YELLOW', [C(x0 + w + 300), 0, C(z0)], [C(x0 + w + 300), C(100), C(z0)], C(15));
    }
  },
});
