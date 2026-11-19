// Cornice kit (CLAUDE.md §5/§6): box cornice, dentil cornice (dentils 6 x 9 cm @ 12 cm), bracketed
// Italianate, modern parapet coping. Cornices are swept profiles; straight pieces run along +x with the
// wall face at z=0 and the projection toward −z. `cornicePath` sweeps along any building perimeter.
import { triangulate, type GeoBuilder } from '../core/geo';
import { C, boxC, registerKit } from './common';
import type { P2 } from '../world/layout';

export type Profile = [number, number][]; // [out, up] cm, from wall/bottom outward, over the top, back to wall

export const PROFILES: Record<string, Profile> = {
  box: [[0, 0], [30, 0], [30, 2], [32, 2], [32, 20], [34, 22], [38, 28], [40, 32], [0, 32]],
  dentilBed: [[0, 0], [8, 0], [8, 6], [14, 9], [14, 12], [0, 12]],
  dentilCrown: [[0, 0], [42, 0], [42, 3], [44, 3], [44, 18], [46, 20], [50, 26], [52, 31], [0, 31]],
  italianate: [[0, 0], [62, 0], [62, 3], [64, 3], [64, 26], [66, 28], [70, 34], [72, 38], [0, 38]],
  coping: [[-2, -6], [0, -6], [0, 0]],
  crown15: [[0, 0], [3, 2], [6, 6], [10, 10], [12, 13], [15, 15], [0, 15]], // interior crown molding 15 cm
  base: [[0, 0], [1.5, 0], [1.5, 10], [1, 12], [0, 13]], // interior baseboard 13 cm
};

/** Sweep a profile along a straight run of length L (cm) with end caps. */
export function corniceStraight(g: GeoBuilder, L: number, profile: Profile, key: string, y0 = 0, caps = true) {
  const prof = profile.map(([o, u]) => [C(o), C(u)] as [number, number]);
  g.sweep(key, prof, [[0, 0], [C(L), 0]], C(y0), false, 1);
  if (!caps) return;
  const poly = prof.map(([o, u]) => [o, u] as [number, number]);
  const tris = triangulate(poly);
  for (const x of [0, C(L)]) for (const [a, b, c] of tris) {
    const P = (i: number): [number, number, number] => [x, C(y0) + poly[i][1], -poly[i][0]];
    if (x === 0) g.tri(key, P(a), P(c), P(b)); else g.tri(key, P(a), P(b), P(c));
  }
}

/** Sweep along a closed building perimeter (plan points in m, wound so outward = left of travel × outSign). */
export function cornicePath(g: GeoBuilder, path: P2[], profile: Profile, key: string, y: number, outSign = 1, closed = true) {
  g.sweep(key, profile.map(([o, u]) => [C(o), C(u)] as [number, number]), path, y, closed, outSign);
}

/** Dentil course: dentils 6 wide x 9 tall, 12 cm on center, projecting `proj` (cm) from z=0. */
export function dentils(g: GeoBuilder, L: number, key: string, y0 = 0, proj = 8) {
  for (let x = 3; x + 6 <= L - 3 + 1e-6; x += 12) boxC(g, key, x, y0, -proj, x + 6, y0 + 9, 0);
}

export function boxCornice(g: GeoBuilder, L: number, key = 'satin:TRIM_WHITE') { corniceStraight(g, L, PROFILES.box, key); }

export function dentilCornice(g: GeoBuilder, L: number, key = 'satin:TRIM_WHITE') {
  corniceStraight(g, L, PROFILES.dentilBed, key, 0);
  dentils(g, L, key, 0, 8 + 6);
  corniceStraight(g, L, PROFILES.dentilCrown, key, 12);
}

/** Bracketed Italianate: deep crown with paired scroll brackets every 90 cm. */
export function italianateCornice(g: GeoBuilder, L: number, key = 'satin:TRIM_WHITE') {
  corniceStraight(g, L, PROFILES.italianate, key, 45);
  // frieze board
  boxC(g, key, 0, 0, -4, L, 45, 0);
  for (let x = 20; x <= L - 30; x += 90) for (const dx of [0, 14]) bracket(g, x + dx, key);
}
function bracket(g: GeoBuilder, x: number, key: string) {
  // scroll bracket side profile (out, up) extruded 10 cm wide
  const prof: [number, number][] = [[0, 0], [8, 2], [14, 8], [18, 16], [26, 24], [40, 30], [58, 34], [60, 45], [0, 45]];
  const tris = triangulate(prof);
  for (const xx of [x, x + 10]) for (const [a, b, c] of tris) {
    const P = (i: number): [number, number, number] => [C(xx), C(prof[i][1]), -C(prof[i][0])];
    if (xx === x) g.tri(key, P(a), P(c), P(b)); else g.tri(key, P(a), P(b), P(c));
  }
  for (let i = 0; i < prof.length; i++) {
    const p = prof[i], q = prof[(i + 1) % prof.length];
    g.quad(key, [C(x), C(p[1]), -C(p[0])], [C(x), C(q[1]), -C(q[0])], [C(x + 10), C(q[1]), -C(q[0])], [C(x + 10), C(p[1]), -C(p[0])]);
  }
  // pendant drop
  g.cylinder(key, C(3), C(-6), C(0), 10, true, C(x + 5), -C(6));
}

/** Modern parapet coping: metal cap over a parapet of thickness t, drip legs 6 cm both faces. */
export function parapetCoping(g: GeoBuilder, L: number, t: number, key = 'metal:GALV_STEEL') {
  boxC(g, key, 0, 0, -2.5, L, 1.5, t + 2.5);
  boxC(g, key, 0, -6, -2.5, L, 0, -1.5);
  boxC(g, key, 0, -6, t + 1.5, L, 0, t + 2.5);
}

registerKit({ kit: 'Cornice', name: 'box cornice 300', build: (g) => boxCornice(g, 300), bbox: [0, 0, -40, 300, 32, 0] });
registerKit({ kit: 'Cornice', name: 'dentil cornice 300', build: (g) => dentilCornice(g, 300), bbox: [0, 0, -52, 300, 43, 0] });
registerKit({ kit: 'Cornice', name: 'bracketed Italianate 300', build: (g) => italianateCornice(g, 300), bbox: [0, -6, -72, 300, 83, 0] });
registerKit({ kit: 'Cornice', name: 'parapet coping 300 t35', build: (g) => parapetCoping(g, 300, 35), bbox: [0, -6, -2.5, 300, 1.5, 37.5] });
