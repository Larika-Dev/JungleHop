// Individual grass blades (CLAUDE.md §8), generated on the GPU. Every blade is its own 3-triangle
// tapered, curved strip, placed in the vertex shader from its instance id on a world-anchored grid
// (stable as the camera moves) in four distance rings that cross-fade into each other:
//   0–6 m  ~800 blades/m²  · 6–16 m ~200/m² · 16–40 m ~40/m² (wider) · 40–100 m ~6/m² (clump-wide)
// Past ~100 m a blade is smaller than a pixel and the terrain's grass texture carries the lawn.
// A data texture baked around the camera (time-sliced on the CPU) supplies ground height and
// where grass grows: full density on lawns (GRASS_OCT), short and sparse on worn desire paths
// (GRASS_WORN), a few sedges on the forest-park floor, none on pavement, pads, clay banks or trails.
// Blades sway with the wind and receive the city's cascaded shadows. Colors are palette uniforms.
import {
  BufferAttribute, DataTexture, DataUtils, DoubleSide, HalfFloatType, InstancedBufferGeometry, LinearFilter,
  Mesh, MeshStandardMaterial, RGBAFormat, Vector2, Vector3,
} from 'three';
import { pc } from '../core/palette';
import { Terrain } from '../terrain/terrain';
import { splatAt } from '../terrain/terrainMesh';
import { canPlant } from './placement';
import { inPark, pathDist } from './parks';

const TEX = 256, TEXEL = 1.25, WINDOW = TEX * TEXEL; // 320 m window around the camera
const MASK = 2.5; // ground-type sampling (m)
const RINGS: { rIn: number; rOut: number; s: number; w: number }[] = [
  { rIn: 0, rOut: 6, s: 0.035, w: 1 },
  { rIn: 6, rOut: 16, s: 0.07, w: 2 },
  { rIn: 16, rOut: 40, s: 0.158, w: 4.4 },
  { rIn: 40, rOut: 100, s: 0.41, w: 11 },
];
const BAND = 0.18; // fraction of a ring boundary used for the cross-fade

const VERT_HEAD = /* glsl */ `
uniform vec3 uCam; uniform float uS, uRin, uRout, uBand, uWScale, uTime; uniform int uN;
uniform sampler2D uData; uniform vec2 uOrigin; uniform float uWin;
varying vec3 vGrass;
float gh(vec2 p, float k) { return fract(sin(dot(p, vec2(127.1 + k, 311.7 - k))) * 43758.5453); }
`;
const VERT_BODY = /* glsl */ `
  int ii = gl_InstanceID % uN, jj = gl_InstanceID / uN;
  vec2 cell = floor(uCam.xz / uS) + vec2(float(ii - uN / 2), float(jj - uN / 2));
  vec2 wp = (cell + vec2(gh(cell, 1.0), gh(cell, 2.0))) * uS;
  float d = distance(wp, uCam.xz);
  float bIn = uRin * uBand, bOut = uRout * uBand;
  float wgt = (uRin > 0.0 ? smoothstep(uRin - bIn, uRin, d) : 1.0) * (1.0 - smoothstep(uRout - bOut, uRout, d));
  vec4 dat = texture2D(uData, (wp - uOrigin) / uWin);
  float dens = dat.g;
  vec3 transformed;
  if (gh(cell, 3.0) > dens * wgt || d > uRout) {
    transformed = vec3(0.0, -1e4, 0.0); // culled blade (degenerate)
    vGrass = vec3(0.0);
  } else {
    float worn = dat.b;
    float hgt = dat.a * (0.75 + 0.5 * gh(cell, 4.0)) * mix(1.0, 0.55, worn);
    float ang = gh(cell, 5.0) * 6.2832;
    vec2 fdir = vec2(cos(ang), sin(ang)), side = vec2(-fdir.y, fdir.x);
    float t = position.y;                       // 0 at the root, 1 at the tip
    float wid = 0.0045 * uWScale * (0.8 + 0.4 * gh(cell, 6.0)) * position.x;
    float lean = (0.25 + 0.35 * gh(cell, 7.0)) * hgt;
    float wind = sin(uTime * 1.6 + wp.x * 0.37 + wp.y * 0.29) * 0.5 + sin(uTime * 2.7 + wp.x * 0.9) * 0.18;
    vec2 off = fdir * (lean * t * t) + vec2(0.7, 0.45) * wind * 0.09 * hgt * t * t;
    transformed = vec3(wp.x + side.x * wid + off.x, dat.r + t * hgt * (1.0 - 0.18 * t), wp.y + side.y * wid + off.y);
    float shade = mix(0.42, 1.0, t);
    vGrass = vec3(worn, gh(cell, 8.0), shade);
  }
`;
const FRAG_HEAD = /* glsl */ `
uniform vec3 uLawn, uWorn, uDry;
varying vec3 vGrass;
`;
const FRAG_COLOR = /* glsl */ `
  vec3 gcol = mix(uLawn, uWorn, vGrass.x);
  gcol = mix(gcol, uDry, step(0.86, vGrass.y) * 0.55);           // October: a few dry, straw-colored blades
  gcol *= (0.86 + 0.28 * vGrass.y) * vGrass.z;                     // per-blade value jitter, dark at the root
  diffuseColor.rgb *= gcol;
`;

export class GrassField {
  mesh: Mesh;
  material: MeshStandardMaterial;
  private meshes: Mesh[] = [];
  private data = new Uint16Array(TEX * TEX * 4);
  private tex: DataTexture;
  private origin = new Vector2(1e9, 1e9);
  private pending: { ox: number; oz: number; buf: Uint16Array; row: number } | null = null;
  private mask = new Map<number, number>(); // packed ground type per 2.5 m cell
  private uniforms: Record<string, { value: unknown }>[] = [];
  private cam = new Vector3();

  constructor() {
    this.tex = new DataTexture(this.data, TEX, TEX, RGBAFormat, HalfFloatType);
    this.tex.magFilter = this.tex.minFilter = LinearFilter;
    this.tex.needsUpdate = true;
    // blade: root (2 verts), mid (2), tip (1) — x = lateral factor, y = height factor
    const g0 = new InstancedBufferGeometry();
    g0.setAttribute('position', new BufferAttribute(new Float32Array([-0.5, 0, 0, 0.5, 0, 0, -0.38, 0.55, 0, 0.38, 0.55, 0, 0, 1, 0]), 3));
    g0.setAttribute('normal', new BufferAttribute(new Float32Array([0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0]), 3));
    g0.setIndex([0, 1, 2, 2, 1, 3, 2, 3, 4]);
    this.material = new MeshStandardMaterial({ side: DoubleSide, roughness: 0.92 });
    this.material.userData.matKey = 'leafy:GRASS_OCT';
    this.mesh = new Mesh(); // container (kept for API compatibility)
    this.mesh.name = 'grass-blades';
    for (const r of RINGS) {
      const N = Math.ceil((2 * r.rOut) / r.s) + 2;
      const g = g0.clone() as InstancedBufferGeometry;
      g.instanceCount = N * N;
      const m = this.material.clone();
      const u = {
        uCam: { value: this.cam }, uS: { value: r.s }, uRin: { value: r.rIn }, uRout: { value: r.rOut }, uBand: { value: BAND },
        uWScale: { value: r.w }, uTime: { value: 0 }, uN: { value: N }, uData: { value: this.tex }, uOrigin: { value: this.origin },
        uWin: { value: WINDOW }, uLawn: { value: pc('GRASS_OCT') }, uWorn: { value: pc('GRASS_WORN') }, uDry: { value: pc('PINE_STRAW').clone().lerp(pc('GINKGO_LEAF'), 0.35) },
      };
      this.uniforms.push(u);
      m.onBeforeCompile = (sh) => {
        Object.assign(sh.uniforms, u);
        sh.vertexShader = VERT_HEAD + sh.vertexShader.replace('#include <begin_vertex>', VERT_BODY);
        sh.fragmentShader = FRAG_HEAD + sh.fragmentShader.replace('#include <color_fragment>', '#include <color_fragment>\n' + FRAG_COLOR);
      };
      m.customProgramCacheKey = () => 'cm-grass-blades';
      m.userData.matKey = 'leafy:GRASS_OCT';
      const mesh = new Mesh(g, m);
      mesh.name = `grass-ring-${r.rOut}m`;
      mesh.frustumCulled = false;
      mesh.receiveShadow = true;
      mesh.castShadow = false;
      this.meshes.push(mesh);
      this.mesh.add(mesh);
    }
  }

  /** Materials (one per ring) for the lighting system (cascaded shadows, presets). */
  get materials() { return this.meshes.map((m) => m.material as MeshStandardMaterial); }

  private groundType(x: number, z: number): number {
    const i = Math.floor(x / MASK), j = Math.floor(z / MASK), k = i * 100003 + j;
    let v = this.mask.get(k);
    if (v === undefined) {
      const T = Terrain.get();
      const cx = (i + 0.5) * MASK, cz = (j + 0.5) * MASK;
      const sp = splatAt(cx, cz, T);
      if (inPark(cx, cz)) v = pathDist(cx, cz) < 0.4 ? 0 : 3;            // sparse sedges on the forest floor
      else if (sp[0] < 0.3 || sp[2] > 0.5 || !canPlant(cx, cz, 0.25)) v = 0;
      else v = sp[1] > 0.3 ? 2 : 1;                                        // worn desire path / lawn
      if (this.mask.size > 400000) this.mask.clear();
      this.mask.set(k, v);
    }
    return v;
  }

  private bakeRows(rows: number) {
    const p = this.pending!;
    const T = Terrain.get();
    const H = DataUtils.toHalfFloat;
    for (let r = 0; r < rows && p.row < TEX; r++, p.row++) {
      const z = p.oz + (p.row + 0.5) * TEXEL;
      for (let c = 0; c < TEX; c++) {
        const x = p.ox + (c + 0.5) * TEXEL;
        const t = this.groundType(x, z);
        const o = (p.row * TEX + c) * 4;
        p.buf[o] = H(T.height(x, z) - 0.01);
        p.buf[o + 1] = H(t === 1 ? 1 : t === 2 ? 0.55 : t === 3 ? 0.07 : 0);
        p.buf[o + 2] = H(t === 2 ? 1 : 0);
        p.buf[o + 3] = H(t === 3 ? 0.32 : 0.12); // mowed lawns ~12 cm, woodland sedges ~32 cm
      }
    }
    if (p.row >= TEX) {
      this.data.set(p.buf);
      this.tex.needsUpdate = true;
      this.origin.set(p.ox, p.oz);
      this.pending = null;
    }
  }

  update(cam: Vector3, force = false) {
    this.cam.copy(cam);
    const time = performance.now() / 1000;
    for (const u of this.uniforms) u.uTime.value = time;
    // too high above the ground for blades to resolve: the terrain texture carries the lawn
    const ground = Terrain.get().height(cam.x, cam.z);
    this.mesh.visible = cam.y - ground < 70;
    const cx = cam.x - (this.origin.x + WINDOW / 2), cz = cam.z - (this.origin.y + WINDOW / 2);
    if (!this.pending && (Math.abs(cx) > 40 || Math.abs(cz) > 40)) {
      const ox = Math.round((cam.x - WINDOW / 2) / 16) * 16, oz = Math.round((cam.z - WINDOW / 2) / 16) * 16;
      this.pending = { ox, oz, buf: new Uint16Array(TEX * TEX * 4), row: 0 };
      // the very first window (or a teleport far outside the current one) bakes at once
      const far = Math.abs(cx) > WINDOW / 2 - 100 || Math.abs(cz) > WINDOW / 2 - 100;
      if (force || far) this.bakeRows(TEX);
    }
    if (this.pending) this.bakeRows(force ? TEX : 24);
  }
}
