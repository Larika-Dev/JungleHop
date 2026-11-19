// Old-growth forest parks: land use, trails, trees and furniture stay consistent.
import { describe, expect, it } from 'vitest';
import { cityPlan } from '../src/world/cityPlan';
import { parks, inPark, pathDist } from '../src/vegetation/parks';
import { treesForTile } from '../src/vegetation/placement';
import { furnitureByTile, LAMPS } from '../src/street/furniture';
import { allTiles, tileInCore } from '../src/core/tiles';
import { districtAt } from '../src/world/layout';
import { inPad } from '../src/world/sites';

describe('forest parks', () => {
  cityPlan();
  const p = parks();
  it('cover most of the green space in the core (0.9–1.8 km²)', () => {
    expect(p.area).toBeGreaterThan(0.9e6);
    expect(p.area).toBeLessThan(1.8e6);
  });
  it('are deterministic', () => {
    const n = p.paths.length, first = JSON.stringify(p.paths[0]?.pts.slice(0, 3));
    expect(n).toBeGreaterThan(30);
    expect(JSON.stringify(parks().paths[0]?.pts.slice(0, 3))).toBe(first);
  });
  it('never replace the quads, the Quarry plaza or downtown', () => {
    for (const [x, z] of [[190, 150], [190, 470], [52, 500], [0, -30], [-200, -30]]) {
      const id = districtAt(x, z)?.id;
      expect(inPark(x, z), `${x},${z} (${id})`).toBe(false);
    }
  });
  it('route trails through the parks (smoothing may graze the edge; never through a building)', () => {
    const near = (x: number, z: number) => [[0, 0], [4, 0], [-4, 0], [0, 4], [0, -4]].some(([dx, dz]) => inPark(x + dx, z + dz));
    for (const q of p.paths) {
      const [sx, sz] = q.pts[0], [ex, ez] = q.pts[q.pts.length - 1];
      const inner = q.pts.filter(([x, z]) => Math.hypot(x - sx, z - sz) > 12 && Math.hypot(x - ex, z - ez) > 12);
      for (const [x, z] of inner) {
        expect(near(x, z), `${x.toFixed(1)},${z.toFixed(1)}`).toBe(true);
        expect(inPad(x, z, 1), `trail through a building at ${x.toFixed(1)},${z.toFixed(1)}`).toBe(false);
      }
    }
  });
  it('keep trees off the trails', () => {
    for (const t of allTiles().filter(tileInCore)) for (const tr of treesForTile(t)) {
      if (!inPark(tr.x, tr.z)) continue;
      expect(pathDist(tr.x, tr.z)).toBeGreaterThan(0.85);
    }
  });
  it('light the gravel trails with campus lanterns and keep benches beside them', () => {
    const f = [...furnitureByTile().values()].flat();
    const lanterns = f.filter((x) => x.model === 'lantern' && inPark(x.x, x.z));
    expect(lanterns.length).toBeGreaterThan(50);
    for (const b of f.filter((x) => (x.model === 'bench' || x.model === 'log' || x.model === 'stump') && inPark(x.x, x.z))) expect(pathDist(b.x, b.z)).toBeGreaterThan(0.25);
    expect(LAMPS.filter((l) => l.color === 'LAMP_CAMPUS').length).toBeGreaterThanOrEqual(lanterns.length);
  });
});
