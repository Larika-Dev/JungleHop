// Kit gallery scene (?scene=gallery): every registered kit piece on a plinth grid with a label.
import { CanvasTexture, DoubleSide, Group, Mesh, MeshBasicMaterial, PlaneGeometry, SRGBColorSpace } from 'three';
import type { App, WorldHandle } from '../app';
import { GeoBuilder } from '../core/geo';
import { mat } from '../core/materials';
import { css } from '../core/palette';
import { DebugOverlays } from '../debug/overlays';
import { KIT_REGISTRY } from './index';
import { NearDetail, registerBricksFromBuilder } from './nearDetail';

function label(text: string, sub: string): Mesh {
  const c = document.createElement('canvas'); c.width = 512; c.height = 96;
  const x = c.getContext('2d')!;
  x.fillStyle = css('ONSU_NAVY'); x.fillRect(0, 0, 512, 96);
  x.fillStyle = css('ONSU_WHITE'); x.font = 'bold 30px Georgia, serif'; x.fillText(text, 14, 40);
  x.fillStyle = css('HEAVEN_BLUE'); x.font = '22px monospace'; x.fillText(sub, 14, 78);
  const t = new CanvasTexture(c); t.colorSpace = SRGBColorSpace;
  const m = new Mesh(new PlaneGeometry(2.4, 0.45), new MeshBasicMaterial({ map: t, side: DoubleSide }));
  return m;
}

export function createGallery(app: App): WorldHandle {
  const root = new Group(); root.name = 'gallery';
  const floor = new GeoBuilder();
  const kits = [...new Set(KIT_REGISTRY.map((k) => k.kit))];
  const colW = 13, rowD = 16;
  let maxCols = 0;
  kits.forEach((kit, row) => {
    const pieces = KIT_REGISTRY.filter((k) => k.kit === kit);
    maxCols = Math.max(maxCols, pieces.length);
    pieces.forEach((p, col) => {
      const g = new GeoBuilder();
      p.build(g);
      const b = g.bounds();
      const x = col * colW, z = -row * rowD;
      const grp = g.toGroup(mat, p.name);
      // fronts face +z (toward the visitor walking north)
      grp.rotation.y = Math.PI;
      grp.position.set(x + (b.min.x + b.max.x) / 2, 0.2 - Math.min(0, b.min.y), z);
      grp.updateMatrix();
      grp.traverse((o) => o.updateMatrix());
      grp.updateMatrixWorld(true);
      root.add(grp);
      registerBricksFromBuilder(g, grp.matrixWorld.clone(), `gallery:${p.name}`);
      floor.box('tex:concrete_new', x - 5.5, 0, z - 6, x + 5.5, 0.2, z + 6);
      const l = label(`${kit}: ${p.name}`, `bbox ${(b.max.x - b.min.x) * 100 | 0} x ${(b.max.y - b.min.y) * 100 | 0} x ${(b.max.z - b.min.z) * 100 | 0} cm`);
      l.position.set(x, 0.6, z + 5.2); l.rotation.x = -0.6;
      root.add(l);
    });
  });
  floor.box('tex:grass', -20, -0.3, -kits.length * rowD - 10, maxCols * colW + 10, 0, 20);
  root.add(floor.toGroup(mat, 'floor'));
  app.scene.add(root);
  app.collision.ground = () => 0.2;
  const overlays = new DebugOverlays(() => 0.2);
  app.scene.add(overlays.root);
  app.player.teleport(-6, 14, 0.2, -0.6, -0.15);
  const near = new NearDetail(null);
  app.scene.add(near.root);
  app.perf.extra.push(() => `near-detail bricks ${near.stats.bricks}`);
  return { update() { near.update(app.camera.position); }, pickables: () => [root], rooms: () => [], ready: async () => { near.update(app.camera.position, true); }, overlays };
}
