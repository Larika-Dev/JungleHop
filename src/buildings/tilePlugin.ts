// Tile plug-in: builds every sited building of a tile (exterior into the tile mesh) and wires
// activation (doors + collision) / interior streaming through the BuildingManager.
import { registerTileBuilder } from '../world/tileRegistry';
import { cityPlan } from '../world/cityPlan';
import type { BuildingManager, BuildingRec } from './manager';

export const buildingTiles = new Map<string, BuildingRec[]>();

registerTileBuilder({
  name: 'buildings', order: 30,
  build: (ctx) => {
    const bm = (ctx.app as any).buildings as BuildingManager | undefined;
    if (!bm) return;
    const recs: BuildingRec[] = [];
    for (const s of cityPlan().byTile.get(ctx.name) ?? []) {
      try { recs.push(bm.addToTile(s.spec, ctx.name, ctx.g, s.grades)); } catch (e) { console.error('building failed', s.spec.id, e); }
    }
    buildingTiles.set(ctx.name, recs);
    ctx.onActivate.push(() => { for (const r of recs) bm.activate(r); });
    ctx.onDeactivate.push(() => { for (const r of recs) bm.deactivate(r); });
    ctx.onDispose.push(() => { for (const r of recs) bm.dispose(r); buildingTiles.delete(ctx.name); });
  },
});
