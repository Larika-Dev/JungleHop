// Phase 2 scaffold scene: calibration ground, 1 m grid, test stair (17.8 cm risers / 28 cm treads), a door.
import { Group, Vector3 } from 'three';
import type { App, WorldHandle } from '../app';
import { GeoBuilder } from '../core/geo';
import { mat } from '../core/materials';
import { cm } from '../core/units';
import { DebugOverlays } from '../debug/overlays';

export function createScaffold(app: App): WorldHandle {
  const g = new GeoBuilder();
  g.box('tex:concrete_new', -60, -0.3, -60, 60, 0, 60);
  // 1 m calibration posts
  for (let i = -5; i <= 5; i++) g.box('paint:MARKING_YELLOW', i - 0.01, 0, -10.01, i + 0.01, 0.02, -9.99);
  g.box('brick:flemish:BRICK_CAMPUS_A', -8, 0, -14, 8, 4, -13.55);
  g.box('brick:running:BRICK_DOWNTOWN_A', 9, 0, -14, 20, 4, -13.55);
  // stair: 10 risers x 17.8 cm, treads 28 cm
  const rise = cm(178) / 10, tread = cm(28);
  for (let i = 0; i < 10; i++) g.box('tex:oak_floor', -3 - 0.56, 0, -4 - i * tread, -3 + 0.56, rise * (i + 1), -4 - (i + 1) * tread);
  for (let i = 0; i < 10; i++) app.collision.addFloor('scaffold', [[-3.56, -4 - i * tread], [-2.44, -4 - i * tread], [-2.44, -4 - (i + 1) * tread], [-3.56, -4 - (i + 1) * tread]], rise * (i + 1));
  g.box('tex:oak_floor', -3.56, 0, -6.8, -2.44, 1.78, -9);
  app.collision.addFloor('scaffold', [[-3.56, -6.8], [-2.44, -6.8], [-2.44, -9], [-3.56, -9]], 1.78);
  // door frame + leaf
  g.box('satin:TRIM_WHITE', 4, 0, -6.06, 4.11, 2.24, -5.94);
  g.box('satin:TRIM_WHITE', 5.02, 0, -6.06, 5.13, 2.24, -5.94);
  g.box('satin:TRIM_WHITE', 4, 2.13, -6.06, 5.13, 2.24, -5.94);
  app.collision.addWall('scaffold', 0, -6, 4, -6, 0, 3, 0.12);
  app.collision.addWall('scaffold', 5.13, -6, 9, -6, 0, 3, 0.12);
  g.box('paint:PLASTER_CAMPUS', 0, 0, -6.06, 4, 3, -5.94);
  g.box('paint:PLASTER_CAMPUS', 5.13, 0, -6.06, 9, 3, -5.94);
  const leaf = new GeoBuilder();
  leaf.box('satin:DOOR_RED', 0, 0, -0.0225, 0.91, 2.13, 0.0225);
  leaf.box('metal:BRASS', 0.8, 0.95, 0.0225, 0.85, 1.0, 0.07);
  app.doors.registerStyle('scaffold', leaf);
  app.doors.add('scaffold', 'scaffold', new Vector3(4.11, 0, -6), 0, 0.91, 2.13, 1);
  const grp: Group = g.toGroup(mat, 'scaffold');
  app.scene.add(grp);
  app.collision.ground = () => 0;
  const overlays = new DebugOverlays(() => 0);
  app.scene.add(overlays.root);
  app.player.teleport(0, 4, 0, 0, 0);
  return {
    update() { overlays.follow(app.player.pos.x, app.player.pos.y, app.player.pos.z); },
    pickables: () => [grp],
    rooms: () => [],
    ready: async () => {},
    overlays,
  };
}
