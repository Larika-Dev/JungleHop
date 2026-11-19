// Door system (CLAUDE.md §5/§16): every door is an openable hinged object, E toggles, animated on hinges.
// Doors of one style share InstancedMeshes (one per material), so thousands of doors cost a few draw calls.
import { InstancedMesh, Matrix4, Object3D, Quaternion, Vector3, type Material, type Scene } from 'three';
import type { GeoBuilder } from '../core/geo';
import { mat } from '../core/materials';
import type { CollisionWorld, WallSeg } from './collision';

export interface DoorInstance {
  id: number;
  style: string;
  owner: string;
  hinge: Vector3;
  /** yaw (radians) of the closed leaf: local +x of the leaf points along this direction */
  yaw: number;
  /** +1 opens toward local -z side (rotate +), -1 the other way */
  swing: number;
  width: number;
  height: number;
  angle: number;
  target: number;
  wall: WallSeg | null;
  index: number;
  meta?: Record<string, unknown>;
}

interface StyleEntry { meshes: InstancedMesh[]; doors: DoorInstance[]; builder: GeoBuilder; capacity: number; }

const _m = new Matrix4(), _q = new Quaternion(), _s = new Vector3(1, 1, 1), _y = new Vector3(0, 1, 0);

export class DoorSystem {
  styles = new Map<string, StyleEntry>();
  root = new Object3D();
  private nextId = 1;
  private animating = new Set<DoorInstance>();
  constructor(scene: Scene, private collision: CollisionWorld) { this.root.name = 'doors'; scene.add(this.root); }

  hasStyle(id: string) { return this.styles.has(id); }
  registerStyle(id: string, builder: GeoBuilder) {
    if (this.styles.has(id)) return;
    const e: StyleEntry = { meshes: [], doors: [], builder, capacity: 0 };
    this.styles.set(id, e);
    this.grow(e, 64);
  }
  private grow(e: StyleEntry, cap: number) {
    for (const m of e.meshes) { this.root.remove(m); m.dispose(); }
    e.meshes = [];
    for (const key of e.builder.buckets.keys()) {
      const g = e.builder.geometryFor(key)!;
      const im = new InstancedMesh(g, mat(key) as Material, cap);
      im.name = `door:${key}`; im.userData.matKey = key;
      im.count = e.doors.length; im.castShadow = true; im.receiveShadow = true; im.frustumCulled = false;
      e.meshes.push(im);
      this.root.add(im);
    }
    e.capacity = cap;
    for (const d of e.doors) this.write(e, d);
  }
  private write(e: StyleEntry, d: DoorInstance) {
    _q.setFromAxisAngle(_y, d.yaw + d.swing * d.angle);
    _m.compose(d.hinge, _q, _s);
    for (const im of e.meshes) { im.setMatrixAt(d.index, _m); im.instanceMatrix.needsUpdate = true; }
  }

  add(owner: string, style: string, hinge: Vector3, yaw: number, width: number, height: number, swing = 1, meta?: Record<string, unknown>): DoorInstance {
    const e = this.styles.get(style);
    if (!e) throw new Error(`door style ${style} not registered`);
    if (e.doors.length >= e.capacity) this.grow(e, e.capacity * 2);
    const ex = Math.cos(yaw), ez = -Math.sin(yaw); // local +x after yaw rotation
    const wall = this.collision.addWall(`door:${owner}`, hinge.x, hinge.z, hinge.x + ex * width, hinge.z + ez * width, hinge.y, hinge.y + height, 0.05);
    const d: DoorInstance = { id: this.nextId++, style, owner, hinge: hinge.clone(), yaw, swing, width, height, angle: 0, target: 0, wall, index: e.doors.length, meta };
    e.doors.push(d);
    for (const im of e.meshes) im.count = e.doors.length;
    this.write(e, d);
    return d;
  }
  removeOwner(owner: string) {
    this.collision.removeOwner(`door:${owner}`);
    for (const e of this.styles.values()) {
      let changed = false;
      for (let i = e.doors.length - 1; i >= 0; i--) {
        if (e.doors[i].owner !== owner) continue;
        this.animating.delete(e.doors[i]);
        const last = e.doors.pop()!;
        if (i < e.doors.length) { e.doors[i] = last; last.index = i; this.write(e, last); }
        changed = true;
      }
      if (changed) for (const im of e.meshes) im.count = e.doors.length;
    }
  }
  toggle(d: DoorInstance) {
    d.target = d.target > 0 ? 0 : Math.PI / 2 * 0.95;
    this.animating.add(d);
    if (d.wall) d.wall.enabled = false;
  }
  setOpen(d: DoorInstance, open: boolean) { d.target = open ? Math.PI / 2 * 0.95 : 0; d.angle = d.target; if (d.wall) d.wall.enabled = !open; this.write(this.styles.get(d.style)!, d); }
  /** Nearest door whose leaf is within maxD of the ray from origin along dir (plan + height check). */
  pick(origin: Vector3, dir: Vector3, maxD = 2.2): DoorInstance | null {
    let best: DoorInstance | null = null, bestD = maxD;
    for (const e of this.styles.values()) for (const d of e.doors) {
      const mx = d.hinge.x + Math.cos(d.yaw + d.swing * d.angle) * d.width / 2;
      const mz = d.hinge.z - Math.sin(d.yaw + d.swing * d.angle) * d.width / 2;
      const my = d.hinge.y + Math.min(1.1, d.height / 2);
      const vx = mx - origin.x, vy = my - origin.y, vz = mz - origin.z;
      const t = vx * dir.x + vy * dir.y + vz * dir.z;
      if (t < 0 || t > maxD + 0.6) continue;
      const px = origin.x + dir.x * t - mx, py = origin.y + dir.y * t - my, pz = origin.z + dir.z * t - mz;
      const off = Math.hypot(px, py * 0.6, pz);
      if (off < d.width * 0.65 && t < bestD + 0.6 && (!best || t < bestD)) { best = d; bestD = t; }
    }
    return best;
  }
  update(dt: number) {
    for (const d of this.animating) {
      const sp = 2.2 * dt;
      d.angle += Math.max(-sp, Math.min(sp, d.target - d.angle));
      if (Math.abs(d.target - d.angle) < 1e-3) {
        d.angle = d.target;
        this.animating.delete(d);
        if (d.wall) d.wall.enabled = d.angle === 0;
      }
      this.write(this.styles.get(d.style)!, d);
    }
  }
  get count() { let n = 0; for (const e of this.styles.values()) n += e.doors.length; return n; }
  all(): DoorInstance[] { const out: DoorInstance[] = []; for (const e of this.styles.values()) out.push(...e.doors); return out; }
}
