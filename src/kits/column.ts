// Column kit (CLAUDE.md §5/§6): Doric, Ionic (24 flutes), square pier, cast-iron storefront column.
// Pivot bottom-front-left of the plinth; shafts have entasis (upper diameter 0.83 D).
import { BufferAttribute, BufferGeometry } from 'three';
import type { GeoBuilder } from '../core/geo';
import { C, boxC, registerKit } from './common';

/** Fluted shaft: lower diameter D, height H (cm), `flutes` with optional fillets. Centered at (cx, cz). */
export function flutedShaft(g: GeoBuilder, key: string, D: number, H: number, flutes = 24, fillet = 0, y0 = 0, cx = 0, cz = 0) {
  const rings = 16, seg = flutes * 6;
  const R0 = C(D / 2), fd = C(D * 0.035);
  const pos: number[] = [], uv: number[] = [];
  for (let j = 0; j <= rings; j++) {
    const t = j / rings;
    const ent = t < 1 / 3 ? 1 : 1 - 0.17 * Math.pow((t - 1 / 3) / (2 / 3), 1.4); // entasis
    const R = R0 * ent;
    for (let i = 0; i <= seg; i++) {
      const th = (i / seg) * Math.PI * 2;
      const s = ((th * flutes) / (Math.PI * 2)) % 1;
      let off = 0;
      if (flutes > 0) {
        if (fillet > 0) off = s < fillet ? 0 : Math.sin((Math.PI * (s - fillet)) / (1 - fillet));
        else off = Math.sin(Math.PI * s);
      }
      const r = R - fd * off * ent;
      pos.push(cx + Math.sin(th) * r, y0 + C(H) * t, cz + Math.cos(th) * r);
      uv.push(th * R, C(H) * t);
    }
  }
  const idx: number[] = [];
  for (let j = 0; j < rings; j++) for (let i = 0; i < seg; i++) {
    const a = j * (seg + 1) + i, b = a + seg + 1;
    idx.push(a, b, a + 1, a + 1, b, b + 1);
  }
  const geo = new BufferGeometry();
  geo.setAttribute('position', new BufferAttribute(new Float32Array(pos), 3));
  geo.setAttribute('uv', new BufferAttribute(new Float32Array(uv), 2));
  geo.setIndex(idx);
  geo.computeVertexNormals();
  g.geometry(key, geo, undefined, true);
}

/** Roman Doric column: plinth + torus base, fluted shaft, echinus + abacus capital. Total height H. */
export function doricColumn(g: GeoBuilder, D: number, H: number, key = 'satin:COLUMN_WHITE', flutes = 24) {
  const half = (1.3 * D) / 2;
  g.push(); g.translate(C(half), 0, C(half));
  const base = 0.5 * D, cap = 0.5 * D;
  boxC(g, key, -half, 0, -half, half, D * 0.17, half);
  g.lathe(key, [[D * 0.62, D * 0.17], [D * 0.65, D * 0.25], [D * 0.62, D * 0.33], [D * 0.55, D * 0.4], [D * 0.52, base]].map(([r, y]) => [C(r), C(y)] as [number, number]), 32);
  flutedShaft(g, key, D, H - base - cap, flutes, 0, C(base));
  const y = H - cap;
  g.lathe(key, [[D * 0.42, y], [D * 0.44, y + D * 0.08], [D * 0.5, y + D * 0.2], [D * 0.58, y + D * 0.3], [D * 0.6, y + D * 0.32]].map(([r, yy]) => [C(r), C(yy)] as [number, number]), 32);
  boxC(g, key, -D * 0.6, y + D * 0.32, -D * 0.6, D * 0.6, H, D * 0.6);
  g.pop();
}

/** Ionic column: Attic base, 24 flutes with fillets, volute capital. */
export function ionicColumn(g: GeoBuilder, D: number, H: number, key = 'satin:COLUMN_WHITE') {
  const half = (1.4 * D) / 2;
  g.push(); g.translate(C(half), 0, C(half));
  const base = 0.5 * D, cap = 0.45 * D;
  boxC(g, key, -half, 0, -half, half, D * 0.14, half);
  g.lathe(key, [[D * 0.66, D * 0.14], [D * 0.68, D * 0.2], [D * 0.62, D * 0.26], [D * 0.56, D * 0.3], [D * 0.58, D * 0.36], [D * 0.6, D * 0.42], [D * 0.52, base]].map(([r, y]) => [C(r), C(y)] as [number, number]), 32);
  flutedShaft(g, key, D, H - base - cap, 24, 0.18, C(base));
  const y = H - cap;
  // echinus (egg-and-dart band approximated) and abacus
  g.lathe(key, [[D * 0.42, y], [D * 0.47, y + D * 0.1], [D * 0.5, y + D * 0.18]].map(([r, yy]) => [C(r), C(yy)] as [number, number]), 32);
  // volute cushion: a horizontal cylinder spanning the capital, scrolled ends as stacked discs
  g.push(); g.translate(0, C(y + D * 0.24), 0); g.rotateZ(Math.PI / 2);
  g.cylinder(key, C(D * 0.13), C(-D * 0.5), C(D * 0.5), 20, false);
  for (const sx of [-1, 1]) for (let k = 0; k < 5; k++) {
    const r = D * (0.2 - k * 0.035), w = D * 0.03;
    const yy = sx * (D * 0.5 + k * 0.004 * D);
    g.cylinder(key, C(r), C(yy - (sx > 0 ? 0 : w)), C(yy + (sx > 0 ? w : 0)), 20, true);
  }
  g.pop();
  boxC(g, key, -D * 0.63, H - D * 0.07, -D * 0.63, D * 0.63, H, D * 0.63);
  g.pop();
}

/** Square brick/stone pier with stone base and cap. */
export function squarePier(g: GeoBuilder, w: number, H: number, key = 'brick:running:BRICK_DOWNTOWN_A', trim = 'tex:limestone') {
  boxC(g, trim, 0, 0, 0, w, 20, w);
  boxC(g, key, 4, 20, 4, w - 4, H - 25, w - 4);
  boxC(g, trim, -2, H - 25, -2, w + 2, H - 10, w + 2);
  boxC(g, trim, 0, H - 10, 0, w, H, w);
}

/** Cast-iron storefront column: slender fluted shaft, foliate capital, square base. */
export function castIronColumn(g: GeoBuilder, H: number, key = 'satin:IRON_BLACK') {
  const D = 22;
  g.push(); g.translate(C(16), 0, C(16));
  boxC(g, key, -16, 0, -16, 16, 30, 16);
  g.lathe(key, [[14, 30], [13, 34], [12, 38]].map(([r, y]) => [C(r), C(y)] as [number, number]), 20);
  flutedShaft(g, key, D, H - 38 - 34, 16, 0.2, C(38));
  const y = H - 34;
  g.lathe(key, [[10, y], [12, y + 6], [17, y + 18], [20, y + 26]].map(([r, yy]) => [C(r), C(yy)] as [number, number]), 20);
  boxC(g, key, -21, H - 8, -21, 21, H, 21);
  // leaf ribs on the bell
  for (let i = 0; i < 8; i++) { g.push(); g.rotateY((i / 8) * Math.PI * 2); boxC(g, key, -1, y + 4, 10, 1, y + 26, 18.5); g.pop(); }
  g.pop();
}

registerKit({ kit: 'Column', name: 'Doric D60 H480', build: (g) => doricColumn(g, 60, 480), bbox: [0, 0, 0, 78, 480, 78] });
registerKit({ kit: 'Column', name: 'Ionic D60 H540', build: (g) => ionicColumn(g, 60, 540), bbox: [0, 0, 0, 84, 540, 84] });
registerKit({ kit: 'Column', name: 'square pier 60 H300', build: (g) => squarePier(g, 60, 300), bbox: [-2, 0, -2, 62, 300, 62] });
registerKit({ kit: 'Column', name: 'cast-iron storefront H360', build: (g) => castIronColumn(g, 360), bbox: [-5, 0, -5, 37, 360, 37] });
