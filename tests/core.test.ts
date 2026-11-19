import { describe, expect, it } from 'vitest';
import { cm, onGrid, snap, toCm } from '../src/core/units';
import { Rng, rng } from '../src/core/rng';
import { COLS, ROWS, tileName, tileNameAt, tileBounds, parseTile } from '../src/core/tiles';
import { GeoBuilder } from '../src/core/geo';

describe('units', () => {
  it('converts integer cm exactly', () => { expect(cm(213)).toBe(2.13); expect(toCm(2.13)).toBe(213); expect(snap(1.23456)).toBe(1.23); expect(onGrid(1.23)).toBe(true); expect(onGrid(1.235)).toBe(false); });
});
describe('rng', () => {
  it('is deterministic per label', () => {
    const a = rng('x'), b = rng('x'), c = rng('y');
    const sa = [a.next(), a.next(), a.next()], sb = [b.next(), b.next(), b.next()];
    expect(sa).toEqual(sb);
    expect(c.next()).not.toBe(sa[0]);
  });
  it('ranges', () => { const r = new Rng('r'); for (let i = 0; i < 1000; i++) { const v = r.int(3, 7); expect(v).toBeGreaterThanOrEqual(3); expect(v).toBeLessThanOrEqual(7); } });
});
describe('tiles', () => {
  it('grid is 18 x 17 and the origin sits in T_9_7', () => {
    expect(COLS).toBe(18); expect(ROWS).toBe(17);
    expect(tileNameAt(0, 0)).toBe('T_9_7');
    expect(tileName(parseTile('T_3_4'))).toBe('T_3_4');
    const b = tileBounds({ col: 9, row: 7 });
    expect(b).toEqual({ x0: -100, x1: 100, z0: -50, z1: 150 });
  });
});
describe('GeoBuilder', () => {
  it('box bounds and outward normals', () => {
    const g = new GeoBuilder();
    g.box('paint:TRIM_WHITE', 0, 0, 0, 1, 2, 3);
    const b = g.bounds();
    expect(b.min.toArray()).toEqual([0, 0, 0]);
    expect(b.max.toArray()).toEqual([1, 2, 3]);
    const geo = g.geometryFor('paint:TRIM_WHITE')!;
    const pos = geo.getAttribute('position'), nor = geo.getAttribute('normal');
    for (let i = 0; i < pos.count; i++) {
      const c = [pos.getX(i) - 0.5, pos.getY(i) - 1, pos.getZ(i) - 1.5];
      const d = c[0] * nor.getX(i) + c[1] * nor.getY(i) + c[2] * nor.getZ(i);
      expect(d).toBeGreaterThan(0);
    }
    expect(g.triangleCount).toBe(12);
  });
  it('prism caps & walls face outward for either winding', () => {
    for (const poly of [[[0, 0], [2, 0], [2, 2], [0, 2]], [[0, 0], [0, 2], [2, 2], [2, 0]]] as [number, number][][]) {
      const g = new GeoBuilder();
      g.prism('k', poly, 0, 1);
      const geo = g.geometryFor('k')!;
      const pos = geo.getAttribute('position'), nor = geo.getAttribute('normal');
      for (let i = 0; i < pos.count; i++) {
        const d = (pos.getX(i) - 1) * nor.getX(i) + (pos.getY(i) - 0.5) * nor.getY(i) + (pos.getZ(i) - 1) * nor.getZ(i);
        expect(d).toBeGreaterThan(0);
      }
    }
  });
});
