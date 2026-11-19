// Lighting & weather presets (CLAUDE.md §15). Sun azimuth = compass degrees clockwise from north
// (north = -Z, east = +X). Golden Hour is the default.
import { Mesh, PMREMGenerator, WebGLRenderTarget,
  Color, DirectionalLight, FogExp2, HemisphereLight, MeshStandardMaterial, Object3D, PerspectiveCamera, PointLight,
  Scene, Vector3, type Material, type WebGLRenderer,
} from 'three';
import { CSM } from 'three/examples/jsm/csm/CSM.js';
import { allMaterials, isExteriorKey, onMaterialCreated } from '../core/materials';
import { pc, type PaletteKey } from '../core/palette';
import { DEG } from '../core/units';
import { Sky } from './sky';

export type PresetName = 'golden' | 'midday' | 'night' | 'rain';
export interface Preset {
  name: PresetName;
  sunElev: number; sunAz: number; sunColor: PaletteKey; sunIntensity: number;
  zenith: PaletteKey; horizon: PaletteKey; groundKey: PaletteKey;
  hemiSky: PaletteKey; hemiGround: PaletteKey; hemiIntensity: number;
  fogKey: PaletteKey; fogDensity: number; exposure: number;
  lampsOn: boolean; windowsLit: number; wet: number; overcast: number; stars: number;
}

export const PRESETS: Record<PresetName, Preset> = {
  golden: { name: 'golden', sunElev: 8, sunAz: 250, sunColor: 'SUN_GOLDEN', sunIntensity: 2.2, zenith: 'SKY_GOLDEN_ZENITH', horizon: 'SKY_GOLDEN_HORIZON', groundKey: 'GRASS_OCT',
    hemiSky: 'SKY_GOLDEN_ZENITH', hemiGround: 'LIMESTONE_TRIM', hemiIntensity: 0.6, fogKey: 'SKY_GOLDEN_HORIZON', fogDensity: 0.0009, exposure: 1.0, lampsOn: false, windowsLit: 0.15, wet: 0, overcast: 0, stars: 0 },
  midday: { name: 'midday', sunElev: 55, sunAz: 180, sunColor: 'SUN_NOON', sunIntensity: 3.0, zenith: 'SKY_MIDDAY_ZENITH', horizon: 'SKY_MIDDAY_HORIZON', groundKey: 'GRASS_OCT',
    hemiSky: 'SKY_MIDDAY_ZENITH', hemiGround: 'CONCRETE_AGED', hemiIntensity: 0.8, fogKey: 'SKY_MIDDAY_HORIZON', fogDensity: 0.0006, exposure: 1.0, lampsOn: false, windowsLit: 0.05, wet: 0, overcast: 0, stars: 0 },
  night: { name: 'night', sunElev: 30, sunAz: 120, sunColor: 'MOON', sunIntensity: 0.15, zenith: 'SKY_NIGHT', horizon: 'SKY_NIGHT', groundKey: 'SKY_NIGHT',
    hemiSky: 'SKY_NIGHT', hemiGround: 'SKY_NIGHT', hemiIntensity: 0.6, fogKey: 'SKY_NIGHT', fogDensity: 0.0012, exposure: 1.0, lampsOn: true, windowsLit: 0.6, wet: 0, overcast: 0, stars: 1 },
  rain: { name: 'rain', sunElev: 40, sunAz: 200, sunColor: 'SKY_RAIN', sunIntensity: 0.55, zenith: 'SKY_RAIN', horizon: 'SKY_RAIN', groundKey: 'SKY_RAIN',
    hemiSky: 'SKY_RAIN', hemiGround: 'ASPHALT_AGED', hemiIntensity: 1.1, fogKey: 'SKY_RAIN', fogDensity: 0.004, exposure: 1.0, lampsOn: true, windowsLit: 0.35, wet: 1, overcast: 1, stars: 0 },
};

export function sunDirection(elevDeg: number, azDeg: number): Vector3 {
  const e = elevDeg * DEG, a = azDeg * DEG;
  return new Vector3(Math.sin(a) * Math.cos(e), Math.sin(e), -Math.cos(a) * Math.cos(e)).normalize();
}

/** Lamp registry: street lamps register positions; the nearest N get real point lights at night. */
export interface LampPoint { x: number; y: number; z: number; color: PaletteKey; range: number; }

export class LightingSystem {
  sky = new Sky();
  hemi = new HemisphereLight();
  sun: DirectionalLight | null = null;
  csm: CSM | null = null;
  preset: Preset = PRESETS.golden;
  lamps: LampPoint[] = [];
  private pool: PointLight[] = [];
  private listeners: ((p: Preset) => void)[] = [];
  root = new Object3D();

  constructor(private scene: Scene, private camera: PerspectiveCamera, private renderer: WebGLRenderer, opts: { shadows: 'csm' | 'simple' | 'off' }) {
    this.root.name = 'lighting';
    scene.add(this.root);
    scene.add(this.sky.mesh);
    this.root.add(this.hemi);
    if (opts.shadows === 'csm') {
      this.csm = new CSM({ maxFar: 400, cascades: 4, mode: 'practical', parent: this.root, shadowMapSize: 2048, lightDirection: new Vector3(0, -1, 0), camera, lightMargin: 120, lightNear: 1, lightFar: 2000 } as any);
      (this.csm as any).fade = true;
      for (const l of this.csm.lights) { l.shadow.bias = -0.0002; l.shadow.normalBias = 0.02; }
      onMaterialCreated((m) => this.setupShadowMaterial(m));
    } else {
      this.sun = new DirectionalLight();
      this.sun.castShadow = opts.shadows === 'simple';
      this.sun.shadow.mapSize.set(2048, 2048);
      const c = this.sun.shadow.camera; c.left = -120; c.right = 120; c.top = 120; c.bottom = -120; c.near = 1; c.far = 1500;
      this.sun.shadow.bias = -0.0003; this.sun.shadow.normalBias = 0.03;
      this.root.add(this.sun, this.sun.target);
    }
    for (let i = 0; i < 12; i++) {
      const p = new PointLight(pc('LAMP_LED'), 0, 18, 2);
      p.visible = false;
      this.pool.push(p);
      this.root.add(p);
    }
    scene.fog = new FogExp2(0, 0.001);
    onMaterialCreated((m) => this.applyMaterial(m, this.preset));
  }

  onChange(f: (p: Preset) => void) { this.listeners.push(f); f(this.preset); }

  /** Enable CSM on a material, chaining any existing onBeforeCompile (custom shaders). */
  setupShadowMaterial(m: Material) {
    if (!this.csm || !(m as MeshStandardMaterial).isMeshStandardMaterial || m.userData.csm) return;
    const prev = m.onBeforeCompile;
    this.csm.setupMaterial(m);
    const csmFn = m.onBeforeCompile;
    m.onBeforeCompile = (sh, r) => { csmFn.call(m, sh, r); prev.call(m, sh, r); };
    m.userData.csm = true;
  }
  /** Apply preset-dependent tweaks to custom materials not created via mat(). */
  adopt(m: Material) { this.setupShadowMaterial(m); this.applyMaterial(m, this.preset); }

  apply(name: PresetName) {
    const p = PRESETS[name];
    this.preset = p;
    const dir = sunDirection(p.sunElev, p.sunAz);
    const u = this.sky.uniforms;
    u.zenith.value.copy(pc(p.zenith)); u.horizon.value.copy(pc(p.horizon)); u.ground.value.copy(pc(p.groundKey)).multiplyScalar(0.6);
    u.sunDir.value.copy(dir); u.sunColor.value.copy(pc(p.sunColor)); u.stars.value = p.stars; u.overcast.value = p.overcast;
    if (name === 'night') u.sunSize.value = 0.99985; else u.sunSize.value = 0.9995;
    this.hemi.color.copy(pc(p.hemiSky)); this.hemi.groundColor.copy(pc(p.hemiGround)); this.hemi.intensity = p.hemiIntensity;
    if (this.csm) {
      this.csm.lightDirection.copy(dir).negate();
      for (const l of this.csm.lights) { l.color.copy(pc(p.sunColor)); l.intensity = p.sunIntensity; l.castShadow = p.overcast < 0.5; }
    }
    if (this.sun) {
      this.sun.color.copy(pc(p.sunColor)); this.sun.intensity = p.sunIntensity;
      this.sun.castShadow = this.sun.castShadow && p.overcast < 0.5;
    }
    (this.scene.fog as FogExp2).color.copy(pc(p.fogKey));
    (this.scene.fog as FogExp2).density = p.fogDensity;
    this.renderer.toneMappingExposure = p.exposure;
    for (const [, m] of allMaterials()) this.applyMaterial(m, p);
    this.updateEnvironment(p);
    for (const f of this.listeners) f(p);
  }

  /** Sky-only PMREM environment so glass, puddles and wet paving reflect the preset's sky. */
  private pmrem: PMREMGenerator | null = null;
  private envRT: WebGLRenderTarget | null = null;
  private updateEnvironment(p: Preset) {
    try {
      this.pmrem ??= new PMREMGenerator(this.renderer);
      const sc = new Scene();
      sc.add(new Mesh(this.sky.mesh.geometry, this.sky.mesh.material));
      this.envRT?.dispose();
      this.envRT = this.pmrem.fromScene(sc, 0, 1, 6000);
      this.scene.environment = this.envRT.texture;
      this.scene.environmentIntensity = p.lampsOn && p.wet === 0 ? 0.12 : 0.3 + 0.4 * p.wet;
    } catch { this.scene.environment = null; }
  }

  /** Wetness & night emissives per material (CLAUDE.md §15 rain: roughness -0.35, darken 15%). */
  private applyMaterial(m: Material, p: Preset) {
    const sm = m as MeshStandardMaterial;
    const key = m.userData.matKey as string | undefined;
    if (!key || !sm.isMeshStandardMaterial) return;
    if (isExteriorKey(key) && m.userData.baseColor) {
      sm.roughness = Math.max(0.04, (m.userData.baseRoughness ?? sm.roughness) - 0.35 * p.wet);
      sm.color.copy(m.userData.baseColor).multiplyScalar(1 - 0.15 * p.wet);
    }
    if (m.userData.wetOnly) m.visible = p.wet > 0;
    if (key.startsWith('glow:')) sm.emissiveIntensity = p.lampsOn ? 3.5 : 0;
    if (key.startsWith('emit:INTERIOR')) sm.emissiveIntensity = p.lampsOn ? 1.6 : 0.6;
  }

  private tmp = new Vector3();
  update(playerPos: Vector3) {
    if (this.csm) this.csm.update();
    if (this.sun) {
      const d = sunDirection(this.preset.sunElev, this.preset.sunAz);
      this.sun.position.copy(playerPos).addScaledVector(d, 600);
      this.sun.target.position.copy(playerPos);
      this.sun.target.updateMatrixWorld();
    }
    // nearest lamps get real lights at night
    if (this.preset.lampsOn && this.lamps.length) {
      const near = this.lamps
        .map((l) => ({ l, d: (l.x - playerPos.x) ** 2 + (l.z - playerPos.z) ** 2 }))
        .sort((a, b) => a.d - b.d).slice(0, this.pool.length);
      this.pool.forEach((pl, i) => {
        const n = near[i];
        if (!n || n.d > 90 * 90) { pl.visible = false; return; }
        pl.visible = true; pl.position.set(n.l.x, n.l.y, n.l.z); pl.color.copy(pc(n.l.color)); pl.intensity = 18; pl.distance = n.l.range;
      });
    } else for (const pl of this.pool) pl.visible = false;
    void this.tmp;
  }
  get color(): Color { return pc(this.preset.sunColor); }
}
