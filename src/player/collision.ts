// Simplified collision world (CLAUDE.md §16): 2D wall segments with vertical extent + walkable floor
// patches (convex polygons carrying a plane, so ramps and stairs are slopes), with terrain as fallback.
// Everything is stored in a spatial hash keyed by owner (tile / building / door) for streaming.

export interface WallSeg {
  ax: number; az: number; bx: number; bz: number;
  /** half thickness (m) */
  t: number;
  y0: number; y1: number;
  enabled: boolean;
  owner: string;
}
export interface FloorPatch {
  poly: [number, number][]; // convex, plan coords
  /** y = a*x + b*z + c */
  a: number; b: number; c: number;
  owner: string;
  /** Solid from below? (slabs block upward motion when true; unused for now) */
  solid?: boolean;
}

const CELL = 4;
const key = (cx: number, cz: number) => cx * 73856093 ^ cz * 19349663;

class Hash<T extends { owner: string }> {
  cells = new Map<number, T[]>();
  byOwner = new Map<string, { item: T; keys: number[] }[]>();
  insert(item: T, x0: number, z0: number, x1: number, z1: number) {
    const keys: number[] = [];
    const cx0 = Math.floor(Math.min(x0, x1) / CELL), cx1 = Math.floor(Math.max(x0, x1) / CELL);
    const cz0 = Math.floor(Math.min(z0, z1) / CELL), cz1 = Math.floor(Math.max(z0, z1) / CELL);
    if ((cx1 - cx0 + 1) * (cz1 - cz0 + 1) > 4000) return; // guard absurd items
    for (let cx = cx0; cx <= cx1; cx++) for (let cz = cz0; cz <= cz1; cz++) {
      const k = key(cx, cz);
      let arr = this.cells.get(k);
      if (!arr) { arr = []; this.cells.set(k, arr); }
      arr.push(item); keys.push(k);
    }
    let o = this.byOwner.get(item.owner);
    if (!o) { o = []; this.byOwner.set(item.owner, o); }
    o.push({ item, keys });
  }
  removeOwner(owner: string) {
    const o = this.byOwner.get(owner);
    if (!o) return;
    for (const { item, keys } of o) for (const k of keys) {
      const arr = this.cells.get(k);
      if (!arr) continue;
      const i = arr.indexOf(item);
      if (i >= 0) { arr[i] = arr[arr.length - 1]; arr.pop(); }
      if (!arr.length) this.cells.delete(k);
    }
    this.byOwner.delete(owner);
  }
  query(x0: number, z0: number, x1: number, z1: number, out: Set<T>) {
    const cx0 = Math.floor(x0 / CELL), cx1 = Math.floor(x1 / CELL), cz0 = Math.floor(z0 / CELL), cz1 = Math.floor(z1 / CELL);
    for (let cx = cx0; cx <= cx1; cx++) for (let cz = cz0; cz <= cz1; cz++) {
      const arr = this.cells.get(key(cx, cz));
      if (arr) for (const it of arr) out.add(it);
    }
  }
  get size() { let n = 0; for (const o of this.byOwner.values()) n += o.length; return n; }
}

function inConvex(x: number, z: number, poly: [number, number][]): boolean {
  let sign = 0;
  for (let i = 0; i < poly.length; i++) {
    const [ax, az] = poly[i], [bx, bz] = poly[(i + 1) % poly.length];
    const c = (bx - ax) * (z - az) - (bz - az) * (x - ax);
    if (Math.abs(c) < 1e-9) continue;
    const s = c > 0 ? 1 : -1;
    if (sign === 0) sign = s; else if (s !== sign) return false;
  }
  return true;
}

export class CollisionWorld {
  walls = new Hash<WallSeg>();
  floors = new Hash<FloorPatch>();
  /** Terrain/road surface height fallback. */
  ground: (x: number, z: number) => number = () => 0;
  private tmpW = new Set<WallSeg>();
  private tmpF = new Set<FloorPatch>();

  addWall(owner: string, ax: number, az: number, bx: number, bz: number, y0: number, y1: number, thickness = 0.2): WallSeg {
    const w: WallSeg = { ax, az, bx, bz, t: thickness / 2, y0, y1, enabled: true, owner };
    const pad = w.t + 0.5;
    this.walls.insert(w, Math.min(ax, bx) - pad, Math.min(az, bz) - pad, Math.max(ax, bx) + pad, Math.max(az, bz) + pad);
    return w;
  }
  /** Walkable patch. Pass the plane via three points or a constant y. */
  addFloor(owner: string, poly: [number, number][], y: number | { a: number; b: number; c: number }) {
    const p: FloorPatch = typeof y === 'number' ? { poly, a: 0, b: 0, c: y, owner } : { poly, ...y, owner };
    let x0 = Infinity, z0 = Infinity, x1 = -Infinity, z1 = -Infinity;
    for (const [x, z] of poly) { x0 = Math.min(x0, x); x1 = Math.max(x1, x); z0 = Math.min(z0, z); z1 = Math.max(z1, z); }
    this.floors.insert(p, x0, z0, x1, z1);
    return p;
  }
  /** Ramp patch rising linearly from edge (p0->p1, height y0) to the opposite edge at y1 along `dir`. */
  addRamp(owner: string, poly: [number, number][], ox: number, oz: number, dx: number, dz: number, y0: number, y1: number, run: number) {
    // y = y0 + ((x-ox)*dx + (z-oz)*dz)/run * (y1-y0)
    const k = (y1 - y0) / run;
    return this.addFloor(owner, poly, { a: dx * k, b: dz * k, c: y0 - (ox * dx + oz * dz) * k });
  }
  removeOwner(owner: string) { this.walls.removeOwner(owner); this.floors.removeOwner(owner); }

  /** Highest walkable surface at (x,z) not above maxY. Returns ground if no patch qualifies. */
  floorAt(x: number, z: number, maxY: number): number {
    let best = -Infinity;
    const g = this.ground(x, z);
    if (g <= maxY) best = g;
    this.tmpF.clear();
    this.floors.query(x, z, x, z, this.tmpF);
    for (const f of this.tmpF) {
      const y = f.a * x + f.b * z + f.c;
      if (y <= maxY && y > best && inConvex(x, z, f.poly)) best = y;
    }
    return best === -Infinity ? g : best;
  }
  /** Lowest surface strictly above y at (x,z) (for ceilings); Infinity if none. */
  ceilingAt(x: number, z: number, y: number): number {
    let best = Infinity;
    this.tmpF.clear();
    this.floors.query(x, z, x, z, this.tmpF);
    for (const f of this.tmpF) {
      const fy = f.a * x + f.b * z + f.c - 0.3;
      if (fy > y && fy < best && inConvex(x, z, f.poly)) best = fy;
    }
    return best;
  }

  /** Push a circle (plan) out of walls overlapping the vertical span [yLo, yHi]. Mutates pos. */
  resolve(pos: { x: number; z: number }, r: number, yLo: number, yHi: number, iterations = 3) {
    for (let it = 0; it < iterations; it++) {
      this.tmpW.clear();
      this.walls.query(pos.x - r, pos.z - r, pos.x + r, pos.z + r, this.tmpW);
      let moved = false;
      for (const w of this.tmpW) {
        if (!w.enabled || w.y1 <= yLo || w.y0 >= yHi) continue;
        const dx = w.bx - w.ax, dz = w.bz - w.az;
        const l2 = dx * dx + dz * dz || 1e-9;
        let t = ((pos.x - w.ax) * dx + (pos.z - w.az) * dz) / l2;
        t = Math.max(0, Math.min(1, t));
        const cx = w.ax + dx * t, cz = w.az + dz * t;
        let nx = pos.x - cx, nz = pos.z - cz;
        const d = Math.hypot(nx, nz);
        const min = r + w.t;
        if (d < min) {
          if (d < 1e-6) { nx = -dz; nz = dx; const l = Math.hypot(nx, nz); nx /= l; nz /= l; } else { nx /= d; nz /= d; }
          pos.x = cx + nx * min; pos.z = cz + nz * min;
          moved = true;
        }
      }
      if (!moved) break;
    }
  }

  /** Segment-vs-walls raycast in plan (for door/interact checks). Returns distance or Infinity. */
  rayWalls(x: number, z: number, dx: number, dz: number, maxD: number, y: number): number {
    this.tmpW.clear();
    this.walls.query(Math.min(x, x + dx * maxD) - 1, Math.min(z, z + dz * maxD) - 1, Math.max(x, x + dx * maxD) + 1, Math.max(z, z + dz * maxD) + 1, this.tmpW);
    let best = Infinity;
    for (const w of this.tmpW) {
      if (!w.enabled || y < w.y0 || y > w.y1) continue;
      const ex = w.bx - w.ax, ez = w.bz - w.az;
      const den = dx * ez - dz * ex;
      if (Math.abs(den) < 1e-9) continue;
      const t = ((w.ax - x) * ez - (w.az - z) * ex) / den;
      const u = ((w.ax - x) * dz - (w.az - z) * dx) / den;
      if (t >= 0 && t <= maxD && u >= 0 && u <= 1) best = Math.min(best, t);
    }
    return best;
  }
  stats() { return { walls: this.walls.size, floors: this.floors.size }; }
}
