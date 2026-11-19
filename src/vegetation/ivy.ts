// Ivy (CLAUDE.md §12): IVY on ~20% of campus building walls, north faces preferred. Leaf-card mats hug the
// wall 3 cm proud, climbing from the ground in irregular columns.
import type { GeoBuilder } from '../core/geo';
import { hash01, Rng } from '../core/rng';
import { localToWorld, type Sited } from '../world/cityPlan';

export function ivyForBuilding(g: GeoBuilder, s: Sited) {
  const spec = s.spec;
  if (!['north_quad', 'founders_quad', 'campus_generic', 'quarry'].includes(spec.district)) return;
  if (!spec.facade.wall.startsWith('brick')) return;
  if (hash01(spec.id.length * 31, Math.round(spec.x), Math.round(spec.z)) > 0.2) return;
  const rng = new Rng(`ivy:${spec.id}`);
  // choose the side whose outward normal points most north (−z)
  const W = spec.w / 100, D = spec.d / 100;
  const sides: { len: number; at: (u: number, off: number) => [number, number]; nz: number }[] = [
    { len: W, at: (u, o) => localToWorld(spec, u, -o), nz: -Math.cos(spec.rotY) },
    { len: W, at: (u, o) => localToWorld(spec, W - u, D + o), nz: Math.cos(spec.rotY) },
    { len: D, at: (u, o) => localToWorld(spec, -o, D - u), nz: Math.sin(spec.rotY) },
    { len: D, at: (u, o) => localToWorld(spec, W + o, u), nz: -Math.sin(spec.rotY) },
  ];
  sides.sort((a, b) => a.nz - b.nz);
  const side = sides[0];
  const top = Math.min(10, (spec.floors * 3.6) * 0.7);
  for (let u = 0.5; u < side.len - 1; u += 1.1) {
    if (rng.chance(0.35)) continue;
    const h = top * (0.3 + rng.next() * 0.7);
    for (let y = 0; y < h; y += 1.1) {
      const [x0, z0] = side.at(u, 0.03), [x1, z1] = side.at(u + 1.3, 0.03);
      const yy = spec.y + y;
      g.quad('leafcard:ivy', [x0, yy, z0], [x1, yy, z1], [x1, yy + 1.3, z1], [x0, yy + 1.3, z0], [[0, 0], [1, 0], [1, 1], [0, 1]]);
    }
  }
}
