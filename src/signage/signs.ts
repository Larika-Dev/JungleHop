// Signage per tile (CLAUDE.md §5 Signage, §11, §14): channel-letter business signs (letters 2 cm deep on
// 2.5 cm standoffs), 60 x 90 cm blade signs on IRON_BLACK brackets, 15 x 76 cm street-name blades, campus
// name plaques & carved friezes, poster columns, alley graffiti and the Billram mural, cinema marquee
// titles, stadium end-zone lettering and the Dome's center-court logo. All text is drawn into one canvas
// atlas per tile (+ a neon atlas), so a tile's signage costs a few draw calls.
import { CanvasTexture, DoubleSide, Group, Mesh, MeshBasicMaterial, MeshStandardMaterial, SRGBColorSpace, Vector3 } from 'three';
import { GeoBuilder } from '../core/geo';
import { mat } from '../core/materials';
import { css, cssA, type PaletteKey } from '../core/palette';
import { Rng, hash01 } from '../core/rng';
import { planFor } from '../buildings/manager';
import { storefrontSpan } from '../buildings/exterior';
import { localToWorld, type Sited } from '../world/cityPlan';
import { roadPlan } from '../roads/build';
import { CURB_H, CROSS_SLOPE } from '../roads/network';
import { tileNameAt } from '../core/tiles';
import { MOVIES, graffitiTag, poster } from './parody';
import { drawBillram } from './billram';
import { font } from './fonts';

type Draw = (x: CanvasRenderingContext2D, w: number, h: number) => void;
interface Entry { w: number; h: number; draw: Draw; neon: boolean; quad: Vector3[]; double?: boolean; }

class Atlas {
  entries: Entry[] = [];
  add(e: Entry) { this.entries.push(e); }
  build(name: string): Group | null {
    if (!this.entries.length) return null;
    const grp = new Group(); grp.name = name;
    for (const neon of [false, true]) {
      const list = this.entries.filter((e) => e.neon === neon);
      if (!list.length) continue;
      // shelf packing
      const S = list.reduce((a, e) => a + e.w * e.h, 0) > 900000 ? 2048 : 1024;
      const c = document.createElement('canvas'); c.width = c.height = S;
      const x = c.getContext('2d')!;
      let cx = 0, cy = 0, rowH = 0;
      const g = new GeoBuilder();
      for (const e of list.sort((a, b) => b.h - a.h)) {
        const sc = Math.min(1, (S - 4) / e.w);
        const w = Math.floor(e.w * sc), h = Math.floor(e.h * sc);
        if (cx + w > S) { cx = 0; cy += rowH + 2; rowH = 0; }
        if (cy + h > S) break;
        x.save(); x.translate(cx, cy); x.beginPath(); x.rect(0, 0, w, h); x.clip(); x.scale(sc, sc); e.draw(x, e.w, e.h); x.restore();
        const u0 = cx / S, u1 = (cx + w) / S, v0 = 1 - (cy + h) / S, v1 = 1 - cy / S;
        const [a, b, cc, d] = e.quad.map((p) => p.toArray() as [number, number, number]);
        g.quad(neon ? 'neon' : 'sign', a, b, cc, d, [[u0, v0], [u1, v0], [u1, v1], [u0, v1]]);
        if (e.double) g.quad(neon ? 'neon' : 'sign', b, a, d, cc, [[u0, v0], [u1, v0], [u1, v1], [u0, v1]].map(([u, v]) => [u0 + u1 - u, v]) as any);
        cx += w + 2; rowH = Math.max(rowH, h);
      }
      const t = new CanvasTexture(c); t.colorSpace = SRGBColorSpace; t.anisotropy = 8;
      const m = neon ? new MeshBasicMaterial({ map: t, alphaTest: 0.4, toneMapped: false, side: DoubleSide }) : new MeshStandardMaterial({ map: t, alphaTest: 0.4, roughness: 0.6, side: DoubleSide });
      m.userData.matKey = neon ? 'neon:sign-atlas' : 'paint:sign-atlas';
      const geo = g.geometryFor(neon ? 'neon' : 'sign');
      if (geo) { const mesh = new Mesh(geo, m); mesh.name = neon ? 'neon-signs' : 'signs'; mesh.userData.matKey = m.userData.matKey; grp.add(mesh); }
    }
    return grp;
  }
}

/** Fit text into a box, drawing letters in `color` (optionally outlined). */
function fitText(x: CanvasRenderingContext2D, text: string, w: number, h: number, fam: Parameters<typeof font>[0], color: string, opts: { stroke?: string; glow?: string; weight?: string } = {}) {
  let px = h * 0.78;
  x.font = font(fam, px, opts.weight);
  const mw = x.measureText(text).width;
  if (mw > w * 0.94) { px *= (w * 0.94) / mw; x.font = font(fam, px, opts.weight); }
  x.textAlign = 'center'; x.textBaseline = 'middle';
  if (opts.glow) { x.shadowColor = opts.glow; x.shadowBlur = h * 0.25; }
  if (opts.stroke) { x.lineWidth = px * 0.08; x.strokeStyle = opts.stroke; x.strokeText(text, w / 2, h * 0.54); }
  x.fillStyle = color; x.fillText(text, w / 2, h * 0.54);
  x.shadowBlur = 0;
}

/** World quad on a building face: side 'front' (local z = −off), from local x0..x1 cm, y0..y1 cm above FFL. */
function faceQuad(s: Sited, x0: number, x1: number, y0: number, y1: number, off: number): Vector3[] {
  const sp = s.spec, y = sp.y;
  const P = (lx: number, ly: number) => { const [wx, wz] = localToWorld(sp, lx / 100, -off / 100); return new Vector3(wx, y + ly / 100, wz); };
  // the front faces local −z, so for someone looking at it local +x runs to their LEFT: text starts at x1
  return [P(x1, y0), P(x0, y0), P(x0, y1), P(x1, y1)];
}
/** Quad on the back face (local z = d + off), x measured from the back-left (looking at the back). */
function backQuad(s: Sited, x0: number, x1: number, y0: number, y1: number, off: number): Vector3[] {
  const sp = s.spec, y = sp.y, W = sp.w, D = sp.d;
  // the back faces local +z; looking at it, local +x runs to the viewer's right
  const P = (lx: number, ly: number) => { const [wx, wz] = localToWorld(sp, lx / 100, (D + off) / 100); return new Vector3(wx, y + ly / 100, wz); };
  return [P(x0, y0), P(x1, y0), P(x1, y1), P(x0, y1)];
}

export function signageForTile(tile: string, buildings: Sited[]): Group | null {
  const A = new Atlas();
  const rng = new Rng(`signs:${tile}`);
  for (const s of buildings) {
    const sp = s.spec;
    const plan = planFor(sp);
    const biz = sp.business;
    if (biz) {
      const span = storefrontSpan(sp, plan);
      const fg = (biz.sign ?? 'MARKING_WHITE') as PaletteKey;
      const neon = biz.type === 'bar' || biz.type === 'tattoo' || biz.type === 'records';
      if (span) {
        const [x0, x1] = span;
        const len = x1 - x0;
        // channel letters 2.5 cm off the sign band (band face at −2 cm)
        A.add({ w: Math.round(len * 1.2), h: 84, neon, quad: faceQuad(s, x0 + 10, x1 - 10, 437, 495, 4.5),
          draw: (x, w, h) => fitText(x, biz.name.toUpperCase(), w, h, biz.type === 'cinema' ? 'poster' : biz.type === 'bank' ? 'serif' : biz.type === 'cafe' || biz.type === 'bakery' ? 'script' : 'condensed', css(fg), { glow: neon ? css(fg) : undefined, stroke: neon ? undefined : cssA('SHADOW_INK', 0.35) }) });
        // letter returns (2 cm deep): a darker copy 2 cm behind the faces
        if (!neon) A.add({ w: Math.round(len * 1.2), h: 84, neon: false, quad: faceQuad(s, x0 + 11, x1 - 9, 436, 494, 2.5), draw: (x, w, h) => fitText(x, biz.name.toUpperCase(), w, h, biz.type === 'cinema' ? 'poster' : biz.type === 'bank' ? 'serif' : biz.type === 'cafe' || biz.type === 'bakery' ? 'script' : 'condensed', cssA('SHADOW_INK', 0.75)) });
        // OPEN neon in the window
        if (hash01(sp.x * 10, sp.z * 10, 3) < 0.5) A.add({ w: 120, h: 50, neon: true, quad: faceQuad(s, x1 - 110, x1 - 30, 200, 233, 8), draw: (x, w, h) => fitText(x, 'OPEN', w, h, 'condensed', css('NEON_RED'), { glow: css('NEON_RED') }) });
      }
      // 60 x 90 cm blade sign on an iron bracket for ~40% of shops
      if (hash01(sp.x * 7, sp.z * 3, 9) < 0.4 || biz.type === 'cinema') {
        const bx = span ? span[0] + 30 : 60;
        const [ax, az] = localToWorld(sp, bx / 100, -0.12), [bxw, bzw] = localToWorld(sp, bx / 100, -0.72);
        const y0 = sp.y + 3.3;
        A.add({ w: 120, h: 180, neon: false, double: true, quad: [new Vector3(ax, y0, az), new Vector3(bxw, y0, bzw), new Vector3(bxw, y0 + 0.9, bzw), new Vector3(ax, y0 + 0.9, az)],
          draw: (x, w, h) => { x.fillStyle = css((biz.signBg ?? 'DOOR_BLACK') as PaletteKey); x.fillRect(0, 0, w, h); x.strokeStyle = css('BRASS'); x.lineWidth = 6; x.strokeRect(5, 5, w - 10, h - 10); x.save(); x.translate(w / 2, h / 2); x.rotate(-Math.PI / 2); fitText(x, biz.name.split(' ')[0].toUpperCase(), h * 0.9, w * 0.6, 'condensed', css(fg)); x.restore(); } });
      }
      if (biz.type === 'cinema') {
        const t1 = rng.pick(MOVIES), t2 = rng.pick(MOVIES.filter((m) => m !== t1));
        A.add({ w: 900, h: 110, neon: false, quad: faceQuad(s, sp.w * 0.12, sp.w * 0.88, 362, 448, 253), draw: (x, w, h) => { x.fillStyle = css('MARQUEE_BULB'); x.fillRect(0, 0, w, h); fitText(x, t1, w, h / 2, 'poster', css('DOOR_BLACK')); x.translate(0, h / 2); fitText(x, t2, w, h / 2, 'poster', css('DOOR_BLACK')); } });
      }
      // alley-side graffiti / mural on the back wall of strip buildings
      if (sp.district === 'hamilton_strip' || sp.district === 'rosemary_row') {
        const r = hash01(sp.x * 3, sp.z * 5, 21);
        if (r < 0.18 && sp.w >= 800) {
          A.add({ w: 600, h: 300, neon: false, quad: backQuad(s, 80, Math.min(sp.w - 80, 680), 60, 360, 1.5), draw: (x, w, h) => { mural(x, w, h, new Rng(sp.id)); } });
        } else if (r < 0.65) {
          const tag = graffitiTag(rng);
          const len = Math.min(sp.w - 100, 380);
          A.add({ w: 520, h: 160, neon: false, quad: backQuad(s, 60, 60 + len, 70, 70 + len * 0.31, 1.2), draw: (x, w, h) => graffiti(x, w, h, tag, rng) });
        }
      }
    } else if (sp.name && sp.public) {
      // carved name on a limestone plaque beside the main door (campus / landmarks)
      const door = plan.extDoors.find((d) => d.side === 'front' && d.floor === 0);
      const at = door ? door.at + door.w + 40 : 60;
      A.add({ w: 300, h: 90, neon: false, quad: faceQuad(s, at, at + 120, 160, 196, 3), draw: (x, w, h) => { x.fillStyle = css('LIMESTONE_TRIM'); x.fillRect(0, 0, w, h); x.strokeStyle = css('CAPSTONE'); x.lineWidth = 4; x.strokeRect(4, 4, w - 8, h - 8); fitText(x, sp.name!.toUpperCase(), w * 0.92, h * 0.7, 'serif', css('FIELDSTONE_B')); } });
    }
    if (sp.custom === 'stadium') stadiumLettering(A, s);
    if (sp.custom === 'coachs_dome') courtLogo(A, s);
  }
  // street-name blades at this tile's nodes
  const P = roadPlan();
  for (const n of P.net.nodes) {
    if (tileNameAt(n.x, n.z) !== tile || n.arms.length < 3) continue;
    for (const a of n.arms) {
      if (!a.road.sec.curb) continue;
      const nx = -a.dir[1], nz = a.dir[0];
      const off = a.half + 0.9, along = a.cut + 1.0;
      const x0 = n.x + a.dir[0] * along - nx * off, z0 = n.z + a.dir[1] * along - nz * off;
      const y = n.y - CROSS_SLOPE * a.half + CURB_H + (n.signal ? 5.9 : 2.9);
      const name = a.road.name.toUpperCase();
      // blade parallel to the road it names (15 x 76 cm)
      const ux = a.dir[0] * 0.38, uz = a.dir[1] * 0.38;
      A.add({ w: 380, h: 75, neon: false, double: true, quad: [new Vector3(x0 - ux, y, z0 - uz), new Vector3(x0 + ux, y, z0 + uz), new Vector3(x0 + ux, y + 0.15, z0 + uz), new Vector3(x0 - ux, y + 0.15, z0 - uz)].map((v) => v.add(new Vector3(nx * 0.012, 0, nz * 0.012))),
        draw: (x, w, h) => { x.fillStyle = css('SIGN_STREET_GREEN'); x.fillRect(0, 0, w, h); x.strokeStyle = css('MARKING_WHITE'); x.lineWidth = 3; x.strokeRect(4, 4, w - 8, h - 8); fitText(x, name, w * 0.9, h * 0.8, 'condensed', css('MARKING_WHITE'), { weight: '600' }); } });
    }
  }
  return A.build(`signage:${tile}`);
}

function graffiti(x: CanvasRenderingContext2D, w: number, h: number, tag: string, rng: Rng) {
  const col = rng.pick(['NEON_PINK', 'NEON_BLUE', 'MARKING_YELLOW', 'EARL_BLUE', 'BIKE_LANE_GREEN'] as PaletteKey[]);
  x.save(); x.translate(w / 2, h / 2); x.rotate((rng.next() - 0.5) * 0.2); x.translate(-w / 2, -h / 2);
  fitText(x, tag, w, h * 0.8, 'script', css(col), { stroke: css('SHADOW_INK'), weight: '400' });
  x.strokeStyle = css(col); x.lineWidth = 3;
  for (let i = 0; i < 9; i++) { const dx = w * (0.15 + rng.next() * 0.7); x.beginPath(); x.moveTo(dx, h * 0.7); x.lineTo(dx, h * (0.75 + rng.next() * 0.25)); x.stroke(); } // drips
  x.restore();
}

function mural(x: CanvasRenderingContext2D, w: number, h: number, rng: Rng) {
  const g = x.createLinearGradient(0, 0, w, h);
  g.addColorStop(0, css('HEAVEN_BLUE')); g.addColorStop(1, css('ONSU_NAVY'));
  x.fillStyle = g; x.fillRect(0, 0, w, h);
  for (let i = 0; i < 14; i++) { x.fillStyle = cssA(rng.pick(['MARKING_YELLOW', 'ONSU_WHITE', 'NEON_PINK'] as PaletteKey[]), 0.25); x.beginPath(); x.arc(rng.next() * w, rng.next() * h, 20 + rng.next() * 60, 0, Math.PI * 2); x.fill(); }
  drawBillram(x, w * 0.3, h * 0.48, h * 0.9);
  x.save(); x.translate(w * 0.55, h * 0.1);
  fitText(x, 'GO PITCH SOLES', w * 0.43, h * 0.3, 'poster', css('ONSU_WHITE'), { stroke: css('ONSU_NAVY') });
  x.translate(0, h * 0.35); fitText(x, 'RAM IT HOME', w * 0.43, h * 0.25, 'script', css('MARKING_YELLOW'), { weight: '400' });
  x.restore();
}

function stadiumLettering(A: Atlas, s: Sited) {
  // end zones: "ONSU" (west) / "BILLRAM" (east) in ONSU_NAVY on HEAVEN_BLUE, reading toward the field
  const sp = s.spec, CX = sp.w / 2, CZ = sp.d / 2, fx = 5486;
  for (const [name, x0, x1] of [['ONSU', CX - fx + 120, CX - fx + 800], ['BILLRAM', CX + fx - 800, CX + fx - 120]] as const) {
    const P = (lx: number, lz: number) => { const [wx, wz] = localToWorld(sp, lx / 100, lz / 100); return new Vector3(wx, sp.y + 0.009, wz); };
    A.add({ w: 1000, h: 280, neon: false, quad: [P(x0, CZ + 2000), P(x0, CZ - 2000), P(x1, CZ - 2000), P(x1, CZ + 2000)], draw: (x, w, h) => fitText(x, name, w, h, 'poster', css('ONSU_NAVY'), { stroke: css('ONSU_WHITE') }) });
  }
}

function courtLogo(A: Atlas, s: Sited) {
  const sp = s.spec, c = sp.w / 2;
  const P = (lx: number, lz: number) => { const [wx, wz] = localToWorld(sp, lx / 100, lz / 100); return new Vector3(wx, sp.y + 0.02, wz); };
  A.add({ w: 512, h: 512, neon: false, quad: [P(c - 110, c + 110), P(c + 110, c + 110), P(c + 110, c - 110), P(c - 110, c - 110)], draw: (x, w, h) => { drawBillram(x, w / 2, h / 2, w * 0.8); } });
}

/** Poster columns at The Summit and the Quarry (flyers pasted all round). */
export function posterColumns(tile: string): Group | null {
  const spots: [number, number][] = [[14, -14.5], [-14, 14.5], [75, 455], [120, -14.5], [-120, 14.5]];
  const A = new Atlas();
  const g = new GeoBuilder();
  const rng = new Rng(`posters:${tile}`);
  for (const [x, z] of spots) {
    if (tileNameAt(x, z) !== tile) continue;
    const y = 0.13;
    g.push(); g.translate(x, y, z);
    g.cylinder('satin:SHUTTER_GREEN', 0.42, 0, 2.6, 16, true);
    g.lathe('satin:SHUTTER_GREEN', [[0.5, 2.6], [0.5, 2.75], [0.3, 2.9], [0.05, 3.1]], 16);
    g.cylinder('satin:SHUTTER_GREEN', 0.48, 0, 0.3, 16, true);
    g.pop();
    for (let i = 0; i < 8; i++) {
      const a = (i / 8) * Math.PI * 2, ca = Math.cos(a), sa = Math.sin(a), r = 0.43;
      const p = poster(rng);
      const yy = y + 0.6 + (i % 2) * 0.75;
      const t = new Vector3(-sa, 0, ca).multiplyScalar(0.22);
      const c0 = new Vector3(x + ca * r, yy, z + sa * r);
      A.add({ w: 220, h: 300, neon: false, quad: [c0.clone().sub(t), c0.clone().add(t), c0.clone().add(t).setY(yy + 0.6), c0.clone().sub(t).setY(yy + 0.6)], draw: (xx, w, h) => drawPoster(xx, w, h, p) });
    }
  }
  const grp = A.build(`posters:${tile}`);
  if (g.isEmpty()) return grp;
  const out = new Group();
  if (grp) out.add(grp);
  out.add(g.toGroup(mat, 'poster-columns'));
  return out;
}
export function drawPoster(x: CanvasRenderingContext2D, w: number, h: number, p: ReturnType<typeof poster>) {
  const bg: PaletteKey = p.kind === 'earl' ? 'HEAVEN_BLUE' : p.kind === 'lostcat' ? 'ONSU_WHITE' : p.kind === 'election' ? 'MARKING_YELLOW' : p.kind === 'concert' ? 'NEON_PINK' : 'SIGN_CREAM';
  x.fillStyle = css(bg); x.fillRect(0, 0, w, h);
  fitText(x, p.title, w, h * 0.22, 'poster', css(p.kind === 'earl' ? 'ONSU_NAVY' : 'DOOR_BLACK'));
  if (p.kind === 'lostcat') { x.fillStyle = css('FIELDSTONE_B'); x.beginPath(); x.ellipse(w / 2, h * 0.42, w * 0.22, h * 0.13, 0, 0, Math.PI * 2); x.fill(); }
  if (p.kind === 'earl') drawBillram(x, w / 2, h * 0.45, h * 0.3);
  p.lines.forEach((l, i) => { x.save(); x.translate(0, h * (0.62 + i * 0.11)); fitText(x, l, w * 0.94, h * 0.1, 'slab', css('DOOR_BLACK'), { weight: '500' }); x.restore(); });
}
