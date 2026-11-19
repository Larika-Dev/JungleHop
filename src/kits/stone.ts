// Fieldstone wall kit (CLAUDE.md §5/§6): straight, curve (radius), end post, gate pier 60x60x150 with cap.
// Individual stones 15–60 cm as real (irregular) geometry, mortar recessed 2–4 cm, flat CAPSTONE caps
// 5–8 cm thick overhanging 2 cm, MOSS in north-facing joints.
import type { GeoBuilder } from '../core/geo';
import { Rng } from '../core/rng';
import { C, boxC, registerKit, rubble } from './common';

const STONES = ['paint:FIELDSTONE_A', 'paint:FIELDSTONE_B', 'paint:FIELDSTONE_C', 'paint:FIELDSTONE_D'];

/**
 * Coursed-rubble face: stones packed in irregular courses over [0,len] x [0,h] on the plane z=0
 * (front, facing −z), protruding `proud` m from a mortar core recessed by 2–4 cm.
 */
function stoneFace(g: GeoBuilder, len: number, h: number, rng: Rng, north: boolean) {
  let y = 0;
  while (y < h - 0.04) {
    const ch = Math.min(h - y, 0.12 + rng.next() * 0.22);
    let x = -rng.next() * 0.1;
    while (x < len - 0.02) {
      const w = Math.min(len - Math.max(0, x), 0.15 + rng.next() * 0.45);
      const x0 = Math.max(0, x) + 0.012, x1 = Math.min(len, x + w) - 0.012;
      if (x1 - x0 > 0.06) {
        const depth = 0.02 + rng.next() * 0.02; // mortar recess 2–4 cm
        rubble(g, rng.pick(STONES), x0, y + 0.012, 0.03 - depth, x1, y + ch - 0.012, 0.14, 0.01, () => rng.next());
      }
      x += w;
    }
    y += ch;
  }
  // moss in joints on north faces
  if (north) for (let i = 0; i < len * 3; i++) {
    const mx = rng.next() * len, my = rng.next() * h * 0.6;
    g.box('paint:MOSS', mx, my, 0.026, Math.min(len, mx + 0.05 + rng.next() * 0.12), my + 0.015, 0.03);
  }
}

/** Straight wall: length L, height h, width t (cm). Front face z=0, back face z=t. */
export function stoneWall(g: GeoBuilder, L: number, h: number, t: number, seed = 'stonewall', northFront = false, cap = true) {
  const rng = new Rng(seed);
  const capT = cap ? 5 + rng.next() * 3 : 0;
  const hs = C(h - capT);
  // mortar core (recessed 3 cm both sides)
  boxC(g, 'paint:MORTAR_HISTORIC', 0, 0, 3, L, h - capT, t - 3);
  g.push(); stoneFace(g, C(L), hs, rng, northFront); g.pop();
  g.push(); g.translate(C(L), 0, C(t)); g.rotateY(Math.PI); stoneFace(g, C(L), hs, rng, !northFront); g.pop();
  // end faces
  boxC(g, 'paint:FIELDSTONE_B', 0, 0, 0, 0.1, h - capT, t, 2);
  boxC(g, 'paint:FIELDSTONE_B', L - 0.1, 0, 0, L, h - capT, t, 1);
  if (cap) {
    // capstones in 60–110 cm slabs, overhang 2 cm each side
    let x = 0;
    while (x < L) {
      const w = Math.min(L - x, 60 + rng.next() * 50);
      boxC(g, 'tex:capstone', x, h - capT, -2, x + w - 0.6, h, t + 2);
      x += w;
    }
  }
}

/** Curved wall along an arc of radius R (cm), sweep angle deg, built from short straight segments. */
export function stoneWallCurve(g: GeoBuilder, R: number, deg: number, h: number, t: number, seed = 'curve') {
  const seg = Math.max(2, Math.ceil((R * (deg * Math.PI / 180)) / 60));
  const a = (deg * Math.PI) / 180 / seg;
  const chord = 2 * R * Math.sin(a / 2);
  for (let i = 0; i < seg; i++) {
    const th = i * a;
    g.push();
    g.translate(C(R * Math.sin(th)), 0, C(R - R * Math.cos(th)));
    g.rotateY(-th - a / 2 * 0);
    g.rotateY(-a / 2);
    stoneWall(g, chord + 1, h, t, `${seed}${i}`);
    g.pop();
  }
}

/** End post: square fieldstone post w x w x h with cap. */
export function stoneEndPost(g: GeoBuilder, w: number, h: number, seed = 'post') {
  stoneWall(g, w, h, w, seed);
}

/** Gate pier 60 x 60 x 150 cm with a 10 cm overhanging pyramidal cap (CLAUDE.md §6). */
export function gatePier(g: GeoBuilder, seed = 'pier') {
  stoneWall(g, 60, 140, 60, seed, false, false);
  boxC(g, 'tex:capstone', -5, 140, -5, 65, 146, 65);
  // low pyramid
  const P = (x: number, y: number, z: number): [number, number, number] => [C(x), C(y), C(z)];
  const k = 'tex:capstone';
  g.tri(k, P(-5, 146, -5), P(30, 150, 30), P(65, 146, -5));
  g.tri(k, P(65, 146, -5), P(30, 150, 30), P(65, 146, 65));
  g.tri(k, P(65, 146, 65), P(30, 150, 30), P(-5, 146, 65));
  g.tri(k, P(-5, 146, 65), P(30, 150, 30), P(-5, 146, -5));
}

registerKit({ kit: 'Stone wall', name: 'straight 300x90x50', build: (g) => stoneWall(g, 300, 90, 50), bbox: [0, 0, -2, 300, 90, 52], note: 'stones jitter ±1.8 cm; checked on core+cap' });
registerKit({ kit: 'Stone wall', name: 'end post 60x110', build: (g) => stoneEndPost(g, 60, 110), bbox: [0, 0, -2, 60, 110, 62] });
registerKit({ kit: 'Stone wall', name: 'gate pier 60x60x150', build: (g) => gatePier(g), bbox: [-5, 0, -5, 65, 150, 65] });
registerKit({ kit: 'Stone wall', name: 'curve R600 90deg', build: (g) => stoneWallCurve(g, 600, 90, 90, 50), bbox: [-2.5, 0, -2, 602, 90, 603.5], note: 'loose bbox (curve)' });
