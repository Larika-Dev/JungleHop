// CLAUDE.md §2 — 200 m tiles named T_{col}_{row}, counted from the NW corner of the total map.
// Plan coordinates [x, z]: +x east, +z south (Three.js -Z = north).
export const CORE = { x0: -900, x1: 700, z0: -450, z1: 950 } as const; // 1600 x 1400 m dense core
export const TOTAL = { x0: -1900, x1: 1700, z0: -1450, z1: 1950 } as const; // core + 1 km ring
export const TILE = 200;
export const COLS = (TOTAL.x1 - TOTAL.x0) / TILE; // 18
export const ROWS = (TOTAL.z1 - TOTAL.z0) / TILE; // 17

export interface TileId { col: number; row: number; }
export const tileName = (t: TileId) => `T_${t.col}_${t.row}`;
export const tileAt = (x: number, z: number): TileId => ({
  col: Math.floor((x - TOTAL.x0) / TILE),
  row: Math.floor((z - TOTAL.z0) / TILE),
});
export const tileNameAt = (x: number, z: number) => tileName(tileAt(x, z));
export const tileBounds = (t: TileId) => ({
  x0: TOTAL.x0 + t.col * TILE, x1: TOTAL.x0 + (t.col + 1) * TILE,
  z0: TOTAL.z0 + t.row * TILE, z1: TOTAL.z0 + (t.row + 1) * TILE,
});
export const tileValid = (t: TileId) => t.col >= 0 && t.row >= 0 && t.col < COLS && t.row < ROWS;
export const parseTile = (name: string): TileId => {
  const m = /^T_(\d+)_(\d+)$/.exec(name);
  if (!m) throw new Error(`bad tile name ${name}`);
  return { col: +m[1], row: +m[2] };
};
/** Is the tile (mostly) inside the dense core? */
export const tileInCore = (t: TileId) => {
  const b = tileBounds(t);
  return b.x1 > CORE.x0 && b.x0 < CORE.x1 && b.z1 > CORE.z0 && b.z0 < CORE.z1;
};
/** Tiles within Chebyshev radius r of center. */
export function ring(center: TileId, r: number): TileId[] {
  const out: TileId[] = [];
  for (let dr = -r; dr <= r; dr++) for (let dc = -r; dc <= r; dc++) {
    const t = { col: center.col + dc, row: center.row + dr };
    if (tileValid(t)) out.push(t);
  }
  return out;
}
export function allTiles(): TileId[] {
  const out: TileId[] = [];
  for (let row = 0; row < ROWS; row++) for (let col = 0; col < COLS; col++) out.push({ col, row });
  return out;
}
