// GeoBuilder: accumulates triangles per material key, then emits ONE mesh per material (CLAUDE.md §3:
// merged BufferGeometry per building shell / per tile). All kit pieces write into a GeoBuilder.
//
// UV convention: planar meters computed in the builder's ROOT space (after the builder's own transform
// stack), so brick/paver textures align across adjoining pieces of one building:
//   vertical faces: u = distance along the face's horizontal tangent, v = height (y)
//   horizontal faces: u = x, v = z
import { BufferAttribute, BufferGeometry, Box3, Color, Group, Material, Matrix3, Matrix4, Mesh, Vector3 } from 'three';

export type MatKey = string;

interface Bucket {
  pos: number[]; nor: number[]; uv: number[]; col: number[]; idx: number[];
  extra: Map<string, { size: number; data: number[] }>;
  vcount: number;
}

const _v = new Vector3();
const _n = new Vector3();
const _a = new Vector3(), _b = new Vector3(), _c = new Vector3(), _d = new Vector3();
const WHITE = new Color(1, 1, 1);

export type V3 = [number, number, number];

export class GeoBuilder {
  readonly buckets = new Map<MatKey, Bucket>();
  private stack: Matrix4[] = [];
  private m = new Matrix4();
  private nm = new Matrix3();
  private identity = true;
  color: Color = WHITE.clone();
  /** Current values for extra vertex attributes (e.g. interior-mapping data on far glass). */
  attrs: Record<string, number[]> = {};
  /** Optional UV offset applied to planar UVs (meters). */
  uvOffset: [number, number] = [0, 0];

  // ---------------------------------------------------------------- transform stack
  push(mat?: Matrix4): this {
    this.stack.push(this.m.clone());
    if (mat) this.m.multiply(mat);
    this.sync();
    return this;
  }
  pop(): this {
    const m = this.stack.pop();
    if (!m) throw new Error('GeoBuilder.pop underflow');
    this.m.copy(m);
    this.sync();
    return this;
  }
  translate(x: number, y: number, z: number): this { this.m.multiply(new Matrix4().makeTranslation(x, y, z)); this.sync(); return this; }
  rotateY(a: number): this { this.m.multiply(new Matrix4().makeRotationY(a)); this.sync(); return this; }
  rotateX(a: number): this { this.m.multiply(new Matrix4().makeRotationX(a)); this.sync(); return this; }
  rotateZ(a: number): this { this.m.multiply(new Matrix4().makeRotationZ(a)); this.sync(); return this; }
  scale(x: number, y: number, z: number): this { this.m.multiply(new Matrix4().makeScale(x, y, z)); this.sync(); return this; }
  apply(mat: Matrix4): this { this.m.multiply(mat); this.sync(); return this; }
  get matrix(): Matrix4 { return this.m; }
  private sync() {
    this.nm.getNormalMatrix(this.m);
    const e = this.m.elements;
    this.identity = e[0] === 1 && e[5] === 1 && e[10] === 1 && e[12] === 0 && e[13] === 0 && e[14] === 0 && e[1] === 0 && e[2] === 0 && e[4] === 0 && e[6] === 0 && e[8] === 0 && e[9] === 0;
  }
  setColor(c: Color | null): this { this.color = c ? c.clone() : WHITE.clone(); return this; }

  // ---------------------------------------------------------------- low level
  private bucket(key: MatKey): Bucket {
    let b = this.buckets.get(key);
    if (!b) { b = { pos: [], nor: [], uv: [], col: [], idx: [], extra: new Map(), vcount: 0 }; this.buckets.set(key, b); }
    return b;
  }
  private pushExtra(b: Bucket) {
    for (const name in this.attrs) {
      const vals = this.attrs[name];
      let e = b.extra.get(name);
      if (!e) {
        e = { size: vals.length, data: new Array((b.vcount) * vals.length).fill(0) };
        b.extra.set(name, e);
      }
      for (let i = 0; i < e.size; i++) e.data.push(vals[i] ?? 0);
    }
    for (const [name, e] of b.extra) if (!(name in this.attrs)) for (let i = 0; i < e.size; i++) e.data.push(0);
  }
  /** Push a vertex already in ROOT space. Returns its index. */
  private vtx(b: Bucket, p: Vector3, n: Vector3, u: number, v: number): number {
    b.pos.push(p.x, p.y, p.z);
    b.nor.push(n.x, n.y, n.z);
    b.uv.push(u, v);
    b.col.push(this.color.r, this.color.g, this.color.b);
    this.pushExtra(b);
    return b.vcount++;
  }
  private planarUV(p: Vector3, n: Vector3): [number, number] {
    if (Math.abs(n.y) > 0.7) return [p.x + this.uvOffset[0], p.z + this.uvOffset[1]];
    // horizontal tangent = up x n
    const tx = n.z, tz = -n.x;
    const l = Math.hypot(tx, tz) || 1;
    return [(p.x * tx + p.z * tz) / l + this.uvOffset[0], p.y + this.uvOffset[1]];
  }
  private xf(p: Vector3): Vector3 { return this.identity ? p : p.applyMatrix4(this.m); }
  private xn(n: Vector3): Vector3 { return this.identity ? n : n.applyMatrix3(this.nm).normalize(); }

  /** Planar quad (a,b,c,d counter-clockwise when viewed from the front). Local coordinates. */
  quad(key: MatKey, a: V3, b: V3, c: V3, d: V3, uvs?: [number, number][]): this {
    const B = this.bucket(key);
    this.xf(_a.set(...a)); this.xf(_b.set(...b)); this.xf(_c.set(...c)); this.xf(_d.set(...d));
    _n.subVectors(_b, _a).cross(_v.subVectors(_c, _a)).normalize();
    if (_n.lengthSq() < 0.5) _n.subVectors(_c, _a).cross(_v.subVectors(_d, _a)).normalize();
    const pts = [_a, _b, _c, _d];
    const i0 = B.vcount;
    for (let i = 0; i < 4; i++) {
      const [u, v] = uvs ? uvs[i] : this.planarUV(pts[i], _n);
      this.vtx(B, pts[i], _n, u, v);
    }
    B.idx.push(i0, i0 + 1, i0 + 2, i0, i0 + 2, i0 + 3);
    return this;
  }
  tri(key: MatKey, a: V3, b: V3, c: V3): this {
    const B = this.bucket(key);
    this.xf(_a.set(...a)); this.xf(_b.set(...b)); this.xf(_c.set(...c));
    _n.subVectors(_b, _a).cross(_v.subVectors(_c, _a)).normalize();
    const i0 = B.vcount;
    for (const p of [_a, _b, _c]) { const [u, v] = this.planarUV(p, _n); this.vtx(B, p, _n, u, v); }
    B.idx.push(i0, i0 + 1, i0 + 2);
    return this;
  }

  /**
   * Axis-aligned (in local space) box. `faces` bitmask: 1=+x 2=-x 4=+y 8=-y 16=+z 32=-z (default all).
   */
  box(key: MatKey, x0: number, y0: number, z0: number, x1: number, y1: number, z1: number, faces = 63): this {
    if (x1 < x0) [x0, x1] = [x1, x0];
    if (y1 < y0) [y0, y1] = [y1, y0];
    if (z1 < z0) [z0, z1] = [z1, z0];
    if (faces & 1) this.quad(key, [x1, y0, z1], [x1, y0, z0], [x1, y1, z0], [x1, y1, z1]);
    if (faces & 2) this.quad(key, [x0, y0, z0], [x0, y0, z1], [x0, y1, z1], [x0, y1, z0]);
    if (faces & 4) this.quad(key, [x0, y1, z1], [x1, y1, z1], [x1, y1, z0], [x0, y1, z0]);
    if (faces & 8) this.quad(key, [x0, y0, z0], [x1, y0, z0], [x1, y0, z1], [x0, y0, z1]);
    if (faces & 16) this.quad(key, [x0, y0, z1], [x1, y0, z1], [x1, y1, z1], [x0, y1, z1]);
    if (faces & 32) this.quad(key, [x1, y0, z0], [x0, y0, z0], [x0, y1, z0], [x1, y1, z0]);
    return this;
  }
  /** Box from bottom-front-left corner + size (meters). */
  boxS(key: MatKey, x: number, y: number, z: number, w: number, h: number, d: number, faces = 63): this {
    return this.box(key, x, y, z, x + w, y + h, z + d, faces);
  }

  /** Merge an arbitrary BufferGeometry (positions/normals/uv used if present). */
  geometry(key: MatKey, g: BufferGeometry, mat?: Matrix4, keepUV = false): this {
    if (mat) this.push(mat);
    const B = this.bucket(key);
    const pos = g.getAttribute('position');
    if (!g.getAttribute('normal')) g.computeVertexNormals();
    const nor = g.getAttribute('normal');
    const uv = g.getAttribute('uv');
    const i0 = B.vcount;
    for (let i = 0; i < pos.count; i++) {
      this.xf(_a.set(pos.getX(i), pos.getY(i), pos.getZ(i)));
      this.xn(_n.set(nor.getX(i), nor.getY(i), nor.getZ(i)));
      let u: number, v: number;
      if (keepUV && uv) { u = uv.getX(i); v = uv.getY(i); } else [u, v] = this.planarUV(_a, _n);
      this.vtx(B, _a, _n, u, v);
    }
    const index = g.getIndex();
    if (index) for (let i = 0; i < index.count; i++) B.idx.push(i0 + index.getX(i));
    else for (let i = 0; i < pos.count; i++) B.idx.push(i0 + i);
    if (mat) this.pop();
    return this;
  }

  /**
   * Lathe a profile [[r, y], ...] around local +Y. seg segments over [phi0, phi0+phiLen].
   * Smooth normals (radial). Used for columns, domes, well curbs, finials.
   */
  lathe(key: MatKey, profile: [number, number][], seg = 24, phi0 = 0, phiLen = Math.PI * 2, smooth = true): this {
    const B = this.bucket(key);
    const rows = profile.length;
    const full = Math.abs(phiLen - Math.PI * 2) < 1e-6;
    const cols = seg + 1;
    const base = B.vcount;
    // profile normals (2D) per vertex
    const pn: [number, number][] = profile.map((_, i) => {
      const p = profile[Math.max(0, i - 1)], q = profile[Math.min(rows - 1, i + 1)];
      const dr = q[0] - p[0], dy = q[1] - p[1];
      const l = Math.hypot(dr, dy) || 1;
      return [dy / l, -dr / l];
    });
    for (let j = 0; j < cols; j++) {
      const phi = phi0 + (phiLen * j) / seg;
      const s = Math.sin(phi), c = Math.cos(phi);
      for (let i = 0; i < rows; i++) {
        const [r, y] = profile[i];
        this.xf(_a.set(r * s, y, r * c));
        const [nr, ny] = pn[i];
        this.xn(_n.set(nr * s, ny, nr * c));
        const arc = r * (phiLen * j) / seg;
        this.vtx(B, _a, _n, smooth ? arc : arc, y);
      }
    }
    for (let j = 0; j < seg; j++) for (let i = 0; i < rows - 1; i++) {
      const a = base + j * rows + i, b = base + (j + 1) * rows + i;
      B.idx.push(a, b, b + 1, a, b + 1, a + 1);
    }
    void full;
    return this;
  }

  /** Vertical cylinder (optionally capped). */
  cylinder(key: MatKey, r: number, y0: number, y1: number, seg = 16, caps = true, x = 0, z = 0): this {
    this.push(new Matrix4().makeTranslation(x, 0, z));
    this.lathe(key, [[r, y0], [r, y1]], seg);
    if (caps) { this.disc(key, r, y1, seg, true); this.disc(key, r, y0, seg, false); }
    this.pop();
    return this;
  }
  /** Horizontal disc (fan) at height y; up=true faces +Y. */
  disc(key: MatKey, r: number, y: number, seg = 16, up = true, r0 = 0): this {
    for (let j = 0; j < seg; j++) {
      const a0 = (j / seg) * Math.PI * 2, a1 = ((j + 1) / seg) * Math.PI * 2;
      const p0: V3 = [Math.sin(a0) * r, y, Math.cos(a0) * r], p1: V3 = [Math.sin(a1) * r, y, Math.cos(a1) * r];
      const q0: V3 = [Math.sin(a0) * r0, y, Math.cos(a0) * r0], q1: V3 = [Math.sin(a1) * r0, y, Math.cos(a1) * r0];
      if (up) this.quad(key, q0, p0, p1, q1); else this.quad(key, q1, p1, p0, q0);
    }
    return this;
  }

  /**
   * Sweep a 2D profile along a horizontal polyline (local XZ) at base height y.
   * Profile points [out, up] in meters: `out` is measured to the LEFT of travel direction
   * (for a CCW footprint traversed counter-clockwise seen from above, left = outward when
   * the polygon is wound clockwise in XZ — use `outSign` to flip). Mitered joints.
   */
  sweep(key: MatKey, profile: [number, number][], path: [number, number][], y: number, closed: boolean, outSign = 1): this {
    const n = path.length;
    if (n < 2) return this;
    const B = this.bucket(key);
    // per path vertex: position and miter offset vector (unit outward scaled by miter factor)
    const off: [number, number][] = [];
    for (let i = 0; i < n; i++) {
      const prev = closed ? path[(i - 1 + n) % n] : path[Math.max(0, i - 1)];
      const next = closed ? path[(i + 1) % n] : path[Math.min(n - 1, i + 1)];
      const cur = path[i];
      const d0 = norm2(cur[0] - prev[0], cur[1] - prev[1]);
      const d1 = norm2(next[0] - cur[0], next[1] - cur[1]);
      const da = i === 0 && !closed ? d1 : d0, db = i === n - 1 && !closed ? d0 : d1;
      // outward normal of direction (dx,dz) -> (dz, -dx) * outSign
      const n0: [number, number] = [da[1] * outSign, -da[0] * outSign];
      const n1: [number, number] = [db[1] * outSign, -db[0] * outSign];
      let mx = n0[0] + n1[0], mz = n0[1] + n1[1];
      const ml = Math.hypot(mx, mz) || 1;
      mx /= ml; mz /= ml;
      const k = 1 / Math.max(0.2, mx * n0[0] + mz * n0[1]);
      off.push([mx * k, mz * k]);
    }
    const segs = closed ? n : n - 1;
    for (let s = 0; s < segs; s++) {
      const i = s, j = (s + 1) % n;
      for (let p = 0; p < profile.length - 1; p++) {
        const [o0, u0] = profile[p], [o1, u1] = profile[p + 1];
        const A: V3 = [path[i][0] + off[i][0] * o0, y + u0, path[i][1] + off[i][1] * o0];
        const Bv: V3 = [path[j][0] + off[j][0] * o0, y + u0, path[j][1] + off[j][1] * o0];
        const C: V3 = [path[j][0] + off[j][0] * o1, y + u1, path[j][1] + off[j][1] * o1];
        const D: V3 = [path[i][0] + off[i][0] * o1, y + u1, path[i][1] + off[i][1] * o1];
        if (outSign > 0) this.quad(key, A, D, C, Bv); else this.quad(key, A, Bv, C, D);
      }
    }
    void B;
    return this;
  }

  /** Extruded vertical prism from a 2D polygon (XZ, any winding), y0..y1, with caps. */
  prism(key: MatKey, poly: [number, number][], y0: number, y1: number, capTop = true, capBottom = true): this {
    const n = poly.length;
    const area = signedArea(poly);
    const ccw = area > 0; // in x-right, z-down coordinates
    for (let i = 0; i < n; i++) {
      const a = poly[i], b = poly[(i + 1) % n];
      if (ccw) this.quad(key, [b[0], y0, b[1]], [a[0], y0, a[1]], [a[0], y1, a[1]], [b[0], y1, b[1]]);
      else this.quad(key, [a[0], y0, a[1]], [b[0], y0, b[1]], [b[0], y1, b[1]], [a[0], y1, a[1]]);
    }
    const tris = triangulate(poly);
    for (const [i, j, k] of tris) {
      const A = poly[i], Bp = poly[j], C = poly[k];
      const up = signedArea([A, Bp, C]) > 0;
      if (capTop) up ? this.tri(key, [A[0], y1, A[1]], [C[0], y1, C[1]], [Bp[0], y1, Bp[1]]) : this.tri(key, [A[0], y1, A[1]], [Bp[0], y1, Bp[1]], [C[0], y1, C[1]]);
      if (capBottom) up ? this.tri(key, [A[0], y0, A[1]], [Bp[0], y0, Bp[1]], [C[0], y0, C[1]]) : this.tri(key, [A[0], y0, A[1]], [C[0], y0, C[1]], [Bp[0], y0, Bp[1]]);
    }
    return this;
  }

  /** Merge another builder's buckets into this one (optionally transformed by `mat` then this stack). */
  merge(other: GeoBuilder, mat?: Matrix4): this {
    if (mat) this.push(mat);
    for (const [key, ob] of other.buckets) {
      const B = this.bucket(key);
      const i0 = B.vcount;
      for (let i = 0; i < ob.vcount; i++) {
        this.xf(_a.set(ob.pos[i * 3], ob.pos[i * 3 + 1], ob.pos[i * 3 + 2]));
        this.xn(_n.set(ob.nor[i * 3], ob.nor[i * 3 + 1], ob.nor[i * 3 + 2]));
        B.pos.push(_a.x, _a.y, _a.z); B.nor.push(_n.x, _n.y, _n.z);
        B.uv.push(ob.uv[i * 2], ob.uv[i * 2 + 1]);
        B.col.push(ob.col[i * 3], ob.col[i * 3 + 1], ob.col[i * 3 + 2]);
      }
      // extras
      const names = new Set([...B.extra.keys(), ...ob.extra.keys()]);
      for (const name of names) {
        const oe = ob.extra.get(name);
        let e = B.extra.get(name);
        const size = oe?.size ?? e!.size;
        if (!e) { e = { size, data: new Array(i0 * size).fill(0) }; B.extra.set(name, e); }
        if (oe) for (const v of oe.data) e.data.push(v); else for (let i = 0; i < ob.vcount * size; i++) e.data.push(0);
      }
      for (const ix of ob.idx) B.idx.push(i0 + ix);
      B.vcount += ob.vcount;
    }
    if (mat) this.pop();
    return this;
  }

  get vertexCount(): number { let n = 0; for (const b of this.buckets.values()) n += b.vcount; return n; }
  get triangleCount(): number { let n = 0; for (const b of this.buckets.values()) n += b.idx.length / 3; return n; }
  isEmpty(): boolean { return this.vertexCount === 0; }

  /** Bounds in ROOT space, optionally restricted to some material keys. */
  bounds(filter?: (k: MatKey) => boolean): Box3 {
    const box = new Box3();
    for (const [k, b] of this.buckets) {
      if (filter && !filter(k)) continue;
      for (let i = 0; i < b.pos.length; i += 3) box.expandByPoint(_v.set(b.pos[i], b.pos[i + 1], b.pos[i + 2]));
    }
    return box;
  }

  /** Build a BufferGeometry for one material bucket. */
  geometryFor(key: MatKey): BufferGeometry | null {
    const b = this.buckets.get(key);
    if (!b || b.vcount === 0) return null;
    const g = new BufferGeometry();
    g.setAttribute('position', new BufferAttribute(new Float32Array(b.pos), 3));
    g.setAttribute('normal', new BufferAttribute(new Float32Array(b.nor), 3));
    g.setAttribute('uv', new BufferAttribute(new Float32Array(b.uv), 2));
    g.setAttribute('color', new BufferAttribute(new Float32Array(b.col), 3));
    for (const [name, e] of b.extra) g.setAttribute(name, new BufferAttribute(new Float32Array(e.data), e.size));
    g.setIndex(new BufferAttribute(b.vcount > 65535 ? new Uint32Array(b.idx) : new Uint16Array(b.idx), 1));
    g.computeBoundingSphere();
    g.computeBoundingBox();
    return g;
  }

  /** One Mesh per material key. */
  toGroup(resolve: (key: MatKey) => Material, name = 'geo', opts: { castShadow?: boolean; receiveShadow?: boolean } = {}): Group {
    const group = new Group();
    group.name = name;
    for (const key of this.buckets.keys()) {
      const g = this.geometryFor(key);
      if (!g) continue;
      const mesh = new Mesh(g, resolve(key));
      mesh.name = key;
      mesh.userData.matKey = key;
      mesh.castShadow = opts.castShadow ?? !key.startsWith('glass');
      mesh.receiveShadow = opts.receiveShadow ?? true;
      mesh.matrixAutoUpdate = false;
      group.add(mesh);
    }
    return group;
  }

  clear(): void { this.buckets.clear(); }
}

function norm2(x: number, z: number): [number, number] { const l = Math.hypot(x, z) || 1; return [x / l, z / l]; }

export function signedArea(poly: [number, number][]): number {
  let a = 0;
  for (let i = 0; i < poly.length; i++) { const p = poly[i], q = poly[(i + 1) % poly.length]; a += p[0] * q[1] - q[0] * p[1]; }
  return a / 2;
}

/** Ear-clipping triangulation for simple polygons. */
export function triangulate(poly: [number, number][]): [number, number, number][] {
  const n = poly.length;
  if (n < 3) return [];
  const idx = [...Array(n).keys()];
  const ccw = signedArea(poly) > 0;
  const out: [number, number, number][] = [];
  const cross = (a: number[], b: number[], c: number[]) => (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0]);
  const inside = (p: number[], a: number[], b: number[], c: number[]) => {
    const d1 = cross(a, b, p), d2 = cross(b, c, p), d3 = cross(c, a, p);
    return ccw ? d1 >= 0 && d2 >= 0 && d3 >= 0 : d1 <= 0 && d2 <= 0 && d3 <= 0;
  };
  let guard = 0;
  while (idx.length > 3 && guard++ < 10000) {
    let clipped = false;
    for (let i = 0; i < idx.length; i++) {
      const i0 = idx[(i - 1 + idx.length) % idx.length], i1 = idx[i], i2 = idx[(i + 1) % idx.length];
      const a = poly[i0], b = poly[i1], c = poly[i2];
      const cr = cross(a, b, c);
      if (ccw ? cr <= 0 : cr >= 0) continue;
      let ok = true;
      for (const j of idx) { if (j === i0 || j === i1 || j === i2) continue; if (inside(poly[j], a, b, c)) { ok = false; break; } }
      if (!ok) continue;
      out.push([i0, i1, i2]);
      idx.splice(i, 1);
      clipped = true;
      break;
    }
    if (!clipped) break;
  }
  if (idx.length === 3) out.push([idx[0], idx[1], idx[2]]);
  return out;
}
