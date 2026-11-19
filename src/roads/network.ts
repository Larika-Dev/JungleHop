// Road network (CLAUDE.md §8/§9): centerlines -> spans between intersection nodes, elevation profiles
// pinned at nodes (Hamilton held at 0 on the ridge), bridges over dips, curb-return fillets at
// corners, and exact surface queries (asphalt crown 2%, 15 cm curbs, sidewalks sloping 2% to the street).
import { naturalHeight } from '../terrain/heightfield';
import { segDist } from '../terrain/ravine';
import { SECTIONS, roadHalf, rowHalf, BYPASS, ROADS, type P2, type RoadDef, type RoadKind, type RoadSection } from '../world/layout';

export const CROSS_SLOPE = 0.02;
export const CURB_H = 0.15;
export const CURB_TOP = 0.15;
const PSTEP = 2; // profile sample spacing (m)

export interface Road {
  id: string; name: string; kind: RoadKind; sec: RoadSection; def: RoadDef;
  pts: P2[]; cum: number[]; length: number; closed: boolean;
  half: number; row: number; priority: number;
  profile: Float32Array; bridges: [number, number][];
  nodes: { node: RNode; s: number }[];
  spans: Span[];
}
export interface Arm { road: Road; s: number; dir: P2; sign: 1 | -1; half: number; row: number; angle: number; cutL: number; cutR: number; cut: number; }
export interface Corner { a: Arm; b: Arm; center: P2; arc: P2[]; radius: number; straight: boolean; ramps: { p: P2; dir: P2 }[]; }
export interface RNode { id: number; x: number; z: number; y: number; arms: Arm[]; corners: Corner[]; core: P2[]; signal: boolean; scramble: boolean; }
export interface Span {
  road: Road; s0: number; s1: number;
  /** curb/sidewalk start & end stations per side (left = +normal) */
  l0: number; l1: number; r0: number; r1: number;
  n0: RNode | null; n1: RNode | null;
}

// ------------------------------------------------------------------------------------------ geometry helpers
export function polyAt(r: Road, s: number): { p: P2; t: P2; n: P2 } {
  s = Math.max(0, Math.min(r.length, s));
  let i = 1;
  while (i < r.cum.length - 1 && r.cum[i] < s) i++;
  const a = r.pts[i - 1], b = r.pts[i];
  const seg = r.cum[i] - r.cum[i - 1] || 1e-9;
  const k = (s - r.cum[i - 1]) / seg;
  const tx = (b[0] - a[0]) / seg, tz = (b[1] - a[1]) / seg;
  return { p: [a[0] + (b[0] - a[0]) * k, a[1] + (b[1] - a[1]) * k], t: [tx, tz], n: [-tz, tx] };
}
export function profileAt(r: Road, s: number): number {
  const f = Math.max(0, Math.min(r.profile.length - 1.0001, s / PSTEP));
  const i = Math.floor(f), k = f - i;
  return r.profile[i] * (1 - k) + r.profile[i + 1] * k;
}
/** Nearest station + signed lateral offset (+ = left normal) for a point. */
export function project(r: Road, x: number, z: number): { s: number; d: number; dist: number } {
  let best = { s: 0, d: 0, dist: Infinity };
  for (let i = 0; i < r.pts.length - 1; i++) {
    const { d, t } = segDist(x, z, r.pts[i], r.pts[i + 1]);
    if (d < best.dist) {
      const a = r.pts[i], b = r.pts[i + 1];
      const seg = r.cum[i + 1] - r.cum[i];
      const tx = (b[0] - a[0]) / seg, tz = (b[1] - a[1]) / seg;
      const side = (x - a[0]) * -tz + (z - a[1]) * tx;
      best = { s: r.cum[i] + t * seg, d: Math.sign(side) * d, dist: d };
    }
  }
  return best;
}

function segIntersect(a: P2, b: P2, c: P2, d: P2): { t: number; u: number; p: P2 } | null {
  const rx = b[0] - a[0], rz = b[1] - a[1], sx = d[0] - c[0], sz = d[1] - c[1];
  const den = rx * sz - rz * sx;
  if (Math.abs(den) < 1e-9) return null;
  const t = ((c[0] - a[0]) * sz - (c[1] - a[1]) * sx) / den;
  const u = ((c[0] - a[0]) * rz - (c[1] - a[1]) * rx) / den;
  if (t < -1e-6 || t > 1 + 1e-6 || u < -1e-6 || u > 1 + 1e-6) return null;
  return { t, u, p: [a[0] + rx * t, a[1] + rz * t] };
}
function lineIntersect(p: P2, d: P2, q: P2, e: P2): [number, number] | null {
  const den = d[0] * e[1] - d[1] * e[0];
  if (Math.abs(den) < 1e-9) return null;
  const t = ((q[0] - p[0]) * e[1] - (q[1] - p[1]) * e[0]) / den;
  const s = ((q[0] - p[0]) * d[1] - (q[1] - p[1]) * d[0]) / den;
  return [t, s];
}

const RADIUS: Record<RoadKind, number> = { hamilton: 4.5, main: 4.5, secondary: 3.5, campus: 3.5, lane: 2.5, alley: 1.2, highway: 8, rail: 1 };
const PRIORITY: RoadKind[] = ['hamilton', 'main', 'highway', 'secondary', 'campus', 'lane', 'alley', 'rail'];

// ------------------------------------------------------------------------------------------ network
export class RoadNetwork {
  roads: Road[] = [];
  nodes: RNode[] = [];
  private hash = new Map<number, { road: Road; i: number }[]>();
  private nodeHash = new Map<number, RNode[]>();
  static instance: RoadNetwork | null = null;
  static get(): RoadNetwork { return (this.instance ??= new RoadNetwork()); }

  constructor(defs: RoadDef[] = ROADS) {
    const all: RoadDef[] = [...defs, { id: 'bypass', name: 'Pamlico Bypass', kind: 'highway', pts: BYPASS }];
    for (const def of all) {
      const pts = def.pts;
      const cum = [0];
      for (let i = 1; i < pts.length; i++) cum.push(cum[i - 1] + Math.hypot(pts[i][0] - pts[i - 1][0], pts[i][1] - pts[i - 1][1]));
      const closed = pts.length > 2 && pts[0][0] === pts[pts.length - 1][0] && pts[0][1] === pts[pts.length - 1][1];
      const half = def.alleyWidthCm ? def.alleyWidthCm / 200 : roadHalf(def.kind);
      const row = def.alleyWidthCm ? def.alleyWidthCm / 200 : rowHalf(def.kind);
      this.roads.push({
        id: def.id, name: def.name, kind: def.kind, sec: SECTIONS[def.kind], def, pts, cum, length: cum[cum.length - 1], closed,
        half, row, priority: PRIORITY.indexOf(def.kind), profile: new Float32Array(0), bridges: [], nodes: [], spans: [],
      });
    }
    this.findNodes();
    this.buildProfiles();
    this.buildCorners();
    this.buildSpans();
    for (const r of this.roads) for (let i = 0; i < r.pts.length - 1; i++) this.hashSeg(r, i);
    for (const n of this.nodes) this.hashNode(n);
  }

  // -------------------------------------------------------------------- nodes
  private findNodes() {
    const raw: { p: P2; hits: { road: Road; s: number }[] }[] = [];
    const addHit = (p: P2, road: Road, s: number) => {
      let n = raw.find((r) => Math.hypot(r.p[0] - p[0], r.p[1] - p[1]) < 8);
      if (!n) { n = { p, hits: [] }; raw.push(n); }
      if (!n.hits.some((h) => h.road === road && Math.abs(h.s - s) < 10)) n.hits.push({ road, s });
    };
    const R = this.roads;
    for (let a = 0; a < R.length; a++) for (let b = a + 1; b < R.length; b++) {
      const ra = R[a], rb = R[b];
      for (let i = 0; i < ra.pts.length - 1; i++) for (let j = 0; j < rb.pts.length - 1; j++) {
        const hit = segIntersect(ra.pts[i], ra.pts[i + 1], rb.pts[j], rb.pts[j + 1]);
        if (hit) {
          addHit(hit.p, ra, ra.cum[i] + hit.t * (ra.cum[i + 1] - ra.cum[i]));
          addHit(hit.p, rb, rb.cum[j] + hit.u * (rb.cum[j + 1] - rb.cum[j]));
        }
      }
      // endpoint T-junctions within 1.5 m of the other road
      for (const [r1, r2] of [[ra, rb], [rb, ra]] as [Road, Road][]) {
        for (const [p, s] of [[r1.pts[0], 0], [r1.pts[r1.pts.length - 1], r1.length]] as [P2, number][]) {
          const pr = project(r2, p[0], p[1]);
          if (pr.dist < 1.5) { addHit(p, r1, s); addHit(p, r2, pr.s); }
        }
      }
    }
    // closed loops: join their own ends
    for (const r of R) if (r.closed) addHit(r.pts[0], r, 0);
    let id = 0;
    for (const n of raw) {
      if (n.hits.length < 2 && !n.hits.some((h) => h.road.closed)) continue;
      const node: RNode = { id: id++, x: n.p[0], z: n.p[1], y: 0, arms: [], corners: [], core: [], signal: false, scramble: false };
      for (const h of n.hits) {
        const r = h.road;
        const mk = (sign: 1 | -1, s: number): Arm => {
          const f = polyAt(r, Math.max(0, Math.min(r.length, s + sign * 2)));
          const p0 = polyAt(r, s).p;
          let dx = f.p[0] - p0[0], dz = f.p[1] - p0[1];
          const l = Math.hypot(dx, dz) || 1; dx /= l; dz /= l;
          return { road: r, s, dir: [dx, dz], sign, half: r.half, row: r.row, angle: Math.atan2(dz, dx), cutL: 0, cutR: 0, cut: 0 };
        };
        if (r.closed && (h.s < 1 || h.s > r.length - 1)) { node.arms.push(mk(1, 0), { ...mk(-1, r.length), s: r.length }); r.nodes.push({ node, s: 0 }, { node, s: r.length }); continue; }
        if (h.s > 1) node.arms.push(mk(-1, h.s));
        if (h.s < r.length - 1) node.arms.push(mk(1, h.s));
        r.nodes.push({ node, s: h.s });
      }
      node.arms.sort((a, b) => a.angle - b.angle);
      const majors = new Set(node.arms.filter((a) => a.road.kind === 'hamilton' || a.road.kind === 'main').map((a) => a.road.def.name));
      node.signal = majors.size >= 2 && node.arms.length >= 3;
      node.scramble = Math.hypot(node.x, node.z) < 2;
      this.nodes.push(node);
    }
    for (const r of R) r.nodes.sort((a, b) => a.s - b.s);
  }

  // -------------------------------------------------------------------- elevation
  private buildProfiles() {
    const order = [...this.roads].sort((a, b) => a.priority - b.priority);
    const assigned = new Set<RNode>();
    for (const r of order) {
      const n = Math.ceil(r.length / PSTEP) + 1;
      const nat = new Float32Array(n);
      for (let i = 0; i < n; i++) { const { p } = polyAt(r, i * PSTEP); nat[i] = naturalHeight(p[0], p[1]); }
      let prof = boxSmooth(boxSmooth(nat, 15), 15);
      // bridge deep dips for through roads: upper envelope over a 180 m window
      if (['hamilton', 'main', 'secondary', 'highway'].includes(r.kind)) {
        const env = boxSmooth(maxFilter(prof, 45), 10);
        const out = new Float32Array(n);
        let inBridge = -1;
        for (let i = 0; i < n; i++) {
          const dip = env[i] - prof[i];
          const w = Math.min(1, Math.max(0, (dip - 3) / 3));
          out[i] = prof[i] + (env[i] - prof[i]) * w;
          const isB = env[i] - nat[i] > 4.5;
          if (isB && inBridge < 0) inBridge = i;
          if (!isB && inBridge >= 0) { if (i - inBridge > 4) r.bridges.push([inBridge * PSTEP - 4, i * PSTEP + 4]); inBridge = -1; }
        }
        prof = out;
      }
      // Hamilton St holds 0.00 along the ridge (CLAUDE.md §8)
      if (r.id === 'hamilton') for (let i = 0; i < n; i++) { const { p } = polyAt(r, i * PSTEP); if (p[0] > -481 && p[0] < 620) prof[i] = 0; else if (p[0] >= 620) prof[i] = Math.min(prof[i], 0) * Math.min(1, (p[0] - 620) / 60) ; }
      // pins at already-assigned nodes
      const pins = r.nodes.filter((h) => assigned.has(h.node)).map((h) => ({ s: h.s, dy: h.node.y - sample(prof, h.s) }));
      if (pins.length) {
        pins.sort((a, b) => a.s - b.s);
        for (let i = 0; i < n; i++) {
          const s = i * PSTEP;
          let dy: number;
          if (s <= pins[0].s) dy = pins[0].dy * Math.max(0, 1 - (pins[0].s - s) / 80);
          else if (s >= pins[pins.length - 1].s) dy = pins[pins.length - 1].dy * Math.max(0, 1 - (s - pins[pins.length - 1].s) / 80);
          else { let k = 0; while (pins[k + 1].s < s) k++; const a = pins[k], b = pins[k + 1]; dy = a.dy + (b.dy - a.dy) * (s - a.s) / (b.s - a.s || 1); }
          prof[i] += dy;
        }
      }
      r.profile = prof;
      for (const h of r.nodes) if (!assigned.has(h.node)) { h.node.y = sample(prof, h.s); assigned.add(h.node); }
      // re-pin exactly (floating error)
    }
  }

  // -------------------------------------------------------------------- corners
  private buildCorners() {
    for (const n of this.nodes) {
      const A = n.arms;
      if (A.length < 2) continue;
      for (let i = 0; i < A.length; i++) {
        const a = A[i], b = A[(i + 1) % A.length];
        let theta = b.angle - a.angle;
        if (theta <= 0) theta += Math.PI * 2;
        const corner: Corner = { a, b, center: [n.x, n.z], arc: [], radius: 0, straight: false, ramps: [] };
        // a's left (+normal) faces b; b's right (-normal) faces a
        const na: P2 = [-a.dir[1], a.dir[0]], nb: P2 = [-b.dir[1], b.dir[0]];
        if (theta > (170 * Math.PI) / 180 || A.length === 2) {
          corner.straight = true;
          n.corners.push(corner);
          continue;
        }
        const swA = a.row - a.half, swB = b.row - b.half;
        const R = Math.max(RADIUS[a.road.kind], RADIUS[b.road.kind], Math.max(swA, swB) + 0.3) * (a.road.kind === 'alley' || b.road.kind === 'alley' ? 0.5 : 1);
        const P1: P2 = [n.x + na[0] * a.half, n.z + na[1] * a.half];
        const P2_: P2 = [n.x - nb[0] * b.half, n.z - nb[1] * b.half];
        const ts = lineIntersect(P1, a.dir, P2_, b.dir);
        if (!ts) { corner.straight = true; n.corners.push(corner); continue; }
        const phi = theta / 2;
        const tan = R / Math.tan(phi);
        const cutA = ts[0] + tan, cutB = ts[1] + tan;
        a.cutL = Math.max(a.cutL, cutA); b.cutR = Math.max(b.cutR, cutB);
        const TA: P2 = [P1[0] + a.dir[0] * cutA, P1[1] + a.dir[1] * cutA];
        const TB: P2 = [P2_[0] + b.dir[0] * cutB, P2_[1] + b.dir[1] * cutB];
        const C: P2 = [TA[0] + na[0] * R, TA[1] + na[1] * R];
        corner.center = C; corner.radius = R;
        const a0 = Math.atan2(TA[1] - C[1], TA[0] - C[0]);
        let a1 = Math.atan2(TB[1] - C[1], TB[0] - C[0]);
        // sweep the short way
        let da = a1 - a0; while (da > Math.PI) da -= Math.PI * 2; while (da < -Math.PI) da += Math.PI * 2;
        const segs = Math.max(4, Math.ceil(Math.abs(da) * R / 0.5));
        for (let k = 0; k <= segs; k++) { const ang = a0 + (da * k) / segs; corner.arc.push([C[0] + Math.cos(ang) * R, C[1] + Math.sin(ang) * R]); }
        void a1;
        // ADA curb ramps at the two tangent points, aimed across each arm
        if (a.road.kind !== 'alley' && b.road.kind !== 'alley' && a.road.kind !== 'highway' && a.road.kind !== 'lane') {
          for (const f of [0.22, 0.78]) {
            const p = corner.arc[Math.round(segs * f)];
            const dx = p[0] - C[0], dz = p[1] - C[1], l = Math.hypot(dx, dz) || 1;
            corner.ramps.push({ p, dir: [dx / l, dz / l] }); // points from sidewalk into the street
          }
        }
        n.corners.push(corner);
      }
      for (const a of A) a.cut = Math.max(a.cutL, a.cutR, a.half * 0.5);
      // straight sides: let curbs run to the node, but asphalt core must meet the arm cut
      // core polygon (star-shaped around the node)
      const core: P2[] = [];
      for (let i = 0; i < A.length; i++) {
        const a = A[i];
        const na: P2 = [-a.dir[1], a.dir[0]];
        const at = (t: number, side: number): P2 => [n.x + a.dir[0] * t + na[0] * a.half * side, n.z + a.dir[1] * t + na[1] * a.half * side];
        if (a.cutR < a.cut) core.push(at(a.cutR, -1));
        core.push(at(a.cut, -1), at(a.cut, 1));
        if (a.cutL < a.cut) core.push(at(a.cutL, 1));
        const c = n.corners[i];
        if (c && !c.straight) for (const p of c.arc.slice(1, -1)) core.push(p);
      }
      n.core = core;
    }
  }

  // -------------------------------------------------------------------- spans
  private buildSpans() {
    for (const r of this.roads) {
      const stops: { s: number; node: RNode | null }[] = [{ s: 0, node: null }, ...r.nodes.map((h) => ({ s: h.s, node: h.node })), { s: r.length, node: null }];
      stops.sort((a, b) => a.s - b.s);
      const uniq: typeof stops = [];
      for (const s of stops) { const last = uniq[uniq.length - 1]; if (last && Math.abs(last.s - s.s) < 1) { if (s.node) last.node = s.node; } else uniq.push({ ...s }); }
      for (let i = 0; i < uniq.length - 1; i++) {
        const A = uniq[i], B = uniq[i + 1];
        if (B.s - A.s < 0.5) continue;
        const armAt = (node: RNode | null, sign: 1 | -1, s: number) => node?.arms.find((a) => a.road === r && a.sign === sign && Math.abs(a.s - s) < 2);
        const a0 = armAt(A.node, 1, A.s), a1 = armAt(B.node, -1, B.s);
        // arm sign -1 points back along the road: its left = road right
        r.spans.push({
          road: r, s0: A.s + (a0?.cut ?? 0), s1: B.s - (a1?.cut ?? 0),
          l0: A.s + (a0?.cutL ?? 0), r0: A.s + (a0?.cutR ?? 0),
          l1: B.s - (a1?.cutR ?? 0), r1: B.s - (a1?.cutL ?? 0),
          n0: A.node, n1: B.node,
        });
      }
    }
  }

  // -------------------------------------------------------------------- spatial queries
  private hashSeg(r: Road, i: number) {
    const a = r.pts[i], b = r.pts[i + 1], pad = r.row + 12;
    for (let cx = Math.floor((Math.min(a[0], b[0]) - pad) / 20); cx <= Math.floor((Math.max(a[0], b[0]) + pad) / 20); cx++)
      for (let cz = Math.floor((Math.min(a[1], b[1]) - pad) / 20); cz <= Math.floor((Math.max(a[1], b[1]) + pad) / 20); cz++) {
        const k = cx * 100003 + cz;
        let arr = this.hash.get(k); if (!arr) { arr = []; this.hash.set(k, arr); }
        arr.push({ road: r, i });
      }
  }
  private hashNode(n: RNode) {
    const R = Math.max(...n.arms.map((a) => a.cut + a.row)) + 10;
    for (let cx = Math.floor((n.x - R) / 20); cx <= Math.floor((n.x + R) / 20); cx++)
      for (let cz = Math.floor((n.z - R) / 20); cz <= Math.floor((n.z + R) / 20); cz++) {
        const k = cx * 100003 + cz;
        let arr = this.nodeHash.get(k); if (!arr) { arr = []; this.nodeHash.set(k, arr); }
        arr.push(n);
      }
  }

  /**
   * Road influence at a point. Returns the paved surface height & zone, or null if outside every
   * right-of-way (+ blend band). `blend` in [0,1] = how much terrain should follow the road.
   */
  query(x: number, z: number): RoadHit | null {
    const k = Math.floor(x / 20) * 100003 + Math.floor(z / 20);
    let best: RoadHit | null = null;
    // intersection cores & corners first (flat at node elevation)
    for (const n of this.nodeHash.get(k) ?? []) {
      const d = Math.hypot(x - n.x, z - n.z);
      if (d > 60) continue;
      if (n.core.length > 2 && inPoly(x, z, n.core)) return { y: n.y, zone: 'asphalt', blend: 1, road: n.arms[0].road, s: 0, d: 0, node: n };
      for (const c of n.corners) {
        if (c.straight || !c.arc.length) continue;
        const dc = Math.hypot(x - c.center[0], z - c.center[1]);
        if (dc <= c.radius + 0.001 && inPoly(x, z, [c.center, ...c.arc])) {
          const fromCurb = c.radius - dc;
          const zone: RoadZone = fromCurb < CURB_TOP ? 'curb' : 'sidewalk';
          return { y: n.y - CROSS_SLOPE * Math.min(c.a.half, c.b.half) + CURB_H + (zone === 'sidewalk' ? CROSS_SLOPE * (fromCurb - CURB_TOP) : 0), zone, blend: 1, road: c.a.road, s: 0, d: 0, node: n };
        }
      }
    }
    for (const { road: r, i } of this.hash.get(k) ?? []) {
      const { d, t } = segDist(x, z, r.pts[i], r.pts[i + 1]);
      if (d > r.row + 12) continue;
      const s = r.cum[i] + t * (r.cum[i + 1] - r.cum[i]);
      if ((s <= 0.01 || s >= r.length - 0.01) && !r.closed && !r.nodes.length) {
        // dead end: allow a rounded cap
      }
      const span = r.spans.find((sp) => s >= sp.s0 - 0.01 && s <= sp.s1 + 0.01) ?? r.spans.find((sp) => s >= Math.min(sp.l0, sp.r0) && s <= Math.max(sp.l1, sp.r1));
      if (!span) continue;
      const y0 = profileAt(r, s);
      const a = r.pts[i], b = r.pts[i + 1];
      const seg = Math.hypot(b[0] - a[0], b[1] - a[1]) || 1;
      const side = ((x - a[0]) * -(b[1] - a[1]) + (z - a[1]) * (b[0] - a[0])) / seg >= 0 ? 1 : -1;
      const inSide = side > 0 ? s >= span.l0 && s <= span.l1 : s >= span.r0 && s <= span.r1;
      let hit: RoadHit;
      const bridge = r.bridges.some(([b0, b1]) => s >= b0 && s <= b1);
      if (d <= r.half) hit = { y: y0 - CROSS_SLOPE * d * (r.sec.curb ? 1 : 0.5), zone: 'asphalt', blend: 1, road: r, s, d: d * side, node: null, bridge };
      else if (!r.sec.curb || r.kind === 'alley' || r.row <= r.half) {
        if (d > r.row + 12) continue;
        const shoulder = r.kind === 'highway' ? 3 : 1.5;
        hit = { y: y0 - CROSS_SLOPE * r.half * 0.5, zone: d <= r.half + shoulder ? 'shoulder' : 'verge', blend: 1 - smooth01((d - r.half - shoulder) / 10), road: r, s, d: d * side, node: null, bridge };
      } else if (!inSide && d <= r.row) {
        continue; // inside a corner fillet's asphalt region handled by node core
      } else if (d <= r.half + CURB_TOP) hit = { y: y0 - CROSS_SLOPE * r.half + CURB_H, zone: 'curb', blend: 1, road: r, s, d: d * side, node: null, bridge };
      else if (d <= r.row) hit = { y: y0 - CROSS_SLOPE * r.half + CURB_H + CROSS_SLOPE * (d - r.half - CURB_TOP), zone: 'sidewalk', blend: 1, road: r, s, d: d * side, node: null, bridge };
      else {
        const edgeY = y0 - CROSS_SLOPE * r.half + CURB_H + CROSS_SLOPE * (r.row - r.half - CURB_TOP);
        hit = { y: edgeY, zone: 'verge', blend: 1 - smooth01((d - r.row) / 12), road: r, s, d: d * side, node: null, bridge };
      }
      if (!best || zoneRank(hit) > zoneRank(best) || (zoneRank(hit) === zoneRank(best) && Math.abs(hit.d) < Math.abs(best.d))) best = hit;
    }
    return best;
  }

  /** Spans/nodes chunked per tile for geometry building. */
  roadByName(name: string) { return this.roads.filter((r) => r.name === name); }
}

export type RoadZone = 'asphalt' | 'curb' | 'sidewalk' | 'shoulder' | 'verge';
export interface RoadHit { y: number; zone: RoadZone; blend: number; road: Road; s: number; d: number; node: RNode | null; bridge?: boolean; }
const zoneRank = (h: RoadHit) => (h.zone === 'asphalt' ? 5 : h.zone === 'curb' ? 4 : h.zone === 'sidewalk' ? 3 : h.zone === 'shoulder' ? 2 : 1) + (h.zone === 'verge' ? h.blend : 0);
const smooth01 = (t: number) => { const u = Math.max(0, Math.min(1, t)); return u * u * (3 - 2 * u); };

export function inPoly(x: number, z: number, poly: P2[]): boolean {
  let inside = false;
  for (let i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    const [xi, zi] = poly[i], [xj, zj] = poly[j];
    if ((zi > z) !== (zj > z) && x < ((xj - xi) * (z - zi)) / (zj - zi) + xi) inside = !inside;
  }
  return inside;
}
function sample(a: Float32Array, s: number): number { const f = Math.max(0, Math.min(a.length - 1.0001, s / PSTEP)); const i = Math.floor(f); return a[i] + (a[i + 1] - a[i]) * (f - i); }
function boxSmooth(a: Float32Array, r: number): Float32Array {
  const out = new Float32Array(a.length);
  for (let i = 0; i < a.length; i++) { let s = 0, n = 0; for (let k = -r; k <= r; k++) { const j = Math.max(0, Math.min(a.length - 1, i + k)); s += a[j]; n++; } out[i] = s / n; }
  return out;
}
function maxFilter(a: Float32Array, r: number): Float32Array {
  // "bridge" envelope: for each i, max over min(max-left, max-right) so only true dips are filled
  const out = new Float32Array(a.length);
  for (let i = 0; i < a.length; i++) {
    let ml = -Infinity, mr = -Infinity;
    for (let k = 0; k <= r; k++) { ml = Math.max(ml, a[Math.max(0, i - k)]); mr = Math.max(mr, a[Math.min(a.length - 1, i + k)]); }
    out[i] = Math.max(a[i], Math.min(ml, mr));
  }
  return out;
}
