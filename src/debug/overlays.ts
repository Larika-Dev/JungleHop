// Debug overlays: tile boundaries and the 35 m interior streaming radius (CLAUDE.md §16).
import { BufferGeometry, Float32BufferAttribute, LineBasicMaterial, LineLoop, LineSegments, Object3D } from 'three';
import { pc } from '../core/palette';
import { COLS, ROWS, TILE, TOTAL } from '../core/tiles';

export class DebugOverlays {
  root = new Object3D();
  tiles: LineSegments;
  radius: LineLoop;
  constructor(height: (x: number, z: number) => number, public interiorRadius = 35) {
    this.root.name = 'debug-overlays';
    const pts: number[] = [];
    const step = 10;
    const seg = (x0: number, z0: number, x1: number, z1: number) => {
      const n = Math.max(1, Math.round(Math.hypot(x1 - x0, z1 - z0) / step));
      for (let i = 0; i < n; i++) {
        const ax = x0 + ((x1 - x0) * i) / n, az = z0 + ((z1 - z0) * i) / n;
        const bx = x0 + ((x1 - x0) * (i + 1)) / n, bz = z0 + ((z1 - z0) * (i + 1)) / n;
        pts.push(ax, height(ax, az) + 0.3, az, bx, height(bx, bz) + 0.3, bz);
      }
    };
    for (let c = 0; c <= COLS; c++) seg(TOTAL.x0 + c * TILE, TOTAL.z0, TOTAL.x0 + c * TILE, TOTAL.z1);
    for (let r = 0; r <= ROWS; r++) seg(TOTAL.x0, TOTAL.z0 + r * TILE, TOTAL.x1, TOTAL.z0 + r * TILE);
    const g = new BufferGeometry(); g.setAttribute('position', new Float32BufferAttribute(pts, 3));
    this.tiles = new LineSegments(g, new LineBasicMaterial({ color: pc('NEON_BLUE') }));
    const rp: number[] = [];
    for (let i = 0; i < 96; i++) { const a = (i / 96) * Math.PI * 2; rp.push(Math.cos(a) * interiorRadius, 0.15, Math.sin(a) * interiorRadius); }
    const rg = new BufferGeometry(); rg.setAttribute('position', new Float32BufferAttribute(rp, 3));
    this.radius = new LineLoop(rg, new LineBasicMaterial({ color: pc('NEON_PINK') }));
    this.root.add(this.tiles, this.radius);
    this.tiles.visible = this.radius.visible = false;
  }
  setTiles(on: boolean) { this.tiles.visible = on; }
  setRadius(on: boolean) { this.radius.visible = on; }
  follow(x: number, y: number, z: number) { this.radius.position.set(x, y, z); }
}
