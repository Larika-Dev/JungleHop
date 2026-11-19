// #7 Moorhouse Observatory (CLAUDE.md §10): brick building with a 20 m COPPER_PATINA dome and a sundial
// garden. Interior: lobby rotunda, dome theater with stepped seating tiers (platforms only), offices,
// rooftop observation deck.
import { C, boxC } from '../../kits/common';
import { customPlan, stackStairs, uStairSize } from '../../interiors/floorplan';
import { SHAFT } from '../../interiors/finishes';
import { ironPicket } from '../../kits/railing';
import { defaultFacade } from '../facades';
import { LANDMARK_HOOKS } from '../manager';
import { LANDMARKS } from '../../world/layout';
import { arcTiers, centered, cofferedDome, drumDome, portico } from './common';
import type { BuildingSpec } from '../../interiors/types';

const W = 7000, D = 6400, THR = 2400; // theater square (dome r 1000 above)

export function specs(): BuildingSpec[] {
  const site = LANDMARKS.find((l) => l.id === 'moorhouse')!;
  return [centered(site, W, D, {
    id: 'LM07_MOORHOUSE', name: 'Moorhouse Observatory', district: 'hamilton_strip', floors: 2, basement: false, attic: true,
    typology: 'historic_academic', plan: 'custom', custom: 'moorhouse', facade: defaultFacade('historic_academic', { roof: 'flat', cornice: 'dentil', parapetH: 107, wall: 'brick:flemish:BRICK_CAMPUS_B', roofKey: 'tex:tpo' }),
    seed: 'moorhouse', public: true, tags: ['landmark', 'roofdeck'],
  })];
}
const thr = () => ({ x0: W / 2 - THR / 2, z0: D / 2 - THR / 2 + 300, x1: W / 2 + THR / 2, z1: D / 2 + THR / 2 + 300 });

LANDMARK_HOOKS.set('moorhouse', {
  plan: (spec) => customPlan(spec, (pb, fl, Wd, Dd, t) => {
    const T = thr();
    const sw = 112, across = 2 * sw + 10;
    for (const f of fl) {
      const F = f.floor, deck = F >= spec.floors;
      const lob = pb.room(F, { x0: T.x0, z0: t, x1: T.x1, z1: T.z0 }, deck ? 'deck' : F === 0 ? 'lobby' : 'gallery', F === 0 ? 'Lobby rotunda' : deck ? 'Observation deck' : undefined);
      const th = pb.room(F, { x0: T.x0, z0: T.z0, x1: T.x1, z1: T.z1 }, deck ? 'deck' : F === 0 ? 'theater' : 'gallery', F === 0 ? 'Dome theater' : undefined);
      const bk = pb.room(F, { x0: T.x0, z0: T.z1, x1: T.x1, z1: Dd - t }, deck ? 'deck' : 'office');
      const L = pb.room(F, { x0: t, z0: t, x1: T.x0, z1: Dd - t }, deck ? 'deck' : 'office', deck ? undefined : 'West offices');
      const R = pb.room(F, { x0: T.x1, z0: t, x1: Wd - t, z1: Dd - t }, deck ? 'deck' : 'office', deck ? undefined : 'East offices');
      if (deck) { pb.open(lob, th); pb.open(th, bk); pb.open(L, lob); pb.open(R, lob); pb.open(L, th); pb.open(R, th); pb.open(L, bk); pb.open(R, bk); }
      else { pb.open(lob, th); pb.door(th, bk, 'mid'); pb.door(L, lob, 'mid'); pb.door(R, lob, 'mid'); pb.door(L, bk, 'mid'); pb.door(R, bk, 'mid'); }
      if (F === 1) pb.hole(1, { x0: T.x0 + 100, z0: T.z0 + 100, x1: T.x1 - 100, z1: T.z1 - 100 });
      if (F === 0) { pb.extDoors.push({ floor: 0, side: 'front', at: Wd / 2 - 91, w: 183, h: 244, style: 'colonial:DOOR_HEAVENBLUE', y: 0 }); pb.extDoors.push({ floor: 0, side: 'back', at: Wd / 2 - 45, w: 91, h: 213, style: 'steel', y: 0 }); }
    }
    stackStairs(pb, fl, (rise) => ({ x0: t + 30, z0: Dd - t - 30 - uStairSize(rise, sw).along, x1: t + 30 + across, z1: Dd - t - 30 }), 'z+', sw, 'A');
    stackStairs(pb, fl, (rise) => ({ x0: Wd - t - 30 - across, z0: Dd - t - 30 - uStairSize(rise, sw).along, x1: Wd - t - 30, z1: Dd - t - 30 }), 'z+', sw, 'B');
    pb.shafts.push({ rect: { x0: t + 30, z0: t + 30, x1: t + 30 + SHAFT.w + 40, z1: t + 30 + SHAFT.d + 40 }, floors: fl.map((f) => f.floor), door: 'x1' });
  }),
  exterior: (spec, plan, out) => {
    const g = out.g, T = thr();
    portico(g, W / 2 - 600, 1200, 300, 700, 4, 'doric');
    drumDome(g, (T.x0 + T.x1) / 2, (T.z0 + T.z1) / 2, 1000, 200, plan.roofY);
    // observation deck guard along the dome drum
    g.push(); g.translate(C(T.x0 - 150), C(plan.roofY), C(T.z0 - 160)); ironPicket(g, THR + 300); g.pop();
    void spec;
  },
  interior: (spec, plan, g) => {
    const T = thr(), cx = (T.x0 + T.x1) / 2, cz = (T.z0 + T.z1) / 2;
    // stepped seating tiers (platforms) ringing a central projector pit under the dome
    arcTiers(g, cx, cz, 320, 7, 95, 30, 0, Math.PI * 2, 0, 'tex:carpet_office');
    boxC(g, 'paint:ALUMINUM_STOREFRONT', cx - 60, 0, cz - 60, cx + 60, 140, cz + 60); // projector plinth (built-in)
    cofferedDome(g, cx, cz, 980, plan.roofY + 200 + 12, 'paint:PLASTER_IVORY');
    void spec;
  },
});
