// Exterior shell builder: every building's facade, roof and services from its Plan (CLAUDE.md §5/§6/§9).
// Output geometry is building-local (meters); the caller applies the building matrix.
import { Matrix4, Vector3 } from 'three';
import { GeoBuilder } from '../core/geo';
import { pc } from '../core/palette';
import { Rng } from '../core/rng';
import { C, boxC } from '../kits/common';
import { jackArch, soldierCourse, wallWithOpenings, chimney, type Opening as WallOpening } from '../kits/brick';
import { cornicePath, PROFILES } from '../kits/cornice';
import { DOOR, doorFrame } from '../kits/door';
import { ironPicket } from '../kits/railing';
import { gableRoof, gambrelRoof, hipRoof, flatRoof, cupola } from '../kits/roof';
import { storefront } from '../kits/storefront';
import { shedAwning, domeAwning, metalCanopy } from '../kits/awning';
import { quoins, gutter, downspout, utilityClutter, addressNumerals } from '../kits/services';
import { basementHopper, dormer, modernFixed, sashWindow, fanlight, oculus } from '../kits/window';
import { stoop } from '../kits/stair';
import { imAttrs } from '../interiors/interiorMapping';
import { finishFor } from '../interiors/finishes';
import type { BuildingSpec, ExtDoor, Plan, WindowRec } from '../interiors/types';

export type Side = 'front' | 'back' | 'left' | 'right';
export interface SideFrame { side: Side; ox: number; oz: number; theta: number; len: number; }
export function sideFrame(spec: BuildingSpec, side: Side): SideFrame {
  const W = spec.w, D = spec.d;
  switch (side) {
    case 'front': return { side, ox: 0, oz: 0, theta: 0, len: W };
    case 'back': return { side, ox: W, oz: D, theta: Math.PI, len: W };
    case 'left': return { side, ox: 0, oz: D, theta: Math.PI / 2, len: D };
    case 'right': return { side, ox: W, oz: 0, theta: -Math.PI / 2, len: D };
  }
}
/** Building-local (cm) point at distance `at` along a side, depth `z` inward, height y. -> local meters */
export function sidePoint(f: SideFrame, at: number, y: number, z: number): Vector3 {
  const c = Math.cos(f.theta), s = Math.sin(f.theta);
  // local +x -> (c, -s), local +z -> (s, c)
  return new Vector3(C(f.ox + at * c + z * s), C(y), C(f.oz - at * s + z * c));
}
export function buildingMatrix(spec: BuildingSpec): Matrix4 {
  return new Matrix4().makeRotationY(spec.rotY).setPosition(spec.x, spec.y, spec.z);
}

export interface DoorSlotLocal { hinge: Vector3; yaw: number; style: string; w: number; h: number; swing: 1 | -1; ext: boolean; }
export interface ExteriorOut {
  g: GeoBuilder;
  doors: DoorSlotLocal[];
  walls: [number, number, number, number, number, number, number][]; // ax, az, bx, bz (m local), y0, y1, thickness
  /** walkable polygons (building-local meters, 3D: the plane passes through the first 3 points) */
  floors: Vector3[][];
  glass: [Vector3, Vector3, Vector3, Vector3][];
}

const winCols = (t: WindowRec['type']): [number, number] => (t === '9/9' ? [3, 3] : t === '2/2' ? [2, 1] : [3, 2]);

export function buildExterior(spec: BuildingSpec, plan: Plan, opts: { frontGrade: number; lowGrade: number; bIndex: number }): ExteriorOut {
  const g = new GeoBuilder();
  const out: ExteriorOut = { g, doors: [], walls: [], floors: [], glass: [] };
  const f = spec.facade;
  const rng = new Rng(spec.seed + ':ext');
  const M = buildingMatrix(spec);
  const sides: Side[] = ['front', 'back', 'left', 'right'];
  const interiorWall = finishFor(spec.typology, 'office').wall;
  const roofY = plan.roofY;
  const sfDoors = new Set<ExtDoor>();
  for (const fp of plan.floors) {
    const top = fp.floor >= spec.floors; // attic floor lives inside the roof
    if (top && (f.roof !== 'flat' || spec.tags?.includes('roofdeck'))) continue;
    const t = fp.extT;
    for (const side of sides) {
      const sf = sideFrame(spec, side);
      const party = (side === 'left' && spec.party?.left) || (side === 'right' && spec.party?.right);
      const key = side === 'front' ? f.wall : party ? 'brick:common:BRICK_DOWNTOWN_C' : (side === 'left' || side === 'right') && f.sideWall ? f.sideWall : f.backWall ?? f.wall;
      const ops: WallOpening[] = [];
      const wins = plan.windows.filter((w) => w.side === side && w.floor === fp.floor);
      for (const w of wins) ops.push({ x: w.at, y: w.sill, w: w.w, h: w.h });
      const doors = plan.extDoors.filter((d) => d.side === side && d.floor === fp.floor);
      for (const d of doors) if (!(f.storefront && side === 'front' && fp.floor === 0 && d.style === 'storefront')) ops.push({ x: d.at, y: 0, w: d.w, h: d.h + (d.w >= 180 && d.style.startsWith('colonial') ? DOOR.frame + d.w / 2 : 0) });
      let sf0 = 0, sf1 = 0;
      if (f.storefront && side === 'front' && fp.floor === 0) {
        const other = doors.filter((d) => d.style !== 'storefront');
        sf0 = Math.max(30, ...other.map((d) => d.at + d.w + 45));
        sf1 = sf.len - 30;
        ops.push({ x: sf0, y: 0, w: sf1 - sf0, h: 325 });
      }
      g.push(); g.translate(C(sf.ox), C(fp.y), C(sf.oz)); g.rotateY(sf.theta);
      wallWithOpenings(g, sf.len, fp.ftf, t, ops, key, interiorWall, key);
      // collision: wall centreline split at door openings (doors add their own leaves)
      const gaps = [...doors.map((d) => [d.at, d.at + d.w]), ...(sf1 > sf0 ? [[sf0, sf1]] : [])].sort((a, b) => a[0] - b[0]);
      let a = 0;
      const pushWall = (x0: number, x1: number) => {
        if (x1 - x0 < 1) return;
        const p = sidePoint(sf, x0, 0, t / 2), q = sidePoint(sf, x1, 0, t / 2);
        out.walls.push([p.x, p.z, q.x, q.z, C(fp.y), C(fp.y + fp.ftf), C(t)]);
      };
      for (const [x0, x1] of gaps) { pushWall(a, x0); a = x1; }
      pushWall(a, sf.len);
      if (sf1 > sf0) {
        // storefront: recessed entry walls block except the door
        const slots = storefront(g.push().translate(C(sf0), 0, 0) as GeoBuilder, {
          w: sf1 - sf0, bays: f.storefront!.bays, entry: f.storefront!.entry, frameKey: f.storefront!.frame, bulkKey: f.storefront!.bulk,
        });
        g.pop();
        for (const s of slots) {
          const hinge = sidePoint(sf, sf0 + s.x, fp.y, s.z + 2.25);
          out.doors.push({ hinge, yaw: sf.theta + s.yaw, style: 'storefront', w: s.w, h: s.h, swing: -1, ext: true });
          const p = sidePoint(sf, sf0, 0, 1), q = sidePoint(sf, sf0 + s.x, 0, 1), r2 = sidePoint(sf, sf0 + s.x + s.w, 0, 1), e = sidePoint(sf, sf1, 0, 1);
          out.walls.push([p.x, p.z, q.x, q.z, 0, 3.2, 0.3], [r2.x, r2.z, e.x, e.z, 0, 3.2, 0.3]);
        }
        const aw = f.storefront!.awning;
        if (aw) {
          g.push(); g.translate(C(sf0), C(335), 0);
          if (aw.kind === 'shed') shedAwning(g, sf1 - sf0, 120, 90, aw.color, aw.stripe);
          else if (aw.kind === 'dome') domeAwning(g, sf1 - sf0, 90, aw.color);
          else metalCanopy(g, sf1 - sf0);
          g.pop();
        }
        // sign band backing (signage pass mounts letters here)
        boxC(g, f.storefront!.signBand ?? 'satin:SHUTTER_BLACK', sf0, 335 + 95, -2, sf1, 335 + 95 + 70, 0);
        sfDoors.add(doors.find((d) => d.style === 'storefront')!);
      }
      // windows
      for (const w of wins) {
        const room = plan.floors.find((p) => p.floor === fp.floor)!.rooms.find((r) => true) ?? null;
        void room;
        const fin = finishFor(spec.typology, fp.floor < 0 ? 'storage' : spec.typology === 'downtown_commercial' && fp.floor > 0 ? 'apartment_living' : 'office');
        const o = sidePoint(sf, 0, 0, 0).applyMatrix4(M);
        const tl = new Vector3(Math.cos(sf.theta + spec.rotY), 0, -Math.sin(sf.theta + spec.rotY));
        const cellStart = (sf.len - Math.max(1, Math.floor((sf.len - 80) / f.bay)) * f.bay) / 2;
        const wc = pc(fin.wallKey), fc = pc(fin.floorKey);
        g.attrs = imAttrs({
          imO: [o.x, o.y, o.z], imT: [tl.x, tl.z], imF: [C(fp.y), C(fp.ftf), C(Math.min(fp.ceiling, fp.ftf - 20)), Math.max(3, Math.min(6.5, C(spec.d) / 2 - 1))],
          imR: [C(f.bay), C(cellStart), (rng.next() * 100) | 0, opts.bIndex], imC: [wc.r, wc.g, wc.b], imD: [fc.r, fc.g, fc.b],
        });
        g.push(); g.translate(C(w.at), C(w.sill), 0);
        if (w.type === 'modern') modernFixed(g, w.w, w.h, Math.max(1, Math.round(w.w / 150)), 1, 'glassFar');
        else if (w.type === 'hopper') basementHopper(g, w.w, w.h, 'glassFar');
        else if (w.type === 'oculus') oculus(g, w.w, 'glassFar');
        else {
          const [cols, rows] = winCols(w.type);
          const lintel = f.lintel === 'keystone' || f.lintel === 'flat' ? f.lintel : 'none';
          sashWindow(g, { w: w.w, h: w.h, cols, rows, glass: 'glassFar', frame: f.trim.startsWith('tex:') ? 'satin:TRIM_WHITE' : f.trim, sill: 'stone', lintel, shutters: f.shutters ?? null });
        }
        g.pop();
        g.attrs = {};
        // glass plane for interior pass (transparent when loaded)
        const sb = w.type === 'modern' ? 6 : 10;
        out.glass.push([sidePoint(sf, w.at + 5, w.sill + 5, sb), sidePoint(sf, w.at + w.w - 5, w.sill + 5, sb), sidePoint(sf, w.at + w.w - 5, w.sill + w.h - 5, sb), sidePoint(sf, w.at + 5, w.sill + w.h - 5, sb)]);
        // brick lintels
        if (f.lintel === 'jack') { g.push(); g.translate(C(w.at), C(w.sill + w.h), C(-0.5)); jackArch(g, w.w, keyOf(f.wall)); g.pop(); }
        if (f.lintel === 'soldier') { g.push(); g.translate(C(w.at - 5), C(w.sill + w.h), C(-0.5)); soldierCourse(g, w.w + 10, keyOf(f.wall)); g.pop(); }
      }
      // doors
      for (const d of doors) {
        if (sfDoors.has(d) || d.style === 'none') continue;
        const histDouble = d.w >= 180 && d.style.startsWith('colonial');
        g.push(); g.translate(C(d.at), 0, 0);
        doorFrame(g, d.w, d.h, t, f.trim.startsWith('tex:') ? 'satin:TRIM_WHITE' : f.trim, 10, true);
        if (histDouble) { g.translate(0, C(d.h + DOOR.frame), 0); fanlight(g, d.w / 2, 'glassFar'); }
        g.pop();
        const leaves = d.w >= 150 ? [[d.at, d.w / 2, 1], [d.at + d.w, d.w / 2, -1]] : [[d.at, d.w, 1]];
        for (const [hx, lw, dir] of leaves) {
          const hinge = sidePoint(sf, hx, fp.y, 14.25);
          out.doors.push({ hinge, yaw: sf.theta + (dir < 0 ? Math.PI : 0), style: normalizeStyle(d.style, lw, d.h), w: C(lw), h: C(d.h), swing: dir < 0 ? 1 : -1, ext: true });
        }
        // stoop / steps up from grade at ground-floor doors
        if (fp.floor === 0 && (side === 'front' ? -opts.frontGrade : -opts.lowGrade) > 0.05) {
          const rise = Math.round((side === 'front' ? -opts.frontGrade : -opts.lowGrade) * 100);
          const sw = d.w + 100;
          g.push(); g.translate(C(d.at - 50), 0, C(-120)); g.translate(0, C(-rise), 0);
          const info = stoop(g, rise, sw, 33, 120, 'tex:limestone', f.wall);
          g.pop();
          const n = info.risers;
          out.floors.push([sidePoint(sf, d.at - 50, -rise, -120 - 33 * n), sidePoint(sf, d.at - 50 + sw, -rise, -120 - 33 * n), sidePoint(sf, d.at - 50 + sw, 0, -120), sidePoint(sf, d.at - 50, 0, -120)]);
          out.floors.push([sidePoint(sf, d.at - 50, 0, -120), sidePoint(sf, d.at - 50 + sw, 0, -120), sidePoint(sf, d.at - 50 + sw, 0, 0), sidePoint(sf, d.at - 50, 0, 0)]);
        }
      }
      // utility clutter (≥ 4 items per non-front facade side) + address numerals
      if (fp.floor === 0 && side !== 'front' && !party) utilityClutter(g, sf.len, `${spec.seed}:${side}`, { commercial: spec.typology !== 'house', topY: Math.min(roofY, 600) });
      if (fp.floor === 0 && side === 'front') { const md = doors[0]; if (md) { g.push(); g.translate(C(md.at + md.w + 25), C(200), 0); addressNumerals(g, String(100 + (Math.abs(hashStr(spec.id)) % 899))); g.pop(); } }
      g.pop();
    }
  }
  // foundation plinth / water table
  const plinthDown = Math.max(0.6, -Math.min(opts.lowGrade, opts.frontGrade) + 0.4);
  const base = spec.basement ? -330 : -Math.round(plinthDown * 100);
  const t0 = plan.floors.find((p) => p.floor === 0)!.extT;
  const pk = ['historic_academic', 'library', 'inn', 'residence_historic'].includes(spec.typology) ? 'tex:limestone' : 'tex:concrete_aged';
  const yb = Math.min(base, -Math.round(plinthDown * 100));
  boxC(g, pk, -3, yb, -3, spec.w + 3, spec.basement ? -330 + 2 : 0, t0);
  boxC(g, pk, -3, yb, spec.d - t0, spec.w + 3, spec.basement ? -330 + 2 : 0, spec.d + 3);
  boxC(g, pk, -3, yb, t0, t0, spec.basement ? -330 + 2 : 0, spec.d - t0);
  boxC(g, pk, spec.w - t0, yb, t0, spec.w + 3, spec.basement ? -330 + 2 : 0, spec.d - t0);
  if (pk === 'tex:limestone') boxC(g, pk, -4, -2, -4, spec.w + 4, 14, spec.d + 4, 1 | 2 | 4 | 16 | 32);
  // roof, cornice, quoins, gutters
  const topT = plan.floors.filter((p) => p.floor < spec.floors).slice(-1)[0].extT;
  const corn = f.cornice;
  const H = { box: 32, dentil: 43, italianate: 83, coping: 0, none: 0 }[corn];
  if (f.roof === 'flat') {
    g.push(); g.translate(0, C(roofY), 0); flatRoof(g, spec.w, spec.d, f.parapetH ?? 90, topT, f.wall, f.roofKey); g.pop();
    if (corn !== 'none' && corn !== 'coping') corniceFront(g, spec, roofY + (f.parapetH ?? 90) - H, corn);
    // rooftop HVAC condensers on larger roofs
    if (spec.w > 1200) for (let i = 0; i < Math.floor(spec.w / 1500); i++) { g.push(); g.translate(C(300 + i * 1500), C(roofY), C(spec.d / 2)); boxC(g, 'satin:GALV_STEEL', 0, 0, 0, 180, 120, 120); g.pop(); }
  } else {
    if (corn !== 'none') corniceFront(g, spec, roofY - H, corn, true);
    g.push(); g.translate(0, C(roofY), 0);
    const gable = f.backWall ?? f.wall;
    if (f.roof === 'gable') gableRoof(g, spec.w, spec.d, f.pitch ?? 38, 30, { top: f.roofKey, under: 'tex:heart_pine', trim: 'satin:TRIM_WHITE' }, gable);
    else if (f.roof === 'hip') hipRoof(g, spec.w, spec.d, f.pitch ?? 32, 30, { top: f.roofKey, under: 'tex:heart_pine', trim: 'satin:TRIM_WHITE' });
    else if (f.roof === 'gambrel') gambrelRoof(g, spec.w, spec.d, 25, { top: f.roofKey, under: 'tex:heart_pine', trim: 'satin:TRIM_WHITE' }, gable);
    // dormers over attic
    if (spec.attic && f.roof === 'gable') {
      const n = Math.max(1, Math.floor(spec.w / 600));
      const rise = (spec.d / 2) * Math.tan(((f.pitch ?? 35) * Math.PI) / 180);
      for (let i = 0; i < n; i++) {
        const x = (spec.w * (i + 0.5)) / n - 53;
        const zIn = 60;
        g.push(); g.translate(C(x), C(zIn * Math.tan(((f.pitch ?? 35) * Math.PI) / 180) - 10), C(zIn)); dormer(g, 76, 110, Math.min(220, rise), f.roofKey, 'glassFar'); g.pop();
      }
    }
    // chimneys at the gable ends
    if (spec.typology === 'house' || spec.typology === 'historic_academic' || spec.typology === 'residence_historic') {
      const rise = (spec.d / 2) * Math.tan(((f.pitch ?? 35) * Math.PI) / 180);
      for (const x of spec.typology === 'house' ? [spec.w * 0.15] : [spec.w * 0.08, spec.w * 0.92 - 90]) { g.push(); g.translate(C(x), C(-40), C(spec.d / 2 - 40)); chimney(g, 90, 60, rise + 160, f.wall.startsWith('brick') ? f.wall : 'brick:running:BRICK_DOWNTOWN_B'); g.pop(); }
    }
    if (spec.tags?.includes('cupola')) { g.push(); g.translate(C(spec.w / 2 - 100), C((spec.d / 2) * Math.tan(((f.pitch ?? 32) * Math.PI) / 180) - 60), C(spec.d / 2 - 100)); cupola(g, 200, 300); g.pop(); }
    g.pop();
    // gutters & downspouts
    for (const side of ['front', 'back'] as Side[]) {
      const sf = sideFrame(spec, side);
      g.push(); g.translate(C(sf.ox), C(roofY - 30), C(sf.oz)); g.rotateY(sf.theta); g.translate(C(-15), 0, C(-28)); gutter(g, sf.len + 30); g.pop();
      for (const at of [10, sf.len - 18]) { g.push(); g.translate(C(sf.ox), 0, C(sf.oz)); g.rotateY(sf.theta); g.translate(C(at), 0, 0); downspout(g, roofY - 30); g.pop(); }
    }
  }
  if (f.quoins) for (const side of ['front', 'back'] as Side[]) {
    const sf = sideFrame(spec, side);
    g.push(); g.translate(C(sf.ox), 0, C(sf.oz)); g.rotateY(sf.theta); quoins(g, roofY); g.translate(C(sf.len), 0, 0); g.rotateY(Math.PI / 2); quoins(g, roofY); g.pop();
  }
  // rear fire escape for upper-floor back doors
  const fe = plan.extDoors.filter((d) => d.side === 'back' && d.floor > 0);
  if (fe.length) fireEscape(g, spec, plan, fe, out);
  return out;
}

function corniceFront(g: GeoBuilder, spec: BuildingSpec, y: number, kind: 'box' | 'dentil' | 'italianate' | 'coping', wrap = false) {
  const W = C(spec.w), D = C(spec.d);
  const profile = kind === 'dentil' ? PROFILES.dentilCrown : kind === 'italianate' ? PROFILES.italianate : PROFILES.box;
  const path: [number, number][] = wrap ? [[0, D], [0, 0], [W, 0], [W, D]] : [[0, 0], [W, 0]];
  const left = !spec.party?.left || wrap, right = !spec.party?.right || wrap;
  const p: [number, number][] = wrap ? path : [...(left ? [[0, Math.min(D, 1.2)] as [number, number]] : []), [0, 0], [W, 0], ...(right ? [[W, Math.min(D, 1.2)] as [number, number]] : [])];
  cornicePath(g, p, profile, 'satin:TRIM_WHITE', C(y), 1, false);
}

function fireEscape(g: GeoBuilder, spec: BuildingSpec, plan: Plan, doors: ExtDoor[], out: ExteriorOut) {
  const sf = sideFrame(spec, 'back');
  const k = 'satin:IRON_BLACK';
  const x0 = Math.min(...doors.map((d) => d.at)) - 60, w = 330;
  g.push(); g.translate(C(sf.ox), 0, C(sf.oz)); g.rotateY(sf.theta);
  for (const d of doors) {
    const y = d.y;
    // grated landing 120 deep
    for (let z = -118; z < 0; z += 4) boxC(g, k, x0, y - 4, z, x0 + w, y, z + 2);
    boxC(g, k, x0, y - 6, -120, x0 + w, y - 4, 0);
    g.push(); g.translate(C(x0), C(y), C(-120)); ironPicket(g, w, 107, k); g.pop();
    // stair down to the floor below (or drop ladder at the first level)
    const below = plan.floors.find((p) => p.floor === d.floor - 1)!;
    const rise = y - (d.floor === 1 ? Math.max(0, below.y + 240) : below.y);
    const n = Math.max(1, Math.ceil(rise / 20));
    for (let i = 0; i < n; i++) boxC(g, k, x0 + w - 70 - (i + 1) * (180 / n), y - (i + 1) * (rise / n) - 3, -110, x0 + w - 70 - i * (180 / n), y - (i + 1) * (rise / n), -40);
    out.floors.push([sidePoint(sf, x0, y, -120), sidePoint(sf, x0 + w, y, -120), sidePoint(sf, x0 + w, y, 0), sidePoint(sf, x0, y, 0)]);
  }
  g.pop();
}

function keyOf(wall: string): any { const p = wall.split(':'); return p[2] ?? 'BRICK_DOWNTOWN_A'; }
function normalizeStyle(style: string, w: number, h: number): string {
  const [kind, arg] = style.split(':');
  return `${kind}:${arg && arg !== 'x' ? arg : ''}:${Math.round(w)}:${Math.round(h)}`;
}
export function hashStr(s: string) { let h = 0; for (let i = 0; i < s.length; i++) h = (h * 31 + s.charCodeAt(i)) | 0; return h; }
