// FPS / draw-call / triangle HUD (CLAUDE.md §16).
import type { WebGLRenderer } from 'three';

export class PerfHud {
  el = document.createElement('div');
  private frames = 0; private last = performance.now(); fps = 0;
  extra: (() => string)[] = [];
  constructor(parent: HTMLElement) { this.el.className = 'perfhud'; parent.appendChild(this.el); }
  update(renderer: WebGLRenderer, visible: boolean) {
    this.frames++;
    const now = performance.now();
    if (now - this.last >= 500) { this.fps = (this.frames * 1000) / (now - this.last); this.frames = 0; this.last = now; }
    this.el.style.display = visible ? 'block' : 'none';
    if (!visible) return;
    const i = renderer.info;
    this.el.textContent = [
      `FPS ${this.fps.toFixed(0)}`,
      `draw calls ${i.render.calls}  (budget 2500)`,
      `triangles ${(i.render.triangles / 1e6).toFixed(2)} M  (budget 8 M)`,
      `geometries ${i.memory.geometries}  textures ${i.memory.textures}`,
      ...this.extra.map((f) => f()),
    ].join('\n');
  }
}
