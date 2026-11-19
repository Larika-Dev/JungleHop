// Measure tool (CLAUDE.md §16): click two points, distance shown in centimeters (QA).
import { BufferGeometry, Float32BufferAttribute, Line, LineBasicMaterial, Mesh, MeshBasicMaterial, Object3D, Raycaster, SphereGeometry, Vector2, Vector3, type Camera } from 'three';
import { pc } from '../core/palette';

export class MeasureTool {
  active = false;
  points: Vector3[] = [];
  root = new Object3D();
  label = document.createElement('div');
  private ray = new Raycaster();
  private line = new Line(new BufferGeometry(), new LineBasicMaterial({ color: pc('NEON_PINK'), depthTest: false }));
  private dots: Mesh[] = [];
  constructor(parent: HTMLElement, private camera: Camera, private targets: () => Object3D[]) {
    this.label.className = 'measure-label';
    parent.appendChild(this.label);
    this.line.renderOrder = 999;
    this.root.add(this.line);
    for (let i = 0; i < 2; i++) {
      const d = new Mesh(new SphereGeometry(0.015, 12, 8), new MeshBasicMaterial({ color: pc('NEON_PINK'), depthTest: false }));
      d.visible = false; d.renderOrder = 999; this.dots.push(d); this.root.add(d);
    }
  }
  setActive(on: boolean) { this.active = on; this.root.visible = on; this.label.style.display = on ? 'block' : 'none'; if (!on) this.clear(); }
  clear() { this.points = []; this.dots.forEach((d) => (d.visible = false)); this.line.visible = false; this.label.textContent = 'Measure: click point 1'; }
  /** ndc: screen point in normalized device coords (0,0 = crosshair). */
  click(ndc = new Vector2(0, 0)): Vector3 | null {
    this.ray.setFromCamera(ndc, this.camera);
    const hits = this.ray.intersectObjects(this.targets(), true).filter((h) => (h.object as Mesh).isMesh && h.object.visible);
    if (!hits.length) return null;
    const p = hits[0].point.clone();
    if (this.points.length >= 2) this.clear();
    this.points.push(p);
    const d = this.dots[this.points.length - 1]; d.position.copy(p); d.visible = true;
    if (this.points.length === 2) {
      const [a, b] = this.points;
      this.line.geometry.setAttribute('position', new Float32BufferAttribute([a.x, a.y, a.z, b.x, b.y, b.z], 3));
      this.line.visible = true;
      const dist = a.distanceTo(b) * 100;
      const dx = Math.abs(a.x - b.x) * 100, dy = Math.abs(a.y - b.y) * 100, dz = Math.abs(a.z - b.z) * 100;
      this.label.textContent = `${dist.toFixed(1)} cm   (dx ${dx.toFixed(1)}  dy ${dy.toFixed(1)}  dz ${dz.toFixed(1)})`;
    } else this.label.textContent = 'Measure: click point 2';
    return p;
  }
}
