// Far impostors (CLAUDE.md §17: merged blocks beyond 80 m): one merged low-poly mesh per tile with every
// building as a colored massing block + roof; hidden while that tile's full-detail content is active.
import { Group, Mesh, MeshStandardMaterial } from 'three';
import { GeoBuilder } from '../core/geo';
import { mat } from '../core/materials';
import { pc, type PaletteKey } from '../core/palette';
import { planFor } from './manager';
import { buildingMatrix } from './exterior';
import type { CityPlan } from '../world/cityPlan';

function wallColor(key: string): PaletteKey {
  const p = key.split(':');
  if (p[0] === 'brick') return p[3] === 'painted' ? 'BRICK_PAINTED_WHITE' : (p[2] as PaletteKey);
  if (p[0] === 'paint') return p[1] as PaletteKey;
  if (key.includes('boardform')) return 'CONCRETE_BOARDFORM';
  if (key.includes('concrete')) return 'CONCRETE_NEW';
  if (key.includes('fieldstone')) return 'FIELDSTONE_A';
  if (key.includes('stucco')) return 'STUCCO';
  if (key.includes('limestone')) return 'LIMESTONE_TRIM';
  return 'BRICK_DOWNTOWN_A';
}
function roofColor(key: string): PaletteKey {
  if (key.includes('slate')) return 'SLATE_A';
  if (key.includes('shingle')) return 'ASPHALT_SHINGLE';
  if (key.includes('seam')) return 'STANDING_SEAM';
  if (key.includes('concrete')) return 'CONCRETE_NEW';
  return 'TPO_ROOF';
}

import { allTiles, tileName } from '../core/tiles';
import { treesForTile } from '../vegetation/placement';
import { SPECIES } from '../vegetation/trees';

export function buildImpostors(city: CityPlan): Map<string, Group> {
  const out = new Map<string, Group>();
  const shared = new MeshStandardMaterial({ vertexColors: true, roughness: 0.9 });
  shared.userData.matKey = 'impostor';
  void mat;
  for (const [tile, list] of city.byTile) {
    const g = new GeoBuilder();
    for (const s of list) {
      const spec = s.spec;
      let h = 0;
      try { h = planFor(spec).roofY / 100; } catch { h = spec.floors * 3.5; }
      if (spec.custom === 'old_cistern') h = 7;
      if (spec.custom === 'coachs_dome') h = 18;
      if (spec.custom === 'benefactor_stadium' || spec.custom === 'stadium') h = 12;
      g.push(buildingMatrix(spec));
      const W = spec.w / 100, D = spec.d / 100;
      g.setColor(pc(wallColor(spec.facade.wall)));
      g.box('imp', 0, -2, 0, W, h, D, 1 | 2 | 16 | 32);
      // window bands (dark) on the front and back faces, one per floor
      g.setColor(pc('GLASS_DARK'));
      const floors = Math.max(1, spec.floors);
      if (spec.facade.window !== 'none') for (let f = 0; f < floors; f++) {
        const y = (h / floors) * (f + 0.45), hh = (h / floors) * 0.35;
        g.box('imp', 0.3, y, -0.02, W - 0.3, y + hh, 0, 32);
        g.box('imp', 0.3, y, D, W - 0.3, y + hh, D + 0.02, 16);
      }
      g.setColor(pc(roofColor(spec.facade.roofKey)));
      if (spec.facade.roof === 'flat' || spec.custom) g.box('imp', 0, h, 0, W, h + 0.3, D, 4);
      else {
        const rise = Math.min(W, D) / 2 * Math.tan(((spec.facade.pitch ?? 35) * Math.PI) / 180);
        g.quad('imp', [W, h, 0], [0, h, 0], [0, h + rise, D / 2], [W, h + rise, D / 2]);
        g.quad('imp', [0, h, D], [W, h, D], [W, h + rise, D / 2], [0, h + rise, D / 2]);
        g.tri('imp', [0, h, 0], [0, h, D], [0, h + rise, D / 2]);
        g.tri('imp', [W, h, D], [W, h, 0], [W, h + rise, D / 2]);
      }
      g.pop();
    }
    const grp = g.toGroup(() => shared, `impostor:${tile}`, { castShadow: false, receiveShadow: false });
    grp.traverse((o) => { if ((o as Mesh).isMesh) (o as Mesh).userData.matKey = 'impostor'; });
    out.set(tile, grp);
  }
  // far trees: crossed quads + trunk stub per tree, all tiles
  for (const t of allTiles()) {
    const name = tileName(t);
    const trees = treesForTile(t);
    if (!trees.length) continue;
    const g = new GeoBuilder();
    for (const tr of trees) {
      const d = SPECIES[tr.sp];
      const h = ((d.h[0] + d.h[1]) / 2) * tr.scale, r = tr.sp === 'loblolly' ? h * 0.18 : h * 0.33;
      const yb = tr.y + (tr.sp === 'loblolly' ? h * 0.55 : h * 0.3);
      g.setColor(pc(d.leaf));
      const a = tr.rot;
      for (let k = 0; k < 2; k++) {
        const ca = Math.cos(a + k * Math.PI / 2) * r, sa = Math.sin(a + k * Math.PI / 2) * r;
        g.quad('imp', [tr.x - ca, yb, tr.z - sa], [tr.x + ca, yb, tr.z + sa], [tr.x + ca * 0.25, tr.y + h, tr.z + sa * 0.25], [tr.x - ca * 0.25, tr.y + h, tr.z - sa * 0.25]);
        g.quad('imp', [tr.x + ca, yb, tr.z + sa], [tr.x - ca, yb, tr.z - sa], [tr.x - ca * 0.25, tr.y + h, tr.z - sa * 0.25], [tr.x + ca * 0.25, tr.y + h, tr.z + sa * 0.25]);
      }
      g.setColor(pc(d.bark === 'tex:bark_pine' ? 'PINE_BARK' : 'OAK_BARK'));
      g.box('imp', tr.x - 0.25, tr.y, tr.z - 0.25, tr.x + 0.25, yb, tr.z + 0.25, 1 | 2 | 16 | 32);
    }
    const grp = g.toGroup(() => shared, `impostor-trees:${name}`, { castShadow: false, receiveShadow: false });
    const prev = out.get(name);
    if (prev) prev.add(grp); else out.set(name, grp);
  }
  return out;
}
