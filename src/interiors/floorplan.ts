// Procedural floor plans (CLAUDE.md §7.3): double-loaded corridor, single-loaded corridor, open plan +
// core, shotgun commercial, center-hall house, atrium, parking. Rooms are rectangles tiling each floor's
// inner area (centerline coordinates); partitions are derived from shared room edges; doors are placed
// on those shared edges. Stairs/shafts are stacked through floors with slab holes.
import { Rng } from '../core/rng';
import { CORRIDOR, FTF, SHAFT, WALL, ceilingHeight, extWallT, finishFor, slabT } from './finishes';
import type { BuildingSpec, ExtDoor, FloorPlan, Opening, Plan, Rect, Room, RoomType, ShaftRec, StairRec, WallSeg, WindowRec } from './types';
import { solveRisers } from '../kits/stair';

export const STAIR_W = { public: 112, residential: 91 } as const;
const GAP = 10;

interface DoorReq { floor: number; a: Room; b: Room; where: 'mid' | 'start' | 'end'; w: number; style: string; }

/** Plan builder: rooms in centerline coords; walls & doors derived in finalize(). */
export class PB {
  rooms = new Map<number, Room[]>();
  doors: DoorReq[] = [];
  opens = new Set<string>();
  fire = new Set<string>();
  stairs: StairRec[] = [];
  shafts: ShaftRec[] = [];
  extDoors: ExtDoor[] = [];
  holes = new Map<number, Rect[]>();
  private n = 0;
  constructor(public spec: BuildingSpec) {}
  room(floor: number, r: Rect, type: RoomType, label?: string): Room {
    const rm: Room = { id: '', idx: this.n++, floor, rect: { ...r }, cl: { ...r }, type, label, finish: finishFor(this.spec.typology, type) };
    let a = this.rooms.get(floor); if (!a) this.rooms.set(floor, (a = [])); a.push(rm);
    return rm;
  }
  door(a: Room, b: Room, where: 'mid' | 'start' | 'end' = 'mid', w = 91, style?: string) {
    this.doors.push({ floor: a.floor, a, b, where, w, style: style ?? (w > 150 ? 'interiorGlass' : 'interior') });
  }
  open(a: Room, b: Room) { this.opens.add(pairKey(a, b)); }
  fireWall(a: Room) { this.fire.add(String(a.idx)); }
  hole(floor: number, r: Rect) { let a = this.holes.get(floor); if (!a) this.holes.set(floor, (a = [])); a.push({ ...r }); }
}
const pairKey = (a: Room, b: Room) => (a.idx < b.idx ? `${a.idx}-${b.idx}` : `${b.idx}-${a.idx}`);

/** Shared edge of two rects (centerline), or null. Returns segment a->b and orientation. */
function sharedEdge(A: Rect, B: Rect): { ax: number; az: number; bx: number; bz: number; axis: 'x' | 'z' } | null {
  const eps = 0.5;
  if (Math.abs(A.x1 - B.x0) < eps || Math.abs(A.x0 - B.x1) < eps) {
    const x = Math.abs(A.x1 - B.x0) < eps ? A.x1 : A.x0;
    const z0 = Math.max(A.z0, B.z0), z1 = Math.min(A.z1, B.z1);
    if (z1 - z0 > 1) return { ax: x, az: z0, bx: x, bz: z1, axis: 'z' };
  }
  if (Math.abs(A.z1 - B.z0) < eps || Math.abs(A.z0 - B.z1) < eps) {
    const z = Math.abs(A.z1 - B.z0) < eps ? A.z1 : A.z0;
    const x0 = Math.max(A.x0, B.x0), x1 = Math.min(A.x1, B.x1);
    if (x1 - x0 > 1) return { ax: x0, az: z, bx: x1, bz: z, axis: 'x' };
  }
  return null;
}

// ------------------------------------------------------------------------------------------ floors
export function floorStack(spec: BuildingSpec): { floor: number; y: number; ftf: number }[] {
  const [g, u] = FTF[spec.typology];
  const out: { floor: number; y: number; ftf: number }[] = [];
  if (spec.basement) out.push({ floor: -1, y: -330, ftf: 330 });
  let y = 0;
  for (let f = 0; f < spec.floors; f++) { const h = f === 0 ? g : u; out.push({ floor: f, y, ftf: h }); y += h; }
  if (spec.attic) out.push({ floor: spec.floors, y, ftf: 260 });
  return out;
}

// ------------------------------------------------------------------------------------------ stairs
/** Footprint of a U stair (flights + mid landing) for a floor-to-floor rise. */
export function uStairSize(rise: number, w: number): { across: number; along: number; run1: number } {
  const { n } = solveRisers(rise);
  const n1 = Math.ceil(n / 2);
  return { across: 2 * w + GAP, along: n1 * 28 + w, run1: n1 * 28 };
}

/** Stack U stairs through all floors inside a stair room column. `rect` is the hole (flights + landing). */
export function stackStairs(pb: PB, floors: { floor: number; y: number; ftf: number }[], hole: (rise: number) => Rect, dir: StairRec['dir'], w: number, id: string, upTo = Infinity) {
  for (let i = 0; i < floors.length - 1; i++) {
    const f = floors[i], g = floors[i + 1];
    if (g.floor > upTo) break;
    const rect = hole(f.ftf);
    pb.stairs.push({ id: `${id}${i}`, floor: f.floor, toFloor: g.floor, rect, kind: 'U', w, dir, rise: f.ftf });
    pb.hole(g.floor, rect);
  }
}

// ------------------------------------------------------------------------------------------ generators
type Fl = { floor: number; y: number; ftf: number };

function doubleLoaded(pb: PB, fl: Fl[], W: number, D: number, t: number, single = false) {
  const s = pb.spec, T = s.typology;
  const res = T === 'residence_historic' || T === 'residence_highrise' || T === 'inn';
  const cw = T === 'hospital' ? CORRIDOR.hospital : res ? CORRIDOR.residential : CORRIDOR.academic;
  const sw = res && T !== 'inn' ? STAIR_W.public : STAIR_W.public;
  const SW = 2 * sw + GAP + 30; // stair room width (x)
  const zc0 = single ? t : Math.round((D - cw) / 2), zc1 = zc0 + cw;
  const xL = t + SW, xR = W - t - SW;
  const module = T === 'hospital' ? 480 : T === 'residence_historic' || T === 'residence_highrise' ? 340 : T === 'inn' ? 400 : T === 'historic_academic' ? 640 : 380;
  const roomType = (floor: number, k: number, front: boolean): RoomType => {
    if (floor < 0) return k % 3 === 0 ? 'mechanical' : 'storage';
    if (floor >= s.floors) return 'attic';
    switch (T) {
      case 'hospital': return floor === 0 ? (k % 3 === 0 ? 'exam' : 'office') : floor === 1 && k % 4 === 0 ? 'or' : 'ward';
      case 'residence_historic': case 'residence_highrise': return k % 7 === 3 ? 'dorm_single' : 'dorm_double';
      case 'inn': return floor === 0 ? (front ? 'dining' : 'kitchen') : 'guest_room';
      case 'historic_academic': return front ? (k % 3 === 1 ? 'lecture' : 'classroom') : (k % 2 ? 'office' : 'classroom');
      default: return front ? 'classroom' : 'office';
    }
  };
  const elevator = s.floors >= 3 || s.public;
  const xm = Math.round(W / 2);
  for (const f of fl) {
    const F = f.floor;
    const attic = F >= s.floors;
    // end stair rooms (full depth) — two exits per floor
    const stL = pb.room(F, { x0: t, z0: t, x1: xL, z1: D - t }, 'stair', 'Stair A');
    const stR = pb.room(F, { x0: xR, z0: t, x1: W - t, z1: D - t }, 'stair', 'Stair B');
    pb.fireWall(stL); pb.fireWall(stR);
    const corr = pb.room(F, { x0: xL, z0: zc0, x1: xR, z1: zc1 }, attic ? 'attic' : 'corridor', attic ? 'Attic' : 'Corridor');
    pb.door(corr, stL, 'mid', 91, 'interiorGlass'); pb.door(corr, stR, 'mid', 91, 'interiorGlass');
    // service block: restrooms (front center) + elevator (back center)
    const rrW = Math.min(300, Math.max(240, module));
    const frontCuts: [number, number, RoomType, string][] = [];
    const backCuts: [number, number, RoomType, string][] = [];
    if (!attic) {
      if (F === 0) frontCuts.push([xm - module, xm + module, 'lobby', 'Lobby']);
      else frontCuts.push([xm - rrW, xm, 'restroom', 'Restroom'], [xm, xm + rrW, 'restroom', 'Restroom']);
      if (elevator) backCuts.push([xm - Math.round((SHAFT.w + 40) / 2), xm + Math.round((SHAFT.w + 40) / 2), 'elevator_lobby', 'Elevator']);
      if (F === 0) backCuts.push([xm + 200, xm + 200 + rrW, 'restroom', 'Restroom']);
    }
    const fillZone = (z0: number, z1: number, front: boolean, cuts: [number, number, RoomType, string][]) => {
      // split [xL, xR] into modules around cut intervals
      const segs: [number, number, RoomType | null, string][] = [];
      let x = xL;
      for (const [a, b, ty, lab] of [...cuts].sort((p, q) => p[0] - q[0])) { if (a > x) segs.push([x, a, null, '']); segs.push([a, b, ty, lab]); x = b; }
      if (x < xR) segs.push([x, xR, null, '']);
      let k = 0;
      for (const [a, b, ty, lab] of segs) {
        if (ty) {
          const r = pb.room(F, { x0: a, z0, x1: b, z1 }, ty, lab);
          if (ty === 'lobby') pb.open(r, corr); else if (ty === 'elevator_lobby') pb.open(r, corr); else pb.door(corr, r, 'mid');
          continue;
        }
        const n = Math.max(1, Math.round((b - a) / module));
        for (let i = 0; i < n; i++) {
          const x0 = Math.round(a + ((b - a) * i) / n), x1 = Math.round(a + ((b - a) * (i + 1)) / n);
          if (x1 - x0 < 150) continue;
          const r = pb.room(F, { x0, z0, x1, z1 }, attic ? 'attic' : roomType(F, k++, front), undefined);
          if (attic) pb.open(r, corr); else pb.door(corr, r, front ? 'start' : 'end');
        }
      }
    };
    if (!single) fillZone(t, zc0, true, frontCuts);
    fillZone(zc1, D - t, false, single ? [...frontCuts, ...backCuts.filter((c) => c[2] !== 'restroom')] : backCuts);
    if (elevator && !attic) {
      const ex0 = xm - Math.round((SHAFT.w + 40) / 2);
      pb.shafts.length === 0 && pb.shafts.push({ rect: { x0: ex0, z0: zc1 + 10, x1: ex0 + SHAFT.w + 40, z1: zc1 + 10 + SHAFT.d + 40 }, floors: [], door: 'z0' });
      pb.shafts[0].floors.push(F);
    }
    if (F === 0) {
      pb.extDoors.push({ floor: 0, side: 'front', at: xm - 91, w: 183, h: 213, style: s.facade.doorStyle, y: 0 });
      pb.extDoors.push({ floor: 0, side: 'left', at: Math.round(D / 2 - 45), w: 91, h: 213, style: 'steel', y: 0 });
      pb.extDoors.push({ floor: 0, side: 'right', at: Math.round(D / 2 - 45), w: 91, h: 213, style: 'steel', y: 0 });
    }
  }
  // U stairs inside each end room: flights along z, arrival zone at the corridor (center)
  const { along } = uStairSize(fl[0].ftf, sw);
  const across = 2 * sw + GAP;
  const lx = t + 15, rx = W - t - 15 - across;
  stackStairs(pb, fl, (rise) => ({ x0: lx, z0: zc1 + 10, x1: lx + across, z1: zc1 + 10 + uStairSize(rise, sw).along }), 'z+', sw, 'A');
  if (single) stackStairs(pb, fl, (rise) => ({ x0: rx, z0: zc1 + 10, x1: rx + across, z1: zc1 + 10 + uStairSize(rise, sw).along }), 'z+', sw, 'B');
  else stackStairs(pb, fl, (rise) => ({ x0: rx, z0: zc0 - 10 - uStairSize(rise, sw).along, x1: rx + across, z1: zc0 - 10 }), 'z-', sw, 'B');
  void along;
}

function shotgun(pb: PB, fl: Fl[], W: number, D: number, t: number) {
  const s = pb.spec;
  const sw = STAIR_W.residential + 21; // 112: commercial stairs serving apartments above
  const across = 2 * sw + GAP;
  const coreW = across + 30;
  const hall = 120;
  const elevator = s.floors >= 3;
  const maxRise = Math.max(...fl.map((f) => f.ftf));
  const coreD = uStairSize(maxRise, sw).along + sw + 40;
  const zCore = D - t - coreD;
  const xs = t + hall; // side hall along the left party wall
  for (const f of fl) {
    const F = f.floor;
    const core = pb.room(F, { x0: t, z0: zCore, x1: t + coreW, z1: D - t }, 'stair', 'Stair');
    pb.fireWall(core);
    let shaftRoom: Room | null = null;
    if (elevator && F >= 0 && F < s.floors) {
      shaftRoom = pb.room(F, { x0: t + coreW, z0: zCore, x1: t + coreW + SHAFT.w + 60, z1: D - t }, 'elevator_lobby', 'Elevator');
      if (!pb.shafts.length) pb.shafts.push({ rect: { x0: t + coreW + 10, z0: D - t - SHAFT.d - 40, x1: t + coreW + 10 + SHAFT.w + 40, z1: D - t }, floors: [], door: 'z0' });
      pb.shafts[0].floors.push(F);
    }
    if (F < 0) {
      const cel = pb.room(F, { x0: t, z0: t, x1: W - t, z1: zCore }, 'cellar', 'Basement');
      pb.door(cel, core, 'start');
      if (W - t - (t + coreW) > 150) { const st = pb.room(F, { x0: t + coreW, z0: zCore, x1: W - t, z1: D - t }, 'mechanical', 'Mechanical'); pb.door(cel, st, 'end'); }
      continue;
    }
    if (F >= s.floors) { // attic
      const at = pb.room(F, { x0: t, z0: t, x1: W - t, z1: zCore }, 'attic', 'Attic'); pb.door(at, core, 'start');
      if (W - t - (t + coreW) > 150) { const a2 = pb.room(F, { x0: t + coreW, z0: zCore, x1: W - t, z1: D - t }, 'attic'); pb.open(a2, at); }
      continue;
    }
    const hallR = pb.room(F, { x0: t, z0: t, x1: xs, z1: zCore }, 'hall', F === 0 ? 'Stair hall' : 'Hall');
    pb.open(hallR, core);
    const rx0 = xs, rx1 = W - t;
    const backZ0 = shaftRoom ? shaftRoom.rect.z0 : zCore;
    if (F === 0) {
      const biz = s.business?.type ?? 'retail';
      const main: RoomType = biz === 'bar' ? 'bar' : biz === 'cafe' ? 'cafe' : biz === 'diner' ? 'dining' : biz === 'bank' ? 'banking_hall' : biz === 'cinema' ? 'lobby' : 'retail_floor';
      const front = pb.room(F, { x0: rx0, z0: t, x1: rx1, z1: Math.round(zCore - (zCore - t) * 0.28) }, main, s.business?.name);
      const back = pb.room(F, { x0: rx0, z0: front.rect.z1, x1: rx1, z1: zCore }, biz === 'bar' || biz === 'diner' || biz === 'cafe' || biz === 'pizza' || biz === 'takeout' ? 'kitchen' : biz === 'bank' ? 'vault' : 'stockroom');
      pb.door(front, back, 'end');
      pb.door(hallR, front, 'start', 91, 'interiorGlass');
      // back strip beside the core: restroom (+ elevator)
      const bx0 = shaftRoom ? shaftRoom.rect.x1 : t + coreW;
      if (rx1 - bx0 > 160) { const rr = pb.room(F, { x0: bx0, z0: zCore, x1: rx1, z1: D - t }, 'restroom'); pb.door(back, rr, 'end'); }
      if (shaftRoom) pb.open(shaftRoom, core);
      pb.extDoors.push({ floor: 0, side: 'front', at: rx0 + Math.round((rx1 - rx0) / 2) - 45, w: 91, h: 213, style: 'storefront', y: 0 });
      pb.extDoors.push({ floor: 0, side: 'front', at: t + 15, w: 91, h: 213, style: s.facade.doorStyle, y: 0 });
      pb.extDoors.push({ floor: 0, side: 'back', at: Math.round(t + coreW / 2) - 45, w: 91, h: 213, style: 'steel', y: 0 });
    } else {
      const apt = s.upperUse !== 'offices';
      const zA = Math.round(t + (zCore - t) * 0.48);
      const r1 = pb.room(F, { x0: rx0, z0: t, x1: rx1, z1: zA }, apt ? 'apartment_living' : 'office');
      const zB = Math.round(zA + (zCore - zA) * 0.6);
      const r2 = pb.room(F, { x0: rx0, z0: zA, x1: rx1, z1: zB }, apt ? 'apartment_bed' : 'office');
      const r3w = Math.round((rx1 - rx0) * 0.5);
      const r3 = pb.room(F, { x0: rx0, z0: zB, x1: rx0 + r3w, z1: zCore }, apt ? 'apartment_kitchen' : 'office');
      const r4 = pb.room(F, { x0: rx0 + r3w, z0: zB, x1: rx1, z1: zCore }, apt ? 'apartment_bath' : 'restroom');
      pb.door(hallR, r1, 'start'); pb.door(hallR, r2, 'mid'); pb.door(hallR, r3, 'end'); pb.door(r3, r4, 'mid');
      const bx0 = shaftRoom ? shaftRoom.rect.x1 : t + coreW;
      if (shaftRoom) pb.open(shaftRoom, core);
      if (rx1 - bx0 > 160) { const st = pb.room(F, { x0: bx0, z0: zCore, x1: rx1, z1: D - t }, apt ? 'laundry' : 'storage'); pb.door(core, st, 'end'); }
      // rear fire-escape door (second exit for > 2 floors)
      pb.extDoors.push({ floor: F, side: 'back', at: Math.round(t + coreW / 2) - 45, w: 91, h: 213, style: 'steel', y: f.y });
    }
  }
  stackStairs(pb, fl, (rise) => ({ x0: t + 15, z0: D - t - 15 - uStairSize(rise, sw).along, x1: t + 15 + across, z1: D - t - 15 }), 'z+', sw, 'S');
  // fix direction: arrival zone is toward the front (z-), flights rise toward the back
}

function centerHall(pb: PB, fl: Fl[], W: number, D: number, t: number) {
  const s = pb.spec;
  const sw = STAIR_W.residential;
  const hw = 220; // center hall width
  const xh0 = Math.round(W / 2 - hw / 2), xh1 = xh0 + hw;
  const twoStory = s.floors >= 2 || s.basement || s.attic;
  const elevator = s.floors >= 3 || !!s.public;
  for (const f of fl) {
    const F = f.floor;
    const hall = pb.room(F, { x0: xh0, z0: t, x1: xh1, z1: D - t }, F >= s.floors ? 'attic' : F < 0 ? 'cellar' : twoStory ? 'stair' : 'hall', F === 0 ? 'Center hall' : 'Hall');
    const zm = Math.round(D * 0.55);
    if (F < 0 || F >= s.floors) {
      const a = pb.room(F, { x0: t, z0: t, x1: xh0, z1: D - t }, F < 0 ? 'mechanical' : 'attic');
      const b = pb.room(F, { x0: xh1, z0: t, x1: W - t, z1: D - t }, F < 0 ? 'storage' : 'attic');
      if (F < 0) { pb.door(hall, a, 'mid'); pb.door(hall, b, 'mid'); } else { pb.open(hall, a); pb.open(hall, b); }
      continue;
    }
    const inn = s.typology === 'inn';
    const L1: RoomType = F === 0 ? (inn ? 'lobby' : 'living') : inn ? 'guest_room' : 'bedroom';
    const R1: RoomType = F === 0 ? (inn ? 'dining' : 'dining') : inn ? 'guest_room' : 'bedroom';
    const L2: RoomType = F === 0 ? (inn ? 'office' : 'study') : inn ? 'guest_room' : 'bath';
    const R2: RoomType = F === 0 ? 'kitchen' : inn ? 'guest_room' : 'bedroom';
    const a = pb.room(F, { x0: t, z0: t, x1: xh0, z1: zm }, L1), b = pb.room(F, { x0: xh1, z0: t, x1: W - t, z1: zm }, R1);
    const c = pb.room(F, { x0: t, z0: zm, x1: xh0, z1: D - t }, L2), d = pb.room(F, { x0: xh1, z0: zm, x1: W - t, z1: D - t }, R2);
    pb.door(hall, a, 'start'); pb.door(hall, b, 'start'); pb.door(hall, c, 'mid'); pb.door(hall, d, 'mid');
    if (F === 0) {
      pb.door(b, d, 'end');
      pb.extDoors.push({ floor: 0, side: 'front', at: xh0 + Math.round(hw / 2) - (inn ? 91 : 53), w: inn ? 183 : 107, h: inn ? 213 : 244, style: s.facade.doorStyle, y: 0 });
      pb.extDoors.push({ floor: 0, side: 'back', at: Math.round(W - t - 160), w: 91, h: 213, style: s.facade.doorStyle, y: 0 });
    }
    if (F >= 1 && s.floors >= 3) pb.extDoors.push({ floor: F, side: 'back', at: xh0 + 20, w: 91, h: 213, style: 'steel', y: f.y });
  }
  if (elevator) {
    // tuck a shaft into the back of the hall
    pb.shafts.push({ rect: { x0: Math.round(W / 2 - (SHAFT.w + 40) / 2), z0: D - t - SHAFT.d - 40, x1: Math.round(W / 2 + (SHAFT.w + 40) / 2), z1: D - t }, floors: fl.filter((f) => f.floor >= 0 && f.floor < s.floors).map((f) => f.floor), door: 'z0' });
  }
  if (twoStory) {
    // straight-run stairs along the hall: alternating direction each floor so they stack
    for (let i = 0; i < fl.length - 1; i++) {
      const f = fl[i], g = fl[i + 1];
      const { n } = solveRisers(f.ftf);
      const run = n * 28;
      const z0 = t + 140;
      const x0 = i % 2 === 0 ? xh0 + 15 : xh1 - 15 - sw;
      const rect: Rect = { x0, z0, x1: x0 + sw, z1: z0 + run };
      pb.stairs.push({ id: `H${i}`, floor: f.floor, toFloor: g.floor, rect, kind: 'straight', w: sw, dir: i % 2 === 0 ? 'z+' : 'z-', rise: f.ftf });
      pb.hole(g.floor, rect);
    }
  }
}

function openCore(pb: PB, fl: Fl[], W: number, D: number, t: number) {
  const s = pb.spec;
  const sw = STAIR_W.public, across = 2 * sw + GAP;
  const maxRise = Math.max(...fl.map((f) => f.ftf));
  const sd = uStairSize(maxRise, sw).along + sw + 30;
  const coreD = Math.max(sd, SHAFT.d + 60);
  const cz0 = Math.round(D / 2 - coreD / 2), cz1 = cz0 + coreD;
  const xm = Math.round(W / 2);
  const cells: [number, number, RoomType, string][] = [
    [xm - across - 30 - 260 - SHAFT.w - 60, xm - 260 - SHAFT.w - 60, 'stair', 'Stair A'],
    [xm - 260 - SHAFT.w - 60, xm - 260, 'elevator_lobby', 'Elevator'],
    [xm - 260, xm, 'restroom', 'Restroom'], [xm, xm + 260, 'restroom', 'Restroom'],
    [xm + 260, xm + 260 + across + 30, 'stair', 'Stair B'],
  ];
  if (cells[0][0] - t < 250) { cells[0][0] = t; cells[cells.length - 1][1] = W - t; }
  const coreX0 = cells[0][0], coreX1 = cells[cells.length - 1][1];
  const wings = coreX0 - t >= 250;
  for (const f of fl) {
    const F = f.floor;
    const attic = F >= s.floors;
    const mainType: RoomType = F < 0 ? 'mechanical' : attic ? 'attic' : F === 0 ? 'lobby' : s.typology === 'library' ? 'stacks' : s.typology === 'modern_academic' ? 'classroom' : 'office';
    const mill = s.typology === 'mill' && F === 0; // §9.9: co-op market on the mill's ground floor
    const front = pb.room(F, { x0: t, z0: t, x1: W - t, z1: cz0 }, mill ? 'retail_floor' : mainType, mill ? 'Co-op Market' : F === 0 ? 'Lobby' : undefined);
    const back = pb.room(F, { x0: t, z0: cz1, x1: W - t, z1: D - t }, mill ? 'stockroom' : F === 0 ? (s.typology === 'office_lab' ? 'office' : 'dining') : mainType, mill ? 'Co-op stockroom' : undefined);
    if (wings) {
      const wl = pb.room(F, { x0: t, z0: cz0, x1: coreX0, z1: cz1 }, F === 0 ? 'office' : mainType === 'stacks' ? 'study' : 'office');
      const wr = pb.room(F, { x0: coreX1, z0: cz0, x1: W - t, z1: cz1 }, F === 0 ? 'office' : mainType === 'stacks' ? 'study' : 'office');
      pb.open(front, wl); pb.open(front, wr); pb.door(wl, back, 'mid'); pb.door(wr, back, 'mid');
    }
    for (const [a, b, ty, lab] of cells) {
      const r = pb.room(F, { x0: a, z0: cz0, x1: b, z1: cz1 }, ty, lab);
      if (ty === 'stair') { pb.fireWall(r); pb.door(front, r, 'mid', 91, 'interiorGlass'); if (!wings) pb.door(r, back, 'mid', 91, 'interiorGlass'); }
      else if (ty === 'elevator_lobby') pb.open(front, r);
      else pb.door(front, r, 'mid');
    }
    if (F === 0) {
      pb.extDoors.push({ floor: 0, side: 'front', at: xm - 91, w: 183, h: 213, style: s.facade.doorStyle, y: 0 });
      pb.extDoors.push({ floor: 0, side: 'back', at: xm - 45, w: 91, h: 213, style: 'steel', y: 0 });
    }
  }
  pb.shafts.push({ rect: { x0: cells[1][0] + 10, z0: cz1 - SHAFT.d - 50, x1: cells[1][0] + 10 + SHAFT.w + 40, z1: cz1 - 10 }, floors: fl.filter((f) => f.floor >= 0 && f.floor < s.floors).map((f) => f.floor), door: 'z0' });
  for (const [i, c] of [cells[0], cells[cells.length - 1]].entries()) {
    const x0 = c[0] + 15;
    stackStairs(pb, fl, (rise) => ({ x0, z0: cz1 - 15 - uStairSize(rise, sw).along, x1: x0 + across, z1: cz1 - 15 }), 'z+', sw, i ? 'B' : 'A');
  }
}

function atrium(pb: PB, fl: Fl[], W: number, D: number, t: number) {
  const s = pb.spec;
  const ring = Math.min(900, Math.round(Math.min(W, D) * 0.28));
  const ax0 = t + ring, ax1 = W - t - ring, az0 = t + ring, az1 = D - t - ring;
  const sw = STAIR_W.public, across = 2 * sw + GAP;
  for (const f of fl) {
    const F = f.floor;
    const ty: RoomType = F < 0 ? 'storage' : F === 0 ? 'reading_room' : s.typology === 'library' ? 'stacks' : 'office';
    const fr = pb.room(F, { x0: t, z0: t, x1: W - t, z1: az0 }, F === 0 ? 'lobby' : ty);
    const bk = pb.room(F, { x0: t, z0: az1, x1: W - t, z1: D - t }, ty);
    const lf = pb.room(F, { x0: t, z0: az0, x1: ax0, z1: az1 }, F > 0 ? 'study' : ty);
    const rt = pb.room(F, { x0: ax1, z0: az0, x1: W - t, z1: az1 }, F > 0 ? 'study' : ty);
    const at = pb.room(F, { x0: ax0, z0: az0, x1: ax1, z1: az1 }, F === 0 ? 'court' : 'gallery', F === 0 ? 'Atrium' : 'Atrium void');
    pb.open(fr, lf); pb.open(fr, rt); pb.open(bk, lf); pb.open(bk, rt); pb.open(fr, at); pb.open(at, lf); pb.open(at, rt); pb.open(at, bk);
    if (F > 0) pb.hole(F, { x0: ax0 + 120, z0: az0 + 120, x1: ax1 - 120, z1: az1 - 120 });
    if (F === 0) {
      pb.extDoors.push({ floor: 0, side: 'front', at: Math.round(W / 2) - 91, w: 183, h: 213, style: s.facade.doorStyle, y: 0 });
      pb.extDoors.push({ floor: 0, side: 'back', at: Math.round(W / 2) - 45, w: 91, h: 213, style: 'steel', y: 0 });
    }
  }
  // stairs in the front corners of the side rooms, elevator beside
  stackStairs(pb, fl, (rise) => ({ x0: t + 30, z0: az0 + 30, x1: t + 30 + across, z1: az0 + 30 + uStairSize(rise, sw).along }), 'z+', sw, 'A');
  stackStairs(pb, fl, (rise) => ({ x0: W - t - 30 - across, z0: az0 + 30, x1: W - t - 30, z1: az0 + 30 + uStairSize(rise, sw).along }), 'z+', sw, 'B');
  pb.shafts.push({ rect: { x0: t + 30, z0: az1 - 30 - SHAFT.d - 40, x1: t + 30 + SHAFT.w + 40, z1: az1 - 30 }, floors: fl.filter((f) => f.floor >= 0).map((f) => f.floor), door: 'x1' });
}

function parking(pb: PB, fl: Fl[], W: number, D: number, t: number) {
  const s = pb.spec;
  const sw = STAIR_W.public, across = 2 * sw + GAP;
  const sd = uStairSize(330, sw).along + sw + 30;
  for (const f of fl) {
    const F = f.floor;
    const sA = pb.room(F, { x0: t, z0: t, x1: t + across + 30, z1: t + sd }, 'stair', 'Stair A');
    const sB = pb.room(F, { x0: W - t - across - 30, z0: D - t - sd, x1: W - t, z1: D - t }, 'stair', 'Stair B');
    const el = pb.room(F, { x0: t + across + 30, z0: t, x1: t + across + 30 + SHAFT.w + 60, z1: t + SHAFT.d + 60 }, 'elevator_lobby', 'Elevator');
    const deck = pb.room(F, { x0: t, z0: t + sd, x1: W - t, z1: D - t - sd }, 'parking', `Level ${F + 1}`);
    const n1 = pb.room(F, { x0: t + across + 30 + SHAFT.w + 60, z0: t, x1: W - t, z1: t + sd }, 'parking');
    const n2 = pb.room(F, { x0: t, z0: D - t - sd, x1: W - t - across - 30, z1: D - t }, 'parking');
    pb.open(deck, n1); pb.open(deck, n2); pb.open(n1, el); pb.open(sA, deck); pb.door(deck, sB, 'mid'); pb.open(el, sA);
    pb.fireWall(sA); pb.fireWall(sB);
    if (F === 0) {
      pb.extDoors.push({ floor: 0, side: 'front', at: Math.round(W / 2) - 300, w: 600, h: 260, style: 'none', y: 0 });
      pb.extDoors.push({ floor: 0, side: 'left', at: t + 40, w: 91, h: 213, style: 'steel', y: 0 });
      pb.extDoors.push({ floor: 0, side: 'right', at: D - t - 140, w: 91, h: 213, style: 'steel', y: 0 });
    }
  }
  pb.shafts.push({ rect: { x0: t + across + 40, z0: t + 10, x1: t + across + 40 + SHAFT.w + 40, z1: t + 10 + SHAFT.d + 40 }, floors: fl.map((f) => f.floor), door: 'z1' });
  stackStairs(pb, fl, (rise) => ({ x0: t + 15, z0: t + 15, x1: t + 15 + across, z1: t + 15 + uStairSize(rise, sw).along }), 'z+', sw, 'A');
  stackStairs(pb, fl, (rise) => ({ x0: W - t - 15 - across, z0: D - t - 15 - uStairSize(rise, sw).along, x1: W - t - 15, z1: D - t - 15 }), 'z-', sw, 'B');
  // vehicle ramps (5 %) in a hole strip along the back of the deck
  for (let i = 0; i < fl.length - 1; i++) pb.hole(fl[i + 1].floor, { x0: t + 600, z0: D - t - sd - 650, x1: W - t - 600, z1: D - t - sd - 50 });
}

/** Hand-authored plan via the plan builder (landmarks). */
export function customPlan(spec: BuildingSpec, fn: (pb: PB, fl: Fl[], W: number, D: number, t: number) => void): Plan {
  const pb = new PB(spec);
  const fl = floorStack(spec);
  fn(pb, fl, spec.w, spec.d, extWallT(spec.typology, 0));
  return finalize(pb, fl, spec.w, spec.d);
}
export type { Fl };

// ------------------------------------------------------------------------------------------ main
export function generatePlan(spec: BuildingSpec): Plan {
  const pb = new PB(spec);
  const fl = floorStack(spec);
  const W = spec.w, D = spec.d;
  const t = extWallT(spec.typology, 0);
  let kind = spec.plan;
  if (kind === 'double_loaded' && D < 2 * 460 + CORRIDOR.academic + 2 * t) kind = 'single_loaded';
  switch (kind) {
    case 'double_loaded': doubleLoaded(pb, fl, W, D, t); break;
    case 'single_loaded': doubleLoaded(pb, fl, W, D, t, true); break;
    case 'shotgun': shotgun(pb, fl, W, D, t); break;
    case 'center_hall': centerHall(pb, fl, W, D, t); break;
    case 'atrium': atrium(pb, fl, W, D, t); break;
    case 'parking': parking(pb, fl, W, D, t); break;
    default: openCore(pb, fl, W, D, t);
  }
  return finalize(pb, fl, W, D);
}

/** Derive partition walls & doors, shrink rooms to wall faces, expand to each floor's exterior inset. */
export function finalize(pb: PB | PlanBuilderLike, fl: Fl[], W: number, D: number): Plan {
  const spec = pb.spec;
  const t0 = extWallT(spec.typology, 0);
  const floors: FloorPlan[] = [];
  for (const f of fl) {
    const rooms = pb.rooms.get(f.floor) ?? [];
    const walls: WallSeg[] = [];
    const tF = extWallT(spec.typology, f.floor);
    for (let i = 0; i < rooms.length; i++) for (let j = i + 1; j < rooms.length; j++) {
      const A = rooms[i], B = rooms[j];
      const e = sharedEdge(A.rect, B.rect);
      if (!e) continue;
      if (pb.opens.has(pairKey(A, B))) continue;
      const fire = pb.fire.has(String(A.idx)) || pb.fire.has(String(B.idx)) || A.type === 'elevator_lobby' && B.type === 'stair';
      const w: WallSeg = { floor: f.floor, ax: e.ax, az: e.az, bx: e.bx, bz: e.bz, t: fire ? WALL.fire : WALL.partition, kind: fire ? 'fire' : 'part', openings: [] };
      // doors requested between A and B
      for (const d of pb.doors) {
        if (!((d.a === A && d.b === B) || (d.a === B && d.b === A))) continue;
        const L = Math.hypot(e.bx - e.ax, e.bz - e.az);
        const dw = Math.min(d.w, L - 40);
        if (dw < 81) continue;
        const at = d.where === 'start' ? 30 : d.where === 'end' ? L - 30 - dw : Math.round(L / 2 - dw / 2);
        // swing into the second room of the request (b)
        const into = d.b;
        const cx = (e.ax + e.bx) / 2, cz = (e.az + e.bz) / 2;
        const nx = -(e.bz - e.az) / L, nz = (e.bx - e.ax) / L;
        const bc = { x: (into.rect.x0 + into.rect.x1) / 2, z: (into.rect.z0 + into.rect.z1) / 2 };
        const swing: 1 | -1 = (bc.x - cx) * nx + (bc.z - cz) * nz > 0 ? 1 : -1;
        w.openings.push({ at, w: dw, h: 213, sill: 0, kind: 'door', style: d.style, swing });
      }
      walls.push(w);
    }
    // shrink rooms to wall faces; expand exterior-touching edges to this floor's inset
    for (const r of rooms) {
      const R = r.rect;
      for (const w of walls) {
        const vertical = w.ax === w.bx;
        const half = w.t / 2;
        if (vertical) {
          if (Math.abs(R.x0 - w.ax) < 0.5 && overlap(R.z0, R.z1, w.az, w.bz)) R.x0 = w.ax + half;
          if (Math.abs(R.x1 - w.ax) < 0.5 && overlap(R.z0, R.z1, w.az, w.bz)) R.x1 = w.ax - half;
        } else {
          if (Math.abs(R.z0 - w.az) < 0.5 && overlap(R.x0, R.x1, w.ax, w.bx)) R.z0 = w.az + half;
          if (Math.abs(R.z1 - w.az) < 0.5 && overlap(R.x0, R.x1, w.ax, w.bx)) R.z1 = w.az - half;
        }
      }
      if (tF !== t0) {
        for (const Q of [R, r.cl]) {
          if (Math.abs(Q.x0 - t0) < 0.5) Q.x0 = tF; if (Math.abs(Q.x1 - (W - t0)) < 0.5) Q.x1 = W - tF;
          if (Math.abs(Q.z0 - t0) < 0.5) Q.z0 = tF; if (Math.abs(Q.z1 - (D - t0)) < 0.5) Q.z1 = D - tF;
        }
      }
    }
    if (tF !== t0) for (const w of walls) {
      if (w.ax === w.bx) { if (Math.abs(w.az - t0) < 0.5) w.az = tF; if (Math.abs(w.bz - (D - t0)) < 0.5) w.bz = D - tF; }
      else { if (Math.abs(w.ax - t0) < 0.5) w.ax = tF; if (Math.abs(w.bx - (W - t0)) < 0.5) w.bx = W - tF; }
    }
    rooms.forEach((r, i) => { r.id = `CM_${spec.id}_F${f.floor}_R${i}`; });
    floors.push({ floor: f.floor, y: f.y, ftf: f.ftf, slab: slabT(spec.typology), ceiling: f.floor >= spec.floors ? f.ftf : ceilingHeight(spec.typology, f.ftf), extT: tF, rooms, walls, holes: pb.holes.get(f.floor) ?? [] });
  }
  const windows = facadeWindows(spec, floors, pb.extDoors, W, D);
  const byIdx = new Map<number, Room>();
  for (const f of floors) for (const r of f.rooms) byIdx.set(r.idx, r);
  const links: [string, string][] = [];
  for (const k of pb.opens) { const [a, b] = k.split('-').map(Number); const A = byIdx.get(a), B = byIdx.get(b); if (A && B) links.push([A.id, B.id]); }
  const top = fl.filter((f) => f.floor < spec.floors);
  const last = top[top.length - 1];
  return { spec, floors, stairs: pb.stairs, shafts: pb.shafts, extDoors: pb.extDoors, windows, roofY: last.y + last.ftf, links };
}
export interface PlanBuilderLike { spec: BuildingSpec; rooms: Map<number, Room[]>; doors: DoorReq[]; opens: Set<string>; fire: Set<string>; stairs: StairRec[]; shafts: ShaftRec[]; extDoors: ExtDoor[]; holes: Map<number, Rect[]>; }
const overlap = (a0: number, a1: number, b0: number, b1: number) => Math.min(a1, Math.max(b0, b1)) - Math.max(a0, Math.min(b0, b1)) > 1;

/** Window placement on each facade by bay (skips party walls, doors and storefront zones). */
export function facadeWindows(spec: BuildingSpec, floors: FloorPlan[], doors: ExtDoor[], W: number, D: number): WindowRec[] {
  const out: WindowRec[] = [];
  const f = spec.facade;
  if (f.window === 'none') return out;
  const rng = new Rng(spec.seed + ':win');
  const sides: { side: WindowRec['side']; len: number }[] = [{ side: 'front', len: W }, { side: 'back', len: W }];
  if (!spec.party?.left) sides.push({ side: 'left', len: D });
  if (!spec.party?.right) sides.push({ side: 'right', len: D });
  for (const fp of floors) {
    if (fp.floor >= spec.floors && spec.facade.roof !== 'flat') continue; // attic: dormers handled by roof
    for (const { side, len } of sides) {
      if (fp.floor === 0 && side === 'front' && f.storefront) continue;
      const bay = f.bay;
      const n = Math.max(1, Math.floor((len - 80) / bay));
      const start = (len - n * bay) / 2;
      const basement = fp.floor < 0;
      if (basement && !f.basementWindows) continue;
      const wh = basement ? 46 : fp.floor >= spec.floors ? Math.min(f.winH, 120) : Math.min(f.winH, fp.ftf - 120);
      const ww = basement ? 81 : f.winW;
      const sill = basement ? fp.ftf - 60 : fp.floor === 0 ? Math.max(76, Math.round((fp.ftf - wh) * 0.45)) : Math.round((fp.ftf - wh) * 0.42);
      for (let i = 0; i < n; i++) {
        const at = Math.round(start + i * bay + (bay - ww) / 2);
        if (doors.some((d) => d.side === side && d.floor === fp.floor && at < d.at + d.w + 30 && at + ww > d.at - 30)) continue;
        if (side !== 'front' && side !== 'back' && rng.chance(0.15)) continue;
        out.push({ floor: fp.floor, side, at, w: ww, h: wh, sill, type: basement ? 'hopper' : f.window });
      }
    }
  }
  return out;
}

