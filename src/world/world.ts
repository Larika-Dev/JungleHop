// Scene selector: ?scene=city (default) | scaffold | gallery | interiors
import type { App, WorldHandle } from '../app';

export async function createWorld(app: App): Promise<WorldHandle> {
  const scene = app.params.get('scene') ?? 'city';
  if (scene === 'scaffold') return (await import('./scaffold')).createScaffold(app);
  if (scene === 'gallery') return (await import('../kits/gallery')).createGallery(app);
  if (scene === 'interiors') return (await import('../interiors/demo')).createInteriorDemo(app);
  return (await import('./city')).createCity(app);
}
