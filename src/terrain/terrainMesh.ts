// Terrain meshes: per-tile 1 m grid, a 0.5 m near patch that follows the player (CLAUDE.md §8:
// 0.5 m resolution in the core), and a 10 m far mesh for the whole 3.6 x 3.4 km map.
// Ground material = 4-layer splat (grass / worn+dirt / red clay / forest floor) blended per vertex.
import { BufferAttribute, BufferGeometry, Mesh, MeshStandardMaterial, Vector2, Vector4 } from 'three';
import { inPark, pathDist } from '../vegetation/parks';
import { hash01 } from '../core/rng';
import { getTexSet } from '../core/textures';
import { TOTAL, tileBounds, type TileId } from '../core/tiles';
import { smoothstep } from '../core/units';
import { districtAt, BOWL, WORN_PATHS, type P2 } from '../world/layout';
import { outerness } from './heightfield';
import { segDist } from './ravine';
import { Terrain } from './terrain';

/** Splat weights [grass, worn/dirt, clay, forest floor] at a point. */
export function splatAt(x: number, z: number, T: Terrain): [number, number, number, number] {
  const slope = T.slope(x, z);
  let clay = smoothstep(0.38, 0.75, slope);
  const creek = T.creek(x, z);
  if (creek < 4) clay = Math.max(clay, 0.8);
  const d = districtAt(x, z);
  let forest = outerness(x, z) * 0.9;
  if (d && (d.id === 'toadstool' || d.id === 'battle_ravine')) forest = Math.max(forest, 0.85);
  // pine-forest bowl around the stadium
  const bq = Math.hypot((x - BOWL.cx) / (BOWL.rx + 70), (z - BOWL.cz) / (BOWL.rz + 70));
  if (bq < 1.25 && bq > 0.95) forest = Math.max(forest, 0.7);
  const n = hash01(Math.floor(x / 3), Math.floor(z / 3), 7);
  forest *= 0.75 + n * 0.25;
  let worn = 0;
  for (const p of WORN_PATHS) {
    for (let i = 0; i < p.pts.length - 1; i++) {
      const r = segDist(x, z, p.pts[i] as P2, p.pts[i + 1] as P2);
      if (r.d < p.w) worn = Math.max(worn, 1 - smoothstep(p.w * 0.35, p.w, r.d));
    }
  }
  // old-growth forest parks: leaf-litter floor, trails worn to dirt
  if (inPark(x, z)) {
    forest = Math.max(forest, 0.9);
    const pd = pathDist(x, z);
    if (pd < 0.8) worn = Math.max(worn, 1 - smoothstep(-0.3, 0.8, pd));
  }
  // verges next to pavement are scuffed
  const hit = T.net.query(x, z);
  if (hit && hit.zone === 'verge' && hit.blend > 0.7) worn = Math.max(worn, 0.35);
  let grass = 1;
  const total = grass + worn * 2 + clay * 3 + forest * 2;
  return [grass / total, (worn * 2) / total, (clay * 3) / total, (forest * 2) / total];
}

/** Shared clip rectangles (x0, z0, x1, z1): finer meshes punch holes in coarser ones. */
export const groundUniforms = { nearRect: { value: new Vector4(1e9, 1e9, -1e9, -1e9) }, activeRect: { value: new Vector4(1e9, 1e9, -1e9, -1e9) } };
const groundMats: (MeshStandardMaterial | null)[] = [null, null, null];
/** Splat ground material. level 0 = near patch, 1 = tile (clipped by near patch), 2 = far (clipped by active tiles). */
export function groundMaterial(level: 0 | 1 | 2 = 1): MeshStandardMaterial {
  const cached = groundMats[level];
  if (cached) return cached;
  const sets = ['grass', 'dirt', 'clay', 'pinestraw'].map((n) => getTexSet(n));
  const m = new MeshStandardMaterial({ roughness: 1, metalness: 0, map: sets[0]?.map ?? null, normalMap: sets[0]?.normalMap ?? null });
  m.name = 'tex:grass';
  m.userData.matKey = 'tex:grass';
  m.userData.baseRoughness = 1;
  const reps = sets.map((s) => new Vector2(1 / (s?.sizeM[0] ?? 2), 1 / (s?.sizeM[1] ?? 2)));
  if (sets[0]?.normalMap) sets[0].normalMap.repeat.copy(reps[0]);
  const clip = level === 1 ? 'nearRect' : level === 2 ? 'activeRect' : '';
  m.onBeforeCompile = (sh) => {
    sh.uniforms.tex0 = { value: sets[0]?.map }; sh.uniforms.tex1 = { value: sets[1]?.map };
    sh.uniforms.tex2 = { value: sets[2]?.map }; sh.uniforms.tex3 = { value: sets[3]?.map };
    sh.uniforms.rep0 = { value: reps[0] }; sh.uniforms.rep1 = { value: reps[1] }; sh.uniforms.rep2 = { value: reps[2] }; sh.uniforms.rep3 = { value: reps[3] };
    sh.uniforms.clipRect = clip ? groundUniforms[clip as 'nearRect'] : { value: new Vector4(1e9, 1e9, -1e9, -1e9) };
    sh.vertexShader = sh.vertexShader
      .replace('#include <common>', '#include <common>\nattribute vec4 splat;\nvarying vec4 vSplat;\nvarying vec2 vW;')
      .replace('#include <uv_vertex>', '#include <uv_vertex>\nvSplat = splat;\nvW = uv;');
    sh.fragmentShader = sh.fragmentShader
      .replace('#include <common>', '#include <common>\nuniform sampler2D tex0, tex1, tex2, tex3;\nuniform vec2 rep0, rep1, rep2, rep3;\nuniform vec4 clipRect;\nvarying vec4 vSplat;\nvarying vec2 vW;')
      .replace('#include <clipping_planes_fragment>', `#include <clipping_planes_fragment>
        if (vW.x > clipRect.x && vW.x < clipRect.z && vW.y > clipRect.y && vW.y < clipRect.w) discard;`)
      .replace('#include <map_fragment>', `
        vec4 c0 = texture2D(tex0, vW * rep0);
        vec4 c0b = texture2D(tex0, vW * rep0 * 0.173 + 0.37);
        c0 = mix(c0, c0b, 0.35);
        vec4 c1 = texture2D(tex1, vW * rep1);
        vec4 c2 = texture2D(tex2, vW * rep2);
        vec4 c3 = texture2D(tex3, vW * rep3);
        vec4 w = vSplat / max(1e-4, vSplat.x + vSplat.y + vSplat.z + vSplat.w);
        diffuseColor *= c0 * w.x + c1 * w.y + c2 * w.z + c3 * w.w;`);
  };
  m.customProgramCacheKey = () => 'ground' + level;
  onMaterialCreatedHook(m);
  groundMats[level] = m;
  return m;
}
let onMaterialCreatedHook: (m: MeshStandardMaterial) => void = () => {};
/** Lighting system hook (CSM setup / wetness) for the custom ground materials. */
export function setGroundMaterialHook(f: (m: MeshStandardMaterial) => void) { onMaterialCreatedHook = f; for (const m of groundMats) if (m) f(m); }

function gridGeometry(x0: number, z0: number, w: number, h: number, step: number, T: Terrain, heightFn: (x: number, z: number) => number, drop = 0, splat = true): BufferGeometry {
  const nx = Math.round(w / step) + 1, nz = Math.round(h / step) + 1;
  const pos = new Float32Array(nx * nz * 3), uv = new Float32Array(nx * nz * 2), nor = new Float32Array(nx * nz * 3), sp = new Float32Array(nx * nz * 4);
  const hgt = new Float32Array((nx + 2) * (nz + 2));
  for (let j = -1; j <= nz; j++) for (let i = -1; i <= nx; i++) hgt[(j + 1) * (nx + 2) + (i + 1)] = heightFn(x0 + i * step, z0 + j * step) - drop;
  const H = (i: number, j: number) => hgt[(j + 1) * (nx + 2) + (i + 1)];
  for (let j = 0; j < nz; j++) for (let i = 0; i < nx; i++) {
    const k = j * nx + i, x = x0 + i * step, z = z0 + j * step;
    pos[k * 3] = x; pos[k * 3 + 1] = H(i, j); pos[k * 3 + 2] = z;
    uv[k * 2] = x; uv[k * 2 + 1] = z;
    const dx = (H(i + 1, j) - H(i - 1, j)) / (2 * step), dz = (H(i, j + 1) - H(i, j - 1)) / (2 * step);
    const l = Math.hypot(dx, 1, dz);
    nor[k * 3] = -dx / l; nor[k * 3 + 1] = 1 / l; nor[k * 3 + 2] = -dz / l;
    if (splat && (i % 2 === 0 || step >= 2) && (j % 2 === 0 || step >= 2)) {
      const s = splatAt(x, z, T);
      sp.set(s, k * 4);
    } else if (splat) {
      // interpolate splat for odd 0.5/1 m vertices from neighbours computed at 2-step spacing
      sp.set([1, 0, 0, 0], k * 4);
    } else sp.set([1, 0, 0, 0], k * 4);
  }
  if (splat && step < 2) {
    // fill odd rows/cols by averaging (halves splat cost)
    for (let j = 0; j < nz; j++) for (let i = 0; i < nx; i++) {
      if (i % 2 === 0 && j % 2 === 0) continue;
      const k = j * nx + i;
      const nb: number[] = [];
      for (const [di, dj] of [[-1, 0], [1, 0], [0, -1], [0, 1], [-1, -1], [1, 1], [-1, 1], [1, -1]]) {
        const ii = i + di, jj = j + dj;
        if (ii < 0 || jj < 0 || ii >= nx || jj >= nz || ii % 2 || jj % 2) continue;
        nb.push(jj * nx + ii);
      }
      if (!nb.length) continue;
      for (let c = 0; c < 4; c++) { let a = 0; for (const q of nb) a += sp[q * 4 + c]; sp[k * 4 + c] = a / nb.length; }
    }
  }
  const idx = new Uint32Array((nx - 1) * (nz - 1) * 6);
  let p = 0;
  for (let j = 0; j < nz - 1; j++) for (let i = 0; i < nx - 1; i++) {
    const a = j * nx + i, b = a + 1, c = a + nx, d = c + 1;
    idx[p++] = a; idx[p++] = c; idx[p++] = b; idx[p++] = b; idx[p++] = c; idx[p++] = d;
  }
  const g = new BufferGeometry();
  g.setAttribute('position', new BufferAttribute(pos, 3));
  g.setAttribute('normal', new BufferAttribute(nor, 3));
  g.setAttribute('uv', new BufferAttribute(uv, 2));
  g.setAttribute('splat', new BufferAttribute(sp, 4));
  g.setIndex(new BufferAttribute(idx, 1));
  g.computeBoundingSphere(); g.computeBoundingBox();
  return g;
}

/** Per-tile terrain at 1 m (pushed back slightly so the 0.5 m near patch wins depth ties). */
export function buildTerrainTile(t: TileId): Mesh {
  const T = Terrain.get();
  const b = tileBounds(t);
  const g = gridGeometry(b.x0, b.z0, b.x1 - b.x0, b.z1 - b.z0, 1, T, (x, z) => T.height(x, z), 0.01);
  const m = new Mesh(g, groundMaterial(1));
  m.name = 'terrain'; m.userData.matKey = 'tex:grass';
  m.receiveShadow = true; m.matrixAutoUpdate = false;
  return m;
}

/** Whole-map 10 m terrain (always present; detailed tiles overlay it). */
export function buildFarTerrain(): Mesh {
  const T = Terrain.get();
  const g = gridGeometry(TOTAL.x0, TOTAL.z0, TOTAL.x1 - TOTAL.x0, TOTAL.z1 - TOTAL.z0, 10, T, (x, z) => T.height(x, z), 0.35);
  const m = new Mesh(g, groundMaterial(2));
  m.name = 'terrain-far'; m.userData.matKey = 'tex:grass';
  m.receiveShadow = true; m.matrixAutoUpdate = false;
  return m;
}

/** 0.5 m patch (80 x 80 m) that re-centres on the player every 10 m. */
export class NearTerrain {
  mesh: Mesh;
  private cx = Infinity; private cz = Infinity;
  constructor(public size = 80) {
    this.mesh = new Mesh(new BufferGeometry(), groundMaterial(0));
    this.mesh.name = 'terrain-near'; this.mesh.userData.matKey = 'tex:grass';
    this.mesh.receiveShadow = true; this.mesh.matrixAutoUpdate = false;
  }
  update(x: number, z: number, force = false) {
    const sx = Math.round(x / 10) * 10, sz = Math.round(z / 10) * 10;
    if (!force && sx === this.cx && sz === this.cz) return;
    this.cx = sx; this.cz = sz;
    const T = Terrain.get();
    const h = this.size / 2;
    const g = gridGeometry(sx - h, sz - h, this.size, this.size, 0.5, T, (px, pz) => T.height(px, pz), 0);
    this.mesh.geometry.dispose();
    this.mesh.geometry = g;
    groundUniforms.nearRect.value.set(sx - h + 0.25, sz - h + 0.25, sx + h - 0.25, sz + h - 0.25);
  }
}

