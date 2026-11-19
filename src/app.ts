// Application shell: renderer, camera, post-processing, player, HUD, debug tools, automation API.
import {
  ACESFilmicToneMapping, Timer, Object3D, OrthographicCamera, PCFShadowMap, PerspectiveCamera, Scene, SRGBColorSpace,
  Vector2, Vector3, WebGLRenderer,
} from 'three';
import { EffectComposer } from 'three/examples/jsm/postprocessing/EffectComposer.js';
import { GTAOPass } from 'three/examples/jsm/postprocessing/GTAOPass.js';
import { OutputPass } from 'three/examples/jsm/postprocessing/OutputPass.js';
import { RenderPass } from 'three/examples/jsm/postprocessing/RenderPass.js';
import { css, cssA } from './core/palette';
import { paletteKeyOf } from './core/materials';
import { tileNameAt } from './core/tiles';
import { MeasureTool } from './debug/measure';
import { PerfHud } from './debug/perfHud';
import { RoomLabels } from './debug/roomLabels';
import { setWireframe } from './debug/wireframe';
import { LightingSystem, type PresetName } from './lighting/presets';
import { CollisionWorld } from './player/collision';
import { Player } from './player/controls';
import { DoorSystem } from './player/doors';
import { Minimap } from './player/minimap';
import { Raycaster } from 'three';
import type { DebugOverlays } from './debug/overlays';

export interface WorldHandle {
  /** Per-frame update (streaming etc). */
  update(dt: number): void;
  /** Objects the measure tool / palette picker may hit. */
  pickables(): Object3D[];
  /** Room Object3Ds for labels. */
  rooms(): Object3D[];
  ready(): Promise<void>;
  stats?(): string[];
  overlays?: DebugOverlays;
  goto?: (id: string, label?: string, facing?: number) => boolean;
}

export class App {
  params: URLSearchParams;
  renderer: WebGLRenderer;
  scene = new Scene();
  camera: PerspectiveCamera;
  ortho: OrthographicCamera | null = null;
  composer: EffectComposer | null = null;
  collision = new CollisionWorld();
  doors: DoorSystem;
  player: Player;
  lighting: LightingSystem;
  minimap: Minimap;
  hud: HTMLElement;
  perf: PerfHud;
  measure: MeasureTool;
  roomLabels: RoomLabels;
  world: WorldHandle | null = null;
  debugOn = false;
  debugFlags = { wireframe: false, rooms: false, tiles: false, radius: false, measure: false, picker: true };
  private clock = new Timer();
  private prompt: HTMLDivElement;
  private pickInfo: HTMLDivElement;
  private debugPanel: HTMLDivElement;
  private raycaster = new Raycaster();
  frameHooks: ((dt: number) => void)[] = [];

  constructor(public container: HTMLElement) {
    this.params = new URLSearchParams(location.search);
    const P = this.params;
    this.renderer = new WebGLRenderer({ antialias: P.get('aa') !== '0', powerPreference: 'high-performance', preserveDrawingBuffer: P.has('shot') });
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio, P.has('shot') ? 1 : 2));
    this.renderer.setSize(window.innerWidth, window.innerHeight);
    this.renderer.toneMapping = ACESFilmicToneMapping;
    this.renderer.toneMappingExposure = 1.0;
    this.renderer.outputColorSpace = SRGBColorSpace;
    const shadows = (P.get('shadows') ?? 'csm') as 'csm' | 'simple' | 'off';
    this.renderer.shadowMap.enabled = shadows !== 'off';
    this.renderer.shadowMap.type = PCFShadowMap;
    this.renderer.info.autoReset = false;
    container.appendChild(this.renderer.domElement);

    this.camera = new PerspectiveCamera(Number(P.get('fov') ?? 70), window.innerWidth / window.innerHeight, 0.03, 6000);
    this.scene.add(this.camera);
    this.doors = new DoorSystem(this.scene, this.collision);
    this.player = new Player(this.camera, this.renderer.domElement, this.collision);
    this.lighting = new LightingSystem(this.scene, this.camera, this.renderer, { shadows });

    this.hud = document.getElementById('hud')!;
    this.minimap = new Minimap(this.hud);
    this.perf = new PerfHud(this.hud);
    this.measure = new MeasureTool(this.hud, this.camera, () => this.world?.pickables() ?? []);
    this.scene.add(this.measure.root);
    this.measure.setActive(false);
    this.roomLabels = new RoomLabels(this.hud, () => this.world?.rooms() ?? []);
    const cross = document.createElement('div'); cross.className = 'crosshair'; this.hud.appendChild(cross);
    this.prompt = document.createElement('div'); this.prompt.className = 'prompt'; this.hud.appendChild(this.prompt);
    this.pickInfo = document.createElement('div'); this.pickInfo.className = 'pickinfo'; this.hud.appendChild(this.pickInfo);
    this.debugPanel = this.buildDebugPanel();
    if (P.get('hud') === '0') this.hud.style.display = 'none';

    if (P.get('ao') !== '0') {
      this.composer = new EffectComposer(this.renderer);
      this.composer.addPass(new RenderPass(this.scene, this.camera));
      const gtao = new GTAOPass(this.scene, this.camera, window.innerWidth, window.innerHeight);
      gtao.updateGtaoMaterial({ radius: 0.6, distanceExponent: 1.5, thickness: 1, scale: 1.2, samples: 12 });
      gtao.blendIntensity = 0.85;
      this.composer.addPass(gtao);
      this.composer.addPass(new OutputPass());
    }

    window.addEventListener('resize', () => this.resize());
    this.renderer.domElement.addEventListener('click', (e) => this.onClick(e));
    this.player.onKey.push((code) => this.onKey(code));
    this.lighting.apply((P.get('preset') ?? 'golden') as PresetName);
  }

  private resize() {
    const w = window.innerWidth, h = window.innerHeight;
    this.camera.aspect = w / h; this.camera.updateProjectionMatrix();
    this.renderer.setSize(w, h);
    this.composer?.setSize(w, h);
  }

  private onClick(e: MouseEvent) {
    if (this.debugOn && this.debugFlags.measure) {
      const ndc = this.player.locked ? new Vector2(0, 0) : new Vector2((e.clientX / innerWidth) * 2 - 1, -(e.clientY / innerHeight) * 2 + 1);
      this.measure.click(ndc);
      return;
    }
    this.player.requestLock();
  }

  private onKey(code: string) {
    if (code === 'Backquote') { this.debugOn = !this.debugOn; this.debugPanel.style.display = this.debugOn ? 'block' : 'none'; this.applyDebug(); }
    if (code === 'KeyM') this.minimap.toggleFull();
    if (code === 'KeyE') {
      const { origin, dir } = this.player.look();
      const d = this.doors.pick(origin, dir);
      if (d) this.doors.toggle(d);
    }
    if (code === 'Digit1') this.lighting.apply('golden');
    if (code === 'Digit2') this.lighting.apply('midday');
    if (code === 'Digit3') this.lighting.apply('night');
    if (code === 'Digit4') this.lighting.apply('rain');
  }

  private buildDebugPanel(): HTMLDivElement {
    const el = document.createElement('div');
    el.className = 'debugpanel';
    el.style.display = 'none';
    const flags: [keyof App['debugFlags'], string][] = [
      ['measure', 'Measure tool (click 2 points, cm)'], ['wireframe', 'Wireframe'], ['rooms', 'Room labels'],
      ['picker', 'Palette key under cursor'], ['tiles', 'Tile boundaries'], ['radius', 'Interior streaming radius (35 m)'],
    ];
    el.innerHTML = `<b>DEBUG</b> (backtick)<br>`;
    for (const [k, label] of flags) {
      const row = document.createElement('label');
      const cb = document.createElement('input'); cb.type = 'checkbox'; cb.checked = this.debugFlags[k];
      cb.onchange = () => { this.debugFlags[k] = cb.checked; this.applyDebug(); };
      row.append(cb, ' ', label); el.append(row, document.createElement('br'));
    }
    el.append('Presets: 1 golden · 2 midday · 3 night · 4 rain');
    this.hud.appendChild(el);
    return el;
  }

  applyDebug() {
    const on = this.debugOn;
    setWireframe(this.scene, on && this.debugFlags.wireframe);
    this.measure.setActive(on && this.debugFlags.measure);
    this.roomLabels.enabled = on && this.debugFlags.rooms;
    this.world?.overlays?.setTiles(on && this.debugFlags.tiles);
    this.world?.overlays?.setRadius(on && this.debugFlags.radius);
    if (this.debugOn && this.debugFlags.measure && this.player.locked) document.exitPointerLock();
  }

  setWorld(w: WorldHandle) { this.world = w; this.applyDebug(); }

  /** Orthographic overhead camera for map/overhead screenshots. */
  setOrtho(cx: number, cz: number, width: number, height?: number) {
    const aspect = innerWidth / innerHeight;
    const h = height ?? width / aspect;
    const w = height ? height * aspect : width;
    this.ortho = new OrthographicCamera(-w / 2, w / 2, h / 2, -h / 2, 1, 3000);
    this.ortho.position.set(cx, 1200, cz);
    this.ortho.up.set(0, 0, -1);
    this.ortho.lookAt(cx, 0, cz);
    this.ortho.updateMatrixWorld();
  }

  frame = () => {
    this.clock.update();
    const dt = this.clock.getDelta();
    this.renderer.info.reset();
    this.player.update(dt);
    this.doors.update(dt);
    this.world?.update(dt);
    for (const h of this.frameHooks) h(dt);
    this.lighting.update(this.player.pos);
    this.render();
    this.hudUpdate();
  };

  render() {
    if (this.ortho) {
      const fog = this.scene.fog; this.scene.fog = null;
      this.renderer.render(this.scene, this.ortho);
      this.scene.fog = fog;
      return;
    }
    if (this.composer) this.composer.render(); else this.renderer.render(this.scene, this.camera);
  }

  private hudUpdate() {
    const p = this.player;
    this.minimap.update(p.pos.x, p.pos.z, p.yaw);
    this.perf.update(this.renderer, this.debugOn);
    this.roomLabels.draw(this.camera, css('ONSU_WHITE'), cssA('UI_PANEL', 0.75));
    // interaction prompt
    const { origin, dir } = p.look();
    const d = this.doors.pick(origin, dir);
    this.prompt.textContent = d ? `E — ${d.angle > 0 ? 'close' : 'open'} door` : '';
    // palette key under cursor
    if (this.debugOn && this.debugFlags.picker && this.world) {
      this.raycaster.setFromCamera(new Vector2(0, 0), this.camera);
      this.raycaster.far = 60;
      const hit = this.raycaster.intersectObjects(this.world.pickables(), true)[0];
      const key = hit ? (hit.object.userData.matKey as string) ?? '' : '';
      this.pickInfo.textContent = hit ? `${paletteKeyOf(key)}   [${key}]   ${(hit.distance * 100).toFixed(0)} cm` : '';
    } else this.pickInfo.textContent = '';
  }

  start() {
    this.renderer.setAnimationLoop(this.frame);
  }

  /** Automation API for Playwright screenshots & export (window.__cm). */
  api() {
    return {
      app: this,
      ready: () => this.world?.ready() ?? Promise.resolve(),
      view: (x: number, y: number | null, z: number, yaw = 0, pitch = 0, fly = true) => {
        this.ortho = null;
        this.player.fly = fly;
        this.player.teleport(x, z, y ?? undefined, yaw, pitch);
        // null y in fly mode: stand on whatever is below at eye height (165 cm)
        if (y === null && fly) { this.player.pos.y += 1.65; this.player.syncCamera(); }
      },
      ortho: (cx: number, cz: number, w: number, h?: number) => this.setOrtho(cx, cz, w, h),
      preset: (n: PresetName) => this.lighting.apply(n),
      frames: async (n = 3) => { for (let i = 0; i < n; i++) { this.frame(); await new Promise((r) => requestAnimationFrame(r)); } },
      stats: () => ({ calls: this.renderer.info.render.calls, tris: this.renderer.info.render.triangles, tile: tileNameAt(this.player.pos.x, this.player.pos.z), ...this.collision.stats(), doors: this.doors.count, world: this.world?.stats?.() ?? [] }),
      goto: (id: string, label?: string, facing = 0) => this.world?.goto?.(id, label, facing) ?? false,
      openDoorsNear: (r = 6) => { for (const d of this.doors.all()) if (d.hinge.distanceTo(this.player.pos) < r) this.doors.setOpen(d, true); },
      pos: () => new Vector3().copy(this.player.pos),
    };
  }
}
