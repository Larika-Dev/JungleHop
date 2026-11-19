// Procedural textures generated on canvas (CLAUDE.md §3). Every texture tile is authored in real
// centimeters and mapped to planar UV meters (see geo.ts), so a brick is 19.4 x 5.7 cm on screen.
// Optional override: /public/textures/<name>_albedo.(png|jpg) replaces the generated albedo when present.
import { CanvasTexture, Color, LinearSRGBColorSpace, RepeatWrapping, SRGBColorSpace, Texture, TextureLoader } from 'three';
import { jitter, mixKeys, pc, type PaletteKey } from './palette';
import { Rng } from './rng';

export interface TexSet {
  map: Texture;
  normalMap?: Texture;
  roughnessMap?: Texture;
  /** World size (meters) of one texture tile. */
  sizeM: [number, number];
}

type Ctx = CanvasRenderingContext2D;

function canvas(w: number, h: number): HTMLCanvasElement {
  const c = document.createElement('canvas');
  c.width = w; c.height = h;
  return c;
}
const hex = (c: Color) => '#' + c.getHexString();
const keyHex = (k: PaletteKey) => hex(pc(k).clone().convertLinearToSRGB());
// Colors from palette are stored linear in three (ColorManagement); canvas needs sRGB strings.
function srgb(c: Color): string { return hex(c.clone().convertLinearToSRGB()); }

/** Build a texture set from albedo + height painters. pxPerM sets resolution. */
function make(name: string, sizeM: [number, number], pxPerM: number,
  paint: (a: Ctx, h: Ctx, r: Ctx | null, W: number, H: number, s: number) => void,
  opts: { normalStrength?: number; rough?: boolean } = {}): TexSet {
  const W = Math.min(2048, Math.round(sizeM[0] * pxPerM)), H = Math.min(2048, Math.round(sizeM[1] * pxPerM));
  const s = W / sizeM[0]; // px per meter
  const ca = canvas(W, H), ch = canvas(W, H);
  const a = ca.getContext('2d')!, h = ch.getContext('2d')!;
  h.fillStyle = gray(0.5); h.fillRect(0, 0, W, H);
  let cr: HTMLCanvasElement | null = null, r: Ctx | null = null;
  if (opts.rough) { cr = canvas(W, H); r = cr.getContext('2d')!; r.fillStyle = gray(0.82); r.fillRect(0, 0, W, H); }
  paint(a, h, r, W, H, s);
  const map = tex(ca, true);
  const set: TexSet = { map, normalMap: tex(heightToNormal(ch, opts.normalStrength ?? 2), false), sizeM };
  if (cr) set.roughnessMap = tex(cr, false);
  tryOverride(name, set);
  return set;
}

function tex(c: HTMLCanvasElement, color: boolean): Texture {
  const t = new CanvasTexture(c);
  t.wrapS = t.wrapT = RepeatWrapping;
  t.colorSpace = color ? SRGBColorSpace : LinearSRGBColorSpace;
  t.anisotropy = 8;
  t.generateMipmaps = true;
  return t;
}

const loader = typeof document !== 'undefined' ? new TextureLoader() : null;
const overrideCache = new Map<string, boolean>();
/** Optional texture pack override (CLAUDE.md §3). Silent if the file is absent. */
function tryOverride(name: string, set: TexSet) {
  if (!loader || overrideCache.has(name)) return;
  overrideCache.set(name, true);
  const url = `${import.meta.env?.BASE_URL ?? '/'}textures/${name}_albedo.jpg`;
  fetch(url, { method: 'HEAD' }).then((res) => {
    if (!res.ok || !(res.headers.get('content-type') ?? '').startsWith('image')) return;
    loader.load(url, (t) => {
      t.wrapS = t.wrapT = RepeatWrapping; t.colorSpace = SRGBColorSpace;
      set.map.image = t.image; set.map.needsUpdate = true;
    });
  }).catch(() => {});
}

/** Sobel height -> tangent-space normal map. Height: mid-gray = surface, darker = recessed. */
function heightToNormal(src: HTMLCanvasElement, strength: number): HTMLCanvasElement {
  const W = src.width, H = src.height;
  const d = src.getContext('2d')!.getImageData(0, 0, W, H).data;
  const out = canvas(W, H);
  const octx = out.getContext('2d')!;
  const img = octx.createImageData(W, H);
  const o = img.data;
  const hgt = (x: number, y: number) => d[(((y + H) % H) * W + ((x + W) % W)) * 4] / 255;
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    const dx = (hgt(x + 1, y) - hgt(x - 1, y)) * strength;
    const dy = (hgt(x, y + 1) - hgt(x, y - 1)) * strength;
    let nx = -dx, ny = dy, nz = 1;
    const l = Math.hypot(nx, ny, nz); nx /= l; ny /= l; nz /= l;
    const i = (y * W + x) * 4;
    o[i] = (nx * 0.5 + 0.5) * 255; o[i + 1] = (ny * 0.5 + 0.5) * 255; o[i + 2] = (nz * 0.5 + 0.5) * 255; o[i + 3] = 255;
  }
  octx.putImageData(img, 0, 0);
  return out;
}

function speckle(ctx: Ctx, W: number, H: number, rng: Rng, n: number, colors: string[], size: [number, number], alpha = 0.25) {
  ctx.globalAlpha = alpha;
  for (let i = 0; i < n; i++) {
    ctx.fillStyle = colors[i % colors.length];
    const s = size[0] + rng.next() * (size[1] - size[0]);
    ctx.fillRect(rng.next() * W, rng.next() * H, s, s);
  }
  ctx.globalAlpha = 1;
}
function gray(v: number) { const g = Math.max(0, Math.min(255, Math.round(v * 255))); return `rgb(${g},${g},${g})`; }

// ------------------------------------------------------------------------------------------ BRICK
export type Bond = 'flemish' | 'running' | 'common' | 'stack' | 'soldier';
export const BRICK = { L: 0.194, H: 0.057, D: 0.092, J: 0.01 } as const; // US modular + 1 cm joint
export const COURSE = BRICK.H + BRICK.J; // 6.7 cm

/** Brick layout in a bond, in meters: returns rects [x, y, w, h, isHeader] covering [0,W)x[0,H). */
export function bondLayout(bond: Bond, W: number, H: number, x0 = 0): [number, number, number, number, boolean][] {
  const out: [number, number, number, number, boolean][] = [];
  const S = BRICK.L + BRICK.J, Hd = BRICK.D + BRICK.J;
  const courses = Math.ceil(H / COURSE) + 1;
  for (let c = 0; c < courses; c++) {
    const y = c * COURSE;
    let pattern: { w: number; header: boolean }[];
    let offset: number;
    if (bond === 'flemish') { pattern = [{ w: S, header: false }, { w: Hd, header: true }]; offset = c % 2 ? (S + Hd) / 2 : 0; }
    else if (bond === 'common' && c % 6 === 5) { pattern = [{ w: Hd, header: true }]; offset = c % 12 === 11 ? Hd / 2 : 0; }
    else if (bond === 'stack') { pattern = [{ w: S, header: false }]; offset = 0; }
    else { pattern = [{ w: S, header: false }]; offset = c % 2 ? S / 2 : 0; }
    const unit = pattern.reduce((s, p) => s + p.w, 0);
    let x = -unit * 2 - offset + (x0 % unit);
    let k = 0;
    while (x < W) {
      const p = pattern[k % pattern.length];
      out.push([x, y, p.w - BRICK.J, BRICK.H, p.header]);
      x += p.w; k++;
    }
  }
  return out;
}
/** Repeat size (m) of a bond so textures tile seamlessly. */
export function bondRepeat(bond: Bond): [number, number] {
  const S = BRICK.L + BRICK.J, Hd = BRICK.D + BRICK.J;
  if (bond === 'flemish') return [(S + Hd) * 3, COURSE * 12];
  if (bond === 'common') return [S * 4, COURSE * 12];
  return [S * 4, COURSE * 12];
}

export function brickTex(bond: Bond, base: PaletteKey, mortar: PaletteKey, opts: { header?: PaletteKey; raked?: boolean; painted?: boolean; seed?: string } = {}): TexSet {
  const size = bondRepeat(bond);
  const name = `brick_${bond}_${base}`;
  return make(name, size, 640, (a, h, r, W, Hh, s) => {
    const rng = new Rng(opts.seed ?? name);
    a.fillStyle = keyHex(mortar); a.fillRect(0, 0, W, Hh);
    speckle(a, W, Hh, rng, 4000, [keyHex(mortar), srgb(pc(mortar).clone().multiplyScalar(0.8))], [1, 2], 0.5);
    // mortar recess: campus concave 0.4 cm, downtown raked 0.6 cm -> darker height
    h.fillStyle = gray(opts.raked ? 0.2 : 0.3); h.fillRect(0, 0, W, Hh);
    const bricks = bondLayout(bond, size[0], size[1]);
    const tmp = new Color();
    for (const [x, y, w, hh, header] of bricks) {
      const key = header && opts.header ? opts.header : base;
      jitter(key, rng.next(), rng.next(), 0.06, 3, tmp);
      const px = x * s, py = Hh - (y + hh) * s, pw = w * s, ph = hh * s;
      for (const ox of [-W, 0, W]) for (const oy of [-Hh, 0, Hh]) {
        a.fillStyle = srgb(tmp); a.fillRect(px + ox, py + oy, pw, ph);
        // face texture: sand speckle and firing streaks
        h.fillStyle = gray(0.62 + rng.next() * 0.06); h.fillRect(px + ox, py + oy, pw, ph);
        if (r) { r.fillStyle = gray(header && opts.header ? 0.45 : 0.78 + rng.next() * 0.14); r.fillRect(px + ox, py + oy, pw, ph); }
      }
      // chipped corners on 12% of bricks (0.2-0.8 cm)
      if (rng.chance(0.12)) {
        const cs = (0.002 + rng.next() * 0.006) * s;
        const cx = rng.chance(0.5) ? px : px + pw - cs, cy = rng.chance(0.5) ? py : py + ph - cs;
        a.fillStyle = keyHex(mortar); a.globalAlpha = 0.6; a.fillRect(cx, cy, cs, cs); a.globalAlpha = 1;
        h.fillStyle = gray(0.4); h.fillRect(cx, cy, cs, cs);
      }
    }
    speckle(a, W, Hh, rng, 9000, [gray(0), gray(1)], [1, 2], 0.05);
    if (opts.painted) {
      // painted brick with peeling patches revealing BRICK_DOWNTOWN_A
      a.globalAlpha = 0.92; a.fillStyle = keyHex('BRICK_PAINTED_WHITE'); a.fillRect(0, 0, W, Hh); a.globalAlpha = 1;
      for (let i = 0; i < 18; i++) {
        a.fillStyle = keyHex('BRICK_DOWNTOWN_A');
        a.beginPath();
        const cx = rng.next() * W, cy = rng.next() * Hh;
        for (let k = 0; k < 8; k++) { const ang = (k / 8) * Math.PI * 2, rr = (6 + rng.next() * 18); a.lineTo(cx + Math.cos(ang) * rr, cy + Math.sin(ang) * rr * 0.6); }
        a.fill();
      }
    }
    // efflorescence bloom, max 15% opacity
    const g = a.createLinearGradient(0, Hh, 0, Hh * 0.6);
    g.addColorStop(0, keyHex('EFFLORESCENCE')); g.addColorStop(1, 'rgba(0,0,0,0)');
    a.globalAlpha = 0.08; a.fillStyle = g; a.fillRect(0, 0, W, Hh); a.globalAlpha = 1;
  }, { normalStrength: 3, rough: true });
}

// ------------------------------------------------------------------------------------------ PAVERS
export function paverTex(pattern: 'herringbone' | 'running'): TexSet {
  // pavers 10 x 20 cm, 0.3 cm sand joints
  const U = 0.103; // module incl. joint
  const size: [number, number] = pattern === 'herringbone' ? [U * 8, U * 8] : [U * 2 * 4, U * 8];
  return make(`pavers_${pattern}`, size, 600, (a, h, _r, W, H, s) => {
    const rng = new Rng(`pavers_${pattern}`);
    a.fillStyle = keyHex('GRAVEL'); a.fillRect(0, 0, W, H);
    h.fillStyle = gray(0.25); h.fillRect(0, 0, W, H);
    const tmp = new Color();
    const draw = (x: number, y: number, w: number, hh: number) => {
      jitter(rng.chance(0.5) ? 'BRICK_PAVER_A' : 'BRICK_PAVER_B', rng.next(), rng.next(), 0.06, 3, tmp);
      for (const ox of [-W, 0, W]) for (const oy of [-H, 0, H]) {
        a.fillStyle = srgb(tmp); a.fillRect((x) * s + ox, (y) * s + oy, w * s, hh * s);
        h.fillStyle = gray(0.6 + rng.next() * 0.08); h.fillRect(x * s + ox, y * s + oy, w * s, hh * s);
      }
    };
    const j = 0.003;
    if (pattern === 'running') {
      for (let r = 0; r < 8; r++) for (let c = -1; c < 5; c++) draw(c * 2 * U + (r % 2 ? U : 0), r * U, 2 * U - j, U - j);
    } else {
      // 45-degree-free herringbone (90-degree): stair-stepped L pairs
      for (let k = -8; k < 16; k++) for (let m = -8; m < 16; m++) {
        const bx = (k + m) * U, by = (m - k) * U;
        draw(bx, by, 2 * U - j, U - j);
        draw(bx + U, by + U, U - j, 2 * U - j);
      }
    }
    speckle(a, W, H, rng, 6000, [gray(0), gray(1)], [1, 2], 0.06);
  }, { normalStrength: 3 });
}

// ------------------------------------------------------------------------------------------ STONE
export function fieldstoneTex(): TexSet {
  return make('fieldstone', [1.2, 1.2], 500, (a, h, _r, W, H, s) => {
    const rng = new Rng('fieldstone');
    a.fillStyle = keyHex('MORTAR_HISTORIC'); a.fillRect(0, 0, W, H);
    h.fillStyle = gray(0.15); h.fillRect(0, 0, W, H);
    const keys: PaletteKey[] = ['FIELDSTONE_A', 'FIELDSTONE_B', 'FIELDSTONE_C', 'FIELDSTONE_D'];
    const tmp = new Color();
    // rough coursed rubble: rows of irregular stones 15-60 cm
    let y = 0;
    while (y < 1.2) {
      const rh = 0.12 + rng.next() * 0.2;
      let x = -rng.next() * 0.3;
      while (x < 1.2) {
        const w = 0.15 + rng.next() * 0.45;
        jitter(rng.pick(keys), rng.next(), rng.next(), 0.08, 4, tmp);
        for (const ox of [-W, 0, W]) for (const oy of [-H, 0, H]) {
          a.fillStyle = srgb(tmp);
          h.fillStyle = gray(0.55 + rng.next() * 0.2);
          a.beginPath(); h.beginPath();
          const cx = (x + w / 2) * s + ox, cy = (y + rh / 2) * s + oy;
          for (let k = 0; k < 9; k++) {
            const ang = (k / 9) * Math.PI * 2;
            const px = cx + Math.cos(ang) * (w / 2 - 0.015) * s * (0.85 + rng.next() * 0.15);
            const py = cy + Math.sin(ang) * (rh / 2 - 0.015) * s * (0.85 + rng.next() * 0.15);
            a.lineTo(px, py); h.lineTo(px, py);
          }
          a.fill(); h.fill();
        }
        x += w;
      }
      y += rh;
    }
    speckle(a, W, H, rng, 1400, [keyHex('LICHEN'), keyHex('MOSS')], [2, 6], 0.25);
  }, { normalStrength: 4 });
}

// ------------------------------------------------------------------------------------------ GENERIC NOISE SURFACES
function noiseSurface(name: string, sizeM: [number, number], pxPerM: number, base: PaletteKey, specks: PaletteKey[], density: number, opts: { joints?: number; jointKey?: PaletteKey; crack?: boolean; streak?: boolean } = {}): TexSet {
  return make(name, sizeM, pxPerM, (a, h, _r, W, H, s) => {
    const rng = new Rng(name);
    a.fillStyle = keyHex(base); a.fillRect(0, 0, W, H);
    speckle(a, W, H, rng, density, specks.map(keyHex), [1, 3], 0.35);
    speckle(h, W, H, rng, density, [gray(0.38), gray(0.63)], [1, 3], 0.5);
    // large-scale mottling
    for (let i = 0; i < 40; i++) {
      const g = a.createRadialGradient(rng.next() * W, rng.next() * H, 0, rng.next() * W, rng.next() * H, (0.2 + rng.next()) * W * 0.3);
      g.addColorStop(0, rng.chance(0.5) ? 'rgba(0,0,0,0.05)' : 'rgba(255,255,255,0.04)'); g.addColorStop(1, 'rgba(0,0,0,0)');
      a.fillStyle = g; a.fillRect(0, 0, W, H);
    }
    if (opts.joints) {
      const j = opts.joints * s;
      a.strokeStyle = keyHex(opts.jointKey ?? 'ASPHALT_PATCH'); a.lineWidth = Math.max(1, 0.008 * s);
      h.strokeStyle = gray(0.2); h.lineWidth = Math.max(1, 0.008 * s);
      for (let x = 0; x <= W; x += j) { a.beginPath(); a.moveTo(x, 0); a.lineTo(x, H); a.stroke(); h.beginPath(); h.moveTo(x, 0); h.lineTo(x, H); h.stroke(); }
      for (let y = 0; y <= H; y += j) { a.beginPath(); a.moveTo(0, y); a.lineTo(W, y); a.stroke(); h.beginPath(); h.moveTo(0, y); h.lineTo(W, y); h.stroke(); }
    }
    if (opts.crack) {
      a.strokeStyle = keyHex('ASPHALT_PATCH'); a.lineWidth = 3; a.globalAlpha = 0.7;
      for (let i = 0; i < 4; i++) {
        a.beginPath(); let x = rng.next() * W, y = rng.next() * H; a.moveTo(x, y);
        for (let k = 0; k < 12; k++) { x += (rng.next() - 0.5) * 60; y += (rng.next() - 0.3) * 50; a.lineTo(x, y); }
        a.stroke();
      }
      a.globalAlpha = 1;
    }
    if (opts.streak) {
      for (let i = 0; i < 30; i++) { a.fillStyle = 'rgba(0,0,0,0.04)'; a.fillRect(rng.next() * W, 0, 2 + rng.next() * 6, H); }
    }
  });
}

function boardTex(name: string, sizeM: [number, number], boardW: number, keys: PaletteKey[], opts: { vertical?: boolean; seam?: number; grain?: boolean; endJoints?: boolean } = {}): TexSet {
  return make(name, sizeM, 500, (a, h, _r, W, H, s) => {
    const rng = new Rng(name);
    const tmp = new Color();
    const rows = Math.round(sizeM[1] / boardW);
    for (let i = 0; i < rows; i++) {
      const y0 = i * boardW * s, bh = boardW * s;
      let x = -rng.next() * W * 0.5;
      while (x < W) {
        const len = opts.endJoints ? (0.6 + rng.next() * 1.2) * s : W * 2;
        jitter(rng.pick(keys), rng.next(), rng.next(), 0.07, 3, tmp);
        a.fillStyle = srgb(tmp); a.fillRect(x, y0, len, bh);
        if (opts.grain) {
          a.globalAlpha = 0.12;
          for (let g = 0; g < 6; g++) { a.fillStyle = rng.chance(0.5) ? gray(0) : gray(1); a.fillRect(x, y0 + rng.next() * bh, len, 1 + rng.next() * 2); }
          a.globalAlpha = 1;
        }
        h.fillStyle = gray(0.6 + rng.next() * 0.04); h.fillRect(x, y0, len, bh);
        h.fillStyle = gray(0.35); h.fillRect(x, y0, Math.max(1, (opts.seam ?? 0.002) * s), bh);
        x += len;
      }
      h.fillStyle = gray(0.3); h.fillRect(0, y0, W, Math.max(1, (opts.seam ?? 0.002) * s));
      a.fillStyle = 'rgba(0,0,0,0.25)'; a.fillRect(0, y0, W, Math.max(1, (opts.seam ?? 0.002) * s));
    }
  }, { normalStrength: 2 });
}

function gridTileTex(name: string, sizeM: [number, number], tile: [number, number], keys: PaletteKey[], grout: PaletteKey, groutW: number, opts: { running?: boolean; checker?: boolean; hex?: boolean; relief?: boolean } = {}): TexSet {
  return make(name, sizeM, 700, (a, h, _r, W, H, s) => {
    const rng = new Rng(name);
    a.fillStyle = keyHex(grout); a.fillRect(0, 0, W, H);
    h.fillStyle = gray(0.3); h.fillRect(0, 0, W, H);
    const tmp = new Color();
    if (opts.hex) {
      const r = tile[0] / 2, hgt = Math.sqrt(3) * r;
      for (let row = -1; row < sizeM[1] / hgt + 1; row++) for (let col = -1; col < sizeM[0] / (r * 1.5) + 1; col++) {
        const cx = col * r * 1.5, cy = row * hgt + (col % 2 ? hgt / 2 : 0);
        jitter(keys[0], rng.next(), rng.next(), 0.02, 1, tmp);
        a.fillStyle = srgb(tmp); h.fillStyle = gray(0.62);
        a.beginPath(); h.beginPath();
        for (let k = 0; k < 6; k++) { const ang = (k / 6) * Math.PI * 2; const px = (cx + Math.cos(ang) * (r - groutW)) * s, py = (cy + Math.sin(ang) * (r - groutW)) * s; a.lineTo(px, py); h.lineTo(px, py); }
        a.fill(); h.fill();
      }
      return;
    }
    const nx = Math.round(sizeM[0] / tile[0]), ny = Math.round(sizeM[1] / tile[1]);
    for (let j = 0; j < ny; j++) for (let i = -1; i < nx + 1; i++) {
      const off = opts.running && j % 2 ? tile[0] / 2 : 0;
      const k = opts.checker ? keys[(i + j) % 2 === 0 ? 0 : 1] : rng.pick(keys);
      jitter(k, rng.next(), rng.next(), 0.03, 1, tmp);
      a.fillStyle = srgb(tmp);
      const x = (i * tile[0] + off + groutW / 2) * s, y = (j * tile[1] + groutW / 2) * s;
      a.fillRect(x, y, (tile[0] - groutW) * s, (tile[1] - groutW) * s);
      h.fillStyle = gray(opts.relief ? 0.7 : 0.62); h.fillRect(x, y, (tile[0] - groutW) * s, (tile[1] - groutW) * s);
      if (opts.relief) {
        // pressed-tin: raised concentric squares, 0.6 cm relief
        h.strokeStyle = gray(0.9); h.lineWidth = 0.01 * s;
        for (let q = 1; q < 4; q++) { const inset = q * tile[0] * 0.12 * s; h.strokeRect(x + inset, y + inset, (tile[0] - groutW) * s - inset * 2, (tile[1] - groutW) * s - inset * 2); }
        h.beginPath(); h.arc(x + (tile[0] / 2) * s, y + (tile[1] / 2) * s, tile[0] * 0.08 * s, 0, Math.PI * 2); h.fillStyle = gray(0.95); h.fill();
      }
    }
    speckle(a, W, H, rng, 2000, [gray(0), gray(1)], [1, 2], 0.04);
  }, { normalStrength: opts.relief ? 4 : 2 });
}

function terrazzoTex(): TexSet {
  return make('terrazzo', [1, 1], 600, (a, h, _r, W, H) => {
    const rng = new Rng('terrazzo');
    a.fillStyle = keyHex('TERRAZZO'); a.fillRect(0, 0, W, H);
    const fl: PaletteKey[] = ['TERRAZZO_FLECK_A', 'TERRAZZO_FLECK_B', 'TERRAZZO_FLECK_C'];
    for (let i = 0; i < 9000; i++) {
      a.fillStyle = keyHex(fl[i % 3]);
      a.beginPath(); a.arc(rng.next() * W, rng.next() * H, 0.8 + rng.next() * 3, 0, Math.PI * 2); a.fill();
    }
    // brass divider strips every 1 m (tile edge)
    a.fillStyle = keyHex('BRASS'); a.fillRect(0, 0, W, 2); a.fillRect(0, 0, 2, H);
    h.fillStyle = gray(0.5); h.fillRect(0, 0, W, 1);
  }, { normalStrength: 0.5 });
}

function marbleTex(): TexSet {
  return make('marble', [1.2, 1.2], 500, (a, _h, _r, W, H) => {
    const rng = new Rng('marble');
    a.fillStyle = keyHex('MARBLE_WHITE'); a.fillRect(0, 0, W, H);
    a.strokeStyle = keyHex('FIELDSTONE_C'); a.globalAlpha = 0.25;
    for (let i = 0; i < 14; i++) {
      a.lineWidth = 0.5 + rng.next() * 2;
      a.beginPath(); let x = rng.next() * W, y = 0; a.moveTo(x, y);
      while (y < H) { x += (rng.next() - 0.5) * 40; y += 10 + rng.next() * 20; a.lineTo(x, y); }
      a.stroke();
    }
    a.globalAlpha = 1;
    // 60 cm slab joints
    a.fillStyle = keyHex('LIMESTONE_TRIM');
    for (let k = 0; k <= 2; k++) { a.fillRect((k * W) / 2, 0, 1, H); a.fillRect(0, (k * H) / 2, W, 1); }
  });
}

function roofTileTex(name: string, keys: PaletteKey[], unitW: number, exposure: number, sizeM: [number, number]): TexSet {
  return make(name, sizeM, 400, (a, h, _r, W, H, s) => {
    const rng = new Rng(name);
    const tmp = new Color();
    const rows = Math.round(sizeM[1] / exposure);
    for (let r = 0; r < rows; r++) {
      const off = r % 2 ? unitW / 2 : 0;
      for (let c = -1; c < sizeM[0] / unitW + 1; c++) {
        jitter(rng.pick(keys), rng.next(), rng.next(), 0.08, 2, tmp);
        const x = (c * unitW + off) * s, y = H - (r + 1) * exposure * s;
        a.fillStyle = srgb(tmp); a.fillRect(x + 1, y, unitW * s - 2, exposure * s);
        const g = h.createLinearGradient(0, y, 0, y + exposure * s);
        g.addColorStop(0, gray(0.4)); g.addColorStop(1, gray(0.75));
        h.fillStyle = g; h.fillRect(x + 1, y, unitW * s - 2, exposure * s);
        a.fillStyle = 'rgba(0,0,0,0.35)'; a.fillRect(x, y + exposure * s - 2, unitW * s, 2);
      }
    }
  }, { normalStrength: 3 });
}

function seamTex(key: PaletteKey, pitch: number): TexSet {
  return make(`seam_${key}`, [pitch * 2, 1], 400, (a, h, _r, W, H, s) => {
    a.fillStyle = keyHex(key); a.fillRect(0, 0, W, H);
    for (const x of [0, pitch * s]) {
      a.fillStyle = 'rgba(255,255,255,0.2)'; a.fillRect(x, 0, 0.02 * s, H);
      h.fillStyle = gray(0.95); h.fillRect(x, 0, 0.025 * s, H);
    }
  }, { normalStrength: 6 });
}

function grassTex(base: PaletteKey, alt: PaletteKey): TexSet {
  return make(`grass_${base}`, [3, 3], 220, (a, h, _r, W, H) => {
    const rng = new Rng(`grass_${base}`);
    a.fillStyle = keyHex(base); a.fillRect(0, 0, W, H);
    speckle(a, W, H, rng, 30000, [keyHex(alt), srgb(pc(base).clone().multiplyScalar(0.7)), srgb(pc(base).clone().multiplyScalar(1.2))], [1, 3], 0.45);
    speckle(a, W, H, rng, 600, [keyHex('FALLEN_LEAF_A'), keyHex('FALLEN_LEAF_B'), keyHex('FALLEN_LEAF_C')], [2, 4], 0.6);
    speckle(h, W, H, rng, 20000, [gray(0.44), gray(0.63)], [1, 2], 0.6);
  }, { normalStrength: 1.5 });
}

function soilTex(name: string, base: PaletteKey, specks: PaletteKey[]): TexSet {
  return make(name, [2, 2], 256, (a, h, _r, W, H) => {
    const rng = new Rng(name);
    a.fillStyle = keyHex(base); a.fillRect(0, 0, W, H);
    speckle(a, W, H, rng, 12000, specks.map(keyHex), [1, 4], 0.4);
    speckle(h, W, H, rng, 9000, [gray(0.38), gray(0.66)], [1, 4], 0.6);
  }, { normalStrength: 2.5 });
}

function pineStrawTex(): TexSet {
  return make('pinestraw', [1, 1], 400, (a, h, _r, W, H) => {
    const rng = new Rng('pinestraw');
    a.fillStyle = keyHex('PINE_BARK'); a.fillRect(0, 0, W, H);
    for (let i = 0; i < 4000; i++) {
      a.strokeStyle = srgb(jitter('PINE_STRAW', rng.next(), rng.next(), 0.15, 5));
      a.lineWidth = 1 + rng.next();
      const x = rng.next() * W, y = rng.next() * H, ang = rng.next() * Math.PI, l = 20 + rng.next() * 50;
      a.beginPath(); a.moveTo(x, y); a.lineTo(x + Math.cos(ang) * l, y + Math.sin(ang) * l); a.stroke();
      h.strokeStyle = gray(0.7); h.beginPath(); h.moveTo(x, y); h.lineTo(x + Math.cos(ang) * l, y + Math.sin(ang) * l); h.stroke();
    }
  });
}

function boardformTex(): TexSet {
  // CLAUDE.md §10.4: boards 15 cm wide, 1 cm seams, wood-grain relief 0.2 cm
  return make('boardform', [2.4, 1.2], 400, (a, h, _r, W, H, s) => {
    const rng = new Rng('boardform');
    a.fillStyle = keyHex('CONCRETE_BOARDFORM'); a.fillRect(0, 0, W, H);
    for (let r = 0; r < 8; r++) {
      const y = r * 0.15 * s;
      a.fillStyle = `rgba(0,0,0,${0.02 + rng.next() * 0.05})`; a.fillRect(0, y, W, 0.15 * s);
      for (let g = 0; g < 18; g++) {
        const gy = y + rng.next() * 0.14 * s;
        h.fillStyle = gray(0.5 + rng.next() * 0.15); h.fillRect(0, gy, W, 1 + rng.next() * 2);
        a.fillStyle = 'rgba(0,0,0,0.05)'; a.fillRect(0, gy, W, 1);
      }
      h.fillStyle = gray(0.3); h.fillRect(0, y, W, 0.01 * s);
      a.fillStyle = 'rgba(0,0,0,0.18)'; a.fillRect(0, y, W, 0.01 * s);
    }
    // form-tie holes
    for (let i = 0; i < 4; i++) for (let j = 0; j < 2; j++) {
      a.fillStyle = 'rgba(0,0,0,0.35)'; a.beginPath(); a.arc((0.3 + i * 0.6) * s, (0.3 + j * 0.6) * s, 0.012 * s, 0, Math.PI * 2); a.fill();
    }
  }, { normalStrength: 3 });
}

function cmuTex(): TexSet {
  // painted CMU coursing 20 x 40 cm visible (CLAUDE.md §7.5)
  return gridTileTex('cmu', [0.8, 0.8], [0.4, 0.2], ['PAINT_DORM_BLOCK'], 'PAINT_DORM_BLOCK', 0.01, { running: true });
}

function patinaTex(): TexSet {
  return make('patina', [2, 2], 256, (a, h, _r, W, H) => {
    const rng = new Rng('patina');
    a.fillStyle = keyHex('COPPER_PATINA'); a.fillRect(0, 0, W, H);
    speckle(a, W, H, rng, 6000, [keyHex('COPPER_NEW'), srgb(mixKeys('COPPER_PATINA', 'TRIM_WHITE', 0.3))], [2, 6], 0.2);
    for (let x = 0; x < W; x += W / 6) { h.fillStyle = gray(0.9); h.fillRect(x, 0, 2, H); }
  }, { normalStrength: 3 });
}

// ------------------------------------------------------------------------------------------ registry
const cacheSets = new Map<string, TexSet>();
export function getTexSet(name: string): TexSet | null {
  if (typeof document === 'undefined') return null;
  let t = cacheSets.get(name);
  if (t) return t;
  t = buildNamed(name) ?? undefined;
  if (t) cacheSets.set(name, t);
  return t ?? null;
}

function buildNamed(name: string): TexSet | null {
  // brick:<bond>:<KEY>[:painted|raked]
  if (name.startsWith('brick:')) {
    const [, bond, key, flag] = name.split(':');
    const campus = key.startsWith('BRICK_CAMPUS');
    return brickTex(bond as Bond, key as PaletteKey, campus ? 'MORTAR_HISTORIC' : 'MORTAR_MODERN', {
      header: bond === 'flemish' ? 'BRICK_HEADER_GLAZED' : bond === 'common' ? (campus ? 'BRICK_CAMPUS_C' : 'BRICK_DOWNTOWN_C') : undefined,
      raked: !campus, painted: flag === 'painted',
    });
  }
  switch (name) {
    case 'pavers_herringbone': return paverTex('herringbone');
    case 'pavers_running': return paverTex('running');
    case 'fieldstone': return fieldstoneTex();
    case 'asphalt_aged': return noiseSurface(name, [4, 4], 160, 'ASPHALT_AGED', ['ASPHALT_FRESH', 'GRAVEL', 'CONCRETE_AGED'], 30000, { crack: true });
    case 'asphalt_fresh': return noiseSurface(name, [4, 4], 160, 'ASPHALT_FRESH', ['ASPHALT_AGED', 'GRAVEL'], 30000);
    case 'asphalt_patch': return noiseSurface(name, [4, 4], 160, 'ASPHALT_PATCH', ['ASPHALT_AGED', 'GRAVEL'], 20000, { crack: true });
    case 'concrete_new': return noiseSurface(name, [1.5, 1.5], 300, 'CONCRETE_NEW', ['CONCRETE_AGED', 'GRAVEL'], 9000, { joints: 1.5, jointKey: 'CONCRETE_AGED' });
    case 'concrete_aged': return noiseSurface(name, [1.5, 1.5], 300, 'CONCRETE_AGED', ['CONCRETE_NEW', 'ASPHALT_AGED', 'LICHEN'], 12000, { joints: 1.5 });
    case 'concrete_deck': return noiseSurface(name, [4, 4], 120, 'CONCRETE_NEW', ['CONCRETE_AGED', 'GRAVEL'], 12000, { streak: true });
    case 'sealed_concrete': return noiseSurface(name, [3, 3], 150, 'SEALED_CONCRETE', ['CONCRETE_AGED', 'CONCRETE_NEW'], 9000);
    case 'granite': return noiseSurface(name, [1, 1], 400, 'GRANITE_CURB', ['FIELDSTONE_B', 'TRIM_WHITE', 'IRON_BLACK'], 14000);
    case 'limestone': return noiseSurface(name, [1.2, 1.2], 350, 'LIMESTONE_TRIM', ['CAPSTONE', 'TRIM_WHITE'], 6000);
    case 'capstone': return noiseSurface(name, [1.2, 1.2], 350, 'CAPSTONE', ['FIELDSTONE_A', 'LICHEN'], 8000);
    case 'stucco': return noiseSurface(name, [1.5, 1.5], 300, 'STUCCO', ['TRIM_WHITE_AGED', 'CONCRETE_AGED'], 15000);
    case 'marble': return marbleTex();
    case 'boardform': return boardformTex();
    case 'slate': return roofTileTex(name, ['SLATE_A', 'SLATE_B'], 0.3, 0.2, [1.2, 1.2]);
    case 'shingle': return roofTileTex(name, ['ASPHALT_SHINGLE'], 0.33, 0.14, [1.32, 1.12]);
    case 'seam': return seamTex('STANDING_SEAM', 0.45);
    case 'tpo': return noiseSurface(name, [3, 3], 100, 'TPO_ROOF', ['CONCRETE_NEW'], 3000, { joints: 3, jointKey: 'CONCRETE_NEW' });
    case 'patina': return patinaTex();
    case 'grass': return grassTex('GRASS_OCT', 'GRASS_WORN');
    case 'grass_worn': return grassTex('GRASS_WORN', 'DIRT_PATH');
    case 'turf': return grassTex('FIELD_TURF', 'FIELD_TURF');
    case 'clay': return soilTex(name, 'RED_CLAY', ['DIRT_PATH', 'FIELDSTONE_D']);
    case 'dirt': return soilTex(name, 'DIRT_PATH', ['RED_CLAY', 'GRAVEL', 'FALLEN_LEAF_C']);
    case 'gravel': return soilTex(name, 'GRAVEL', ['FIELDSTONE_B', 'CONCRETE_NEW', 'FIELDSTONE_D']);
    case 'leaflitter': return soilTex(name, 'FALLEN_LEAF_A', ['FALLEN_LEAF_B', 'FALLEN_LEAF_C', 'GRASS_OCT']);
    case 'pinestraw': return pineStrawTex();
    case 'terrazzo': return terrazzoTex();
    case 'vct': return gridTileTex(name, [0.61, 0.61], [0.305, 0.305], ['VCT_A', 'VCT_B'], 'VCT_B', 0.001, { checker: true });
    case 'vct_plain': return gridTileTex(name, [0.61, 0.61], [0.305, 0.305], ['VCT_A'], 'VCT_B', 0.001);
    case 'acoustic': return gridTileTex(name, [1.22, 1.22], [0.61, 0.61], ['ACOUSTIC_TILE'], 'ACOUSTIC_GRID', 0.024);
    case 'subway': return gridTileTex(name, [0.6, 0.6], [0.15, 0.075], ['TILE_WHITE_SUBWAY'], 'SUBWAY_GROUT', 0.002, { running: true });
    case 'hextile': return gridTileTex(name, [0.3, 0.3], [0.025, 0.025], ['HEX_TILE_WHITE'], 'HEX_GROUT', 0.0015, { hex: true });
    case 'porcelain': return gridTileTex(name, [1.2, 1.2], [0.6, 0.6], ['PORCELAIN_MODERN'], 'HEX_GROUT', 0.003);
    case 'tin': return gridTileTex(name, [1.22, 1.22], [0.61, 0.61], ['CEILING_WHITE'], 'CEILING_WHITE', 0.004, { relief: true });
    case 'cmu': return cmuTex();
    case 'oak_floor': return boardTex(name, [1.2, 1.2], 0.076, ['OAK_FLOOR'], { grain: true, endJoints: true });
    case 'heart_pine': return boardTex(name, [1.2, 1.27], 0.127, ['HEART_PINE'], { grain: true, endJoints: true });
    case 'walnut': return boardTex(name, [1.2, 1.2], 0.2, ['WALNUT_DARK'], { grain: true });
    case 'maple_court': return boardTex(name, [1.2, 1.14], 0.057, ['SPORTS_MAPLE'], { grain: true, endJoints: true });
    case 'carpet_inn': return noiseSurface(name, [1, 1], 300, 'CARPET_INN', ['DOOR_RED', 'WALNUT_DARK'], 30000);
    case 'carpet_office': return noiseSurface(name, [1, 1], 300, 'CARPET_OFFICE', ['ALUMINUM_STOREFRONT', 'GALV_STEEL'], 30000);
    case 'rubber': return noiseSurface(name, [1, 1], 300, 'RUBBER_FLOOR', ['GALV_STEEL'], 6000);
    case 'sheet_vinyl': return noiseSurface(name, [2, 2], 150, 'SHEET_VINYL', ['VCT_A'], 6000);
    case 'bark_oak': return noiseSurface(name, [0.6, 1.2], 300, 'OAK_BARK', ['FIELDSTONE_B', 'LICHEN'], 9000, { streak: true });
    case 'bark_pine': return noiseSurface(name, [0.6, 1.2], 300, 'PINE_BARK', ['RED_CLAY', 'FIELDSTONE_B'], 9000, { streak: true });
  }
  return null;
}
