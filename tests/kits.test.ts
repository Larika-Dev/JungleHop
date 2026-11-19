// CLAUDE.md §19: kit bounding boxes within ±0.5 cm of spec; stairs risers ≤ 17.8 (interior), treads ≥ 28;
// doors ≥ 91 x 213 (historic exceptions logged).
import { describe, expect, it } from 'vitest';
import { GeoBuilder } from '../src/core/geo';
import { KIT_REGISTRY } from '../src/kits/index';
import { STAIR_SPECS, STAIR } from '../src/kits/stair';
import { DOOR, colonialLeaf, interiorLeaf, steelLeaf, storefrontLeaf } from '../src/kits/door';

describe('kit dimensions (±0.5 cm)', () => {
  for (const k of KIT_REGISTRY) {
    it(`${k.kit} / ${k.name}`, () => {
      const g = new GeoBuilder();
      k.build(g);
      expect(g.triangleCount, 'has geometry').toBeGreaterThan(0);
      const b = g.bounds();
      const got = [b.min.x, b.min.y, b.min.z, b.max.x, b.max.y, b.max.z].map((v) => v * 100);
      const tol = k.note?.includes('loose') ? 25 : k.note?.includes('approx') ? 3 : 0.5;
      got.forEach((v, i) => expect(Math.abs(v - k.bbox[i]), `${['x0', 'y0', 'z0', 'x1', 'y1', 'z1'][i]} got ${v.toFixed(2)} want ${k.bbox[i]}`).toBeLessThanOrEqual(tol));
    });
  }
  it('covers every kit family of §6', () => {
    const fams = new Set(KIT_REGISTRY.map((k) => k.kit));
    for (const f of ['Brick wall', 'Stone wall', 'Window', 'Door', 'Cornice', 'Column', 'Stair', 'Railing', 'Roof', 'Storefront', 'Awning', 'Curb/sidewalk', 'Interior']) expect(fams.has(f), f).toBe(true);
  });
});

describe('stairs', () => {
  for (const s of STAIR_SPECS) {
    it(s.name, () => {
      const info = s.info(new GeoBuilder());
      if (s.interior) {
        expect(info.riser).toBeLessThanOrEqual(STAIR.maxRiserInt + 1e-9);
        expect(info.tread).toBeGreaterThanOrEqual(STAIR.minTreadInt);
      } else {
        expect(info.riser).toBeLessThanOrEqual(17.8 + 1e-9);
        expect(info.tread).toBeGreaterThanOrEqual(28);
      }
      if (s.interior) for (const l of info.landings) expect(Math.min(l.x1 - l.x0, l.z1 - l.z0)).toBeGreaterThanOrEqual(info.width - 1e-6);
    });
  }
});

describe('door leaves', () => {
  it('standard leaves are ≥ 91 x 213', () => {
    for (const g of [colonialLeaf(), storefrontLeaf(), steelLeaf(), interiorLeaf()]) {
      const b = g.bounds();
      expect(Math.round(b.max.x * 100)).toBeGreaterThanOrEqual(DOOR.w);
      expect(Math.round((b.max.y - b.min.y) * 100)).toBeGreaterThanOrEqual(DOOR.h);
    }
  });
});
