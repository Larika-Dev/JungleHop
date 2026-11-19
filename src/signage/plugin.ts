// Signage tile plug-in (CLAUDE.md §14).
import { registerTileBuilder } from '../world/tileRegistry';
import { cityPlan } from '../world/cityPlan';
import { posterColumns, signageForTile } from './signs';

registerTileBuilder({
  name: 'signage', order: 50,
  build: (ctx) => {
    const g = signageForTile(ctx.name, cityPlan().byTile.get(ctx.name) ?? []);
    if (g) ctx.group.add(g);
    const p = posterColumns(ctx.name);
    if (p) ctx.group.add(p);
  },
});
