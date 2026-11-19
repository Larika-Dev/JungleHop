// Building manager: exterior shells into tile geometry, doors/collision/near-detail registration, and
// interior streaming (CLAUDE.md §7.6): interiors load within 35 m of any door (or when inside) and unload
// beyond 45 m; far windows then switch back to the interior-mapping shader.
import { Group, Matrix4, Object3D, PointLight, Vector3 } from 'three';
import type { App } from '../app';
import { GeoBuilder as GeoBuilderCtor, type GeoBuilder } from '../core/geo';
import { mat } from '../core/materials';
import { pc } from '../core/palette';
import { doorStyleBuilder } from '../kits/door';
import { registerBricksFromBuilder, unregisterOwner } from '../kits/nearDetail';
import { buildInterior, interiorCollision, type InteriorOut } from '../interiors/build';
import { generatePlan } from '../interiors/floorplan';
import { setInteriorLoaded } from '../interiors/interiorMapping';
import type { BuildingSpec, Plan } from '../interiors/types';
import { buildExterior, buildingMatrix, type ExteriorOut } from './exterior';

export const INTERIOR_LOAD_M = 35;
const INTERIOR_UNLOAD_M = 45;

export interface BuildingRec {
  spec: BuildingSpec;
  plan: Plan;
  matrix: Matrix4;
  inv: Matrix4;
  ext: ExteriorOut | null;
  bIndex: number;
  doorPts: Vector3[]; // world door hinge points
  interior: InteriorOut | null;
  tile: string;
  grades: { front: number; low: number };
}

const planCache = new Map<string, Plan>();
export function planFor(spec: BuildingSpec): Plan {
  let p = planCache.get(spec.id);
  if (!p) { p = spec.custom ? customPlan(spec) : generatePlan(spec); planCache.set(spec.id, p); }
  return p;
}
/** Landmark hooks (buildings/landmarks/*): custom plan, hero exterior geometry, extra interior geometry. */
export interface LandmarkHooks {
  plan?: (spec: BuildingSpec) => Plan;
  /** skip the generic shell (round/odd buildings build everything themselves) */
  customShell?: boolean;
  exterior?: (spec: BuildingSpec, plan: Plan, out: ExteriorOut) => void;
  interior?: (spec: BuildingSpec, plan: Plan, g: GeoBuilder) => void;
  /** custom terrain pads (default: footprint at FFL) */
  pads?: (spec: BuildingSpec) => { cx: number; cz: number; hw: number; hd: number; y: number }[];
  /** fixed FFL (world y) instead of terrain siting */
  fixedY?: number;
  /** FFL from the front grade (world y) */
  siteY?: (frontGrade: number, maxGrade: number) => number;
}
export const LANDMARK_HOOKS = new Map<string, LandmarkHooks>();
function customPlan(spec: BuildingSpec): Plan { const f = LANDMARK_HOOKS.get(spec.custom!)?.plan; return f ? f(spec) : generatePlan(spec); }

let nextIndex = 1;
export function ensureDoorStyle(app: App, style: string) {
  if (app.doors.hasStyle(style)) return;
  app.doors.registerStyle(style, doorStyleBuilder(style).g);
}

export class BuildingManager {
  records = new Map<string, BuildingRec>();
  loaded = new Set<BuildingRec>();
  roomsList: Object3D[] = [];
  private lights: PointLight[] = [];
  private t = 0;
  constructor(public app: App) {
    for (let i = 0; i < 6; i++) { const l = new PointLight(pc('INTERIOR_WARM'), 0, 14, 1.6); l.visible = false; app.scene.add(l); this.lights.push(l); }
  }

  /** Build a building's exterior into a tile's merged builder; register doors, collision, bricks. */
  addToTile(spec: BuildingSpec, tile: string, g: GeoBuilder, grades = { front: 0, low: 0 }, opts: { exteriorOnly?: (ext: ExteriorOut) => void } = {}): BuildingRec {
    const plan = planFor(spec);
    const matrix = buildingMatrix(spec);
    const rec: BuildingRec = { spec, plan, matrix, inv: matrix.clone().invert(), ext: null, bIndex: nextIndex++, doorPts: [], interior: null, tile, grades };
    const hooks = spec.custom ? LANDMARK_HOOKS.get(spec.custom) : undefined;
    const ext: ExteriorOut = hooks?.customShell ? { g: new GeoBuilderCtor(), doors: [], walls: [], floors: [], glass: [] } : buildExterior(spec, plan, { frontGrade: grades.front, lowGrade: grades.low, bIndex: rec.bIndex });
    hooks?.exterior?.(spec, plan, ext);
    rec.ext = ext;
    opts.exteriorOnly?.(ext);
    g.merge(ext.g, matrix);
    registerBricksFromBuilder(ext.g, matrix, `b:${spec.id}`);
    this.records.set(spec.id, rec);
    return rec;
  }

  /** Doors + collision for a building (call when its tile activates). */
  activate(rec: BuildingRec) {
    const app = this.app, owner = `b:${rec.spec.id}`;
    app.doors.removeOwner(owner);
    app.collision.removeOwner(owner);
    const M = rec.matrix;
    const rot = rec.spec.rotY;
    rec.doorPts = [];
    for (const d of rec.ext!.doors) {
      ensureDoorStyle(app, d.style);
      const h = d.hinge.clone().applyMatrix4(M);
      app.doors.add(owner, d.style, h, d.yaw + rot, d.w, d.h, d.swing);
      rec.doorPts.push(h);
    }
    const P = (x: number, z: number) => new Vector3(x, 0, z).applyMatrix4(M);
    const yBase = rec.spec.y;
    for (const [ax, az, bx, bz, y0, y1, t] of rec.ext!.walls) { const a = P(ax, az), b = P(bx, bz); app.collision.addWall(owner, a.x, a.z, b.x, b.z, yBase + y0, yBase + y1, t); }
    const addPoly = (poly: Vector3[]) => {
      const w = poly.map((p) => p.clone().applyMatrix4(M));
      const [p0, p1, p2] = w;
      const n = new Vector3().subVectors(p1, p0).cross(new Vector3().subVectors(p2, p0));
      if (Math.abs(n.y) < 1e-6) return;
      // plane: n·(p - p0) = 0 -> y = p0.y - (n.x (x-p0.x) + n.z (z-p0.z)) / n.y
      const a = -n.x / n.y, b = -n.z / n.y, c = p0.y - a * p0.x - b * p0.z;
      app.collision.addFloor(owner, w.map((p) => [p.x, p.z] as [number, number]), { a, b, c });
    };
    for (const poly of rec.ext!.floors) addPoly(poly);
    const ic = LANDMARK_HOOKS.get(rec.spec.custom ?? '')?.customShell ? { walls: [], floors: [] } : interiorCollision(rec.plan);
    for (const [ax, az, bx, bz, y0, y1, t] of ic.walls) { const a = P(ax, az), b = P(bx, bz); app.collision.addWall(owner, a.x, a.z, b.x, b.z, yBase + y0, yBase + y1, t); }
    for (const poly of ic.floors) addPoly(poly);
  }
  deactivate(rec: BuildingRec) {
    const owner = `b:${rec.spec.id}`;
    this.unloadInterior(rec);
    this.app.doors.removeOwner(owner);
    this.app.collision.removeOwner(owner);
  }
  dispose(rec: BuildingRec) { this.deactivate(rec); unregisterOwner(`b:${rec.spec.id}`); this.records.delete(rec.spec.id); }

  private loadInterior(rec: BuildingRec) {
    if (rec.interior) return;
    const out = buildInterior(rec.plan, rec.ext, LANDMARK_HOOKS.get(rec.spec.custom ?? '')?.customShell);
    const hooks = rec.spec.custom ? LANDMARK_HOOKS.get(rec.spec.custom) : undefined;
    if (hooks?.interior) { const g = new GeoBuilderCtor(); hooks.interior(rec.spec, rec.plan, g); out.group.add(g.toGroup(mat, 'landmark-interior', { castShadow: false })); }
    out.group.matrixAutoUpdate = false;
    out.group.matrix.copy(rec.matrix);
    out.group.updateMatrixWorld(true);
    this.app.scene.add(out.group);
    rec.interior = out;
    const owner = `int:${rec.spec.id}`;
    for (const d of out.doors) {
      ensureDoorStyle(this.app, d.style);
      this.app.doors.add(owner, d.style, d.hinge.clone().applyMatrix4(rec.matrix), d.yaw + rec.spec.rotY, d.w, d.h, d.swing);
    }
    for (const r of out.rooms) this.roomsList.push(r);
    setInteriorLoaded(rec.bIndex, true);
    this.loaded.add(rec);
  }
  unloadInterior(rec: BuildingRec) {
    if (!rec.interior) return;
    rec.interior.group.removeFromParent();
    rec.interior.group.traverse((o: any) => { if (o.isMesh) o.geometry.dispose(); });
    this.app.doors.removeOwner(`int:${rec.spec.id}`);
    const set = new Set(rec.interior.rooms);
    this.roomsList = this.roomsList.filter((r) => !set.has(r));
    rec.interior = null;
    setInteriorLoaded(rec.bIndex, false);
    this.loaded.delete(rec);
  }

  /** Distance (m) from a world point to a building's footprint (0 if inside). */
  distance(rec: BuildingRec, p: Vector3): number {
    const l = p.clone().applyMatrix4(rec.inv);
    const W = rec.spec.w / 100, D = rec.spec.d / 100;
    const dx = Math.max(0 - l.x, 0, l.x - W), dz = Math.max(0 - l.z, 0, l.z - D);
    return Math.hypot(dx, dz);
  }
  inside(rec: BuildingRec, p: Vector3) { return this.distance(rec, p) === 0; }

  /** Stream interiors around the player; cull floors when inside a building. */
  update(dt: number, active: (rec: BuildingRec) => boolean, force = false) {
    this.t += dt;
    if (!force && this.t < 0.25) return;
    this.t = 0;
    const p = this.app.player.pos;
    const cands: [BuildingRec, number][] = [];
    for (const rec of this.records.values()) {
      if (!active(rec)) { if (rec.interior) this.unloadInterior(rec); continue; }
      const dFoot = this.distance(rec, p);
      let d = dFoot;
      for (const dp of rec.doorPts) d = Math.min(d, Math.hypot(dp.x - p.x, dp.z - p.z));
      if (d < INTERIOR_LOAD_M) cands.push([rec, d]);
      else if (d > INTERIOR_UNLOAD_M && rec.interior) this.unloadInterior(rec);
    }
    cands.sort((a, b) => a[1] - b[1]);
    let budget = force ? 99 : 1; // one interior build per tick keeps frames smooth
    for (const [rec] of cands) if (!rec.interior && budget-- > 0) this.loadInterior(rec);
    // floor culling + interior lights for the building the player is in
    let lit = 0;
    for (const rec of this.loaded) {
      const inside = this.inside(rec, p);
      const localY = (p.y - rec.spec.y) * 100;
      let fl = 0;
      for (const fp of rec.plan.floors) if (localY >= fp.y - 50) fl = fp.floor;
      for (const [f, g] of rec.interior!.floorGroups) g.visible = !inside || Math.abs(f - fl) <= 1;
      if (inside) {
        // light the nearest rooms of the current floor (ceiling fixtures are items later; these stand in)
        const fp = rec.plan.floors.find((f) => f.floor === fl)!;
        const local = p.clone().applyMatrix4(rec.inv);
        const near = [...fp.rooms].map((r) => ({ r, d: Math.hypot((r.rect.x0 + r.rect.x1) / 200 - local.x, (r.rect.z0 + r.rect.z1) / 200 - local.z) })).sort((a, b) => a.d - b.d);
        for (const { r } of near) {
          if (lit >= this.lights.length) break;
          const l = this.lights[lit++];
          const c = new Vector3((r.rect.x0 + r.rect.x1) / 200, (fp.y + Math.min(fp.ceiling, 400) - 40) / 100, (r.rect.z0 + r.rect.z1) / 200).applyMatrix4(rec.matrix);
          l.visible = true; l.intensity = 22; l.color.copy(pc(r.finish.lighting)); l.position.copy(c);
        }
      }
    }
    for (let i = lit; i < this.lights.length; i++) this.lights[i].visible = false;
  }
  rooms() { return this.roomsList; }
  static group(): Group { return new Group(); }
}
