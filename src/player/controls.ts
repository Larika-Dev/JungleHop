// First-person controls (CLAUDE.md §16): WASD + mouse with pointer lock, eye 165 cm, walk 1.4 m/s,
// run 4 m/s (Shift), step-up 20 cm, capsule radius 30 cm. F toggles free-fly.
import { PerspectiveCamera, Vector3 } from 'three';
import { cm } from '../core/units';
import type { CollisionWorld } from './collision';

export const PLAYER = {
  eye: cm(165), walk: 1.4, run: 4.0, stepUp: cm(20), radius: cm(30), height: cm(180),
  gravity: 9.81, jump: 3.2, fly: 12, flyFast: 60,
} as const;

export class Player {
  pos = new Vector3(0, 0, 8); // feet
  vel = new Vector3();
  yaw = 0; // radians, 0 looks toward -Z (north)
  pitch = 0;
  fly = false;
  onGround = false;
  keys = new Set<string>();
  locked = false;
  enabled = true;
  /** Callbacks for single key presses (E, M, `, F ...). */
  onKey: ((code: string, e: KeyboardEvent) => void)[] = [];

  constructor(public camera: PerspectiveCamera, public dom: HTMLElement, public world: CollisionWorld) {
    window.addEventListener('keydown', (e) => {
      if ((e.target as HTMLElement)?.tagName === 'INPUT') return;
      if (!this.keys.has(e.code)) {
        if (e.code === 'KeyF') this.toggleFly();
        for (const f of this.onKey) f(e.code, e);
      }
      this.keys.add(e.code);
      if (['Space', 'ArrowUp', 'ArrowDown'].includes(e.code)) e.preventDefault();
    });
    window.addEventListener('keyup', (e) => this.keys.delete(e.code));
    window.addEventListener('blur', () => this.keys.clear());
    document.addEventListener('pointerlockchange', () => { this.locked = document.pointerLockElement === dom; });
    // drag-to-look fallback where pointer lock is unavailable (sandboxed/embedded pages)
    let drag = false;
    dom.addEventListener('mousedown', () => { drag = true; });
    window.addEventListener('mouseup', () => { drag = false; });
    document.addEventListener('mousemove', (e) => {
      if (!this.locked && !drag) return;
      this.yaw -= e.movementX * 0.0022;
      this.pitch = Math.max(-1.55, Math.min(1.55, this.pitch - e.movementY * 0.0022));
    });
  }

  requestLock() {
    if (this.locked) return;
    try { const r = this.dom.requestPointerLock?.() as unknown as Promise<void> | undefined; r?.catch?.(() => {}); } catch { /* not allowed here: drag-to-look */ }
  }

  toggleFly() {
    this.fly = !this.fly;
    this.vel.set(0, 0, 0);
    if (!this.fly) {
      // drop to the surface below
      const y = this.world.floorAt(this.pos.x, this.pos.z, this.pos.y + 0.5);
      if (this.pos.y - y < 3) this.pos.y = y;
    }
  }

  teleport(x: number, z: number, y?: number, yaw?: number, pitch?: number) {
    this.pos.set(x, y ?? this.world.floorAt(x, z, 1e6), z);
    if (yaw !== undefined) this.yaw = yaw;
    if (pitch !== undefined) this.pitch = pitch;
    this.vel.set(0, 0, 0);
    this.syncCamera();
  }

  update(dt: number) {
    dt = Math.min(dt, 0.1);
    if (this.enabled) {
      const k = this.keys;
      const f = (k.has('KeyW') || k.has('ArrowUp') ? 1 : 0) - (k.has('KeyS') || k.has('ArrowDown') ? 1 : 0);
      const s = (k.has('KeyD') || k.has('ArrowRight') ? 1 : 0) - (k.has('KeyA') || k.has('ArrowLeft') ? 1 : 0);
      const fast = k.has('ShiftLeft') || k.has('ShiftRight');
      const sin = Math.sin(this.yaw), cos = Math.cos(this.yaw);
      // forward = (-sin, -cos) in xz; right = (cos, -sin)
      let wx = -sin * f + cos * s, wz = -cos * f - sin * s;
      const wl = Math.hypot(wx, wz);
      if (wl > 0) { wx /= wl; wz /= wl; }
      if (this.fly) {
        const sp = fast ? PLAYER.flyFast : PLAYER.fly;
        const up = (k.has('Space') ? 1 : 0) - (k.has('ControlLeft') || k.has('KeyC') ? 1 : 0);
        const cp = Math.cos(this.pitch), sp2 = Math.sin(this.pitch);
        this.pos.x += (wx * (f !== 0 ? cp : 1)) * sp * dt;
        this.pos.z += (wz * (f !== 0 ? cp : 1)) * sp * dt;
        this.pos.y += (f * sp2 + up) * sp * dt;
      } else {
        const sp = fast ? PLAYER.run : PLAYER.walk;
        const accel = this.onGround ? 12 : 2;
        this.vel.x += (wx * sp - this.vel.x) * Math.min(1, accel * dt);
        this.vel.z += (wz * sp - this.vel.z) * Math.min(1, accel * dt);
        if (this.onGround && k.has('Space')) { this.vel.y = PLAYER.jump; this.onGround = false; }
        this.vel.y -= PLAYER.gravity * dt;
        // horizontal move in substeps (no tunnelling through 12 cm partitions)
        const steps = Math.max(1, Math.ceil((Math.hypot(this.vel.x, this.vel.z) * dt) / 0.08));
        for (let i = 0; i < steps; i++) {
          this.pos.x += (this.vel.x * dt) / steps;
          this.pos.z += (this.vel.z * dt) / steps;
          this.world.resolve(this.pos, PLAYER.radius, this.pos.y + PLAYER.stepUp + 0.01, this.pos.y + PLAYER.height);
        }
        // vertical
        const floor = this.world.floorAt(this.pos.x, this.pos.z, this.pos.y + PLAYER.stepUp);
        const ny = this.pos.y + this.vel.y * dt;
        if (ny <= floor + 0.001) {
          this.pos.y = this.onGround && floor < this.pos.y && this.pos.y - floor < PLAYER.stepUp + 0.05 ? floor : Math.max(ny, floor);
          if (this.pos.y <= floor + 0.001) { this.pos.y = floor; this.vel.y = 0; this.onGround = true; }
        } else {
          // keep feet glued when walking down steps/ramps
          if (this.onGround && this.vel.y <= 0 && this.pos.y - floor < PLAYER.stepUp + 0.05) { this.pos.y = floor; this.vel.y = 0; }
          else { this.pos.y = ny; this.onGround = false; }
        }
        const ceil = this.world.ceilingAt(this.pos.x, this.pos.z, this.pos.y + 1.0);
        if (this.pos.y + PLAYER.height > ceil && this.vel.y > 0) this.vel.y = 0;
        if (this.pos.y < -200) this.teleport(0, 8);
      }
    }
    this.syncCamera();
  }

  syncCamera() {
    this.camera.position.set(this.pos.x, this.pos.y + (this.fly ? 0 : PLAYER.eye), this.pos.z);
    this.camera.rotation.set(this.pitch, this.yaw, 0, 'YXZ');
    this.camera.updateMatrixWorld();
  }

  /** Eye position & look direction (for interaction raycasts). */
  look(): { origin: Vector3; dir: Vector3 } {
    const dir = new Vector3(0, 0, -1).applyEuler(this.camera.rotation);
    return { origin: this.camera.position.clone(), dir };
  }
}
