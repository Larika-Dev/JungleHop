// Phase 5 proof scene (?scene=interiors): three generic buildings on a flat lot — a historic academic hall
// (double-loaded, basement + attic), a downtown shotgun commercial block (3 floors, storefront) and a
// center-hall house — each with full interiors, streaming, doors, room metadata and far-window mapping.
import type { App, WorldHandle } from '../app';
import { GeoBuilder } from '../core/geo';
import { mat } from '../core/materials';
import { DebugOverlays } from '../debug/overlays';
import { defaultFacade } from '../buildings/facades';
import { BuildingManager } from '../buildings/manager';
import { NearDetail } from '../kits/nearDetail';
import { imUniforms } from './interiorMapping';
import { pc } from '../core/palette';
import { sunDirection } from '../lighting/presets';
import type { BuildingSpec } from './types';

export const DEMO_SPECS: BuildingSpec[] = [
  { id: 'DEMO_HALL', name: 'Demo Hall', district: 'campus_generic', x: -30, z: -40, rotY: 0, y: 0.64, w: 3600, d: 1600, floors: 3, basement: true, attic: true,
    typology: 'historic_academic', plan: 'double_loaded', facade: defaultFacade('historic_academic'), public: true, seed: 'demo-hall', tags: ['cupola'] },
  { id: 'DEMO_SHOP', name: 'Demo Block', district: 'hamilton_strip', x: 20, z: -36, rotY: 0, y: 0, w: 800, d: 2400, floors: 3, basement: true, attic: false,
    typology: 'downtown_commercial', plan: 'shotgun', facade: defaultFacade('downtown_commercial'), seed: 'demo-shop', business: { name: 'Hilltop Hardware', type: 'retail' }, upperUse: 'apartments', party: { right: true } },
  { id: 'DEMO_HOUSE', name: 'Demo House', district: 'residential_north', x: 40, z: -30, rotY: 0, y: 0.48, w: 1200, d: 1000, floors: 2, basement: true, attic: true,
    typology: 'house', plan: 'center_hall', facade: defaultFacade('house', { wall: 'paint:SIDING_SAGE' }), seed: 'demo-house' },
];

export function createInteriorDemo(app: App): WorldHandle {
  const g = new GeoBuilder();
  g.box('tex:concrete_new', -60, -0.3, -10, 70, 0, 6);
  g.box('tex:grass', -80, -0.31, -80, 90, 0, 20);
  const bm = new BuildingManager(app);
  for (const s of DEMO_SPECS) {
    const rec = bm.addToTile(s, 'demo', g, { front: -s.y, low: -s.y });
    bm.activate(rec);
  }
  const grp = g.toGroup(mat, 'demo');
  app.scene.add(grp);
  app.collision.ground = (x, z) => (z > -10 && z < 6 && x > -60 && x < 70 ? 0 : 0);
  const overlays = new DebugOverlays(() => 0);
  app.scene.add(overlays.root);
  const near = new NearDetail(null);
  app.scene.add(near.root);
  app.lighting.onChange((p) => {
    imUniforms.uLit.value = p.windowsLit; imUniforms.uNight.value = p.lampsOn ? 1 : 0;
    imUniforms.uSky.value.copy(pc(p.horizon)); imUniforms.uSun.value.copy(sunDirection(p.sunElev, p.sunAz));
  });
  app.player.teleport(0, 4, 0, 0, 0);
  return {
    update(dt) { bm.update(dt, () => true); near.update(app.camera.position); overlays.follow(app.player.pos.x, app.player.pos.y, app.player.pos.z); },
    pickables: () => [grp, ...[...bm.loaded].map((r) => r.interior!.group)],
    rooms: () => bm.rooms(),
    ready: async () => { bm.update(1, () => true, true); near.update(app.camera.position, true); },
    stats: () => [`interiors loaded ${bm.loaded.size}`],
    overlays,
  };
}
