// GTA-style minimap (top-right, rotates with heading) + full map screen (M) with landmark icons.
import { css, cssA } from '../core/palette';
import { TOTAL } from '../core/tiles';
import { BYPASS, DISTRICTS, LANDMARKS, RAIL, ROADS, districtAt, rowHalf, roadHalf } from '../world/layout';

export type MapLayer = (ctx: CanvasRenderingContext2D, toPx: (x: number, z: number) => [number, number], s: number) => void;

const PX_PER_M = 0.75;

export class Minimap {
  base: HTMLCanvasElement;
  mini: HTMLCanvasElement;
  full: HTMLCanvasElement;
  label: HTMLDivElement;
  fullOpen = false;
  layers: MapLayer[] = [];
  private dirty = true;

  constructor(parent: HTMLElement) {
    this.base = document.createElement('canvas');
    this.base.width = Math.round((TOTAL.x1 - TOTAL.x0) * PX_PER_M);
    this.base.height = Math.round((TOTAL.z1 - TOTAL.z0) * PX_PER_M);
    this.mini = document.createElement('canvas');
    this.mini.width = this.mini.height = 440;
    this.mini.className = 'minimap';
    this.label = document.createElement('div');
    this.label.className = 'minimap-label';
    this.full = document.createElement('canvas');
    this.full.className = 'fullmap';
    this.full.style.display = 'none';
    parent.append(this.mini, this.label, this.full);
  }

  addLayer(l: MapLayer) { this.layers.push(l); this.dirty = true; }
  invalidate() { this.dirty = true; }

  private toPx = (x: number, z: number): [number, number] => [(x - TOTAL.x0) * PX_PER_M, (z - TOTAL.z0) * PX_PER_M];

  private renderBase() {
    const c = this.base.getContext('2d')!;
    const s = PX_PER_M;
    c.fillStyle = css('LOBLOLLY_NEEDLE'); c.fillRect(0, 0, this.base.width, this.base.height);
    for (const d of [...DISTRICTS].sort((a, b) => a.order - b.order)) {
      if (d.id === 'summit') continue;
      c.fillStyle = cssA(d.mapColor, d.id === 'campus_generic' ? 0.55 : 0.75);
      c.beginPath(); for (const [x, z] of d.poly) c.lineTo(...this.toPx(x, z)); c.closePath(); c.fill();
    }
    const stroke = (pts: [number, number][], w: number, col: string) => {
      c.strokeStyle = col; c.lineWidth = w; c.lineJoin = 'round'; c.lineCap = 'round';
      c.beginPath(); for (const [x, z] of pts) c.lineTo(...this.toPx(x, z)); c.stroke();
    };
    stroke(BYPASS, 16 * s, css('ASPHALT_FRESH'));
    stroke(RAIL, 3 * s, css('IRON_BLACK'));
    for (const r of ROADS) stroke(r.pts, rowHalf(r.kind) * 2 * s, css('CONCRETE_AGED'));
    for (const r of ROADS) stroke(r.pts, Math.max(3, (r.alleyWidthCm ? r.alleyWidthCm / 100 : roadHalf(r.kind) * 2) * s), css('ASPHALT_AGED'));
    for (const l of this.layers) l(c, this.toPx, s);
    this.dirty = false;
  }

  update(x: number, z: number, yaw: number) {
    if (this.dirty) this.renderBase();
    const c = this.mini.getContext('2d')!;
    const W = this.mini.width, R = W / 2;
    const zoom = 2.0; // canvas px per base px
    c.save();
    c.clearRect(0, 0, W, W);
    c.beginPath(); c.arc(R, R, R - 4, 0, Math.PI * 2); c.clip();
    c.fillStyle = css('UI_PANEL'); c.fillRect(0, 0, W, W);
    c.translate(R, R);
    c.rotate(yaw);
    const [px, pz] = this.toPx(x, z);
    c.scale(zoom, zoom);
    c.drawImage(this.base, -px, -pz);
    c.restore();
    // frame + player arrow
    c.strokeStyle = css('ONSU_NAVY'); c.lineWidth = 8; c.beginPath(); c.arc(R, R, R - 4, 0, Math.PI * 2); c.stroke();
    c.fillStyle = css('ONSU_WHITE'); c.strokeStyle = css('IRON_BLACK'); c.lineWidth = 2;
    c.beginPath(); c.moveTo(R, R - 16); c.lineTo(R + 11, R + 12); c.lineTo(R, R + 6); c.lineTo(R - 11, R + 12); c.closePath(); c.fill(); c.stroke();
    // north marker
    const na = yaw; const nx = R + Math.sin(-na) * (R - 22) * -1, nz = R - Math.cos(na) * (R - 22);
    c.fillStyle = css('NEON_RED'); c.font = 'bold 26px sans-serif'; c.textAlign = 'center'; c.textBaseline = 'middle';
    c.fillText('N', nx, nz);
    const d = districtAt(x, z);
    this.label.textContent = (d?.name ?? 'Outer Ring').toUpperCase();
    if (this.fullOpen) this.drawFull(x, z, yaw);
  }

  toggleFull(force?: boolean) {
    this.fullOpen = force ?? !this.fullOpen;
    this.full.style.display = this.fullOpen ? 'block' : 'none';
  }

  private drawFull(x: number, z: number, yaw: number) {
    const cv = this.full;
    const W = (cv.width = Math.round(window.innerWidth * devicePixelRatio));
    const H = (cv.height = Math.round(window.innerHeight * devicePixelRatio));
    const c = cv.getContext('2d')!;
    c.fillStyle = css('UI_PANEL'); c.fillRect(0, 0, W, H);
    // fit the dense core with margin
    const cx0 = -1000, cx1 = 800, cz0 = -550, cz1 = 1050;
    const s = Math.min(W / (cx1 - cx0), H / (cz1 - cz0));
    const ox = (W - (cx1 - cx0) * s) / 2, oz = (H - (cz1 - cz0) * s) / 2;
    const k = s / PX_PER_M;
    c.save();
    c.translate(ox, oz);
    c.scale(k, k);
    c.drawImage(this.base, -(cx0 - TOTAL.x0) * PX_PER_M, -(cz0 - TOTAL.z0) * PX_PER_M);
    c.restore();
    const P = (px: number, pz: number): [number, number] => [ox + (px - cx0) * s, oz + (pz - cz0) * s];
    c.textAlign = 'center'; c.textBaseline = 'middle';
    for (const d of DISTRICTS) {
      if (d.id === 'campus_generic' || d.id === 'summit') continue;
      const [lx, lz] = P(d.label[0], d.label[1]);
      c.font = `bold ${Math.round(16 * devicePixelRatio)}px Georgia, serif`;
      c.lineWidth = 5; c.strokeStyle = css('UI_PANEL'); c.strokeText(d.name.toUpperCase(), lx, lz);
      c.fillStyle = css('ONSU_WHITE'); c.fillText(d.name.toUpperCase(), lx, lz);
    }
    for (const l of LANDMARKS) {
      const [lx, lz] = P(l.x, l.z);
      const r = 13 * devicePixelRatio;
      c.fillStyle = css('ONSU_NAVY'); c.strokeStyle = css('HEAVEN_BLUE'); c.lineWidth = 3;
      c.beginPath(); c.arc(lx, lz, r, 0, Math.PI * 2); c.fill(); c.stroke();
      c.fillStyle = css('ONSU_WHITE'); c.font = `bold ${Math.round(13 * devicePixelRatio)}px sans-serif`; c.fillText(String(l.n), lx, lz);
      c.font = `${Math.round(12 * devicePixelRatio)}px sans-serif`; c.fillStyle = css('MARQUEE_BULB');
      c.fillText(l.name, lx, lz + r + 10 * devicePixelRatio);
    }
    const [pxp, pzp] = P(x, z);
    c.save(); c.translate(pxp, pzp); c.rotate(-yaw);
    c.fillStyle = css('NEON_RED'); c.beginPath(); c.moveTo(0, -16); c.lineTo(10, 12); c.lineTo(-10, 12); c.closePath(); c.fill();
    c.restore();
    c.fillStyle = css('ONSU_WHITE'); c.font = `bold ${Math.round(28 * devicePixelRatio)}px Georgia, serif`; c.textAlign = 'left';
    c.fillText('CATHEDRAL MOUNT', 24 * devicePixelRatio, 36 * devicePixelRatio);
    c.font = `${Math.round(14 * devicePixelRatio)}px sans-serif`;
    c.fillText('State of Pamlico · press M to close', 24 * devicePixelRatio, 64 * devicePixelRatio);
  }
}
