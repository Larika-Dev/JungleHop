// Near-detail system (CLAUDE.md §5 / §17): everything within 15 m of the camera is real geometry —
// individual bricks (exact bond, 4–6 mm proud of the recessed mortar plane), individual 10 x 20 cm pavers
// (with root heave near tree pits) and truncated domes on curb ramps. Instances align exactly with the
// procedural textures used beyond 15 m, so the hand-off is seamless.
import { BoxGeometry, BufferGeometry, Color, CylinderGeometry, InstancedMesh, Matrix4, MeshStandardMaterial, Object3D, Quaternion, Vector3 } from 'three';
import { jitter, pc, type PaletteKey } from '../core/palette';
import { hash01 } from '../core/rng';
import { bondLayout, bondRepeat, paverLayout, paverRepeat, PAVER_U, type Bond } from '../core/textures';
import { RoadNetwork } from '../roads/network';

export const NEAR_RADIUS = 15;

export interface BrickSurface {
  /** building-local -> world */
  matrix: Matrix4;
  /** outward unit normal (local, horizontal) and plane offset: n·p = c */
  nx: number; nz: number; c: number;
  u0: number; u1: number; v0: number; v1: number;
  bond: Bond; key: PaletteKey; header?: PaletteKey; proud: number;
  holes: [number, number, number, number][]; // [u0, v0, u1, v1]
  owner: string;
  /** world-space bounding sphere for culling */
  cx: number; cy: number; cz: number; r: number;
}
export interface DomeRec { x: number; z: number; dx: number; dz: number; yBack: number; yFront: number; w: number; d: number; }

const BRICK_SURFACES = new Map<string, BrickSurface[]>();
const DOMES = new Map<string, DomeRec>();
export function registerBrickSurface(s: BrickSurface) { let a = BRICK_SURFACES.get(s.owner); if (!a) BRICK_SURFACES.set(s.owner, (a = [])); a.push(s); }
export function unregisterOwner(owner: string) { BRICK_SURFACES.delete(owner); }
export function registerDomes(d: DomeRec) { DOMES.set(`${d.x.toFixed(2)},${d.z.toFixed(2)}`, d); }
/**
 * Register every vertical brick quad of a builder (in its ROOT space) as a near-detail surface.
 * UVs are the builder's planar meters, so instances line up with the texture exactly.
 */
export function registerBricksFromBuilder(g: { buckets: Map<string, { pos: number[]; nor: number[]; uv: number[]; idx: number[]; vcount: number }> }, matrix: Matrix4, owner: string) {
  for (const [key, b] of g.buckets) {
    if (!key.startsWith('brick:')) continue;
    const [, bond, pk, flag] = key.split(':');
    const campus = pk.startsWith('BRICK_CAMPUS');
    for (let t = 0; t + 5 < b.idx.length; t += 6) {
      const i0 = b.idx[t];
      if (b.idx[t + 1] !== i0 + 1 || b.idx[t + 2] !== i0 + 2 || b.idx[t + 5] !== i0 + 3) continue;
      const nx = b.nor[i0 * 3], ny = b.nor[i0 * 3 + 1], nz = b.nor[i0 * 3 + 2];
      if (Math.abs(ny) > 0.3) continue;
      let u0 = Infinity, u1 = -Infinity, v0 = Infinity, v1 = -Infinity;
      for (let k = 0; k < 4; k++) { const u = b.uv[(i0 + k) * 2], v = b.uv[(i0 + k) * 2 + 1]; u0 = Math.min(u0, u); u1 = Math.max(u1, u); v0 = Math.min(v0, v); v1 = Math.max(v1, v); }
      if (u1 - u0 < 0.2 || v1 - v0 < 0.06) continue;
      const px = b.pos[i0 * 3], py = b.pos[i0 * 3 + 1], pz = b.pos[i0 * 3 + 2];
      const l = Math.hypot(nx, nz);
      const c = (px * nx + pz * nz) / l;
      const tx = nz / l, tz = -nx / l;
      const cu = (u0 + u1) / 2, cv = (v0 + v1) / 2;
      const center = new Vector3(tx * cu + (nx / l) * c, cv, tz * cu + (nz / l) * c).applyMatrix4(matrix);
      void py;
      registerBrickSurface({
        matrix: matrix.clone(), nx: nx / l, nz: nz / l, c, u0, u1, v0, v1, bond: bond as Bond,
        key: flag === 'painted' ? 'BRICK_PAINTED_WHITE' : (pk as PaletteKey), header: bond === 'common' ? (campus ? 'BRICK_CAMPUS_C' : 'BRICK_DOWNTOWN_C') : undefined,
        proud: campus ? 0.004 : 0.006, holes: [], owner, cx: center.x, cy: center.y, cz: center.z, r: Math.hypot(u1 - u0, v1 - v0) / 2,
      });
    }
  }
}

export type PaverResolver = (x: number, z: number) => { y: number; pattern: 'herringbone' | 'running' } | null;

const _m = new Matrix4(), _q = new Quaternion(), _s = new Vector3(), _p = new Vector3(), _c = new Color(), _inv = new Matrix4(), _v = new Vector3();
const layoutCache = new Map<string, [number, number, number, number, boolean][]>();
function tileBricks(bond: Bond) {
  let l = layoutCache.get(bond);
  if (!l) {
    const [W, H] = bondRepeat(bond);
    l = bondLayout(bond, W, H).filter(([x, y]) => x >= -1e-9 && x < W - 1e-9 && y >= -1e-9 && y < H - 1e-9);
    layoutCache.set(bond, l);
  }
  return l;
}

export class NearDetail {
  root = new Object3D();
  bricks: InstancedMesh;
  glazed: InstancedMesh;
  pavers: InstancedMesh;
  domes: InstancedMesh;
  private last = new Vector3(1e9, 1e9, 1e9);
  private paverMemo = new Map<number, ReturnType<PaverResolver>>();
  enabled = true;
  stats = { bricks: 0, pavers: 0, domes: 0 };
  constructor(public paverAt: PaverResolver | null = null, cap = { bricks: 70000, pavers: 30000, domes: 12000 }) {
    this.root.name = 'near-detail';
    const brickGeo = new BoxGeometry(1, 1, 1);
    const mk = (geo: BufferGeometry, n: number, rough: number, key: PaletteKey, name: string) => {
      const m = new InstancedMesh(geo, new MeshStandardMaterial({ roughness: rough }), n);
      (m.material as MeshStandardMaterial).color.copy(pc('ONSU_WHITE'));
      m.name = name; m.userData.matKey = `near:${key}`; m.count = 0; m.frustumCulled = false; m.castShadow = true; m.receiveShadow = true;
      m.setColorAt(0, pc(key));
      this.root.add(m);
      return m;
    };
    this.bricks = mk(brickGeo, cap.bricks, 0.85, 'BRICK_CAMPUS_A', 'near-bricks');
    this.glazed = mk(brickGeo, cap.bricks / 3, 0.45, 'BRICK_HEADER_GLAZED', 'near-glazed');
    this.pavers = mk(brickGeo, cap.pavers, 0.85, 'BRICK_PAVER_A', 'near-pavers');
    const dome = new CylinderGeometry(0.006, 0.0115, 0.005, 8, 1, false);
    dome.translate(0, 0.0025, 0);
    this.domes = mk(dome, cap.domes, 0.6, 'TRUNCATED_DOME', 'near-domes');
  }

  update(cam: Vector3, force = false) {
    if (!this.enabled) { this.root.visible = false; return; }
    this.root.visible = true;
    if (!force && cam.distanceToSquared(this.last) < 1.0) return;
    this.last.copy(cam);
    this.buildBricks(cam);
    this.buildPavers(cam);
    this.buildDomes(cam);
  }

  private buildBricks(cam: Vector3) {
    const R = NEAR_RADIUS;
    let nb = 0, ng = 0;
    const capB = this.bricks.instanceMatrix.count, capG = this.glazed.instanceMatrix.count;
    for (const list of BRICK_SURFACES.values()) for (const s of list) {
      const dx = s.cx - cam.x, dy = s.cy - cam.y, dz = s.cz - cam.z;
      if (dx * dx + dy * dy + dz * dz > (R + s.r) ** 2) continue;
      _inv.copy(s.matrix).invert();
      _v.copy(cam).applyMatrix4(_inv);
      const dist = _v.x * s.nx + _v.z * s.nz - s.c;
      if (Math.abs(dist) > R) continue;
      const rr = Math.sqrt(R * R - dist * dist);
      const tx = s.nz, tz = -s.nx; // planar-UV tangent (geo.ts)
      const uc = _v.x * tx + _v.z * tz, vc = _v.y;
      const ua = Math.max(s.u0, uc - rr), ub = Math.min(s.u1, uc + rr), va = Math.max(s.v0, vc - rr), vb = Math.min(s.v1, vc + rr);
      if (ua >= ub || va >= vb) continue;
      const [W, H] = bondRepeat(s.bond);
      const lay = tileBricks(s.bond);
      // rotation: box X -> tangent, Y -> up, Z -> normal
      _m.makeBasis(new Vector3(tx, 0, tz), new Vector3(0, 1, 0), new Vector3(s.nx, 0, s.nz));
      _q.setFromRotationMatrix(_m);
      const wq = new Quaternion().setFromRotationMatrix(new Matrix4().extractRotation(s.matrix)).multiply(_q);
      for (let k = Math.floor(ua / W); k <= Math.floor(ub / W); k++) for (let m = Math.floor(va / H); m <= Math.floor(vb / H); m++) {
        for (let i = 0; i < lay.length; i++) {
          const [x, y, w, h, header] = lay[i];
          const u = x + k * W, v = y + m * H;
          if (u < s.u0 - 1e-4 || u + w > s.u1 + 1e-4 || v < s.v0 - 1e-4 || v + h > s.v1 + 1e-4) continue;
          const cu = u + w / 2, cv = v + h / 2;
          if ((cu - uc) ** 2 + (cv - vc) ** 2 > rr * rr) continue;
          let hole = false;
          for (const o of s.holes) if (cu > o[0] && cu < o[2] && cv > o[1] && cv < o[3]) { hole = true; break; }
          if (hole) continue;
          const isGlazed = header && s.bond === 'flemish';
          if (isGlazed ? ng >= capG : nb >= capB) continue;
          const depth = 0.02;
          const nOff = s.c + s.proud - depth / 2;
          _p.set(tx * cu + s.nx * nOff, cv, tz * cu + s.nz * nOff).applyMatrix4(s.matrix);
          _s.set(w, h, depth);
          _m.compose(_p, wq, _s);
          const h1 = hash01(k * 131 + i, m * 71, s.u0 * 100 | 0), h2 = hash01(i, k + 7, m + 3);
          const key: PaletteKey = header ? (s.header ?? (s.bond === 'flemish' ? 'BRICK_HEADER_GLAZED' : s.key)) : s.key;
          jitter(key, h1, h2, 0.06, 3, _c);
          if (isGlazed) { this.glazed.setMatrixAt(ng, _m); this.glazed.setColorAt(ng, _c); ng++; }
          else { this.bricks.setMatrixAt(nb, _m); this.bricks.setColorAt(nb, _c); nb++; }
        }
      }
    }
    this.finish(this.bricks, nb); this.finish(this.glazed, ng);
    this.stats.bricks = nb + ng;
  }

  private buildPavers(cam: Vector3) {
    if (!this.paverAt) { this.finish(this.pavers, 0); return; }
    const R = NEAR_RADIUS, cap = this.pavers.instanceMatrix.count;
    let n = 0;
    const net = RoadNetwork.get();
    void net;
    for (const pattern of ['running', 'herringbone'] as const) {
      const [W, H] = paverRepeat(pattern);
      const lay = paverLayout(pattern).filter(([x, y]) => x >= 0 && x < W && y >= 0 && y < H);
      for (let k = Math.floor((cam.x - R) / W); k <= Math.floor((cam.x + R) / W); k++) for (let m = Math.floor((cam.z - R) / H); m <= Math.floor((cam.z + R) / H); m++) {
        for (let i = 0; i < lay.length && n < cap; i++) {
          const [x, y, w, h] = lay[i];
          const cx = x + k * W + w / 2, cz = y + m * H + h / 2;
          const d2 = (cx - cam.x) ** 2 + (cz - cam.z) ** 2;
          if (d2 > R * R) continue;
          const key = Math.round(cx * 20) * 100003 + Math.round(cz * 20);
          let r = this.paverMemo.get(key);
          if (r === undefined) { r = this.paverAt(cx, cz); this.paverMemo.set(key, r); if (this.paverMemo.size > 400000) this.paverMemo.clear(); }
          if (!r || r.pattern !== pattern) continue;
          if (Math.abs(r.y - cam.y) > R) continue;
          _p.set(cx, r.y + 0.004 - 0.03, cz);
          _s.set(w, 0.06, h);
          _m.compose(_p, _q.identity(), _s);
          jitter(hash01(i, k, m) < 0.5 ? 'BRICK_PAVER_A' : 'BRICK_PAVER_B', hash01(k, m, i), hash01(m, i, k), 0.06, 3, _c);
          this.pavers.setMatrixAt(n, _m); this.pavers.setColorAt(n, _c); n++;
        }
      }
    }
    this.finish(this.pavers, n);
    this.stats.pavers = n;
    void PAVER_U;
  }

  private buildDomes(cam: Vector3) {
    const R = NEAR_RADIUS, cap = this.domes.instanceMatrix.count;
    let n = 0;
    const sp = 0.055;
    for (const d of DOMES.values()) {
      if ((d.x - cam.x) ** 2 + (d.z - cam.z) ** 2 > R * R) continue;
      const nx = -d.dz, nz = d.dx;
      const nu = Math.floor(d.w / sp), nv = Math.floor(d.d / sp);
      for (let i = 0; i < nu; i++) for (let j = 0; j < nv && n < cap; j++) {
        const u = -((nu - 1) * sp) / 2 + i * sp, v = -((nv - 1) * sp) / 2 + j * sp;
        const t = (v + d.d / 2) / d.d;
        _p.set(d.x + nx * u + d.dx * v, d.yBack + (d.yFront - d.yBack) * t + 0.002, d.z + nz * u + d.dz * v);
        _m.compose(_p, _q.identity(), _s.set(1, 1, 1));
        this.domes.setMatrixAt(n, _m); this.domes.setColorAt(n, pc('TRUNCATED_DOME')); n++;
      }
    }
    this.finish(this.domes, n);
    this.stats.domes = n;
  }

  private finish(m: InstancedMesh, n: number) {
    m.count = n;
    m.instanceMatrix.needsUpdate = true;
    if (m.instanceColor) m.instanceColor.needsUpdate = true;
  }
}
