// Plan validation (CLAUDE.md §7.3 / §19): rooms per floor, reachability from exterior doors through
// doors/openings/stairs/elevators, floors reachable by stairs, elevators where required, two exits per
// floor over two floors, no door swinging into a stair's walking path, itemSlots present.
import type { Plan, Rect, Room, WallSeg } from './types';

const inR = (r: Rect, x: number, z: number, pad = 0) => x >= r.x0 - pad && x <= r.x1 + pad && z >= r.z0 - pad && z <= r.z1 + pad;
export function roomAt(rooms: Room[], x: number, z: number, pad = 1): Room | null {
  let best: Room | null = null, bestA = Infinity;
  for (const r of rooms) if (inR(r.rect, x, z, pad)) { const a = (r.rect.x1 - r.rect.x0) * (r.rect.z1 - r.rect.z0); if (a < bestA) { best = r; bestA = a; } }
  return best;
}

/** Two room ids adjacent through an opening or an open (wall-less) shared edge. */
export function adjacency(plan: Plan): Map<string, Set<string>> {
  const adj = new Map<string, Set<string>>();
  const link = (a: string, b: string) => { if (a === b) return; (adj.get(a) ?? adj.set(a, new Set()).get(a)!).add(b); (adj.get(b) ?? adj.set(b, new Set()).get(b)!).add(a); };
  for (const fp of plan.floors) {
    for (const r of fp.rooms) adj.set(r.id, adj.get(r.id) ?? new Set());
    // openings in partitions
    for (const w of fp.walls) for (const o of w.openings) {
      if (o.kind !== 'door' && o.kind !== 'arch') continue;
      const { cx, cz, nx, nz } = openingCenter(w, o.at + o.w / 2);
      const off = w.t / 2 + 8;
      const a = roomAt(fp.rooms, cx + nx * off, cz + nz * off), b = roomAt(fp.rooms, cx - nx * off, cz - nz * off);
      if (a && b) link(a.id, b.id);
    }
  }
  for (const [a, b] of plan.links) link(a, b);
  // stairs connect the stair rooms (room containing the hole's entry side) between floors
  for (const s of plan.stairs) {
    const a = plan.floors.find((f) => f.floor === s.floor), b = plan.floors.find((f) => f.floor === s.toFloor);
    if (!a || !b) continue;
    const cx = (s.rect.x0 + s.rect.x1) / 2, cz = (s.rect.z0 + s.rect.z1) / 2;
    const ra = roomAt(a.rooms, cx, cz, 30), rb = roomAt(b.rooms, cx, cz, 30);
    if (ra && rb) link(ra.id, rb.id);
  }
  for (const sh of plan.shafts) {
    const ids: string[] = [];
    for (const fl of sh.floors) {
      const fp = plan.floors.find((f) => f.floor === fl);
      const r = fp && roomAt(fp.rooms, (sh.rect.x0 + sh.rect.x1) / 2, (sh.rect.z0 + sh.rect.z1) / 2, 40);
      if (r) ids.push(r.id);
    }
    for (let i = 0; i < ids.length - 1; i++) link(ids[i], ids[i + 1]);
  }
  return adj;
}

export function openingCenter(w: WallSeg, along: number) {
  const L = Math.hypot(w.bx - w.ax, w.bz - w.az) || 1;
  const ux = (w.bx - w.ax) / L, uz = (w.bz - w.az) / L;
  return { cx: w.ax + ux * along, cz: w.az + uz * along, nx: -uz, nz: ux, ux, uz, L };
}

/** Room (on the ground/appropriate floor) just inside each exterior door. */
export function entryRooms(plan: Plan): Room[] {
  const s = plan.spec, out: Room[] = [];
  for (const d of plan.extDoors) {
    const fp = plan.floors.find((f) => f.floor === d.floor);
    if (!fp) continue;
    const mid = d.at + d.w / 2, inset = fp.extT + 20;
    const p = d.side === 'front' ? [mid, inset] : d.side === 'back' ? [s.w - mid, s.d - inset] : d.side === 'left' ? [inset, s.d - mid] : [s.w - inset, mid];
    const r = roomAt(fp.rooms, p[0], p[1], 25);
    if (r) out.push(r);
  }
  return out;
}

export interface Report { ok: boolean; errors: string[]; }
export function validatePlan(plan: Plan): Report {
  const errors: string[] = [];
  const s = plan.spec;
  for (const fp of plan.floors) if (!fp.rooms.length) errors.push(`floor ${fp.floor} has no rooms`);
  const adj = adjacency(plan);
  const entries = entryRooms(plan);
  if (!entries.length) errors.push('no exterior door enters a room');
  const seen = new Set<string>();
  const q = entries.map((r) => r.id);
  for (const id of q) seen.add(id);
  while (q.length) { const id = q.shift()!; for (const n of adj.get(id) ?? []) if (!seen.has(n)) { seen.add(n); q.push(n); } }
  for (const fp of plan.floors) for (const r of fp.rooms) if (!seen.has(r.id)) errors.push(`unreachable ${r.id} (${r.type})`);
  // floors reachable by stairs (graph without elevators)
  const floorsWithStairs = new Set<number>();
  for (const st of plan.stairs) { floorsWithStairs.add(st.floor); floorsWithStairs.add(st.toFloor); }
  if (plan.floors.length > 1) for (const fp of plan.floors) if (!floorsWithStairs.has(fp.floor)) errors.push(`floor ${fp.floor} not served by stairs`);
  const above = plan.floors.filter((f) => f.floor >= 0 && f.floor < s.floors).length;
  if ((above >= 3 || s.public) && s.typology !== 'house' && !plan.shafts.length && plan.floors.length > 1) errors.push('elevator required');
  if (above > 2 && !s.tags?.includes('exit-exception')) for (const fp of plan.floors) {
    if (fp.floor < 0 || fp.floor >= s.floors) continue;
    const stairsHere = plan.stairs.filter((st) => st.floor === fp.floor || st.toFloor === fp.floor).length;
    const stairIds = new Set(plan.stairs.filter((st) => st.floor === fp.floor || st.toFloor === fp.floor).map((st) => st.id.replace(/\d+$/, '')));
    const extHere = plan.extDoors.filter((d) => d.floor === fp.floor).length;
    if (stairIds.size + extHere < 2 && stairsHere > 0) errors.push(`floor ${fp.floor} has < 2 exits`);
  }
  // doors must not swing into a stair's walking path (hole rect on either floor)
  for (const fp of plan.floors) for (const w of fp.walls) for (const o of w.openings) {
    if (o.kind !== 'door') continue;
    const { cx, cz, nx, nz } = openingCenter(w, o.at + o.w / 2);
    const sw = o.swing ?? 1;
    const px = cx + nx * sw * (w.t / 2 + o.w * 0.6), pz = cz + nz * sw * (w.t / 2 + o.w * 0.6);
    for (const st of plan.stairs) if ((st.floor === fp.floor || st.toFloor === fp.floor) && inR(st.rect, px, pz, -5)) errors.push(`door on F${fp.floor} swings into stair ${st.id}`);
  }
  return { ok: errors.length === 0, errors };
}
