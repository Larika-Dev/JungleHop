// District helpers: lots along a road segment, facing it, at the right-of-way line + setback.
import { Rng } from '../core/rng';
import { RoadNetwork, polyAt, type Road } from '../roads/network';
import type { CityPlanBuilder } from '../world/cityPlan';
import type { BuildingSpec } from '../interiors/types';

export interface LotCtx { x: number; z: number; rotY: number; w: number; d: number; i: number; s: number; }

/**
 * Walk a road (by id) between stations s0..s1 on one side (+1 = left of travel), placing lots of width
 * from `widths()`; `make` returns a spec for a lot (origin/rotation given) or null to leave it empty.
 */
export function alongRoad(b: CityPlanBuilder, roadId: string, side: 1 | -1, s0: number, s1: number, setback: number,
  widths: () => number, depth: () => number, make: (lot: LotCtx) => BuildingSpec | null, gap = 2): number {
  const net = RoadNetwork.get();
  const r = net.roads.find((q) => q.id === roadId);
  if (!r) return 0;
  let s = Math.max(0, s0), n = 0, i = 0;
  const end = Math.min(r.length, s1);
  while (s < end - 6) {
    const w = widths(), d = depth();
    if (s + w / 100 > end) break;
    const lot = lotAt(r, s, side, setback, w, d, i);
    const spec = make(lot);
    if (spec && b.add(spec)) { n++; s += w / 100 + gap; }
    else s += 3;
    i++;
  }
  return n;
}

export function lotAt(r: Road, s: number, side: 1 | -1, setback: number, w: number, d: number, i: number): LotCtx {
  const f = polyAt(r, s + w / 200);
  const nx = f.n[0] * side, nz = f.n[1] * side;
  const theta = Math.atan2(nx, nz); // local +z (into the lot) points away from the road
  const off = r.row + setback;
  const cx = f.p[0] + nx * off, cz = f.p[1] + nz * off;
  // front-left corner: local +x direction = (cos θ, -sin θ)
  const ux = Math.cos(theta), uz = -Math.sin(theta);
  return { x: cx - ux * (w / 200), z: cz - uz * (w / 200), rotY: theta, w, d, i, s };
}

export const rngFor = (name: string) => new Rng(`district:${name}`);
