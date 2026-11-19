// Curb / sidewalk kit (CLAUDE.md §5/§6): straight, corner radius, ramp, driveway apron, tree pit with
// 120 x 120 cm grate. These wrap the road builders' primitives as standalone, dimension-tested pieces.
import type { GeoBuilder, V3 } from '../core/geo';
import { sweepCurb } from '../roads/curbs';
import { domePanel, treeGrate } from '../roads/sidewalks';
import { C, boxC, registerKit } from './common';

/** Straight curb L cm along +x (gutter line at z=0, sidewalk toward +z). 15 high, 15 top, 2 cm chamfer. */
export function curbStraight(g: GeoBuilder, L: number, key = 'tex:granite') {
  sweepCurb(g, key, [[0, 0, 0], [C(L), 0, 0]], 1);
}
/** Corner-radius curb: quarter arc of radius R cm (center at (R, R) in x/z). */
export function curbCorner(g: GeoBuilder, R: number, key = 'tex:granite') {
  const pts: [number, number, number][] = [];
  for (let i = 0; i <= 16; i++) { const a = Math.PI + (i / 16) * (Math.PI / 2); pts.push([C(R + Math.cos(a) * R), C(R + Math.sin(a) * R), 0]); }
  sweepCurb(g, key, pts, 1);
}
/** Curb ramp: 122 wide flat run at 1:12 over 183 cm with flared sides and a truncated-dome panel. */
export function curbRamp(g: GeoBuilder, key = 'tex:concrete_new') {
  const P = (x: number, y: number, z: number): V3 => [C(x), C(y), C(z)];
  const run = 183, wid = 122, flare = 46;
  g.quad(key, P(flare, 0, 0), P(flare, 15, run), P(flare + wid, 15, run), P(flare + wid, 0, 0));
  g.quad(key, P(0, 15, 0), P(0, 15, run), P(flare, 15, run), P(flare, 0, 0));
  g.quad(key, P(flare + wid, 0, 0), P(flare + wid, 15, run), P(flare * 2 + wid, 15, run), P(flare * 2 + wid, 15, 0));
  domePanel(g, [C(flare + wid / 2), C(30.5)], [0, -1], C(15 * 61 / run), 0, 1.22, 0.61, true);
  boxC(g, key, 0, -10, 0, flare * 2 + wid, 0, run, 8 | 1 | 2 | 16 | 32);
}
/** Driveway apron: depressed curb with sloped wings, w cm opening. */
export function drivewayApron(g: GeoBuilder, w = 360, key = 'tex:concrete_aged') {
  const P = (x: number, y: number, z: number): V3 => [C(x), C(y), C(z)];
  const d = 150, wing = 90;
  g.quad(key, P(wing, 2, 0), P(wing, 15, d), P(wing + w, 15, d), P(wing + w, 2, 0));
  g.quad(key, P(0, 15, 0), P(0, 15, d), P(wing, 15, d), P(wing, 2, 0));
  g.quad(key, P(wing + w, 2, 0), P(wing + w, 15, d), P(2 * wing + w, 15, d), P(2 * wing + w, 15, 0));
  boxC(g, key, 0, -10, 0, 2 * wing + w, 0, d, 8 | 1 | 2 | 16 | 32);
}
/** Tree pit with 120 x 120 cm cast-iron grate. */
export function treePit(g: GeoBuilder) { treeGrate(g, [0.6, 0.6], [1, 0], 0.15); }

registerKit({ kit: 'Curb/sidewalk', name: 'straight curb 300', build: (g) => curbStraight(g, 300), bbox: [0, -2, 0, 300, 15, 15] });
registerKit({ kit: 'Curb/sidewalk', name: 'corner radius R450', build: (g) => curbCorner(g, 450), bbox: [0, -2, 0, 450.74, 15, 450.74], note: 'arc curb, 15 cm top inside' });
registerKit({ kit: 'Curb/sidewalk', name: 'ADA curb ramp 1:12', build: (g) => curbRamp(g), bbox: [0, -10, 0, 214, 15.5, 183] });
registerKit({ kit: 'Curb/sidewalk', name: 'driveway apron 360', build: (g) => drivewayApron(g), bbox: [0, -10, 0, 540, 15, 150] });
registerKit({ kit: 'Curb/sidewalk', name: 'tree pit grate 120x120', build: (g) => treePit(g), bbox: [0, 12, 0, 120, 16.2, 120] });
