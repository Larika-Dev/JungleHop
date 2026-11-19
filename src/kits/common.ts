// Kit infrastructure (CLAUDE.md §6): every piece is a function of integer-cm dimensions writing into a
// GeoBuilder with its pivot at bottom-front-left (x = width →, y = up, z = depth into the wall/back;
// the FRONT face lies on z = 0 and faces −z). Every piece registers an expected bounding box (cm) that
// tests/kits.test.ts verifies to ±0.5 cm and the gallery scene displays.
import type { GeoBuilder } from '../core/geo';
import { cm } from '../core/units';

export const C = cm; // shorthand: C(213) -> 2.13 m

export interface KitSpec {
  kit: string; // kit family (Brick wall, Window, ...)
  name: string; // piece name
  /** Build at origin into g. */
  build: (g: GeoBuilder) => void;
  /** Expected bounding box in cm: [x0, y0, z0, x1, y1, z1]. */
  bbox: [number, number, number, number, number, number];
  note?: string;
}

export const KIT_REGISTRY: KitSpec[] = [];
export function registerKit(k: KitSpec) { KIT_REGISTRY.push(k); }

/** Axis-aligned box from cm coordinates. */
export function boxC(g: GeoBuilder, key: string, x0: number, y0: number, z0: number, x1: number, y1: number, z1: number, faces = 63) {
  g.box(key, C(x0), C(y0), C(z0), C(x1), C(y1), C(z1), faces);
}

/** Irregular hexahedron (rubble stone) with corner jitter (meters). r = 8 random numbers. */
export function rubble(g: GeoBuilder, key: string, x0: number, y0: number, z0: number, x1: number, y1: number, z1: number, j: number, r: () => number) {
  const J = () => (r() - 0.5) * 2 * j;
  const c = [
    [x0 + J(), y0, z0 + J() * 0.5], [x1 + J(), y0, z0 + J() * 0.5], [x1 + J(), y1 + J() * 0.4, z0 + J() * 0.5], [x0 + J(), y1 + J() * 0.4, z0 + J() * 0.5],
    [x0 + J(), y0, z1], [x1 + J(), y0, z1], [x1 + J(), y1 + J() * 0.4, z1], [x0 + J(), y1 + J() * 0.4, z1],
  ] as [number, number, number][];
  const q = (a: number, b: number, cc: number, d: number) => g.quad(key, c[a], c[b], c[cc], c[d]);
  q(1, 0, 3, 2); // front (z0) faces -z
  q(4, 5, 6, 7); // back
  q(0, 4, 7, 3); // left
  q(5, 1, 2, 6); // right
  q(3, 7, 6, 2); // top
  q(0, 1, 5, 4); // bottom
}

/** Hand-rail/round bar along a straight line (dia in m), 8-sided. */
export function bar(g: GeoBuilder, key: string, a: [number, number, number], b: [number, number, number], dia: number, seg = 8) {
  const dx = b[0] - a[0], dy = b[1] - a[1], dz = b[2] - a[2];
  const L = Math.hypot(dx, dy, dz);
  if (L < 1e-6) return;
  const ux = dx / L, uy = dy / L, uz = dz / L;
  // perpendicular basis
  let px = -uz, py = 0, pz = ux;
  if (Math.hypot(px, pz) < 1e-3) { px = 1; py = 0; pz = 0; }
  let pl = Math.hypot(px, py, pz); px /= pl; py /= pl; pz /= pl;
  const qx = uy * pz - uz * py, qy = uz * px - ux * pz, qz = ux * py - uy * px;
  const r = dia / 2;
  const ring = (o: [number, number, number], k: number): [number, number, number] => {
    const t = (k / seg) * Math.PI * 2, c = Math.cos(t) * r, s = Math.sin(t) * r;
    return [o[0] + px * c + qx * s, o[1] + py * c + qy * s, o[2] + pz * c + qz * s];
  };
  for (let k = 0; k < seg; k++) g.quad(key, ring(a, k), ring(a, k + 1), ring(b, k + 1), ring(b, k));
  void pl;
}
