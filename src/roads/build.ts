// Per-tile road geometry: asphalt ribbons with crown, curbs, sidewalks (+tree pits, ramps), intersection
// cores, curb-return corners, crosswalks, markings, bridges, rail line, alleys and the bypass.
import { GeoBuilder, triangulate, type V3 } from '../core/geo';
import { tileNameAt } from '../core/tiles';
import { hash01 } from '../core/rng';
import { Terrain } from '../terrain/terrain';
import { naturalHeight } from '../terrain/heightfield';
import type { P2 } from '../world/layout';
import { sweepCurb } from './curbs';
import { MARK_BIKE, MARK_W, MARK_Y, dashed, ladderCrosswalk, stopBar, strip, type Frame } from './markings';
import { CROSS_SLOPE, CURB_H, CURB_TOP, RoadNetwork, polyAt, profileAt, type RNode, type Road, type Span } from './network';
import { domePanel, rampDip, treeGrate } from './sidewalks';

interface Chunk { span: Span; c0: number; c1: number; }
interface Ramp { road: Road; s: number; side: 1 | -1; }

export interface TreePit { x: number; z: number; y: number; road: string; }
export interface CrosswalkInfo { x: number; z: number; along: P2; road: string; node: number | null; }

class RoadPlan {
  chunks = new Map<string, Chunk[]>();
  nodes = new Map<string, RNode[]>();
  rail = new Map<string, [number, number][]>();
  treePits: TreePit[] = [];
  midblock: Ramp[] = [];
  crosswalks: CrosswalkInfo[] = [];
  constructor(public net: RoadNetwork) {
    for (const r of net.roads) for (const sp of r.spans) {
      const s0 = Math.min(sp.s0, sp.l0, sp.r0), s1 = Math.max(sp.s1, sp.l1, sp.r1);
      const n = Math.max(1, Math.ceil((s1 - s0) / 30));
      for (let i = 0; i < n; i++) {
        const c0 = s0 + ((s1 - s0) * i) / n, c1 = s0 + ((s1 - s0) * (i + 1)) / n;
        const mid = polyAt(r, (c0 + c1) / 2).p;
        push(this.chunks, tileNameAt(mid[0], mid[1]), { span: sp, c0, c1 });
      }
      // mid-block crosswalks on long Hamilton/main spans (CLAUDE.md §9.1)
      if ((r.kind === 'hamilton' || (r.kind === 'main' && r.id === 'columbia_s')) && sp.s1 - sp.s0 > 150 && sp.n0 && sp.n1) {
        const s = (sp.s0 + sp.s1) / 2;
        this.midblock.push({ road: r, s, side: 1 }, { road: r, s, side: -1 });
        const f = polyAt(r, s);
        this.crosswalks.push({ x: f.p[0], z: f.p[1], along: f.t, road: r.id, node: null });
      }
      // tree pits every 9 m on Hamilton & main sidewalks (vegetation phase plants these)
      if ((r.kind === 'hamilton' || r.kind === 'main') && r.sec.sidewalkCm >= 300) {
        for (const side of [1, -1] as const) {
          const a = side > 0 ? sp.l0 : sp.r0, b = side > 0 ? sp.l1 : sp.r1;
          for (let s = a + 6; s < b - 6; s += 9) {
            if (this.midblock.some((m) => m.road === r && Math.abs(m.s - s) < 4)) continue;
            if (r.id === 'hamilton' && side > 0 && polyAt(r, s).p[0] > 18 && polyAt(r, s).p[0] < 302) continue; // quad wall side
            if (r.bridges.some(([b0, b1]) => s > b0 - 5 && s < b1 + 5)) continue;
            const f = polyAt(r, s);
            const d = side * (r.half + CURB_TOP + 0.75);
            const y = gutter(r, s) + CURB_H + CROSS_SLOPE * (Math.abs(d) - r.half - CURB_TOP);
            this.treePits.push({ x: f.p[0] + f.n[0] * d, z: f.p[1] + f.n[1] * d, y, road: r.id });
          }
        }
      }
    }
    for (const n of net.nodes) {
      push(this.nodes, tileNameAt(n.x, n.z), n);
      for (const a of n.arms) {
        if (!a.road.sec.curb || a.road.kind === 'alley' || n.arms.length < 3) continue;
        const d = Math.max(2, a.cut - 1.6);
        this.crosswalks.push({ x: n.x + a.dir[0] * d, z: n.z + a.dir[1] * d, along: a.dir, road: a.road.id, node: n.id });
      }
    }
    const rail = Terrain.get().rail;
    const L = rail.cum[rail.cum.length - 1];
    for (let s = 0; s < L; s += 25) { const p = rail.at(s + 12.5); push(this.rail, tileNameAt(p[0], p[1]), [s, Math.min(L, s + 25)]); }
  }
}
function push<T>(m: Map<string, T[]>, k: string, v: T) { let a = m.get(k); if (!a) { a = []; m.set(k, a); } a.push(v); }
const gutter = (r: Road, s: number) => profileAt(r, s) - CROSS_SLOPE * r.half;

let plan: RoadPlan | null = null;
export function roadPlan(): RoadPlan { return (plan ??= new RoadPlan(RoadNetwork.get())); }

function frames(r: Road, s0: number, s1: number, step = 2): Frame[] {
  const out: Frame[] = [];
  const st = new Set<number>([s0, s1]);
  for (let s = Math.ceil(s0 / step) * step; s < s1; s += step) st.add(s);
  for (const c of r.cum) if (c > s0 && c < s1) st.add(c);
  for (const s of [...st].sort((a, b) => a - b)) {
    const f = polyAt(r, s);
    out.push({ p: f.p, t: f.t, n: f.n, y: profileAt(r, s), s });
  }
  return out;
}

export function walkMaterial(r: Road, side: 1 | -1, s: number): string {
  const w = r.sec.walk;
  if (r.id === 'hamilton') {
    const x = polyAt(r, s).p[0];
    return side > 0 && x > 18 && x < 302 ? 'tex:pavers_herringbone' : 'tex:pavers_running';
  }
  return w === 'none' ? 'tex:concrete_aged' : `tex:${w}`;
}

/** Build all road geometry belonging to a tile into `g`. */
export function buildRoadsForTile(tile: string, g: GeoBuilder) {
  const P = roadPlan();
  for (const ch of P.chunks.get(tile) ?? []) buildChunk(g, ch, P);
  for (const n of P.nodes.get(tile) ?? []) buildNode(g, n);
  for (const [s0, s1] of P.rail.get(tile) ?? []) buildRail(g, s0, s1);
}

function buildChunk(g: GeoBuilder, ch: Chunk, P: RoadPlan) {
  const { span: sp } = ch;
  const r = sp.road;
  const asphalt = `tex:${r.sec.surface}`;
  const a0 = Math.max(ch.c0, sp.s0), a1 = Math.min(ch.c1, sp.s1);
  const crown = (f: Frame, d: number) => f.y - CROSS_SLOPE * Math.abs(d) * (r.kind === 'alley' ? -0.5 : 1) - (r.kind === 'alley' ? CROSS_SLOPE * r.half * 0.5 : 0);
  if (a1 > a0 + 0.01) {
    const F = frames(r, a0, a1);
    strip(g, asphalt, F, -r.half, 0, crown, 0);
    strip(g, asphalt, F, 0, r.half, crown, 0);
    if (r.kind === 'highway' || r.kind === 'lane') {
      // gravel shoulders
      strip(g, 'tex:gravel', F, r.half, r.half + (r.kind === 'highway' ? 3 : 0.8), (f, d) => crown(f, r.half) - 0.03 - 0.02 * (Math.abs(d) - r.half), 0);
      strip(g, 'tex:gravel', F, -r.half - (r.kind === 'highway' ? 3 : 0.8), -r.half, (f, d) => crown(f, r.half) - 0.03 - 0.02 * (Math.abs(d) - r.half), 0);
    }
    markings(g, r, F, crown, sp);
    if (r.id === 'rosemary' || r.kind === 'alley') patches(g, r, F, crown);
  }
  // curbs & sidewalks per side
  if (r.sec.curb) for (const side of [1, -1] as const) {
    const b0 = Math.max(ch.c0, side > 0 ? sp.l0 : sp.r0), b1 = Math.min(ch.c1, side > 0 ? sp.l1 : sp.r1);
    if (b1 <= b0 + 0.01) continue;
    const F = frames(r, b0, b1, 1);
    const ramps = P.midblock.filter((m) => m.road === r && m.side === side && m.s > b0 - 2 && m.s < b1 + 2);
    const dip = (f: Frame, d: number) => ramps.reduce((acc, m) => Math.max(acc, rampDip(f.s - m.s, Math.abs(d) - r.half - CURB_TOP)), 0);
    const walkY = (f: Frame, d: number) => f.y - CROSS_SLOPE * r.half + CURB_H + CROSS_SLOPE * (Math.abs(d) - r.half - CURB_TOP) - dip(f, d);
    // curb: break around ramps
    let run: [number, number, number][] = [];
    const flush = () => { if (run.length > 1) sweepCurb(g, `tex:${r.sec.curbKey === 'GRANITE_CURB' ? 'granite' : 'concrete_aged'}`, run, side); run = []; };
    for (const f of F) {
      if (ramps.some((m) => Math.abs(f.s - m.s) < 0.9)) { flush(); continue; }
      run.push([f.p[0] + f.n[0] * r.half * side, f.p[1] + f.n[1] * r.half * side, f.y - CROSS_SLOPE * r.half]);
    }
    flush();
    // ramp aprons where the curb is cut: slope from gutter up to the walk
    for (const m of ramps) {
      const RF = frames(r, m.s - 0.9, m.s + 0.9, 0.3);
      strip(g, 'tex:concrete_new', RF, Math.min(side * r.half, side * (r.half + CURB_TOP)), Math.max(side * r.half, side * (r.half + CURB_TOP)), walkY, 0);
      const f = polyAt(r, m.s);
      const into: P2 = [-f.n[0] * side, -f.n[1] * side];
      const c: P2 = [f.p[0] + f.n[0] * side * (r.half + CURB_TOP + 0.305), f.p[1] + f.n[1] * side * (r.half + CURB_TOP + 0.305)];
      const yG = gutter(r, m.s);
      domePanel(g, c, into, yG + CROSS_SLOPE * 0.61 + 0.0, yG + 0.002, 1.22, 0.61);
    }
    // sidewalk strip (+ back edge)
    const walk = walkMaterial(r, side, (b0 + b1) / 2);
    const dIn = side * (r.half + CURB_TOP), dOut = side * r.row;
    strip(g, walk, F, Math.min(dIn, dOut), Math.max(dIn, dOut), walkY, 0);
    // back edge skirt (hides terrain seams)
    for (let i = 0; i < F.length - 1; i++) {
      const A = F[i], B = F[i + 1];
      const pa: V3 = [A.p[0] + A.n[0] * dOut, walkY(A, dOut), A.p[1] + A.n[1] * dOut];
      const pb: V3 = [B.p[0] + B.n[0] * dOut, walkY(B, dOut), B.p[1] + B.n[1] * dOut];
      const qa: V3 = [pa[0], pa[1] - 0.4, pa[2]], qb: V3 = [pb[0], pb[1] - 0.4, pb[2]];
      if (side > 0) g.quad('tex:concrete_aged', qa, qb, pb, pa); else g.quad('tex:concrete_aged', qa, pa, pb, qb);
    }
    // tree pits
    for (const t of P.treePits) {
      if (t.road !== r.id) continue;
      const pr = projectOnSpan(r, t.x, t.z);
      if (pr.s < b0 || pr.s >= b1 || Math.sign(pr.d) !== side) continue;
      treeGrate(g, [t.x, t.z], polyAt(r, pr.s).t, t.y);
    }
  }
  // bridge structure
  for (const [bs0, bs1] of r.bridges) {
    const c0 = Math.max(ch.c0, bs0), c1 = Math.min(ch.c1, bs1);
    if (c1 > c0) bridge(g, r, c0, c1, bs0, bs1);
  }
}

function projectOnSpan(r: Road, x: number, z: number) {
  let best = { s: 0, d: 0, dist: Infinity };
  for (let i = 0; i < r.pts.length - 1; i++) {
    const a = r.pts[i], b = r.pts[i + 1];
    const dx = b[0] - a[0], dz = b[1] - a[1], l2 = dx * dx + dz * dz;
    const t = Math.max(0, Math.min(1, ((x - a[0]) * dx + (z - a[1]) * dz) / l2));
    const px = a[0] + dx * t, pz = a[1] + dz * t, dist = Math.hypot(x - px, z - pz);
    if (dist < best.dist) { const l = Math.sqrt(l2); best = { s: r.cum[i] + t * l, d: Math.sign((x - a[0]) * (-dz) + (z - a[1]) * dx) * dist, dist }; }
  }
  return best;
}

function markings(g: GeoBuilder, r: Road, F: Frame[], yAt: (f: Frame, d: number) => number, sp: Span) {
  const margin = 4;
  const inner = F.filter((f) => f.s > sp.s0 + margin && f.s < sp.s1 - margin);
  if (inner.length < 2) return;
  const k = r.kind;
  if (k === 'hamilton' || k === 'main' || k === 'highway') {
    strip(g, MARK_Y, inner, -0.15, -0.05, yAt); strip(g, MARK_Y, inner, 0.05, 0.15, yAt);
  } else if (k === 'secondary' || k === 'campus') dashed(g, MARK_Y, inner, 0, 0.1, 3, 9, yAt);
  if (k === 'hamilton') {
    const e = r.half - r.sec.parkingCm / 100;
    for (const sd of [1, -1]) {
      strip(g, MARK_W, inner, sd * e - 0.05, sd * e + 0.05, yAt);
      // parking stall T-ticks every 6.7 m
      const s0 = inner[0].s, s1 = inner[inner.length - 1].s;
      for (let s = Math.ceil(s0 / 6.7) * 6.7; s < s1; s += 6.7) {
        const f = polyAt(r, s);
        const pts: Frame[] = [{ p: f.p, t: f.t, n: f.n, y: profileAt(r, s), s }, { p: polyAt(r, s + 0.1).p, t: f.t, n: f.n, y: profileAt(r, s + 0.1), s: s + 0.1 }];
        strip(g, MARK_W, pts, sd > 0 ? e : -e - 0.9, sd > 0 ? e + 0.9 : -e, yAt);
      }
    }
  }
  if (k === 'main' && r.sec.bikeCm) {
    const e = r.half - r.sec.bikeCm / 100;
    for (const sd of [1, -1]) {
      strip(g, MARK_BIKE, inner, Math.min(sd * e, sd * (r.half - 0.1)), Math.max(sd * e, sd * (r.half - 0.1)), yAt, 0.003);
      strip(g, MARK_W, inner, sd * e - 0.075, sd * e + 0.075, yAt);
    }
  }
  if (k === 'highway') {
    for (const sd of [1, -1]) {
      dashed(g, MARK_W, inner, sd * 3.65, 0.1, 3, 9, yAt);
      strip(g, MARK_W, inner, sd * (r.half - 0.2) - 0.05, sd * (r.half - 0.2) + 0.05, yAt);
    }
  }
}

function patches(g: GeoBuilder, r: Road, F: Frame[], yAt: (f: Frame, d: number) => number) {
  // ASPHALT_PATCH rectangles + crack-seal (grittier Rosemary Row / alleys, CLAUDE.md §9.3)
  for (let i = 0; i < F.length - 3; i += 3) {
    const h = hash01(Math.round(F[i].s), r.id.length, 91);
    if (h > 0.45) continue;
    const d0 = (hash01(i, 3, 5) - 0.5) * r.half * 1.4, w = 0.8 + hash01(i, 9, 2) * 2;
    strip(g, 'tex:asphalt_patch', F.slice(i, i + 3), d0, d0 + w, yAt, 0.002);
  }
}

function buildNode(g: GeoBuilder, n: RNode) {
  if (n.arms.length < 2 || !n.core.length) return;
  const y = n.y;
  const asphalt = `tex:${n.arms[0].road.sec.surface}`;
  // core fan
  for (let i = 0; i < n.core.length; i++) {
    const a = n.core[i], b = n.core[(i + 1) % n.core.length];
    const cross = (a[0] - n.x) * (b[1] - n.z) - (a[1] - n.z) * (b[0] - n.x);
    if (Math.abs(cross) < 1e-6) continue;
    if (cross > 0) g.tri(asphalt, [n.x, y, n.z], [b[0], y, b[1]], [a[0], y, a[1]]); else g.tri(asphalt, [n.x, y, n.z], [a[0], y, a[1]], [b[0], y, b[1]]);
  }
  // corners: sector sidewalk with ramp dips + curb arc
  for (const c of n.corners) {
    if (c.straight || c.arc.length < 2) continue;
    const kind = c.a.road.sec.curb ? c.a.road : c.b.road;
    if (!kind.sec.curb) continue;
    const yG = y - CROSS_SLOPE * Math.min(c.a.half, c.b.half);
    const walk = `tex:${kind.sec.walk === 'none' ? 'concrete_aged' : kind.sec.walk}`;
    const rampPts = c.ramps.map((r) => r.p);
    const vy = (p: P2) => {
      const fromCurb = c.radius - Math.hypot(p[0] - c.center[0], p[1] - c.center[1]);
      let dip = 0;
      for (const rp of rampPts) dip = Math.max(dip, rampDip(Math.hypot(p[0] - rp[0], p[1] - rp[1]) * (fromCurb < 0.2 ? 1 : 0.8), fromCurb));
      return yG + CURB_H + CROSS_SLOPE * Math.max(0, fromCurb - CURB_TOP) - dip;
    };
    // sector fan subdivided radially (2 rings) so ramp dips read
    const C = c.center;
    for (let i = 0; i < c.arc.length - 1; i++) {
      const A = c.arc[i], B = c.arc[i + 1];
      const mid = (p: P2, t: number): P2 => [C[0] + (p[0] - C[0]) * t, C[1] + (p[1] - C[1]) * t];
      const rings = [0, 0.55, 0.85, 1];
      for (let k = 0; k < rings.length - 1; k++) {
        const a0 = mid(A, rings[k]), b0 = mid(B, rings[k]), a1 = mid(A, rings[k + 1]), b1 = mid(B, rings[k + 1]);
        const pts: V3[] = [[a0[0], vy(a0), a0[1]], [a1[0], vy(a1), a1[1]], [b1[0], vy(b1), b1[1]], [b0[0], vy(b0), b0[1]]];
        const cr = (A[0] - C[0]) * (B[1] - C[1]) - (A[1] - C[1]) * (B[0] - C[0]);
        if (k === 0) { if (cr > 0) g.tri(walk, pts[0], pts[2], pts[1]); else g.tri(walk, pts[0], pts[1], pts[2]); }
        else if (cr > 0) g.quad(walk, pts[0], pts[3], pts[2], pts[1]); else g.quad(walk, pts[0], pts[1], pts[2], pts[3]);
      }
    }
    // curb along arc, broken at ramps
    let run: [number, number, number][] = [];
    const ck = `tex:${kind.sec.curbKey === 'GRANITE_CURB' ? 'granite' : 'concrete_aged'}`;
    const cr = (c.arc[0][0] - C[0]) * (c.arc[1][1] - C[1]) - (c.arc[0][1] - C[1]) * (c.arc[1][0] - C[0]);
    const flush = () => { if (run.length > 1) sweepCurb(g, ck, run, cr > 0 ? 1 : -1); run = []; };
    for (const p of c.arc) {
      if (rampPts.some((rp) => Math.hypot(p[0] - rp[0], p[1] - rp[1]) < 0.9)) { flush(); continue; }
      run.push([p[0], p[1], yG]);
    }
    flush();
    for (const rp of c.ramps) {
      const into = rp.dir;
      const cpos: P2 = [rp.p[0] - into[0] * 0.305, rp.p[1] - into[1] * 0.305];
      domePanel(g, cpos, into, yG + CROSS_SLOPE * 0.61, yG + 0.002, 1.22, 0.61);
    }
  }
  // crosswalks + stop bars
  const signalized = n.signal;
  for (const a of n.arms) {
    if (!a.road.sec.curb || a.road.kind === 'alley' || n.arms.length < 3) continue;
    const d = Math.max(2, a.cut - 1.6);
    ladderCrosswalk(g, [n.x + a.dir[0] * d, n.z + a.dir[1] * d], a.dir, a.half, 3.0, y);
    if (signalized || a.road.kind === 'secondary' || a.road.kind === 'campus') stopBar(g, [n.x + a.dir[0] * (d + 2.3), n.z + a.dir[1] * (d + 2.3)], a.dir, -a.half + 0.3, -0.2, 0.6, profileAt(a.road, a.s + a.sign * (d + 2.6)));
  }
  // scramble diagonals at The Summit (CLAUDE.md §9.2)
  if (n.scramble) {
    const cs = n.corners.filter((c) => !c.straight && c.arc.length);
    for (let i = 0; i < 2 && cs.length === 4; i++) {
      const A = cs[i].arc[Math.floor(cs[i].arc.length / 2)], B = cs[i + 2].arc[Math.floor(cs[i + 2].arc.length / 2)];
      const dx = B[0] - A[0], dz = B[1] - A[1], L = Math.hypot(dx, dz);
      const along: P2 = [-dz / L, dx / L];
      ladderCrosswalk(g, [(A[0] + B[0]) / 2, (A[1] + B[1]) / 2], along, L / 2 - 1.5, 3.0, y + 0.0015);
    }
  }
  // mid-block crosswalk stripes are on spans; draw them here for spans touching this node? (done per plan)
}

/** Draw the mid-block crosswalks belonging to a tile (called by the tile builder). */
export function buildMidblockForTile(tile: string, g: GeoBuilder) {
  const P = roadPlan();
  for (const cw of P.crosswalks) {
    if (cw.node !== null || tileNameAt(cw.x, cw.z) !== tile) continue;
    const r = P.net.roads.find((q) => q.id === cw.road)!;
    const pr = projectOnSpan(r, cw.x, cw.z);
    const n: P2 = [-cw.along[1], cw.along[0]];
    ladderCrosswalk(g, [cw.x, cw.z], n, r.half, 3.0, profileAt(r, pr.s));
  }
}

function bridge(g: GeoBuilder, r: Road, c0: number, c1: number, b0: number, b1: number) {
  const F = frames(r, c0, c1, 2);
  const w = r.row;
  // deck slab 70 cm under the walking surface
  strip(g, 'tex:concrete_aged', F, w, -w, (f) => f.y - 0.75, 0);
  for (const side of [1, -1] as const) {
    // stone-faced parapet 45 cm thick, 107 cm guard height
    for (let i = 0; i < F.length - 1; i++) {
      const A = F[i], B = F[i + 1];
      const yA = A.y - CROSS_SLOPE * r.half + CURB_H, yB = B.y - CROSS_SLOPE * r.half + CURB_H;
      const pA = (d: number, y: number): V3 => [A.p[0] + A.n[0] * d * side, y, A.p[1] + A.n[1] * d * side];
      const pB = (d: number, y: number): V3 => [B.p[0] + B.n[0] * d * side, y, B.p[1] + B.n[1] * d * side];
      const di = w, dq = w + 0.45;
      const face = (d: number, out: boolean) => out === side > 0
        ? g.quad('tex:fieldstone', pA(d, A.y - 0.75), pB(d, B.y - 0.75), pB(d, yB + 1.07), pA(d, yA + 1.07))
        : g.quad('tex:fieldstone', pB(d, B.y - 0.75), pA(d, A.y - 0.75), pA(d, yA + 1.07), pB(d, yB + 1.07));
      face(dq, true); face(di, false);
      if (side > 0) g.quad('tex:capstone', pA(di - 0.02, yA + 1.07), pA(dq + 0.02, yA + 1.07), pB(dq + 0.02, yB + 1.07), pB(di - 0.02, yB + 1.07));
      else g.quad('tex:capstone', pA(di - 0.02, yA + 1.07), pB(di - 0.02, yB + 1.07), pB(dq + 0.02, yB + 1.07), pA(dq + 0.02, yA + 1.07));
    }
  }
  // fieldstone piers every 18 m, arches between (semi-circular soffit approximated)
  const span = 18;
  for (let s = Math.ceil((b0 + 6) / span) * span; s < b1 - 4; s += span) {
    if (s < c0 || s >= c1) continue;
    const f = polyAt(r, s);
    const top = profileAt(r, s) - 0.75;
    const bottom = naturalHeight(f.p[0], f.p[1]) - 1;
    if (top - bottom < 2) continue;
    g.push(); g.translate(f.p[0], 0, f.p[1]); g.rotateY(Math.atan2(-f.t[1], f.t[0]));
    g.box('tex:fieldstone', -1.2, bottom, -w - 0.45, 1.2, top, w + 0.45);
    g.pop();
  }
  // arch rings: thin voussoir bands under the deck between piers
  for (let s = Math.ceil((b0 + 6) / span) * span; s + span < b1 - 4; s += span) {
    for (let k = 1; k < 12; k++) {
      const s1 = s + 1.2 + ((span - 2.4) * k) / 12, s2 = s + 1.2 + ((span - 2.4) * (k + 1)) / 12;
      if (s1 < c0 || s1 >= c1) continue;
      const rr = (span - 2.4) / 2, cx = s + span / 2;
      const yOf = (q: number) => profileAt(r, q) - 0.75 - (rr - Math.sqrt(Math.max(0, rr * rr - (q - cx) ** 2))) - 0.05;
      const fa = polyAt(r, s1), fb = polyAt(r, s2);
      for (const side of [1, -1]) {
        const d = side * (w + 0.45);
        const ya = yOf(s1), yb = yOf(s2);
        const top = profileAt(r, s1) - 0.75;
        void top;
        const p = (f: typeof fa, y: number, dd: number): V3 => [f.p[0] + f.n[0] * dd, y, f.p[1] + f.n[1] * dd];
        // spandrel wall face (between arch curve and deck)
        if (side > 0) g.quad('tex:fieldstone', p(fa, ya, d), p(fb, yb, d), p(fb, profileAt(r, s2) - 0.75, d), p(fa, profileAt(r, s1) - 0.75, d));
        else g.quad('tex:fieldstone', p(fb, yb, d), p(fa, ya, d), p(fa, profileAt(r, s1) - 0.75, d), p(fb, profileAt(r, s2) - 0.75, d));
      }
    }
  }
}

function buildRail(g: GeoBuilder, s0: number, s1: number) {
  const rail = Terrain.get().rail;
  const pts: { p: P2; t: P2; n: P2; y: number; s: number }[] = [];
  for (let s = s0; s <= s1 + 1e-6; s += 2.5) {
    const p = rail.at(s), q = rail.at(Math.min(s + 0.5, s1 + 1));
    let tx = q[0] - p[0], tz = q[1] - p[1]; const l = Math.hypot(tx, tz) || 1; tx /= l; tz /= l;
    pts.push({ p, t: [tx, tz], n: [-tz, tx], y: rail.yAt(s) - 0.35, s });
  }
  // ballast bed (gravel) 4.4 m wide
  strip(g, 'tex:gravel', pts, -2.2, 2.2, (f) => f.y, 0.02);
  // ties every 50 cm: 260 x 23 x 18 cm, creosoted
  for (let s = Math.ceil(s0 / 0.5) * 0.5; s < s1; s += 0.5) {
    const p = rail.at(s), q = rail.at(s + 0.3);
    const a = Math.atan2(-(q[1] - p[1]), q[0] - p[0]);
    const y = rail.yAt(s) - 0.35;
    g.push(); g.translate(p[0], y, p[1]); g.rotateY(a);
    g.box('paint:PINE_BARK', -0.115, 0, -1.3, 0.115, 0.18, 1.3);
    g.pop();
  }
  // rails: standard gauge 143.5 cm, 15 cm tall heads
  for (const side of [1, -1]) {
    const d = side * (1.435 / 2 + 0.036);
    strip(g, 'metal:GALV_STEEL', pts, d - 0.036, d + 0.036, (f) => f.y + 0.18 + 0.15, 0);
    for (let i = 0; i < pts.length - 1; i++) {
      const A = pts[i], B = pts[i + 1];
      for (const e of [-1, 1]) {
        const dd = d + e * 0.036;
        const a0: V3 = [A.p[0] + A.n[0] * dd, A.y + 0.18, A.p[1] + A.n[1] * dd], b0: V3 = [B.p[0] + B.n[0] * dd, B.y + 0.18, B.p[1] + B.n[1] * dd];
        const a1: V3 = [a0[0], A.y + 0.33, a0[2]], b1: V3 = [b0[0], B.y + 0.33, b0[2]];
        if (e > 0) g.quad('metal:GALV_STEEL', a0, b0, b1, a1); else g.quad('metal:GALV_STEEL', b0, a0, a1, b1);
      }
    }
  }
}

/** Collision helpers: none needed — Terrain.surface() covers roads. */
export const _tri = triangulate;
