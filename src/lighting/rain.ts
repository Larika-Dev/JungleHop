// Rain preset effects (CLAUDE.md §15): falling rain streaks around the camera, drip lines falling from
// cornices/eaves of nearby buildings, and puddles in paver depressions (around heaved tree pits) and
// along gutters. Wet material response (roughness −0.35, darken 15%) lives in presets.ts.
import {
  AdditiveBlending, BufferAttribute, BufferGeometry, Color, LineSegments, Material, MeshStandardMaterial,
  PerspectiveCamera, Scene, ShaderMaterial, Vector3,
} from 'three';
import { pc } from '../core/palette';
import { registerMaterialFactory } from '../core/materials';
import { Rng } from '../core/rng';
import { Terrain } from '../terrain/terrain';
import { roadPlan } from '../roads/build';
import { RoadNetwork, polyAt } from '../roads/network';
import { registerTileBuilder } from '../world/tileRegistry';
import { tileAt } from '../core/tiles';
import { cityPlan } from '../world/cityPlan';
import { planFor } from '../buildings/manager';
import { buildingMatrix } from '../buildings/exterior';
import type { Preset } from './presets';

const BOX = new Vector3(70, 36, 70);
const STREAKS = 14000;
const FALL = 9.0; // m/s terminal velocity of rain
const WIND = new Vector3(0.9, 0, 0.4);

const streakVS = /* glsl */ `
  attribute vec3 seed; attribute float tip;
  uniform vec3 uCam, uBox, uWind; uniform float uTime, uFall, uLen;
  varying float vA;
  void main(){
    vec3 vel = vec3(uWind.x, -uFall, uWind.z);
    vec3 p = seed * uBox + vel * uTime;
    p = mod(p - uCam + uBox * 0.5, uBox) + uCam - uBox * 0.5;
    p -= normalize(vel) * uLen * tip;
    vA = 1.0 - tip * 0.85;
    gl_Position = projectionMatrix * viewMatrix * vec4(p, 1.0);
  }`;
const streakFS = /* glsl */ `
  uniform vec3 uColor; uniform float uOpacity; varying float vA;
  void main(){ gl_FragColor = vec4(uColor, uOpacity * vA); }`;

const dripVS = /* glsl */ `
  attribute vec3 origin; attribute float fallH, phase, tip;
  uniform float uTime, uFall, uLen;
  varying float vA;
  void main(){
    float t = fract(uTime * uFall / max(fallH, 0.5) + phase);
    vec3 p = origin - vec3(0.0, t * fallH + tip * uLen, 0.0);
    vA = (1.0 - tip * 0.8) * smoothstep(0.0, 0.05, t);
    gl_Position = projectionMatrix * viewMatrix * vec4(p, 1.0);
  }`;

function lineMaterial(vs: string, extra: Record<string, { value: unknown }>, opacity: number) {
  return new ShaderMaterial({
    vertexShader: vs, fragmentShader: streakFS, transparent: true, depthWrite: false, blending: AdditiveBlending, fog: false,
    uniforms: { uTime: { value: 0 }, uFall: { value: FALL }, uLen: { value: 0.55 }, uColor: { value: new Color() }, uOpacity: { value: opacity }, ...extra },
  });
}

export class RainSystem {
  streaks: LineSegments;
  drips: LineSegments;
  private on = false;
  private t = 0;
  private dripCenter = new Vector3(1e9, 0, 0);
  private camPos = new Vector3();

  constructor(private scene: Scene, private camera: PerspectiveCamera, private isInside: () => boolean) {
    // rain streaks: 2 vertices per streak sharing a seed; tip = 0 head, 1 tail
    const rng = new Rng('rain');
    const seed = new Float32Array(STREAKS * 6), tip = new Float32Array(STREAKS * 2);
    for (let i = 0; i < STREAKS; i++) {
      const a = [rng.next(), rng.next(), rng.next()];
      seed.set(a, i * 6); seed.set(a, i * 6 + 3); tip[i * 2 + 1] = 1;
    }
    const g = new BufferGeometry();
    g.setAttribute('position', new BufferAttribute(new Float32Array(STREAKS * 6), 3));
    g.setAttribute('seed', new BufferAttribute(seed, 3));
    g.setAttribute('tip', new BufferAttribute(tip, 1));
    const sm = lineMaterial(streakVS, { uCam: { value: new Vector3() }, uBox: { value: BOX.clone() }, uWind: { value: WIND.clone() } }, 0.28);
    (sm.uniforms.uColor.value as Color).copy(pc('MARKING_WHITE')).multiplyScalar(0.55);
    this.streaks = new LineSegments(g, sm);
    this.streaks.frustumCulled = false;
    this.streaks.name = 'rain-streaks';
    this.streaks.visible = false;
    this.streaks.renderOrder = 10;

    const dm = lineMaterial(dripVS, {}, 0.5);
    dm.uniforms.uLen.value = 0.18;
    dm.uniforms.uFall.value = 6.5;
    (dm.uniforms.uColor.value as Color).copy(pc('MARKING_WHITE')).multiplyScalar(0.6);
    this.drips = new LineSegments(new BufferGeometry(), dm);
    this.drips.frustumCulled = false;
    this.drips.name = 'rain-drips';
    this.drips.visible = false;
    scene.add(this.streaks, this.drips);
  }

  setPreset(p: Preset) {
    this.on = p.wet > 0.5 && p.overcast > 0.5;
    this.streaks.visible = this.drips.visible = this.on;
    const night = p.lampsOn && p.name === 'night';
    (this.streaks.material as ShaderMaterial).uniforms.uOpacity.value = night ? 0.18 : 0.28;
  }

  update(dt: number) {
    if (!this.on) return;
    this.t += dt;
    this.camera.getWorldPosition(this.camPos);
    const sm = this.streaks.material as ShaderMaterial, dm = this.drips.material as ShaderMaterial;
    sm.uniforms.uTime.value = this.t % 1000;
    (sm.uniforms.uCam.value as Vector3).copy(this.camPos);
    dm.uniforms.uTime.value = this.t % 1000;
    // inside a building: no rain in the room (drips outside the windows still read)
    this.streaks.visible = !this.isInside();
    if (this.camPos.distanceTo(this.dripCenter) > 12) this.rebuildDrips();
  }

  /** Drip sources every 30 cm along the front and back eaves of buildings within 45 m. */
  private rebuildDrips() {
    this.dripCenter.copy(this.camPos);
    const T = Terrain.get();
    const origin: number[] = [], fallH: number[] = [], phase: number[] = [], tip: number[] = [];
    const rng = new Rng(`drips:${Math.round(this.camPos.x)}:${Math.round(this.camPos.z)}`);
    const v = new Vector3();
    const R = 45;
    const ct = tileAt(this.camPos.x, this.camPos.z);
    for (let dc = -1; dc <= 1; dc++) for (let dr = -1; dr <= 1; dr++) {
      for (const s of cityPlan().byTile.get(`T_${ct.col + dc}_${ct.row + dr}`) ?? []) {
        const sp = s.spec;
        if (Math.hypot(sp.x - this.camPos.x, sp.z - this.camPos.z) > R + Math.max(sp.w, sp.d) / 100) continue;
        let roof = 0;
        try { roof = planFor(sp).roofY / 100; } catch { continue; }
        if (sp.custom === 'old_cistern' || sp.custom === 'benefactor_stadium' || sp.custom === 'grove_amphitheatre') continue;
        const M = buildingMatrix(sp);
        const W = sp.w / 100, D = sp.d / 100;
        for (const [z, out] of [[0, -0.32], [D, 0.32]] as const) {
          for (let x = 0.15; x < W; x += 0.3) {
            if (rng.next() < 0.35) continue;
            v.set(x, roof, z + out).applyMatrix4(M);
            if (Math.hypot(v.x - this.camPos.x, v.z - this.camPos.z) > R) continue;
            const gy = T.surface(v.x, v.z);
            const h = v.y - gy;
            if (h < 1) continue;
            const ph = rng.next();
            for (const tp of [0, 1]) { origin.push(v.x, v.y, v.z); fallH.push(h); phase.push(ph); tip.push(tp); }
            if (origin.length > 3 * 2 * 9000) break;
          }
        }
      }
    }
    const g = this.drips.geometry;
    g.dispose();
    const ng = new BufferGeometry();
    const n = tip.length;
    ng.setAttribute('position', new BufferAttribute(new Float32Array(n * 3), 3));
    ng.setAttribute('origin', new BufferAttribute(new Float32Array(origin), 3));
    ng.setAttribute('fallH', new BufferAttribute(new Float32Array(fallH), 1));
    ng.setAttribute('phase', new BufferAttribute(new Float32Array(phase), 1));
    ng.setAttribute('tip', new BufferAttribute(new Float32Array(tip), 1));
    this.drips.geometry = ng;
    void this.scene;
  }
}

// ------------------------------------------------------------------------------------------ puddles
// PUDDLE_TINT, near-mirror; visible only when the preset is wet (presets.ts toggles material.visible).
registerMaterialFactory((key) => {
  if (key !== 'puddle') return null;
  const m = new MeshStandardMaterial({ color: pc('PUDDLE_TINT'), roughness: 0.03, metalness: 0.2, transparent: true, opacity: 0.88, polygonOffset: true, polygonOffsetFactor: -2, polygonOffsetUnits: -2 });
  m.userData.wetOnly = true;
  return m as Material;
});

/** Irregular puddle polygon (fan, upward-facing) at a surface point. */
function puddle(g: import('../core/geo').GeoBuilder, x: number, z: number, y: number, r: number, stretch: [number, number], rng: Rng) {
  const N = 14;
  const pts: [number, number][] = [];
  const ph = rng.next() * 6.283;
  for (let i = 0; i < N; i++) {
    const a = (i / N) * Math.PI * 2;
    const k = r * (0.72 + 0.28 * Math.sin(a * 3 + ph) * 0.6 + 0.2 * rng.next());
    const lx = Math.cos(a) * k * 1.6, lz = Math.sin(a) * k * 0.8;
    pts.push([x + lx * stretch[0] - lz * stretch[1], z + lx * stretch[1] + lz * stretch[0]]);
  }
  for (let i = 0; i < N; i++) {
    const a = pts[i], b = pts[(i + 1) % N];
    g.tri('puddle', [x, y, z], [b[0], y, b[1]], [a[0], y, a[1]]);
  }
}

registerTileBuilder({
  name: 'puddles', order: 75,
  build: (ctx) => {
    const T = Terrain.get();
    const rng = new Rng(`puddles:${ctx.name}`);
    const inTile = (x: number, z: number) => { const t = tileAt(x, z); return t.col === ctx.tile.col && t.row === ctx.tile.row; };
    // paver depressions next to heaved tree pits (CLAUDE.md §5: roots heave pavers within 3 m)
    for (const p of roadPlan().treePits) {
      if (!inTile(p.x, p.z) || rng.next() < 0.45) continue;
      const a = rng.next() * Math.PI * 2, d = 1.4 + rng.next() * 1.3;
      const x = p.x + Math.cos(a) * d, z = p.z + Math.sin(a) * d;
      puddle(ctx.gNoShadow, x, z, T.surface(x, z) + 0.004, 0.22 + rng.next() * 0.25, [Math.cos(a), Math.sin(a)], rng);
    }
    // gutter puddles along curbs (asphalt low point next to the curb face)
    for (const r of RoadNetwork.get().roads) {
      if (r.kind === 'rail' || r.kind === 'highway') continue;
      for (let s = 7; s < r.length - 7; s += 11 + rng.next() * 14) {
        if (rng.next() < 0.5) continue;
        const f = polyAt(r, s);
        const side = rng.next() < 0.5 ? 1 : -1;
        const d = side * (r.half - 0.32);
        const x = f.p[0] + f.n[0] * d, z = f.p[1] + f.n[1] * d;
        if (!inTile(x, z)) continue;
        const hit = RoadNetwork.get().query(x, z);
        if (!hit || hit.zone !== 'asphalt' || hit.bridge) continue;
        puddle(ctx.gNoShadow, x, z, T.surface(x, z) + 0.006, 0.25 + rng.next() * 0.35, [f.t[0], f.t[1]], rng);
      }
    }
  },
});
