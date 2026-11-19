// Room metadata for the later items pass (CLAUDE.md §7.4). Each room becomes an Object3D named
// CM_{BuildingId}_F{floor}_R{index} with userData {roomId, buildingId, floor, roomType, areaM2, ceilingCm,
// floorFinish, wallFinish, ceilingFinish, lightingKey, itemSlots: [], anchorWalls, openings}.
// Coordinates in anchorWalls/openings are BUILDING-LOCAL meters (buildings.json carries each building's transform).
import { Object3D } from 'three';
import { C } from '../kits/common';
import { sideFrame, sidePoint } from '../buildings/exterior';
import { openingCenter } from './validate';
import type { FloorPlan, Plan, Room } from './types';

export interface AnchorWall { start: [number, number, number]; end: [number, number, number]; normal: [number, number, number]; }
export interface RoomOpening { type: 'door' | 'window'; position: [number, number, number]; widthCm: number; }
export interface RoomMeta {
  roomId: string; buildingId: string; floor: number; roomType: string; label?: string;
  areaM2: number; ceilingCm: number; floorFinish: string; wallFinish: string; ceilingFinish: string;
  lightingKey: 'INTERIOR_WARM' | 'INTERIOR_COOL'; itemSlots: never[]; anchorWalls: AnchorWall[]; openings: RoomOpening[];
  rect: [number, number, number, number]; y: number;
}

const r2 = (v: number) => Math.round(v * 1000) / 1000;

export function roomMeta(plan: Plan, fp: FloorPlan, room: Room): RoomMeta {
  const R = room.rect;
  const y = C(fp.y);
  const openings: RoomOpening[] = [];
  const near = (x: number, z: number, pad = 30) => x >= R.x0 - pad && x <= R.x1 + pad && z >= R.z0 - pad && z <= R.z1 + pad;
  // doors in partitions touching this room
  for (const w of fp.walls) for (const o of w.openings) {
    const c = openingCenter(w, o.at + o.w / 2);
    if (near(c.cx, c.cz, w.t / 2 + 2)) openings.push({ type: 'door', position: [r2(C(c.cx)), r2(y), r2(C(c.cz))], widthCm: o.w });
  }
  // exterior windows/doors on this room's edges
  const spec = plan.spec;
  for (const wdw of plan.windows) {
    if (wdw.floor !== fp.floor) continue;
    const p = sidePoint(sideFrame(spec, wdw.side), wdw.at + wdw.w / 2, fp.y + wdw.sill, fp.extT);
    if (near(p.x * 100, p.z * 100, 5)) openings.push({ type: 'window', position: [r2(p.x), r2(p.y), r2(p.z)], widthCm: wdw.w });
  }
  for (const d of plan.extDoors) {
    if (d.floor !== fp.floor) continue;
    const p = sidePoint(sideFrame(spec, d.side), d.at + d.w / 2, fp.y, fp.extT);
    if (near(p.x * 100, p.z * 100, 5)) openings.push({ type: 'door', position: [r2(p.x), r2(p.y), r2(p.z)], widthCm: d.w });
  }
  // anchor walls: each edge split around openings, keep runs ≥ 60 cm
  const anchorWalls: AnchorWall[] = [];
  const edges: { a: [number, number]; b: [number, number]; n: [number, number] }[] = [
    { a: [R.x0, R.z0], b: [R.x1, R.z0], n: [0, 1] }, { a: [R.x1, R.z0], b: [R.x1, R.z1], n: [-1, 0] },
    { a: [R.x1, R.z1], b: [R.x0, R.z1], n: [0, -1] }, { a: [R.x0, R.z1], b: [R.x0, R.z0], n: [1, 0] },
  ];
  for (const e of edges) {
    const L = Math.hypot(e.b[0] - e.a[0], e.b[1] - e.a[1]);
    const ux = (e.b[0] - e.a[0]) / L, uz = (e.b[1] - e.a[1]) / L;
    const cuts: [number, number][] = [];
    for (const o of openings) {
      const px = o.position[0] * 100, pz = o.position[2] * 100;
      const along = (px - e.a[0]) * ux + (pz - e.a[1]) * uz, off = Math.abs((px - e.a[0]) * -uz + (pz - e.a[1]) * ux);
      if (off < 40 && along > -o.widthCm && along < L + o.widthCm) cuts.push([along - o.widthCm / 2 - 10, along + o.widthCm / 2 + 10]);
    }
    cuts.sort((p, q) => p[0] - q[0]);
    let s = 0;
    const push = (s0: number, s1: number) => {
      if (s1 - s0 < 60) return;
      anchorWalls.push({ start: [r2(C(e.a[0] + ux * s0)), r2(y), r2(C(e.a[1] + uz * s0))], end: [r2(C(e.a[0] + ux * s1)), r2(y), r2(C(e.a[1] + uz * s1))], normal: [e.n[0], 0, e.n[1]] });
    };
    for (const [c0, c1] of cuts) { push(s, Math.max(s, c0)); s = Math.max(s, c1); }
    push(s, L);
  }
  const f = room.finish;
  return {
    roomId: room.id, buildingId: spec.id, floor: fp.floor, roomType: room.type, label: room.label,
    areaM2: r2(((R.x1 - R.x0) * (R.z1 - R.z0)) / 10000), ceilingCm: fp.ceiling,
    floorFinish: f.floorKey, wallFinish: f.wallKey, ceilingFinish: f.ceilingKey, lightingKey: f.lighting,
    itemSlots: [], anchorWalls, openings, rect: [r2(C(R.x0)), r2(C(R.z0)), r2(C(R.x1)), r2(C(R.z1))], y: r2(y),
  };
}

/** Object3D carrying the metadata, positioned at the room's floor center (building-local). */
export function roomObject(meta: RoomMeta): Object3D {
  const o = new Object3D();
  o.name = meta.roomId;
  o.position.set((meta.rect[0] + meta.rect[2]) / 2, meta.y + 1.2, (meta.rect[1] + meta.rect[3]) / 2);
  o.userData = { ...meta };
  return o;
}

export function allRoomMeta(plan: Plan): RoomMeta[] {
  const out: RoomMeta[] = [];
  for (const fp of plan.floors) for (const r of fp.rooms) out.push(roomMeta(plan, fp, r));
  return out;
}
