// Tile content plug-ins: each phase (roads, buildings, vegetation, furniture...) registers a builder
// that writes into the tile's merged GeoBuilder and/or adds special objects.
import { Object3D } from 'three';
import type { App } from '../app';
import { GeoBuilder } from '../core/geo';
import type { TileId } from '../core/tiles';

export interface TileCtx {
  tile: TileId;
  name: string;
  app: App;
  /** merged static geometry (one mesh per material for the whole tile) */
  g: GeoBuilder;
  /** shadow-less merged geometry (markings, small decals) */
  gNoShadow: GeoBuilder;
  /** extra objects (instanced meshes, lights...) */
  group: Object3D;
  /** run when tile becomes active/inactive/disposed */
  onActivate: (() => void)[];
  onDeactivate: (() => void)[];
  onDispose: (() => void)[];
}
export type TileBuilder = { name: string; order: number; build: (ctx: TileCtx) => void | Promise<void> };
export const TILE_BUILDERS: TileBuilder[] = [];
export function registerTileBuilder(b: TileBuilder) { TILE_BUILDERS.push(b); TILE_BUILDERS.sort((a, c) => a.order - c.order); }
