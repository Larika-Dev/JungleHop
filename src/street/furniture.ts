// Street furniture (CLAUDE.md §13): campus lanterns (IRON_GREEN 3.7 m, LAMP_CAMPUS), downtown acorn lamps
// (IRON_BLACK 4.3 m, LAMP_LED), sodium cobra-heads on side streets, traffic-signal mast arms (GALV_STEEL,
// heads SIGNAL_HEAD with MARKING_YELLOW backplates), benches (IRON_GREEN + BENCH_SLAT, 183 cm, seat 45 cm),
// inverted-U bike racks, hydrants, bus shelters, newspaper boxes, trash/recycling cans, bollards, parking
// meters and manhole covers with the cast city seal. All instanced per tile.
import { InstancedMesh, Matrix4, Object3D, Quaternion, Vector3 } from 'three';
import { GeoBuilder } from '../core/geo';
import { mat } from '../core/materials';
import { hash01 } from '../core/rng';
import { bar, boxC, C } from '../kits/common';
import { roadPlan } from '../roads/build';
import { CURB_TOP, polyAt, profileAt, CROSS_SLOPE, CURB_H, type Road } from '../roads/network';
import { Terrain } from '../terrain/terrain';
import { tileNameAt } from '../core/tiles';
import type { LampPoint } from '../lighting/presets';

// ------------------------------------------------------------------------------------------ models (origin at base)
const models = new Map<string, GeoBuilder>();
function model(name: string, f: (g: GeoBuilder) => void): GeoBuilder { let g = models.get(name); if (!g) { g = new GeoBuilder(); f(g); models.set(name, g); } return g; }

export const MODELS: Record<string, () => GeoBuilder> = {
  acorn: () => model('acorn', (g) => {
    const k = 'satin:IRON_BLACK';
    g.lathe(k, [[C(16), 0], [C(16), C(40)], [C(10), C(50)], [C(7), C(60)], [C(6), C(360)], [C(9), C(372)], [C(12), C(380)]].map(([r, y]) => [r, y] as [number, number]), 12);
    g.lathe('glow:LAMP_LED', [[C(12), C(380)], [C(22), C(395)], [C(23), C(415)], [C(14), C(428)], [C(4), C(430)]], 14);
    g.lathe(k, [[C(5), C(428)], [C(3), C(440)], [C(0.5), C(450)]], 8);
  }),
  lantern: () => model('lantern', (g) => {
    const k = 'satin:IRON_GREEN';
    g.lathe(k, [[C(13), 0], [C(13), C(30)], [C(6), C(42)], [C(5), C(300)], [C(9), C(310)]].map(([r, y]) => [r, y] as [number, number]), 10);
    boxC(g, k, -16, 310, -16, 16, 314, 16);
    for (const [x, z] of [[-14, -14], [14, -14], [-14, 14], [14, 14]]) boxC(g, k, x - 1, 314, z - 1, x + 1, 352, z + 1);
    boxC(g, 'glow:LAMP_CAMPUS', -12, 316, -12, 12, 350, 12);
    const P = (x: number, y: number, z: number): [number, number, number] => [C(x), C(y), C(z)];
    for (const [a, b] of [[[-18, -18], [18, -18]], [[18, -18], [18, 18]], [[18, 18], [-18, 18]], [[-18, 18], [-18, -18]]] as [number, number][][]) g.tri(k, P(a[0], 352, a[1]), P(0, 370, 0), P(b[0], 352, b[1]));
  }),
  cobra: () => model('cobra', (g) => {
    g.cylinder('satin:GALV_STEEL', C(9), 0, C(820), 10, true);
    bar(g, 'satin:GALV_STEEL', [0, C(800), 0], [0, C(840), C(-200)], C(7));
    boxC(g, 'satin:GALV_STEEL', -22, 825, -260, 22, 845, -180);
    boxC(g, 'glow:LAMP_SODIUM', -18, 822, -255, 18, 826, -185);
  }),
  bench: () => model('bench', (g) => {
    const k = 'satin:IRON_GREEN';
    for (const x of [-80, 0, 80]) { boxC(g, k, x - 3, 0, -25, x + 3, 45, -20); boxC(g, k, x - 3, 0, 20, x + 3, 45, 25); boxC(g, k, x - 3, 40, -25, x + 3, 45, 25); boxC(g, k, x - 3, 45, 20, x + 3, 85, 25); }
    for (let i = 0; i < 5; i++) boxC(g, 'paint:BENCH_SLAT', -91.5, 45, -24 + i * 9, 91.5, 48, -17 + i * 9);
    for (let i = 0; i < 3; i++) boxC(g, 'paint:BENCH_SLAT', -91.5, 55 + i * 10, 23, 91.5, 62 + i * 10, 26);
  }),
  bikerack: () => model('bikerack', (g) => {
    for (const x of [-40, 40]) { bar(g, 'metal:GALV_STEEL', [C(x - 25), 0, 0], [C(x - 25), C(80), 0], C(5)); bar(g, 'metal:GALV_STEEL', [C(x + 25), 0, 0], [C(x + 25), C(80), 0], C(5)); bar(g, 'metal:GALV_STEEL', [C(x - 25), C(80), 0], [C(x + 25), C(80), 0], C(5)); }
  }),
  hydrant: () => model('hydrant', (g) => {
    g.lathe('gloss:HYDRANT_RED', [[C(12), 0], [C(12), C(8)], [C(9.5), C(10)], [C(9.5), C(62)], [C(12), C(66)], [C(11), C(72)]].map(([r, y]) => [r, y] as [number, number]), 14);
    g.lathe('gloss:HYDRANT_CAP', [[C(11), C(72)], [C(9), C(80)], [C(3), C(86)], [C(2), C(90)]], 14);
    for (const a of [0, Math.PI, Math.PI / 2]) { g.push(); g.rotateY(a); g.translate(0, C(48), 0); g.rotateX(Math.PI / 2); g.cylinder('gloss:HYDRANT_CAP', C(a === Math.PI / 2 ? 6 : 4.5), 0, C(16), 10, true); g.pop(); }
  }),
  shelter: () => model('shelter', (g) => {
    const k = 'satin:ONSU_NAVY';
    for (const [x, z] of [[-200, -60], [200, -60], [-200, 60], [200, 60]]) boxC(g, k, x - 5, 0, z - 5, x + 5, 250, z + 5);
    boxC(g, k, -215, 250, -75, 215, 262, 75);
    g.quad('glass', [C(-200), C(20), C(60)], [C(200), C(20), C(60)], [C(200), C(240), C(60)], [C(-200), C(240), C(60)]);
    g.quad('glass', [C(-200), C(20), C(-55)], [C(-200), C(20), C(55)], [C(-200), C(240), C(55)], [C(-200), C(240), C(-55)]);
    boxC(g, 'paint:TRIM_WHITE', 120, 40, 55, 195, 200, 58); // route map panel (map art in signage pass)
    for (let x = -150; x < 100; x += 50) boxC(g, 'metal:GALV_STEEL', x, 45, 30, x + 45, 48, 55);
  }),
  newsbox: () => model('newsbox', (g) => {
    boxC(g, 'gloss:AWNING_HARBOR_BLUE', -25, 30, -20, 25, 105, 20);
    boxC(g, 'glass', -20, 60, -21, 20, 95, -20.5);
    for (const x of [-22, 22]) boxC(g, 'satin:IRON_BLACK', x - 2, 0, -18, x + 2, 30, 18);
  }),
  newsbox2: () => model('newsbox2', (g) => {
    boxC(g, 'gloss:CURB_PAINT_RED', -25, 30, -20, 25, 105, 20);
    boxC(g, 'glass', -20, 60, -21, 20, 95, -20.5);
    for (const x of [-22, 22]) boxC(g, 'satin:IRON_BLACK', x - 2, 0, -18, x + 2, 30, 18);
  }),
  trash: () => model('trash', (g) => {
    g.lathe('satin:IRON_BLACK', [[C(28), 0], [C(30), C(90)], [C(32), C(92)], [C(5), C(100)]], 16);
    for (let i = 0; i < 16; i++) { const a = (i / 16) * Math.PI * 2; bar(g, 'satin:IRON_BLACK', [Math.sin(a) * 0.3, 0.05, Math.cos(a) * 0.3], [Math.sin(a) * 0.315, 0.88, Math.cos(a) * 0.315], C(2)); }
  }),
  recycle: () => model('recycle', (g) => {
    g.lathe('gloss:AWNING_HARBOR_BLUE', [[C(28), 0], [C(30), C(90)], [C(32), C(92)], [C(5), C(100)]], 16);
  }),
  bollard: () => model('bollard', (g) => { g.lathe('satin:IRON_BLACK', [[C(10), 0], [C(10), C(80)], [C(11), C(85)], [C(7), C(95)], [C(0.5), C(100)]], 12); }),
  meter: () => model('meter', (g) => {
    g.cylinder('metal:GALV_STEEL', C(3.5), 0, C(110), 8, true);
    boxC(g, 'metal:GALV_STEEL', -10, 110, -8, 10, 150, 8);
    boxC(g, 'glass', -7, 128, -8.5, 7, 145, -8);
  }),
  manhole: () => model('manhole', (g) => {
    // cast iron cover with raised seal rings ("CITY OF CATHEDRAL MOUNT — 1819" lettering in the signage pass)
    g.disc('satin:IRON_BLACK', C(33), C(0.4), 24, true);
    for (const r of [8, 18, 28]) g.disc('satin:IRON_BLACK', C(r + 1), C(0.8), 24, true, C(r));
    for (let i = 0; i < 12; i++) { const a = (i / 12) * Math.PI; g.push(); g.rotateY(a); boxC(g, 'satin:IRON_BLACK', -28, 0.4, -0.6, 28, 0.8, 0.6); g.pop(); }
  }),
  signal: () => model('signal', (g) => {
    // mast-arm pole (arm along local −z over the lanes), heads hang every 3.3 m
    g.cylinder('metal:GALV_STEEL', C(16), 0, C(720), 12, true);
    bar(g, 'metal:GALV_STEEL', [0, C(700), 0], [0, C(680), C(-900)], C(14));
    bar(g, 'metal:GALV_STEEL', [0, C(600), 0], [0, C(690), C(-300)], C(6)); // brace
    for (const z of [-350, -680]) {
      boxC(g, 'paint:MARKING_YELLOW', -27, 560, z - 8, 27, 680, z - 5); // backplate
      boxC(g, 'paint:MARKING_WHITE', -29, 558, z - 8.5, 29, 682, z - 7.9); // retroreflective border
      boxC(g, 'satin:SIGNAL_HEAD', -17, 570, z - 5, 17, 670, z + 25);
      for (const [y, k] of [[655, 'glow:NEON_RED'], [620, 'glow:MARKING_YELLOW'], [585, 'glow:BIKE_LANE_GREEN']] as const) g.cylinder(k, C(10), C(y - 10), C(y + 10), 12, true, 0, C(z - 6));
    }
    // pedestrian head on the pole
    boxC(g, 'satin:SIGNAL_HEAD', 16, 260, -18, 50, 300, 18);
  }),
  blade: () => model('blade', (g) => {
    g.cylinder('metal:GALV_STEEL', C(4), 0, C(300), 8, true);
    boxC(g, 'paint:SIGN_STREET_GREEN', -38, 290, -1, 38, 305, 1); // 15 x 76 cm (names in signage pass)
    boxC(g, 'paint:SIGN_STREET_GREEN', -1, 270, -38, 1, 285, 38);
  }),
};

// ------------------------------------------------------------------------------------------ placement per tile
export interface Placement { model: string; x: number; y: number; z: number; rot: number; }
export const LAMPS: LampPoint[] = [];

function walkY(r: Road, s: number, d: number) { return profileAt(r, s) - CROSS_SLOPE * r.half + CURB_H + CROSS_SLOPE * (Math.abs(d) - r.half - CURB_TOP); }

const plCache = new Map<string, Placement[]>();
export function furnitureByTile(): Map<string, Placement[]> {
  if (plCache.size) return plCache;
  const P = roadPlan();
  const add = (p: Placement) => { const t = tileNameAt(p.x, p.z); let a = plCache.get(t); if (!a) plCache.set(t, (a = [])); a.push(p); };
  for (const r of P.net.roads) {
    if (!r.sec.curb && r.kind !== 'lane') continue;
    const lampModel = r.sec.light === 'LAMP_LED' ? 'acorn' : r.sec.light === 'LAMP_CAMPUS' ? 'lantern' : r.sec.light === 'LAMP_SODIUM' ? 'cobra' : null;
    for (const sp of r.spans) for (const side of [1, -1] as const) {
      const a = side > 0 ? sp.l0 : sp.r0, b = side > 0 ? sp.l1 : sp.r1;
      if (b - a < 8) continue;
      const lampEvery = r.kind === 'hamilton' ? 22 : r.kind === 'lane' ? 30 : 36;
      for (let s = a + 4; s < b - 4; s += lampEvery) {
        if (r.bridges.some(([b0, b1]) => s > b0 && s < b1)) continue;
        const f = polyAt(r, s);
        const d = side * (r.half + (r.sec.curb ? 0.6 : 1.2));
        const x = f.p[0] + f.n[0] * d, z = f.p[1] + f.n[1] * d;
        const y = r.sec.curb ? walkY(r, s, d) : Terrain.get().height(x, z);
        const rot = Math.atan2(f.n[0] * side, f.n[1] * side);
        if (lampModel && (r.kind !== 'hamilton' || ((s / lampEvery) | 0) % 2 === (side > 0 ? 0 : 1) || true)) {
          add({ model: lampModel, x, y, z, rot: rot + Math.PI });
          const lh = lampModel === 'acorn' ? 4.1 : lampModel === 'lantern' ? 3.35 : 8.2;
          LAMPS.push({ x, y: y + lh, z, color: r.sec.light as LampPoint['color'], range: lampModel === 'cobra' ? 26 : 18 });
        }
        const h = hash01(Math.round(s), r.id.length, side + 5);
        // street-side furniture between lamps (Hamilton & main)
        if (r.kind === 'hamilton' || r.kind === 'main') {
          const s2 = s + lampEvery / 2;
          if (s2 < b - 4) {
            const f2 = polyAt(r, s2);
            const d2 = side * (r.half + 0.75), x2 = f2.p[0] + f2.n[0] * d2, z2 = f2.p[1] + f2.n[1] * d2;
            const y2 = walkY(r, s2, d2);
            const kind = h < 0.22 ? 'bench' : h < 0.36 ? 'trash' : h < 0.44 ? 'recycle' : h < 0.56 ? 'bikerack' : h < 0.64 ? 'newsbox' : h < 0.7 ? 'newsbox2' : h < 0.78 ? 'hydrant' : null;
            if (kind) add({ model: kind, x: x2, y: y2, z: z2, rot: rot + (kind === 'bench' ? Math.PI : Math.PI / 2) });
            if (r.kind === 'hamilton' && h > 0.92) { const d3 = side * (r.row - 1.2); add({ model: 'shelter', x: f2.p[0] + f2.n[0] * d3, y: walkY(r, s2, d3), z: f2.p[1] + f2.n[1] * d3, rot: rot + Math.PI }); }
          }
          // parking meters at stalls (Hamilton)
          if (r.kind === 'hamilton') for (let m = s + 3.35; m < Math.min(b - 2, s + lampEvery); m += 6.7) {
            const fm = polyAt(r, m), dm = side * (r.half + 0.45);
            add({ model: 'meter', x: fm.p[0] + fm.n[0] * dm, y: walkY(r, m, dm), z: fm.p[1] + fm.n[1] * dm, rot: rot + Math.PI });
          }
        } else if (h < 0.18) {
          const f2 = polyAt(r, s + 9), d2 = side * (r.half + 0.6);
          add({ model: 'hydrant', x: f2.p[0] + f2.n[0] * d2, y: walkY(r, s + 9, d2), z: f2.p[1] + f2.n[1] * d2, rot });
        }
      }
      // manholes in the travel lanes every ~60 m
      if (side > 0) for (let s = a + 20; s < b - 10; s += 60) { const f = polyAt(r, s), d = r.half * 0.35; add({ model: 'manhole', x: f.p[0] + f.n[0] * d, y: profileAt(r, s) - CROSS_SLOPE * d, z: f.p[1] + f.n[1] * d, rot: 0 }); }
    }
  }
  // signals at signalized nodes: one mast arm per approach on its right-hand corner; street blades at every node
  for (const n of P.net.nodes) {
    if (n.arms.length < 3) continue;
    for (const a of n.arms) {
      if (!a.road.sec.curb) continue;
      const nx = -a.dir[1], nz = a.dir[0];
      const off = a.half + 0.9, along = a.cut + 1.0;
      const x = n.x + a.dir[0] * along - nx * off, z = n.z + a.dir[1] * along - nz * off;
      const rot = Math.atan2(a.dir[0], a.dir[1]) + Math.PI / 2;
      const y = n.y - CROSS_SLOPE * a.half + CURB_H;
      if (n.signal) add({ model: 'signal', x, y, z, rot });
      else add({ model: 'blade', x, y, z, rot });
    }
  }
  // bollards at alley mouths & the Quarry plaza edge
  for (const r of P.net.roads.filter((q) => q.kind === 'alley')) for (const s of [1.5]) {
    const f = polyAt(r, s);
    for (const d of [-1.4, 0, 1.4]) add({ model: 'bollard', x: f.p[0] + f.n[0] * d, y: profileAt(r, s), z: f.p[1] + f.n[1] * d, rot: 0 });
  }
  return plCache;
}

/** Instanced furniture group for a tile. */
export function furnitureGroup(list: Placement[]): Object3D {
  const root = new Object3D(); root.name = 'furniture';
  const by = new Map<string, Placement[]>();
  for (const p of list) { let a = by.get(p.model); if (!a) by.set(p.model, (a = [])); a.push(p); }
  const m = new Matrix4(), q = new Quaternion(), s = new Vector3(1, 1, 1), v = new Vector3(), up = new Vector3(0, 1, 0);
  for (const [name, arr] of by) {
    const g = MODELS[name]();
    for (const key of g.buckets.keys()) {
      const im = new InstancedMesh(g.geometryFor(key)!, mat(key), arr.length);
      im.name = `${name}:${key}`; im.userData.matKey = key; im.castShadow = name !== 'manhole'; im.receiveShadow = true;
      arr.forEach((p, i) => { q.setFromAxisAngle(up, p.rot); v.set(p.x, p.y, p.z); m.compose(v, q, s); im.setMatrixAt(i, m); });
      im.computeBoundingSphere();
      root.add(im);
    }
  }
  return root;
}
