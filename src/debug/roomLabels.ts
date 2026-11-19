// Room labels overlay (roomType + area) for rooms within 25 m (CLAUDE.md §16).
import { Vector3, type Camera, type Object3D } from 'three';

export class RoomLabels {
  canvas = document.createElement('canvas');
  enabled = false;
  constructor(parent: HTMLElement, private rooms: () => Object3D[]) { this.canvas.className = 'overlay2d'; parent.appendChild(this.canvas); }
  draw(camera: Camera, labelColor: string, bg: string) {
    const c = this.canvas;
    const W = (c.width = window.innerWidth), H = (c.height = window.innerHeight);
    const ctx = c.getContext('2d')!;
    ctx.clearRect(0, 0, W, H);
    if (!this.enabled) return;
    const v = new Vector3();
    ctx.font = '12px monospace'; ctx.textAlign = 'center';
    for (const r of this.rooms()) {
      r.getWorldPosition(v);
      if (v.distanceTo(camera.position) > 25) continue;
      v.project(camera);
      if (v.z > 1 || Math.abs(v.x) > 1 || Math.abs(v.y) > 1) continue;
      const x = (v.x * 0.5 + 0.5) * W, y = (-v.y * 0.5 + 0.5) * H;
      const u = r.userData;
      const t = `${u.roomType} · ${Number(u.areaM2).toFixed(1)} m²`;
      const w = ctx.measureText(t).width + 8;
      ctx.fillStyle = bg; ctx.fillRect(x - w / 2, y - 10, w, 16);
      ctx.fillStyle = labelColor; ctx.fillText(t, x, y + 2);
    }
  }
}
