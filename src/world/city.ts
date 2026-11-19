// The city world: far terrain, near 0.5 m terrain patch, streamed 200 m tiles with plug-in builders.
import { Group, Object3D } from 'three';
import type { App, WorldHandle } from '../app';
import { GeoBuilder } from '../core/geo';
import { mat } from '../core/materials';
import { TileStreamer, yieldFrame, type TileContent } from '../core/streaming';
import { tileBounds, tileName, tileAt, ring } from '../core/tiles';
import { DebugOverlays } from '../debug/overlays';
import { buildMidblockForTile, buildRoadsForTile, roadPlan, walkMaterial } from '../roads/build';
import { NearDetail } from '../kits/nearDetail';
import { NearTerrain, buildFarTerrain, buildTerrainTile, groundUniforms, setGroundMaterialHook } from '../terrain/terrainMesh';
import { Terrain } from '../terrain/terrain';
import { TILE_BUILDERS, registerTileBuilder, type TileCtx } from './tileRegistry';
import './plugins';

registerTileBuilder({ name: 'roads', order: 10, build: (ctx) => { buildRoadsForTile(ctx.name, ctx.g); buildMidblockForTile(ctx.name, ctx.gNoShadow); } });

export async function createCity(app: App): Promise<WorldHandle> {
  const msg = document.getElementById('loadmsg');
  const say = (t: string) => { if (msg) msg.textContent = t; };
  say('terrain & road network…');
  await yieldFrame();
  const T = Terrain.get();
  app.collision.ground = (x, z) => T.surface(x, z);
  setGroundMaterialHook((m) => app.lighting.adopt(m));
  const far = buildFarTerrain();
  app.scene.add(far);
  const near = new NearTerrain();
  app.scene.add(near.mesh);
  const pickRoots: Object3D[] = [near.mesh];
  const rooms: Object3D[] = [];
  const extraStats: (() => string)[] = [];

  const streamer = new TileStreamer(async (t) => {
    const name = tileName(t);
    const group = new Group();
    const ctx: TileCtx = { tile: t, name, app, g: new GeoBuilder(), gNoShadow: new GeoBuilder(), group, onActivate: [], onDeactivate: [], onDispose: [] };
    const terrain = buildTerrainTile(t);
    group.add(terrain);
    await yieldFrame();
    for (const b of TILE_BUILDERS) {
      try { await b.build(ctx); } catch (e) { console.error(`tile builder ${b.name} failed on ${name}`, e); }
      await yieldFrame();
    }
    const merged = ctx.g.toGroup(mat, 'static');
    const flat = ctx.gNoShadow.toGroup(mat, 'decals', { castShadow: false });
    group.add(merged, flat);
    group.updateMatrixWorld(true);
    const content: TileContent = {
      object: group,
      activate: () => { pickRoots.push(group); for (const f of ctx.onActivate) f(); },
      deactivate: () => { const i = pickRoots.indexOf(group); if (i >= 0) pickRoots.splice(i, 1); for (const f of ctx.onDeactivate) f(); },
      dispose: () => {
        const i = pickRoots.indexOf(group); if (i >= 0) pickRoots.splice(i, 1);
        for (const f of ctx.onDispose) f();
        group.traverse((o: any) => { if (o.isMesh || o.isInstancedMesh) o.geometry?.dispose(); });
      },
    };
    return content;
  });
  app.scene.add(streamer.root);
  const updateActiveRect = () => {
    const c = tileAt(app.player.pos.x, app.player.pos.z);
    const names = ring(c, streamer.opts.active).map(tileName);
    if (names.every((n) => streamer.isActive(n))) {
      const b0 = tileBounds({ col: c.col - 1, row: c.row - 1 }), b1 = tileBounds({ col: c.col + 1, row: c.row + 1 });
      groundUniforms.activeRect.value.set(b0.x0 + 0.5, b0.z0 + 0.5, b1.x1 - 0.5, b1.z1 - 0.5);
    } else groundUniforms.activeRect.value.set(1e9, 1e9, -1e9, -1e9);
  };
  streamer.onChange.push(updateActiveRect);

  // near-detail (CLAUDE.md §5): real pavers/bricks/domes within 15 m
  const plan = roadPlan();
  const near15 = new NearDetail((x, z) => {
    const hit = T.net.query(x, z);
    if (!hit || hit.zone !== 'sidewalk') return null;
    let key: string;
    if (hit.node) { const c = hit.node.arms[0].road; key = `tex:${c.sec.walk}`; }
    else key = walkMaterial(hit.road, hit.d >= 0 ? 1 : -1, hit.s);
    if (!key.includes('pavers')) return null;
    let heave = 0;
    for (const t of plan.treePits) {
      const dx = Math.abs(t.x - x), dz = Math.abs(t.z - z);
      if (dx < 0.66 && dz < 0.66) return null;
      const d = Math.hypot(t.x - x, t.z - z);
      if (d < 3) heave = Math.max(heave, (0.02 + 0.04 * ((t.x * 7.3 + t.z) % 1 + 1) % 1) * (1 - d / 3));
    }
    for (const m of plan.midblock) { const f = m.road; const pr = Math.abs(hit.s - m.s); if (f === hit.road && pr < 1.6 && Math.sign(hit.d) === m.side) return null; }
    if (hit.node) for (const c of hit.node.corners) for (const r of c.ramps) if (Math.hypot(r.p[0] - x, r.p[1] - z) < 2.0) return null;
    return { y: hit.y + heave, pattern: key.includes('herringbone') ? 'herringbone' : 'running' };
  });
  app.scene.add(near15.root);
  app.frameHooks.push(() => near15.update(app.camera.position));
  extraStats.push(() => `near-detail bricks ${near15.stats.bricks} · pavers ${near15.stats.pavers} · domes ${near15.stats.domes}`);

  const overlays = new DebugOverlays((x, z) => T.height(x, z));
  app.scene.add(overlays.root);
  app.perf.extra.push(() => `tiles active ${streamer.activeNames().length} · loaded ${streamer.entries.size}`, ...extraStats);

  // start position: ?x=&z= or Hamilton St sidewalk in front of the North Quad wall, looking west to The Summit
  const P = app.params;
  const sx = Number(P.get('x') ?? 40), sz = Number(P.get('z') ?? -9);
  app.player.teleport(sx, sz, undefined, Math.PI / 2, 0);
  near.update(sx, sz, true);
  say('streaming tiles…');
  await streamer.ready(sx, sz);
  app.player.teleport(sx, sz, undefined, Number(P.get('yaw') ?? 90) * Math.PI / 180, 0);

  return {
    update: () => {
      const p = app.player.pos;
      streamer.update(p.x, p.z);
      near.update(p.x, p.z);
      updateActiveRect();
      overlays.follow(p.x, p.y, p.z);
    },
    pickables: () => pickRoots,
    rooms: () => rooms,
    ready: async () => { const p = app.player.pos; near.update(p.x, p.z, true); await streamer.ready(p.x, p.z); updateActiveRect(); near15.update(app.camera.position, true); },
    stats: () => [`tiles ${streamer.activeNames().join(',')}`],
    overlays,
  };
}
