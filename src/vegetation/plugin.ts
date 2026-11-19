// Vegetation tile plug-in: detailed instanced trees, hedges/azaleas, mulch & leaf litter, ivy (CLAUDE.md §12).
import { Rng } from '../core/rng';
import { registerTileBuilder } from '../world/tileRegistry';
import { cityPlan } from '../world/cityPlan';
import { treesForTile } from './placement';
import { treeGroup } from './trees';
import { litterForTrees, shrubsForBuilding } from './shrubs';
import { ivyForBuilding } from './ivy';

registerTileBuilder({
  name: 'vegetation', order: 40,
  build: (ctx) => {
    const trees = treesForTile(ctx.tile);
    if (trees.length) ctx.group.add(treeGroup(trees));
    const rng = new Rng(`veg:${ctx.name}`);
    litterForTrees(ctx.gNoShadow, trees.filter((t) => t.sp !== 'loblolly'), rng);
    for (const s of cityPlan().byTile.get(ctx.name) ?? []) { shrubsForBuilding(ctx.g, s, rng); ivyForBuilding(ctx.g, s); }
  },
});
