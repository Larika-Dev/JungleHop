// Terrain = natural heightfield flattened by road corridors (2% cross-slopes) and the rail embankment.
//   height(x,z)  -> terrain mesh surface (tucked 12 cm under paved areas, which have their own meshes)
//   surface(x,z) -> exact walkable surface (asphalt crown, 15 cm curbs, sidewalks) for collision
import { RoadNetwork } from '../roads/network';
import { smoothstep } from '../core/units';
import { RAIL, type P2 } from '../world/layout';
import { naturalHeight, naturalSlope } from './heightfield';
import { creekDistance } from './ravine';
import { segDist } from './ravine';

const RAIL_HALF_TOP = 2.2; // ballast shoulder half-width (m)
const RAIL_LIFT = 1.5; // embankment height (CLAUDE.md §8)

class Rail {
  cum: number[] = [0];
  profile: number[] = [];
  constructor(public pts: P2[]) {
    for (let i = 1; i < pts.length; i++) this.cum.push(this.cum[i - 1] + Math.hypot(pts[i][0] - pts[i - 1][0], pts[i][1] - pts[i - 1][1]));
    const L = this.cum[this.cum.length - 1];
    const raw: number[] = [];
    for (let s = 0; s <= L; s += 4) { const p = this.at(s); raw.push(naturalHeight(p[0], p[1])); }
    // heavy smoothing: rail grades are gentle
    let sm = raw;
    for (let pass = 0; pass < 4; pass++) sm = sm.map((_, i) => { let a = 0, n = 0; for (let k = -12; k <= 12; k++) { const j = Math.max(0, Math.min(sm.length - 1, i + k)); a += sm[j]; n++; } return a / n; });
    this.profile = sm.map((v, i) => Math.max(v, raw[i] - 0.5) + RAIL_LIFT);
  }
  at(s: number): P2 {
    let i = 1; while (i < this.cum.length - 1 && this.cum[i] < s) i++;
    const a = this.pts[i - 1], b = this.pts[i], k = (s - this.cum[i - 1]) / (this.cum[i] - this.cum[i - 1] || 1);
    return [a[0] + (b[0] - a[0]) * k, a[1] + (b[1] - a[1]) * k];
  }
  yAt(s: number) { const f = Math.max(0, Math.min(this.profile.length - 1.001, s / 4)); const i = Math.floor(f); return this.profile[i] + (this.profile[i + 1] - this.profile[i]) * (f - i); }
  project(x: number, z: number) {
    let best = { d: Infinity, s: 0 };
    for (let i = 0; i < this.pts.length - 1; i++) { const r = segDist(x, z, this.pts[i], this.pts[i + 1]); if (r.d < best.d) best = { d: r.d, s: this.cum[i] + r.t * (this.cum[i + 1] - this.cum[i]) }; }
    return best;
  }
}

export class Terrain {
  static instance: Terrain | null = null;
  static get(): Terrain { return (this.instance ??= new Terrain()); }
  net = RoadNetwork.get();
  rail = new Rail(RAIL);

  /** Rail embankment influence: returns blended height or null. */
  private railHeight(x: number, z: number, e: number): number | null {
    if (x > -560 || x < -900 && x < -1000) return null;
    const { d, s } = this.rail.project(x, z);
    if (d > 30) return null;
    const ry = this.rail.yAt(s);
    if (d <= RAIL_HALF_TOP) return ry - 0.35; // ballast top (ties/rails sit on it)
    const side = RAIL_HALF_TOP + Math.abs(ry - 0.35 - e) * 1.5; // 1:1.5 slopes
    if (d >= side) return null;
    return ry - 0.35 + (e - (ry - 0.35)) * smoothstep(RAIL_HALF_TOP, side, d);
  }

  natural(x: number, z: number) { return naturalHeight(x, z); }

  /** Height for the terrain mesh. */
  height(x: number, z: number): number {
    let e = naturalHeight(x, z);
    const rh = this.railHeight(x, z, e);
    if (rh !== null) e = rh;
    const hit = this.net.query(x, z);
    if (!hit) return e;
    if (hit.bridge) return hit.zone === 'verge' ? e : Math.min(e, hit.y - 3);
    if (hit.zone === 'verge' || hit.zone === 'shoulder') return e + (hit.y - e) * hit.blend - (hit.zone === 'shoulder' ? 0.02 : 0);
    return hit.y - 0.12;
  }

  /** Exact walkable surface (collision ground). */
  surface(x: number, z: number): number {
    const hit = this.net.query(x, z);
    if (hit && hit.zone !== 'verge' && hit.zone !== 'shoulder') return hit.y;
    return this.height(x, z);
  }

  /** Ground classification for splat/vegetation: 0 grass, 1 clay/bank, 2 forest floor, 3 worn. */
  slope(x: number, z: number) { return naturalSlope(x, z); }
  creek(x: number, z: number) { return creekDistance(x, z); }
  paved(x: number, z: number): boolean { const h = this.net.query(x, z); return !!h && h.zone !== 'verge'; }
}
