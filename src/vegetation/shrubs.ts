// Shrubs, hedges & mulch (CLAUDE.md §12): boxwood hedges 60–120 cm along campus building fronts, azaleas
// (AZALEA, no blooms in October) at house foundations, PINE_STRAW mulch beds, leaf-litter drifts under oaks.
import type { GeoBuilder } from '../core/geo';
import { Rng } from '../core/rng';
import { Terrain } from '../terrain/terrain';
import { localToWorld, type Sited } from '../world/cityPlan';
import type { TreeInst } from './trees';
import { canPlant } from './placement';

/** Irregular ground decal (mulch / leaf litter) following the terrain. */
export function groundPatch(g: GeoBuilder, key: string, cx: number, cz: number, r: number, rng: Rng, lift = 0.015) {
  const T = Terrain.get();
  const n = 14;
  const pts: [number, number][] = [];
  for (let i = 0; i < n; i++) { const a = (i / n) * Math.PI * 2, rr = r * (0.75 + rng.next() * 0.35); pts.push([cx + Math.cos(a) * rr, cz + Math.sin(a) * rr]); }
  const cy = T.height(cx, cz) + lift;
  for (let i = 0; i < n; i++) {
    const a = pts[i], b = pts[(i + 1) % n];
    g.tri(key, [cx, cy, cz], [b[0], T.height(b[0], b[1]) + lift, b[1]], [a[0], T.height(a[0], a[1]) + lift, a[1]]);
  }
}

export function shrubsForBuilding(g: GeoBuilder, s: Sited, rng: Rng) {
  const spec = s.spec;
  const W = spec.w / 100;
  const campus = ['north_quad', 'founders_quad', 'campus_generic', 'quarry', 'carillon_south'].includes(spec.district);
  const house = spec.typology === 'house';
  if (!campus && !house) return;
  const T = Terrain.get();
  // hedge/azalea run along the front, broken at the central entrance
  const segs: [number, number][] = house ? [[0.4, W * 0.38], [W * 0.62, W - 0.4]] : [[0.5, W * 0.4], [W * 0.6, W - 0.5]];
  for (const [a, b] of segs) {
    for (let x = a; x < b - 0.5; x += house ? 1.4 : 1.0) {
      const [wx, wz] = localToWorld(spec, x + 0.5, -0.9);
      if (!canPlant(wx, wz, -0.2)) continue;
      const y = T.height(wx, wz);
      if (house) {
        // azalea mound
        const r = 0.45 + rng.next() * 0.25;
        g.push(); g.translate(wx, y - 0.05, wz);
        g.lathe('leafy:AZALEA', [[0.05, 0], [r, 0.1], [r * 1.05, r * 0.6], [r * 0.7, r * 1.05], [0.02, r * 1.2]], 9);
        g.pop();
      } else {
        const h = 0.6 + rng.next() * 0.6;
        g.push(); g.translate(wx, y - 0.05, wz); g.rotateY(spec.rotY);
        g.box('leafy:BOXWOOD', -0.52, 0, -0.32, 0.52, h, 0.32);
        g.box('leafy:BOXWOOD', -0.45, h, -0.26, 0.45, h + 0.08, 0.26);
        g.pop();
      }
    }
    const [mx, mz] = localToWorld(spec, (a + b) / 2, -0.9);
    if (canPlant(mx, mz, -0.5)) groundPatch(g, 'tex:pinestraw', mx, mz, Math.min(2.2, (b - a) / 2), rng, 0.012);
  }
}

export function litterForTrees(g: GeoBuilder, trees: TreeInst[], rng: Rng) {
  for (const t of trees) {
    if (t.sp === 'willow_oak' || t.sp === 'white_oak') groundPatch(g, 'tex:leaflitter', t.x + (rng.next() - 0.5) * 3, t.z + (rng.next() - 0.5) * 3, t.sp === 'willow_oak' ? 7 : 4, rng, 0.01);
    else if (t.sp === 'red_maple' || t.sp === 'sugar_maple' || t.sp === 'dogwood') { if (rng.chance(0.4)) groundPatch(g, 'tex:leaflitter', t.x, t.z, 2.2, rng, 0.012); }
  }
}
