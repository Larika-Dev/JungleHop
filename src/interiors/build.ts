// Interior geometry (CLAUDE.md §7): floors, ceilings (plaster / suspended grid with emissive panels),
// partitions with per-side finishes (wainscot, tile to 150 cm, hospital band, baseboards, crown), door
// casings, stairs with handrails and guards, elevator shafts, interior glass, room metadata objects,
// and the collision data for walls / floors / stair ramps. Building-local meters.
import { Group, Object3D, Vector3 } from 'three';
import { GeoBuilder } from '../core/geo';
import { mat } from '../core/materials';
import { C, bar, boxC } from '../kits/common';
import { wallWithOpenings } from '../kits/brick';
import { interiorCasing } from '../kits/door';
import { corniceStraight, PROFILES } from '../kits/cornice';
import { elevatorShaft } from '../kits/interior';
import { flight, solveRisers, straightStair } from '../kits/stair';
import { wallHandrail } from '../kits/railing';
import { sideFrame } from '../buildings/exterior';
import type { ExteriorOut } from '../buildings/exterior';
import { roomAt, openingCenter } from './validate';
import { roomMeta, roomObject } from './roomMeta';
import type { FloorPlan, Plan, Rect, Room, StairRec, WallSeg } from './types';

const GAP = 10;

export interface InteriorCollision {
  walls: [number, number, number, number, number, number, number][]; // local m: ax, az, bx, bz, y0, y1, t
  floors: Vector3[][]; // local m polygons (plane through first 3 points)
}
export interface InteriorDoor { hinge: Vector3; yaw: number; style: string; w: number; h: number; swing: 1 | -1; floor: number; }
export interface InteriorOut { group: Group; floorGroups: Map<number, Group>; rooms: Object3D[]; doors: InteriorDoor[]; }

export function subtractRects(r: Rect, holes: Rect[]): Rect[] {
  let parts: Rect[] = [r];
  for (const h of holes) {
    const next: Rect[] = [];
    for (const p of parts) {
      if (h.x1 <= p.x0 || h.x0 >= p.x1 || h.z1 <= p.z0 || h.z0 >= p.z1) { next.push(p); continue; }
      if (h.z0 > p.z0) next.push({ x0: p.x0, z0: p.z0, x1: p.x1, z1: h.z0 });
      if (h.z1 < p.z1) next.push({ x0: p.x0, z0: h.z1, x1: p.x1, z1: p.z1 });
      const z0 = Math.max(p.z0, h.z0), z1 = Math.min(p.z1, h.z1);
      if (h.x0 > p.x0) next.push({ x0: p.x0, z0, x1: h.x0, z1 });
      if (h.x1 < p.x1) next.push({ x0: h.x1, z0, x1: p.x1, z1 });
    }
    parts = next;
  }
  return parts.filter((p) => p.x1 - p.x0 > 1 && p.z1 - p.z0 > 1);
}

const wallAngle = (w: { ax: number; az: number; bx: number; bz: number }) => Math.atan2(-(w.bz - w.az), w.bx - w.ax);

/** Holes on a floor = stair holes + shafts passing through it. */
function floorHoles(plan: Plan, fp: FloorPlan): Rect[] {
  const h = [...fp.holes];
  for (const s of plan.shafts) if (s.floors.includes(fp.floor)) h.push(s.rect);
  return h;
}

// ------------------------------------------------------------------------------------------ collision (data only)
export function interiorCollision(plan: Plan): InteriorCollision {
  const out: InteriorCollision = { walls: [], floors: [] };
  for (const fp of plan.floors) {
    const holes = floorHoles(plan, fp);
    for (const r of fp.rooms) for (const p of subtractRects(r.cl, holes)) out.floors.push(rectPoly(p, fp.y));
    for (const w of fp.walls) {
      const L = Math.hypot(w.bx - w.ax, w.bz - w.az);
      const ux = (w.bx - w.ax) / L, uz = (w.bz - w.az) / L;
      const cuts = w.openings.filter((o) => o.kind !== 'window').map((o) => [o.at, o.at + o.w]).sort((a, b) => a[0] - b[0]);
      let s = 0;
      const seg = (s0: number, s1: number) => { if (s1 - s0 > 1) out.walls.push([C(w.ax + ux * s0), C(w.az + uz * s0), C(w.ax + ux * s1), C(w.az + uz * s1), C(fp.y), C(fp.y + fp.ftf), C(w.t)]); };
      for (const [a, b] of cuts) { seg(s, a); s = b; }
      seg(s, L);
    }
  }
  for (const st of plan.stairs) stairCollision(st, plan, out);
  for (const sh of plan.shafts) {
    const r = sh.rect, ys = plan.floors.filter((f) => sh.floors.includes(f.floor));
    const y0 = C(Math.min(...ys.map((f) => f.y)) - 150), y1 = C(Math.max(...ys.map((f) => f.y + f.ftf)));
    for (const [ax, az, bx, bz] of [[r.x0, r.z0, r.x1, r.z0], [r.x1, r.z0, r.x1, r.z1], [r.x1, r.z1, r.x0, r.z1], [r.x0, r.z1, r.x0, r.z0]]) out.walls.push([C(ax), C(az), C(bx), C(bz), y0, y1, 0.2]);
  }
  return out;
}
function rectPoly(p: Rect, ycm: number): Vector3[] {
  const y = C(ycm);
  return [new Vector3(C(p.x0), y, C(p.z0)), new Vector3(C(p.x1), y, C(p.z0)), new Vector3(C(p.x1), y, C(p.z1)), new Vector3(C(p.x0), y, C(p.z1))];
}

/** Stair local frame -> building local (cm). */
function stairFrame(st: StairRec): { ox: number; oz: number; theta: number } {
  const r = st.rect;
  switch (st.dir) {
    case 'z+': return { ox: r.x0, oz: r.z0, theta: 0 };
    case 'z-': return { ox: r.x1, oz: r.z1, theta: Math.PI };
    case 'x+': return { ox: r.x0, oz: r.z1, theta: Math.PI / 2 };
    case 'x-': return { ox: r.x1, oz: r.z0, theta: -Math.PI / 2 };
  }
}
function stairPt(st: StairRec, x: number, y: number, z: number, y0: number): Vector3 {
  const f = stairFrame(st), c = Math.cos(f.theta), s = Math.sin(f.theta);
  return new Vector3(C(f.ox + x * c + z * s), C(y0 + y), C(f.oz - x * s + z * c));
}
function stairCollision(st: StairRec, plan: Plan, out: InteriorCollision) {
  const fp = plan.floors.find((f) => f.floor === st.floor)!;
  const { n, riser } = solveRisers(st.rise);
  const w = st.w;
  if (st.kind === 'straight') {
    const run = n * 28;
    out.floors.push([stairPt(st, 0, 0, 0, fp.y), stairPt(st, w, 0, 0, fp.y), stairPt(st, w, st.rise, run, fp.y), stairPt(st, 0, st.rise, run, fp.y)]);
    return;
  }
  const n1 = Math.ceil(n / 2), n2 = n - n1, run1 = n1 * 28, ly = n1 * riser;
  out.floors.push([stairPt(st, 0, 0, 0, fp.y), stairPt(st, w, 0, 0, fp.y), stairPt(st, w, ly, run1, fp.y), stairPt(st, 0, ly, run1, fp.y)]);
  out.floors.push([stairPt(st, 0, ly, run1, fp.y), stairPt(st, 2 * w + GAP, ly, run1, fp.y), stairPt(st, 2 * w + GAP, ly, run1 + w, fp.y), stairPt(st, 0, ly, run1 + w, fp.y)]);
  out.floors.push([stairPt(st, w + GAP, ly, run1, fp.y), stairPt(st, 2 * w + GAP, ly, run1, fp.y), stairPt(st, 2 * w + GAP, st.rise, run1 - n2 * 28, fp.y), stairPt(st, w + GAP, st.rise, run1 - n2 * 28, fp.y)]);
  // well guard (keeps you on your flight)
  const a = stairPt(st, w + GAP / 2, 0, 0, fp.y), b = stairPt(st, w + GAP / 2, 0, run1, fp.y);
  out.walls.push([a.x, a.z, b.x, b.z, C(fp.y), C(fp.y + st.rise + 110), 0.08]);
}

// ------------------------------------------------------------------------------------------ geometry
export function buildInterior(plan: Plan, ext: ExteriorOut | null, customShell = false): InteriorOut {
  const skipPartitions = customShell;
  const spec = plan.spec;
  const group = new Group(); group.name = `interior:${spec.id}`;
  const floorGroups = new Map<number, Group>();
  const rooms: Object3D[] = [];
  const doors: InteriorDoor[] = [];
  const core = new GeoBuilder();
  for (const fp of plan.floors) {
    const g = new GeoBuilder();
    const holes = floorHoles(plan, fp);
    const above = plan.floors.find((f) => f.floor === fp.floor + 1);
    const holesAbove = above ? floorHoles(plan, above) : [];
    const attic = fp.floor >= spec.floors;
    for (const r of fp.rooms) {
      if (customShell) { rooms.push(roomObject(roomMeta(plan, fp, r))); continue; }
      // floor finish over the centerline rect minus holes
      for (const p of subtractRects(r.cl, holes)) boxC(g, r.finish.floor, p.x0, fp.y - 2, p.z0, p.x1, fp.y, p.z1, 4);
      // ceiling
      if (!attic) {
        const cy = fp.y + fp.ceiling;
        for (const p of subtractRects(r.cl, [...holesAbove, ...(fp.openCeiling ?? [])])) {
          if (r.finish.suspended) {
            boxC(g, 'tex:acoustic', p.x0, cy, p.z0, p.x1, cy + 1.5, p.z1, 8);
            for (let x = p.x0 + 122; x < p.x1 - 61; x += 244) for (let z = p.z0 + 122; z < p.z1 - 122; z += 244) boxC(g, `emit:${r.finish.lighting}`, x, cy - 0.4, z, x + 61, cy, z + 122, 8);
          } else {
            boxC(g, r.finish.ceiling, p.x0, cy, p.z0, p.x1, cy + 2, p.z1, 8);
            const nx = Math.max(1, Math.round((p.x1 - p.x0) / 400)), nz = Math.max(1, Math.round((p.z1 - p.z0) / 400));
            for (let i = 0; i < nx; i++) for (let j = 0; j < nz; j++) {
              const x = p.x0 + ((p.x1 - p.x0) * (i + 0.5)) / nx, z = p.z0 + ((p.z1 - p.z0) * (j + 0.5)) / nz;
              boxC(g, `emit:${r.finish.lighting}`, x - 30, cy - 1.2, z - 30, x + 30, cy, z + 30, 8 | 1 | 2 | 16 | 32);
            }
          }
          // plenum slab underside above suspended ceilings (seen through stair holes)
          if (r.finish.suspended) boxC(g, 'tex:sealed_concrete', p.x0, fp.y + fp.ftf - fp.slab, p.z0, p.x1, fp.y + fp.ftf - fp.slab + 1, p.z1, 8);
        }
      }
      // exterior-wall trims for this room
      extTrims(g, plan, fp, r);
      // room metadata object
      const meta = roomMeta(plan, fp, r);
      rooms.push(roomObject(meta));
    }
    // slab edges around holes
    if (!customShell) for (const h of fp.holes) {
      const y0 = fp.y - fp.slab, y1 = fp.y;
      boxC(g, 'tex:sealed_concrete', h.x0, y0, h.z0, h.x1, y1, h.z1, 1 | 2 | 16 | 32);
    }
    // partitions
    if (!skipPartitions) for (const w of fp.walls) partitionGeo(g, plan, fp, w, doors);
    // stairs starting on this floor
    if (!customShell) for (const st of plan.stairs.filter((s) => s.floor === fp.floor)) stairGeo(g, plan, st);
    // guards around stair holes where no stair continues upward
    for (const st of plan.stairs.filter((s) => s.toFloor === fp.floor)) {
      if (plan.stairs.some((s) => s.floor === fp.floor && s.id.replace(/\d+$/, '') === st.id.replace(/\d+$/, ''))) continue;
      if (st.kind === 'U') {
        g.push(); const f = stairFrame(st); g.translate(C(f.ox), C(fp.y), C(f.oz)); g.rotateY(f.theta);
        guardRail(g, 0, 0, st.w + GAP, 0, 0);
        g.pop();
      }
    }
    // interior glass behind each exterior window of this floor (visible when streamed in)
    if (ext) for (const q of ext.glass) if (q[0].y * 100 >= fp.y - 1 && q[0].y * 100 < fp.y + fp.ftf) g.quad('glass', q[0].toArray() as any, q[1].toArray() as any, q[2].toArray() as any, q[3].toArray() as any);
    const fgrp = g.toGroup(mat, `F${fp.floor}`, { castShadow: false, receiveShadow: true });
    floorGroups.set(fp.floor, fgrp);
    group.add(fgrp);
  }
  for (const sh of customShell ? [] : plan.shafts) {
    const ys = plan.floors.filter((f) => sh.floors.includes(f.floor)).map((f) => f.y);
    core.push();
    const r = sh.rect;
    if (sh.door === 'z0') core.translate(C(r.x0), 0, C(r.z0));
    else if (sh.door === 'z1') { core.translate(C(r.x1), 0, C(r.z1)); core.rotateY(Math.PI); }
    else if (sh.door === 'x0') { core.translate(C(r.x0), 0, C(r.z1)); core.rotateY(Math.PI / 2); }
    else { core.translate(C(r.x1), 0, C(r.z0)); core.rotateY(-Math.PI / 2); }
    const y0 = Math.min(...ys);
    core.translate(0, C(y0), 0);
    elevatorShaft(core, ys.map((y) => y - y0));
    core.pop();
  }
  const cg = core.toGroup(mat, 'core', { castShadow: false });
  group.add(cg);
  for (const r of rooms) group.add(r);
  return { group, floorGroups, rooms, doors };
}

/** Wainscot / tile / band / baseboard / crown along a room's exterior-wall edges. */
function extTrims(g: GeoBuilder, plan: Plan, fp: FloorPlan, r: Room) {
  const spec = plan.spec, t = fp.extT, R = r.rect, fin = r.finish;
  const W = spec.w, D = spec.d;
  const h = fp.ceiling;
  const runs: { side: 'front' | 'back' | 'left' | 'right'; a: number; b: number }[] = [];
  if (Math.abs(R.z0 - t) < 1) runs.push({ side: 'front', a: R.x0, b: R.x1 });
  if (Math.abs(R.z1 - (D - t)) < 1) runs.push({ side: 'back', a: W - R.x1, b: W - R.x0 });
  if (Math.abs(R.x0 - t) < 1) runs.push({ side: 'left', a: D - R.z1, b: D - R.z0 });
  if (Math.abs(R.x1 - (W - t)) < 1) runs.push({ side: 'right', a: R.z0, b: R.z1 });
  for (const run of runs) {
    const sf = sideFrame(spec, run.side);
    const ops = [...plan.windows.filter((w) => w.side === run.side && w.floor === fp.floor).map((w) => [w.at, w.at + w.w, w.sill] as const),
      ...plan.extDoors.filter((d) => d.side === run.side && d.floor === fp.floor).map((d) => [d.at - 20, d.at + d.w + 20, 0] as const)];
    g.push(); g.translate(C(sf.ox), C(fp.y), C(sf.oz)); g.rotateY(sf.theta);
    const segs = (minY: number): [number, number][] => {
      const cuts = ops.filter((o) => o[2] < minY).map((o) => [o[0], o[1]] as [number, number]).sort((p, q) => p[0] - q[0]);
      const outS: [number, number][] = [];
      let s = run.a;
      for (const [c0, c1] of cuts) { if (c1 < run.a || c0 > run.b) continue; if (c0 > s) outS.push([s, Math.min(c0, run.b)]); s = Math.max(s, c1); }
      if (s < run.b) outS.push([s, run.b]);
      return outS;
    };
    const z = t; // inner face
    if (fin.tileH) for (const [a, b] of segs(fin.tileH)) boxC(g, 'tex:subway', a, 0, z - 0.8, b, fin.tileH, z, 32 | 4);
    else if (fin.wainscot && fin.wainscotH) for (const [a, b] of segs(fin.wainscotH)) { boxC(g, fin.wainscot, a, 0, z - 1.5, b, fin.wainscotH, z, 32 | 4); boxC(g, fin.wainscot, a, fin.wainscotH - 4, z - 2.5, b, fin.wainscotH, z, 32 | 4 | 8); }
    if (fin.band) for (const [a, b] of segs(115)) boxC(g, fin.band, a, 100, z - 0.3, b, 115, z, 32);
    for (const [a, b] of segs(13)) boxC(g, 'satin:TRIM_WHITE', a, 0, z - 1.5, b, 13, z, 32 | 4);
    if (fin.crown && fp.floor < spec.floors) { g.push(); g.translate(C(run.a), C(h - 15), C(z)); g.rotateY(Math.PI); g.translate(C(-(run.b - run.a)), 0, 0); corniceStraight(g, run.b - run.a, PROFILES.crown15, 'satin:TRIM_WHITE', 0, false); g.pop(); }
    g.pop();
  }
}

/** Partition with openings, per-side finishes and casings; registers interior doors. */
function partitionGeo(g: GeoBuilder, plan: Plan, fp: FloorPlan, w: WallSeg, doors: InteriorDoor[]) {
  const L = Math.hypot(w.bx - w.ax, w.bz - w.az);
  const { cx, cz, nx, nz } = openingCenter(w, L / 2);
  const off = w.t / 2 + 6;
  const left = roomAt(fp.rooms, cx + nx * off, cz + nz * off), right = roomAt(fp.rooms, cx - nx * off, cz - nz * off);
  const fa = right?.finish, fb = left?.finish;
  const suspended = (fa?.suspended || fb?.suspended) ?? false;
  const h = Math.round(suspended ? fp.ceiling + 2 : fp.y + fp.ftf - fp.slab - fp.y);
  const ka = w.kind === 'fire' && right?.type === 'stair' ? 'tex:cmu' : fa?.wall ?? 'paint:PAINT_OFFICE';
  const kb = w.kind === 'fire' && left?.type === 'stair' ? 'tex:cmu' : fb?.wall ?? 'paint:PAINT_OFFICE';
  const theta = wallAngle(w);
  g.push(); g.translate(C(w.ax), C(fp.y), C(w.az)); g.rotateY(theta); g.translate(0, 0, C(-w.t / 2));
  const ops = w.openings.map((o) => ({ x: o.at, y: o.sill, w: o.w, h: o.h }));
  wallWithOpenings(g, L, h, w.t, ops, ka, kb, ka);
  const doorCuts = w.openings.map((o) => [o.at - 10, o.at + o.w + 10] as [number, number]).sort((a, b) => a[0] - b[0]);
  const runs = (minus: [number, number][]) => { const out: [number, number][] = []; let s = 0; for (const [a, b] of minus) { if (a > s) out.push([s, a]); s = Math.max(s, b); } if (s < L) out.push([s, L]); return out; };
  const segs = runs(doorCuts);
  for (const [fin, z, sgn] of [[fa, 0, -1], [fb, w.t, 1]] as const) {
    if (!fin) continue;
    const face = sgn < 0 ? 32 : 16;
    for (const [a, b] of segs) {
      if (fin.tileH) boxC(g, 'tex:subway', a, 0, z + sgn * 0.8, b, fin.tileH, z, face | 4);
      else if (fin.wainscot && fin.wainscotH) { boxC(g, fin.wainscot, a, 0, z + sgn * 1.5, b, fin.wainscotH, z, face | 4); boxC(g, fin.wainscot, a, fin.wainscotH - 4, z + sgn * 2.5, b, fin.wainscotH, z, face | 4 | 8); }
      if (fin.band) boxC(g, fin.band, a, 100, z + sgn * 0.3, b, 115, z, face);
      boxC(g, 'satin:TRIM_WHITE', a, 0, z + sgn * 1.5, b, 13, z, face | 4);
    }
  }
  for (const o of w.openings) {
    if (o.kind !== 'door') continue;
    g.push(); g.translate(C(o.at), 0, 0); interiorCasing(g, o.w, o.h, w.t); g.pop();
  }
  g.pop();
  // doors (hinged leaves) — hinge at the opening start, leaf along the wall direction
  for (const o of w.openings) {
    if (o.kind !== 'door' || !o.style) continue;
    const ux = (w.bx - w.ax) / L, uz = (w.bz - w.az) / L;
    const hinge = new Vector3(C(w.ax + ux * o.at), C(fp.y), C(w.az + uz * o.at));
    doors.push({ hinge, yaw: theta, style: `${o.style}::${o.w}:${o.h}`, w: C(o.w), h: C(o.h), swing: (o.swing ?? 1) > 0 ? -1 : 1, floor: fp.floor });
  }
}

/** Sloped guard (top rail at 91 cm above nosings + balusters ≤ 10 cm clear) along local x = x0 from z0..z1. */
function guardRail(g: GeoBuilder, x0: number, z0: number, x1: number, z1: number, y0: number, y1 = y0) {
  const k = 'satin:IRON_BLACK';
  const L = Math.hypot(x1 - x0, z1 - z0);
  bar(g, 'satin:WALNUT_DARK', [C(x0), C(y0 + 107), C(z0)], [C(x1), C(y1 + 107), C(z1)], C(5));
  for (let s = 5; s < L; s += 11.5) {
    const t = s / L, x = x0 + (x1 - x0) * t, z = z0 + (z1 - z0) * t, y = y0 + (y1 - y0) * t;
    boxC(g, k, x - 0.8, y, z - 0.8, x + 0.8, y + 105, z + 0.8);
  }
}

function stairGeo(g: GeoBuilder, plan: Plan, st: StairRec) {
  const fp = plan.floors.find((f) => f.floor === st.floor)!;
  const room = roomAt(fp.rooms, (st.rect.x0 + st.rect.x1) / 2, (st.rect.z0 + st.rect.z1) / 2, 30);
  const tread = room?.finish.floor ?? 'tex:terrazzo';
  const riserKey = tread === 'tex:oak_floor' ? 'satin:TRIM_WHITE' : tread;
  const f = stairFrame(st);
  g.push(); g.translate(C(f.ox), C(fp.y), C(f.oz)); g.rotateY(f.theta);
  const w = st.w;
  const { n, riser } = solveRisers(st.rise);
  if (st.kind === 'straight') {
    straightStair(g, st.rise, w, 28, { tread, riser: riserKey }, plan.spec.typology === 'house');
    g.push(); g.translate(C(w + 5), 0, 0); g.rotateY(-Math.PI / 2); g.pop();
    guardRail(g, w + 3, 0, w + 3, n * 28, riser, st.rise);
    g.push(); g.translate(0, 0, 0); g.rotateY(-Math.PI / 2); g.translate(0, 0, C(0)); wallHandrail(g, n * 28, st.rise); g.pop();
  } else {
    const n1 = Math.ceil(n / 2), n2 = n - n1, run1 = n1 * 28, ly = n1 * riser;
    flight(g, 0, 0, 0, w, n1, riser, 28, tread, riserKey, false, 'tex:sealed_concrete');
    boxC(g, tread, 0, 0, run1, 2 * w + GAP, ly, run1 + w, 63 & ~32);
    flight(g, w + GAP, ly, run1, w, n2, riser, 28, tread, riserKey, false, 'tex:sealed_concrete', -1);
    // well guards on both flights + wall handrails (outer sides)
    guardRail(g, w + 2, 0, w + 2, run1, riser, ly);
    guardRail(g, w + GAP - 2, run1, w + GAP - 2, run1 - n2 * 28, ly + riser, st.rise);
    g.push(); g.translate(0, 0, 0); g.rotateY(-Math.PI / 2); wallHandrail(g, run1, ly); g.pop();
    g.push(); g.translate(C(2 * w + GAP), C(ly), C(run1)); g.rotateY(Math.PI / 2); wallHandrail(g, n2 * 28, st.rise - ly); g.pop();
  }
  g.pop();
}
