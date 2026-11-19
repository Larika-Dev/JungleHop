// Street furniture tile plug-in (CLAUDE.md §13) + lamp registration for night lighting.
import { registerTileBuilder } from '../world/tileRegistry';
import { furnitureByTile, furnitureGroup, LAMPS } from './furniture';

registerTileBuilder({
  name: 'furniture', order: 45,
  build: (ctx) => {
    const list = furnitureByTile().get(ctx.name) ?? [];
    if (list.length) ctx.group.add(furnitureGroup(list));
    if (!ctx.app.lighting.lamps.length) ctx.app.lighting.lamps = LAMPS;
  },
});
