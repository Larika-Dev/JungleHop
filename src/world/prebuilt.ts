// Prebuilt full-detail tiles for the model viewer (?view=orbit). `npm run export:gltf -- tiles` +
// scripts/pack-tiles.mjs produce one meshopt-compressed GLB per core tile (every facade, curb,
// marking, tree, lamp and shrub at cm precision), wrapped as JSON for text-only static hosts.
// This streams them around the orbit target so the whole city can be seen at full detail at once,
// not just the 3x3 ring the live generator builds. Materials are re-bound to the game's own
// procedural materials by key (material name), so prebuilt and live tiles look identical.
import { Group, Material, Mesh, MeshStandardMaterial, Object3D } from 'three';
import { GLTFLoader } from 'three/examples/jsm/loaders/GLTFLoader.js';
import { MeshoptDecoder } from 'three/examples/jsm/libs/meshopt_decoder.module.js';
import type { App } from '../app';
import { mat } from '../core/materials';
import { tileBounds, parseTile } from '../core/tiles';

/** The game's materials multiply by vertex color; packed tiles drop all-white color attributes, so
 *  those meshes get a copy of the material with vertex colors off (same textures, palette and wetness). */
const flatCache = new Map<string, Material>();
function flatMat(key: string, app: App): Material {
  let m = flatCache.get(key);
  if (!m) {
    const base = mat(key);
    m = base.clone();
    (m as MeshStandardMaterial).vertexColors = false;
    m.userData = { ...base.userData, csm: false }; // let the lighting system set up cascaded shadows on the copy
    app.lighting.adopt(m);
    flatCache.set(key, m);
  }
  return m;
}

interface Entry { name: string; cx: number; cz: number; bytes: number; group: Group | null; loading: boolean; failed: boolean }

export class PrebuiltTiles {
  entries = new Map<string, Entry>();
  private loader = new GLTFLoader().setMeshoptDecoder(MeshoptDecoder);
  private t = 0;
  private inflight = 0;
  root = new Object3D();
  available = false;
  /** Called whenever a tile's prebuilt content appears or disappears. */
  onChange: (() => void)[] = [];

  constructor(private app: App, private isLive: (tile: string) => boolean) {
    this.root.name = 'prebuilt-tiles';
    app.scene.add(this.root);
  }

  async init(base = './tiles/') {
    try {
      const r = await fetch(`${base}index.json`);
      if (!r.ok) return;
      const list = (await r.json()) as { tile: string; bytes: number }[];
      for (const { tile, bytes } of list) {
        const b = tileBounds(parseTile(tile));
        this.entries.set(tile, { name: tile, cx: (b.x0 + b.x1) / 2, cz: (b.z0 + b.z1) / 2, bytes, group: null, loading: false, failed: false });
      }
      this.base = base;
      this.available = this.entries.size > 0;
    } catch { /* no prebuilt tiles published: the live generator alone */ }
  }
  private base = './tiles/';

  /** Is this tile currently shown from prebuilt data? */
  shown(tile: string) { const e = this.entries.get(tile); return !!e?.group?.visible; }
  get loadedCount() { let n = 0; for (const e of this.entries.values()) if (e.group) n++; return n; }

  update(dt: number) {
    if (!this.available || !this.app.orbit) return;
    this.t += dt;
    if (this.t < 0.4) return;
    this.t = 0;
    const tgt = this.app.orbit.target, dist = this.app.camera.position.distanceTo(tgt);
    const R = Math.min(1500, Math.max(420, dist * 1.5));
    let changed = false;
    const want: Entry[] = [];
    for (const e of this.entries.values()) {
      const d = Math.hypot(e.cx - tgt.x, e.cz - tgt.z);
      if (e.group) {
        const vis = !this.isLive(e.name);
        if (e.group.visible !== vis) { e.group.visible = vis; changed = true; }
        if (d > R + 350) { this.unload(e); changed = true; }
      } else if (d < R && !e.loading && !e.failed) want.push(e);
    }
    want.sort((a, b) => Math.hypot(a.cx - tgt.x, a.cz - tgt.z) - Math.hypot(b.cx - tgt.x, b.cz - tgt.z));
    for (const e of want) { if (this.inflight >= 2) break; void this.load(e); }
    if (changed) for (const f of this.onChange) f();
  }

  private async load(e: Entry) {
    e.loading = true; this.inflight++;
    try {
      const res = await fetch(`${this.base}${e.name}.json`);
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const { glb } = (await res.json()) as { glb: string };
      const bin = Uint8Array.from(atob(glb), (c) => c.charCodeAt(0));
      const gltf = await this.loader.parseAsync(bin.buffer, '');
      const g = gltf.scene;
      g.name = `prebuilt:${e.name}`;
      g.traverse((o) => {
        const m = o as Mesh;
        if (!m.isMesh) return;
        const name = (m.material as Material).name;
        if (name && name !== 'terrain') m.material = m.geometry.getAttribute('color') ? mat(name) : flatMat(name, this.app);
        else {
          // flat vertex-colored ground reads darker than the live textured splat; lift it to match
          (m.material as MeshStandardMaterial).color.setScalar(1.55);
          this.app.lighting.adopt(m.material as MeshStandardMaterial);
        }
        m.userData.matKey = name;
        m.castShadow = name !== 'terrain' && !name.startsWith('tex:leaflitter');
        m.receiveShadow = true;
      });
      g.visible = !this.isLive(e.name);
      // the orbit target may have moved away while this downloaded
      if (!this.app.orbit) return;
      e.group = g;
      this.root.add(g);
      for (const f of this.onChange) f();
    } catch (err) {
      e.failed = true;
      console.warn(`prebuilt tile ${e.name} failed`, err);
    } finally { e.loading = false; this.inflight--; }
  }

  private unload(e: Entry) {
    if (!e.group) return;
    this.root.remove(e.group);
    e.group.traverse((o) => { const m = o as Mesh; if (m.isMesh) m.geometry.dispose(); });
    e.group = null;
  }
}
