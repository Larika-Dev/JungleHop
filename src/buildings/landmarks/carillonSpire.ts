// #2 The Carillon Spire (CLAUDE.md §10): square Flemish-bond brick tower ~52 m with limestone quoins and a
// copper-roofed belfry. Interior: spiral stairs between intermediate landings, a ringing room and a bell
// chamber with a timber bell frame (bells are items later). Louvered openings. Logged exception: a single
// stair (tower) — second exit by the elevator only.
import { Vector3 } from 'three';
import { C, boxC } from '../../kits/common';
import { wallWithOpenings } from '../../kits/brick';
import { quoins } from '../../kits/services';
import { belfry } from '../../kits/roof';
import { spiralStair, solveRisers } from '../../kits/stair';
import { doorFrame } from '../../kits/door';
import { elevatorShaft } from '../../kits/interior';
import { customPlan } from '../../interiors/floorplan';
import { defaultFacade } from '../facades';
import { LANDMARK_HOOKS } from '../manager';
import { LANDMARKS } from '../../world/layout';
import { centered } from './common';
import type { BuildingSpec, Rect } from '../../interiors/types';

const W = 600, T = 45, LEVELS = 10; // floors 0..9 (9 = bell chamber)
const BRICK = 'brick:flemish:BRICK_CAMPUS_A';
const SPIRAL: Rect = { x0: T + 20, z0: 600 - T - 20 - 240, x1: T + 20 + 240, z1: 600 - T - 20 };
const SHAFT: Rect = { x0: 600 - T - 5 - 253, z0: T + 5, x1: 600 - T - 5, z1: T + 5 + 243 };

export function specs(): BuildingSpec[] {
  const site = LANDMARKS.find((l) => l.id === 'carillon_spire')!;
  return [centered(site, W, W, {
    id: 'LM02_CARILLON_SPIRE', name: 'The Carillon Spire', district: 'carillon_south', floors: LEVELS, basement: false, attic: false,
    typology: 'historic_academic', plan: 'custom', custom: 'carillon_spire', facade: defaultFacade('historic_academic', { wall: BRICK }), seed: 'carillon', public: true, tags: ['landmark', 'exit-exception'],
  })];
}

const levelY = (k: number) => (k === 0 ? 0 : 480 + 420 * (k - 1));

LANDMARK_HOOKS.set('carillon_spire', {
  customShell: true,
  plan: (spec) => customPlan(spec, (pb, fl) => {
    for (const f of fl) {
      const type = f.floor === 0 ? 'lobby' : f.floor === 8 ? 'ringing_room' : f.floor === 9 ? 'bell_chamber' : 'stair';
      pb.room(f.floor, { x0: T, z0: T, x1: W - T, z1: W - T }, type, f.floor === 0 ? 'Tower base' : undefined);
      if (f.floor > 0) pb.hole(f.floor, SPIRAL);
    }
    for (let i = 0; i < fl.length - 1; i++) pb.stairs.push({ id: `SP${i}`, floor: fl[i].floor, toFloor: fl[i + 1].floor, rect: SPIRAL, kind: 'spiral', w: 108, dir: 'z+', rise: fl[i].ftf });
    pb.shafts.push({ rect: SHAFT, floors: fl.filter((f) => f.floor <= 8).map((f) => f.floor), door: 'z1' });
    pb.extDoors.push({ floor: 0, side: 'front', at: 255, w: 91, h: 213, style: 'colonial:DOOR_GREEN', y: 0 });
  }),
  exterior: (spec, plan, out) => {
    const g = out.g;
    const top = levelY(9); // bell chamber floor
    // four brick faces with door + narrow slit windows each level
    for (let side = 0; side < 4; side++) {
      g.push(); g.translate(C(W / 2), 0, C(W / 2)); g.rotateY((side * Math.PI) / 2); g.translate(C(-W / 2), 0, C(-W / 2));
      const ops = [];
      if (side === 0) ops.push({ x: 255, y: 0, w: 91, h: 213 });
      for (let k = 1; k < 9; k++) ops.push({ x: 270, y: levelY(k) + 120, w: 60, h: 180 });
      wallWithOpenings(g, W, top, T, ops, BRICK, 'tex:cmu', BRICK);
      for (let k = 1; k < 9; k++) {
        boxC(g, 'tex:limestone', 262, levelY(k) + 105, -4.5, 338, levelY(k) + 120, T * 0.3);
        boxC(g, 'glassFar', 270, levelY(k) + 120, 10, 330, levelY(k) + 300, 10.5, 32);
      }
      quoins(g, top);
      // limestone belt courses
      for (const y of [levelY(1) - 20, levelY(5) - 20, top - 30]) boxC(g, 'tex:limestone', -3, y, -3, W + 3, y + 30, 0);
      if (side === 0) { doorFrame(g, 91, 213, T, 'satin:TRIM_WHITE'); }
      g.pop();
      const corners: [number, number, number, number][] = [[0, 0, W, 0], [W, 0, W, W], [W, W, 0, W], [0, W, 0, 0]];
      const [ax, az, bx, bz] = corners[side];
      if (side === 0) { out.walls.push([0, 0, C(255), 0, 0, C(top), C(T)], [C(346), 0, C(W), 0, 0, C(top), C(T)]); }
      else out.walls.push([C(ax), C(az), C(bx), C(bz), 0, C(top + 800), C(T)]);
    }
    out.doors.push({ hinge: new Vector3(C(255), 0, C(14.25)), yaw: 0, style: 'colonial:DOOR_GREEN:91:213', w: 0.91, h: 2.13, swing: -1, ext: true });
    // belfry (louvered arched openings) + copper pyramidal roof to ~52 m
    g.push(); g.translate(0, C(top), 0); belfry(g, W, 700, BRICK); g.pop();
    void plan;
    // collision: tower base floor and each landing (minus the spiral hole)
    for (const fp of plan.floors) {
      const holes = fp.floor > 0 ? [SPIRAL, SHAFT] : [SHAFT];
      for (const r of rectMinus({ x0: T, z0: T, x1: W - T, z1: W - T }, holes)) out.floors.push(poly(r, levelY(fp.floor)));
    }
    // spiral treads as wedges (collision)
    for (let k = 0; k < 9; k++) {
      const { n, riser } = solveRisers(levelY(k + 1) - levelY(k));
      const da = (Math.PI * 2) / 14;
      for (let i = 0; i < n; i++) {
        const a0 = i * da, a1 = a0 + da * 1.08, y = levelY(k) + (i + 1) * riser;
        const cx = SPIRAL.x0 + 120, cz = SPIRAL.z0 + 120;
        out.floors.push([new Vector3(C(cx + Math.sin(a0) * 12), C(y), C(cz + Math.cos(a0) * 12)), new Vector3(C(cx + Math.sin(a0) * 120), C(y), C(cz + Math.cos(a0) * 120)), new Vector3(C(cx + Math.sin(a1) * 120), C(y), C(cz + Math.cos(a1) * 120)), new Vector3(C(cx + Math.sin(a1) * 12), C(y), C(cz + Math.cos(a1) * 12))]);
      }
    }
  },
  interior: (spec, plan, g) => {
    for (const fp of plan.floors) {
      const y = levelY(fp.floor);
      const fin = fp.rooms[0].finish;
      for (const r of rectMinus({ x0: T, z0: T, x1: W - T, z1: W - T }, fp.floor > 0 ? [SPIRAL, SHAFT] : [SHAFT])) {
        boxC(g, fp.floor >= 8 ? 'tex:heart_pine' : fin.floor, r.x0, y - 2, r.z0, r.x1, y, r.z1, 4);
        if (fp.floor > 0) boxC(g, 'paint:CEILING_WHITE', r.x0, y - 35, r.z0, r.x1, y - 33, r.z1, 8);
      }
      if (fp.floor < 9) {
        g.push(); g.translate(C(SPIRAL.x0), C(y), C(SPIRAL.z0)); spiralStair(g, levelY(fp.floor + 1) - y, 120, 12, 14, 'tex:capstone'); g.pop();
        boxC(g, `emit:INTERIOR_WARM`, 280, y + fp.ftf - 37, 280, 340, y + fp.ftf - 35, 340, 8);
      }
    }
    // elevator shaft to the ringing room
    g.push(); g.translate(C(SHAFT.x1), 0, C(SHAFT.z1)); g.rotateY(Math.PI); elevatorShaft(g, plan.shafts[0].floors.map(levelY)); g.pop();
    // timber bell frame in the bell chamber (bells are items later)
    const by = levelY(9);
    const k = 'paint:WALNUT_DARK';
    for (const z of [180, 420]) { boxC(g, k, 90, by, z - 15, 510, by + 30, z + 15); boxC(g, k, 90, by + 260, z - 15, 510, by + 290, z + 15); }
    for (const x of [90, 300, 480]) for (const z of [165, 405]) boxC(g, k, x, by + 30, z, x + 30, by + 260, z + 30);
    for (const x of [90, 480]) { boxC(g, k, x, by + 260, 165, x + 30, by + 290, 435); }
    for (let x = 140; x < 470; x += 110) boxC(g, k, x, by + 270, 165, x + 20, by + 290, 435); // headstock beams
    void spec;
  },
});

function rectMinus(r: Rect, holes: Rect[]): Rect[] {
  let parts = [r];
  for (const h of holes) {
    const next: Rect[] = [];
    for (const p of parts) {
      if (h.x1 <= p.x0 || h.x0 >= p.x1 || h.z1 <= p.z0 || h.z0 >= p.z1) { next.push(p); continue; }
      if (h.z0 > p.z0) next.push({ ...p, z1: h.z0 });
      if (h.z1 < p.z1) next.push({ ...p, z0: h.z1 });
      const z0 = Math.max(p.z0, h.z0), z1 = Math.min(p.z1, h.z1);
      if (h.x0 > p.x0) next.push({ x0: p.x0, z0, x1: h.x0, z1 });
      if (h.x1 < p.x1) next.push({ x0: h.x1, z0, x1: p.x1, z1 });
    }
    parts = next;
  }
  return parts;
}
function poly(r: Rect, y: number): Vector3[] { return [new Vector3(C(r.x0), C(y), C(r.z0)), new Vector3(C(r.x1), C(y), C(r.z0)), new Vector3(C(r.x1), C(y), C(r.z1)), new Vector3(C(r.x0), C(y), C(r.z1))]; }
export { rectMinus, poly };
