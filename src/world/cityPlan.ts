// Deterministic city plan (seed 1795): every building spec in the city, sited on the terrain (FFL,
// grades), with terrain pads registered and per-tile assignment. Districts and landmarks feed it.
import { Terrain } from '../terrain/terrain';
import { naturalHeight } from '../terrain/heightfield';
import { tileNameAt } from '../core/tiles';
import { LANDMARK_HOOKS } from '../buildings/manager';
import { landmarkSpecs } from '../buildings/landmarks/index';
import type { BuildingSpec } from '../interiors/types';
import '../districts/index';
import { addPad, padFor } from './sites';

export interface Sited { spec: BuildingSpec; grades: { front: number; low: number }; tile: string; }
export interface CityPlan { buildings: Sited[]; byTile: Map<string, Sited[]>; byId: Map<string, Sited>; }

type Rect4 = { cx: number; cz: number; c: number; s: number; hw: number; hd: number };
const footprint = (s: BuildingSpec): Rect4 => {
  const c = Math.cos(s.rotY), sn = Math.sin(s.rotY), hw = s.w / 200, hd = s.d / 200;
  return { cx: s.x + hw * c + hd * sn, cz: s.z - hw * sn + hd * c, c, s: sn, hw, hd };
};
/** Separating-axis overlap of two oriented rects (m), with margin. */
export function overlaps(a: Rect4, b: Rect4, margin = 0.3): boolean {
  const axes = [[a.c, -a.s], [a.s, a.c], [b.c, -b.s], [b.s, b.c]];
  for (const [ax, az] of axes) {
    const proj = (r: Rect4) => { const ux = [r.c, -r.s], uz = [r.s, r.c]; const ext = r.hw * Math.abs(ux[0] * ax + ux[1] * az) + r.hd * Math.abs(uz[0] * ax + uz[1] * az); const c = r.cx * ax + r.cz * az; return [c - ext, c + ext]; };
    const [a0, a1] = proj(a), [b0, b1] = proj(b);
    if (a1 + margin < b0 || b1 + margin < a0) return false;
  }
  return true;
}

/** Local building point (m) -> world xz. */
export function localToWorld(s: BuildingSpec, lx: number, lz: number): [number, number] {
  const c = Math.cos(s.rotY), sn = Math.sin(s.rotY);
  return [s.x + lx * c + lz * sn, s.z - lx * sn + lz * c];
}

export class CityPlanBuilder {
  sited: Sited[] = [];
  private rects: Rect4[] = [];
  T = Terrain.get();

  /** Is the footprint clear of road right-of-way and other buildings? */
  clear(spec: BuildingSpec, margin = 0.3): boolean {
    const r = footprint(spec);
    for (const o of this.rects) if (overlaps(r, o, margin)) return false;
    const W = spec.w / 100, D = spec.d / 100;
    for (let i = 0; i <= Math.ceil(W / 3); i++) for (let j = 0; j <= Math.ceil(D / 3); j++) {
      const [x, z] = localToWorld(spec, Math.min(W, i * 3), Math.min(D, j * 3));
      const hit = this.T.net.query(x, z);
      if (hit && hit.zone !== 'verge') return false;
    }
    return true;
  }

  /** Site a spec: FFL from the front grade (+ stoop for historic types), register its terrain pad. */
  add(spec: BuildingSpec, opts: { check?: boolean; stoop?: number } = {}): Sited | null {
    if (opts.check !== false && !this.clear(spec)) return null;
    const W = spec.w / 100, D = spec.d / 100;
    const front: number[] = [], all: number[] = [];
    for (let i = 0; i <= 4; i++) { const [x, z] = localToWorld(spec, (W * i) / 4, -1.2); front.push(this.T.surface(x, z)); }
    for (let i = 0; i <= 4; i++) for (let j = 0; j <= 4; j++) { const [x, z] = localToWorld(spec, (W * i) / 4, (D * j) / 4); all.push(naturalHeight(x, z)); }
    const fg = front.reduce((a, b) => a + b, 0) / front.length;
    const maxG = Math.max(...all), minG = Math.min(...all, ...front);
    const hooks = spec.custom ? LANDMARK_HOOKS.get(spec.custom) : undefined;
    let y: number;
    if (hooks?.fixedY !== undefined) y = hooks.fixedY;
    else if (hooks?.siteY) y = hooks.siteY(fg, maxG);
    else if (spec.facade.storefront || spec.typology === 'parking') y = fg + 0.02;
    else y = Math.max(fg, Math.min(maxG, fg + 1.2)) + (opts.stoop ?? (spec.facade.stoop ? 0.48 : 0.15));
    spec.y = Math.round(y * 100) / 100;
    const pads = hooks?.pads ? hooks.pads(spec) : [padFor(spec, spec.y)];
    for (const p of pads) addPad('c' in p ? (p as any) : { ...p, c: 1, s: 0, margin: 6 });
    this.rects.push(footprint(spec));
    const s: Sited = { spec, grades: { front: fg - spec.y, low: minG - spec.y }, tile: '' };
    const r = footprint(spec);
    s.tile = tileNameAt(r.cx, r.cz);
    this.sited.push(s);
    return s;
  }
  reserve(spec: BuildingSpec) { this.rects.push(footprint(spec)); }
  /** Site a building on top of another's roof (set-back towers above a base). */
  reserveOnRoof(spec: BuildingSpec, base: BuildingSpec) {
    const [g, u] = [450, 330];
    spec.y = base.y + (g + u * (base.floors - 1)) / 100;
    const r = footprint(spec);
    const s: Sited = { spec, grades: { front: 0, low: 0 }, tile: tileNameAt(r.cx, r.cz) };
    this.sited.push(s);
  }
}

import { DISTRICT_GENERATORS } from './districtRegistry';

let plan: CityPlan | null = null;
export function cityPlan(): CityPlan {
  if (plan) return plan;
  const b = new CityPlanBuilder();
  for (const s of landmarkSpecs()) b.add(s, { check: false });
  for (const g of [...DISTRICT_GENERATORS].sort((p, q) => p.order - q.order)) g.run(b);
  const byTile = new Map<string, Sited[]>(), byId = new Map<string, Sited>();
  for (const s of b.sited) { let a = byTile.get(s.tile); if (!a) byTile.set(s.tile, (a = [])); a.push(s); byId.set(s.spec.id, s); }
  plan = { buildings: b.sited, byTile, byId };
  return plan;
}
