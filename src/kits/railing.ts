// Railing kit (CLAUDE.md §5/§6): iron picket, wood colonial balustrade, glass modern, pipe rail; plus
// wall-mounted handrails. Guardrails 107 cm high, balusters ≤ 10 cm clear; handrails 4 cm dia with top
// at 86–97 cm, 4 cm wall clearance and 30 cm extensions at top and bottom. Runs along +x from origin.
import type { GeoBuilder } from '../core/geo';
import { C, bar, boxC, registerKit } from './common';

export const RAIL = { guard: 107, handrailTop: 91, dia: 4, clearMax: 10, ext: 30, wallClear: 4 } as const;

/** Iron picket guard: 1.6 cm square pickets at ≤10 cm clear, top/bottom rails, posts every 180 cm. */
export function ironPicket(g: GeoBuilder, L: number, h: number = RAIL.guard, key = 'satin:IRON_BLACK') {
  const pk = 1.6, pitch = pk + 9.5; // 9.5 cm clear
  boxC(g, key, 0, h - 4, -2, L, h, 2); // top rail 4 x 4
  boxC(g, key, 0, 6, -1, L, 9, 1); // bottom rail
  for (let x = pk / 2; x <= L - pk / 2 + 1e-6; x += pitch) boxC(g, key, x - pk / 2, 6, -pk / 2, x + pk / 2, h - 4, pk / 2);
  for (let x = 0; x <= L + 1e-6; x += 180) { const xx = Math.min(x, L - 5); boxC(g, key, xx, 0, -2.5, xx + 5, h + 3, 2.5); }
}

/** Wood colonial balustrade: turned balusters (lathe), square newels, molded handrail, bottom rail. */
export function colonialBalustrade(g: GeoBuilder, L: number, h: number = RAIL.guard, key = 'satin:TRIM_WHITE') {
  const prof: [number, number][] = [[2.5, 8], [3.2, 12], [2, 20], [2.4, 34], [4.2, 52], [3.6, 64], [2.1, 74], [2.6, 82], [2.6, h - 9]];
  for (let x = 7.5; x <= L - 7.5; x += 11.5) {
    g.push(); g.translate(C(x), 0, 0);
    g.lathe(key, prof.map(([r, y]) => [C(r), C(y)] as [number, number]), 10);
    g.pop();
  }
  boxC(g, key, 0, 0, -4, L, 8, 4);
  // handrail with a molded top
  boxC(g, key, 0, h - 9, -5, L, h - 3, 5);
  g.push(); g.translate(0, C(h - 3), 0);
  for (const [z0, z1, y1] of [[-5, 5, 2], [-3.5, 3.5, 3]] as const) boxC(g, key, 0, 0, z0, L, y1, z1);
  g.pop();
  for (const x of [0, L - 12]) boxC(g, key, x, 0, -6, x + 12, h + 8, 6); // newels
}

/** Glass modern guard: 1.2 cm tempered panels in a shoe, stainless cap rail. */
export function glassGuard(g: GeoBuilder, L: number, h: number = RAIL.guard) {
  boxC(g, 'metal:ALUMINUM_STOREFRONT', 0, 0, -4, L, 10, 4);
  for (let x = 0; x < L - 1; x += 150) {
    const x1 = Math.min(L, x + 148);
    g.quad('glass', [C(x), C(10), 0], [C(x), C(h - 4), 0], [C(x1), C(h - 4), 0], [C(x1), C(10), 0]);
  }
  boxC(g, 'metal:GALV_STEEL', 0, h - 4, -2.5, L, h, 2.5);
}

/** Pipe rail: 4 cm pipes, posts every 150 cm, top rail at 107 and mid rail at 53. */
export function pipeRail(g: GeoBuilder, L: number, h: number = RAIL.guard, key = 'metal:GALV_STEEL') {
  bar(g, key, [0, C(h - 2), 0], [C(L), C(h - 2), 0], C(4));
  bar(g, key, [0, C(h / 2), 0], [C(L), C(h / 2), 0], C(4));
  for (let x = 2; x <= L - 2 + 1e-6; x += Math.min(150, (L - 4) / Math.max(1, Math.round((L - 4) / 150)))) bar(g, key, [C(x), 0, 0], [C(x), C(h), 0], C(4));
}

/**
 * Wall-mounted handrail along a stair: run (cm) and rise (cm) along +x, top of rail at 91 cm above
 * nosings, 4 cm clear of the wall (wall at z = 0, rail at z = −(4 + 2)), 30 cm level extensions.
 */
export function wallHandrail(g: GeoBuilder, run: number, rise: number, key = 'metal:BRASS') {
  const z = -(RAIL.wallClear + RAIL.dia / 2);
  const top = RAIL.handrailTop - RAIL.dia / 2;
  const a: [number, number, number] = [C(-RAIL.ext), C(top), C(z)], b: [number, number, number] = [0, C(top), C(z)];
  const c: [number, number, number] = [C(run), C(top + rise), C(z)], d: [number, number, number] = [C(run + RAIL.ext), C(top + rise), C(z)];
  bar(g, key, a, b, C(RAIL.dia), 10); bar(g, key, b, c, C(RAIL.dia), 10); bar(g, key, c, d, C(RAIL.dia), 10);
  // returns to the wall + brackets every 120 cm
  bar(g, key, a, [a[0], a[1], 0], C(RAIL.dia), 8); bar(g, key, d, [d[0], d[1], 0], C(RAIL.dia), 8);
  for (let x = 30; x < run; x += 120) {
    const y = top + (rise * x) / run;
    bar(g, key, [C(x), C(y - 6), 0], [C(x), C(y - 6), C(z)], C(1.6), 6);
  }
}

registerKit({ kit: 'Railing', name: 'iron picket 300', build: (g) => ironPicket(g, 300), bbox: [0, 0, -2.5, 300, 110, 2.5] });
registerKit({ kit: 'Railing', name: 'colonial balustrade 300', build: (g) => colonialBalustrade(g, 300), bbox: [0, 0, -6, 300, 115, 6] });
registerKit({ kit: 'Railing', name: 'glass modern 300', build: (g) => glassGuard(g, 300), bbox: [0, 0, -4, 300, 107, 4] });
registerKit({ kit: 'Railing', name: 'pipe rail 300', build: (g) => pipeRail(g, 300), bbox: [0, 0, -2, 300, 107, 2] });
registerKit({ kit: 'Railing', name: 'wall handrail run 280 rise 178', build: (g) => wallHandrail(g, 280, 178), bbox: [-32, 87, -8, 312, 269, 0], note: 'top at 91 cm' });
