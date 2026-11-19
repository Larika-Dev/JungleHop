// Building pads: terrain is cut under and around every footprint so ground never pokes into floors;
// siting computes each building's ground-floor elevation (FFL) and grade offsets from the terrain.
import { smoothstep } from '../core/units';
import type { BuildingSpec } from '../interiors/types';

export interface Pad { cx: number; cz: number; c: number; s: number; hw: number; hd: number; y: number; margin: number; }
const pads: Pad[] = [];
const hash = new Map<number, Pad[]>();
const K = (x: number, z: number) => Math.floor(x / 50) * 100003 + Math.floor(z / 50);

export function addPad(p: Pad) {
  pads.push(p);
  const r = Math.hypot(p.hw, p.hd) + p.margin;
  for (let x = p.cx - r; x <= p.cx + r + 50; x += 50) for (let z = p.cz - r; z <= p.cz + r + 50; z += 50) {
    const k = K(x, z);
    let a = hash.get(k); if (!a) hash.set(k, (a = []));
    if (!a.includes(p)) a.push(p);
  }
}
export function padFor(spec: BuildingSpec, y: number, margin = 6): Pad {
  const c = Math.cos(spec.rotY), s = Math.sin(spec.rotY);
  const hw = spec.w / 200, hd = spec.d / 200;
  // center = origin + R(hw, hd)
  const cx = spec.x + hw * c + hd * s, cz = spec.z - hw * s + hd * c;
  return { cx, cz, c, s, hw, hd, y, margin };
}
/** Apply pad cuts to a terrain height. */
export function padCut(x: number, z: number, h: number): number {
  const a = hash.get(K(x, z));
  if (!a) return h;
  for (const p of a) {
    const dx = x - p.cx, dz = z - p.cz;
    const lx = dx * p.c - dz * p.s, lz = dx * p.s + dz * p.c; // inverse rotation
    const ox = Math.max(Math.abs(lx) - p.hw, 0), oz = Math.max(Math.abs(lz) - p.hd, 0);
    const d = Math.hypot(ox, oz);
    if (d > p.margin) continue;
    const target = p.y - 0.15;
    if (h > target) h = target + (h - target) * smoothstep(1.0, p.margin, d);
  }
  return h;
}
export function padsCount() { return pads.length; }
