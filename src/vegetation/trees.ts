// Trees (CLAUDE.md §12): willow oak (22–30 m, 1–1.4 m trunks, modeled trunk + primary branches, instanced
// leaf-card foliage), white oak, red & sugar maple street trees (8–12 m in grated pits), dogwood understory,
// magnolia (glossy), loblolly pine (20–30 m), ginkgo accents, holly (berries). Late-October colors.
import { CanvasTexture, Color, DoubleSide, InstancedMesh, Matrix4, MeshStandardMaterial, Object3D, Quaternion, SRGBColorSpace, Vector3, type Material } from 'three';
import { GeoBuilder } from '../core/geo';
import { mat, registerMaterialFactory } from '../core/materials';
import { css, jitter, pc, type PaletteKey } from '../core/palette';
import { Rng, hash01 } from '../core/rng';

export type Species = 'willow_oak' | 'white_oak' | 'red_maple' | 'sugar_maple' | 'dogwood' | 'magnolia' | 'loblolly' | 'ginkgo' | 'holly' | 'ivy';
interface SpeciesDef { h: [number, number]; trunk: [number, number]; leaf: PaletteKey; leaf2?: PaletteKey; mix?: number; bark: 'tex:bark_oak' | 'tex:bark_pine'; crown: 'round' | 'cone' | 'pine' | 'vase'; cards: number; card: number; rough: number; berries?: PaletteKey; }
export const SPECIES: Record<Species, SpeciesDef> = {
  willow_oak: { h: [22, 30], trunk: [1.0, 1.4], leaf: 'WILLOW_OAK_LEAF', leaf2: 'WILLOW_OAK_LEAF_TURN', mix: 0.3, bark: 'tex:bark_oak', crown: 'round', cards: 110, card: 3.2, rough: 0.8 },
  white_oak: { h: [14, 20], trunk: [0.6, 0.9], leaf: 'WHITE_OAK_LEAF', leaf2: 'FALLEN_LEAF_C', mix: 0.2, bark: 'tex:bark_oak', crown: 'round', cards: 70, card: 2.6, rough: 0.8 },
  red_maple: { h: [8, 12], trunk: [0.3, 0.45], leaf: 'RED_MAPLE_LEAF', leaf2: 'SUGAR_MAPLE_LEAF', mix: 0.15, bark: 'tex:bark_oak', crown: 'vase', cards: 40, card: 1.9, rough: 0.8 },
  sugar_maple: { h: [9, 12], trunk: [0.32, 0.45], leaf: 'SUGAR_MAPLE_LEAF', leaf2: 'RED_MAPLE_LEAF', mix: 0.2, bark: 'tex:bark_oak', crown: 'round', cards: 42, card: 2.0, rough: 0.8 },
  dogwood: { h: [5, 7], trunk: [0.15, 0.22], leaf: 'DOGWOOD_LEAF', bark: 'tex:bark_oak', crown: 'vase', cards: 22, card: 1.4, rough: 0.8 },
  magnolia: { h: [10, 15], trunk: [0.35, 0.5], leaf: 'MAGNOLIA_LEAF', bark: 'tex:bark_oak', crown: 'cone', cards: 60, card: 1.8, rough: 0.3 },
  loblolly: { h: [20, 30], trunk: [0.45, 0.65], leaf: 'LOBLOLLY_NEEDLE', bark: 'tex:bark_pine', crown: 'pine', cards: 46, card: 2.6, rough: 0.85 },
  ginkgo: { h: [11, 14], trunk: [0.35, 0.5], leaf: 'GINKGO_LEAF', bark: 'tex:bark_oak', crown: 'cone', cards: 45, card: 1.8, rough: 0.8 },
  ivy: { h: [1, 1], trunk: [0.01, 0.01], leaf: 'IVY', bark: 'tex:bark_oak', crown: 'round', cards: 1, card: 1, rough: 0.6 },
  holly: { h: [3, 5], trunk: [0.1, 0.15], leaf: 'HOLLY_LEAF', bark: 'tex:bark_oak', crown: 'cone', cards: 26, card: 1.1, rough: 0.5, berries: 'HOLLY_BERRY' },
};

// ------------------------------------------------------------------------------------------ leaf textures
const leafMats = new Map<string, Material>();
export function leafMaterial(sp: Species): Material {
  const key = `leafcard:${sp}`;
  let m = leafMats.get(key);
  if (m) return m;
  const d = SPECIES[sp];
  const c = document.createElement('canvas'); c.width = c.height = 256;
  const x = c.getContext('2d')!;
  const rng = new Rng(key);
  const col = new Color();
  const n = sp === 'loblolly' ? 260 : 150;
  for (let i = 0; i < n; i++) {
    const turn = d.leaf2 && rng.chance(d.mix ?? 0);
    jitter(turn ? d.leaf2! : d.leaf, rng.next(), rng.next(), 0.12, 6, col);
    x.fillStyle = '#' + col.clone().convertLinearToSRGB().getHexString();
    // keep leaves inside a soft round mask
    const a = rng.next() * Math.PI * 2, r = Math.sqrt(rng.next()) * 112;
    const px = 128 + Math.cos(a) * r, py = 128 + Math.sin(a) * r;
    x.save(); x.translate(px, py); x.rotate(rng.next() * Math.PI * 2);
    if (sp === 'loblolly') { x.fillRect(-1, -22, 2, 44); x.fillRect(-1, -22, 2, 44); }
    else if (sp === 'willow_oak') { x.beginPath(); x.ellipse(0, 0, 2.2, 10, 0, 0, Math.PI * 2); x.fill(); }
    else if (sp === 'ginkgo') { x.beginPath(); x.moveTo(0, 0); x.arc(0, 0, 9, -Math.PI * 0.9, -Math.PI * 0.1); x.closePath(); x.fill(); }
    else if (sp === 'magnolia' || sp === 'holly') { x.beginPath(); x.ellipse(0, 0, 5, 12, 0, 0, Math.PI * 2); x.fill(); }
    else { x.beginPath(); for (let k = 0; k < 5; k++) { const aa = (k / 5) * Math.PI * 2; x.lineTo(Math.cos(aa) * 9, Math.sin(aa) * 9); x.lineTo(Math.cos(aa + 0.6) * 4, Math.sin(aa + 0.6) * 4); } x.fill(); }
    x.restore();
  }
  if (d.berries) for (let i = 0; i < 30; i++) { x.fillStyle = css(d.berries); x.beginPath(); x.arc(40 + rng.next() * 176, 40 + rng.next() * 176, 3, 0, Math.PI * 2); x.fill(); }
  const t = new CanvasTexture(c); t.colorSpace = SRGBColorSpace; t.anisotropy = 4;
  m = new MeshStandardMaterial({ map: t, alphaTest: 0.45, side: DoubleSide, roughness: d.rough, color: pc('ONSU_WHITE') });
  m.userData.matKey = `leaf:${d.leaf}`;
  leafMats.set(key, m);
  return m;
}

registerMaterialFactory((key) => (key.startsWith('leafcard:') && typeof document !== 'undefined' ? leafMaterial(key.slice(9) as Species) : null));

// ------------------------------------------------------------------------------------------ geometry
function taperBar(g: GeoBuilder, key: string, a: Vector3, b: Vector3, r0: number, r1: number, seg = 7) {
  const dir = new Vector3().subVectors(b, a);
  const L = dir.length(); dir.normalize();
  const up = Math.abs(dir.y) > 0.9 ? new Vector3(1, 0, 0) : new Vector3(0, 1, 0);
  const p = new Vector3().crossVectors(dir, up).normalize(), q = new Vector3().crossVectors(dir, p).normalize();
  const ring = (o: Vector3, r: number, k: number): [number, number, number] => {
    const t = (k / seg) * Math.PI * 2; const v = o.clone().addScaledVector(p, Math.cos(t) * r).addScaledVector(q, Math.sin(t) * r); return [v.x, v.y, v.z];
  };
  for (let k = 0; k < seg; k++) g.quad(key, ring(a, r0, k), ring(a, r0, k + 1), ring(b, r1, k + 1), ring(b, r1, k));
  void L;
}

/** Trunk/branch + foliage-card geometry for one species variant (origin at the root collar). */
export function treeGeometry(sp: Species, variant: number): { wood: GeoBuilder; leaves: GeoBuilder; h: number } {
  const d = SPECIES[sp];
  const rng = new Rng(`tree:${sp}:${variant}`);
  const h = d.h[0] + (d.h[1] - d.h[0]) * (0.3 + 0.7 * rng.next());
  const tr = (d.trunk[0] + (d.trunk[1] - d.trunk[0]) * rng.next()) / 2;
  const wood = new GeoBuilder(), leaves = new GeoBuilder();
  const tips: { p: Vector3; s: number }[] = [];
  if (d.crown === 'pine') {
    taperBar(wood, d.bark, new Vector3(0, -0.3, 0), new Vector3(0, h * 0.97, 0), tr, tr * 0.15, 9);
    for (let i = 0; i < 14; i++) {
      const y = h * (0.62 + 0.33 * (i / 14)), a = rng.next() * Math.PI * 2, L = (1 - i / 14) * h * 0.18 + 1.2;
      const e = new Vector3(Math.cos(a) * L, y + 0.6, Math.sin(a) * L);
      taperBar(wood, d.bark, new Vector3(0, y, 0), e, tr * 0.18, 0.03, 5);
      tips.push({ p: e, s: 1.3 });
    }
  } else {
    const fork = d.crown === 'cone' ? h * 0.15 : h * (sp === 'willow_oak' ? 0.3 : 0.36);
    taperBar(wood, d.bark, new Vector3(0, -0.3, 0), new Vector3(0, fork, 0), tr * 1.15, tr * 0.8, 10);
    // buttress flare at the base
    taperBar(wood, d.bark, new Vector3(0, -0.3, 0), new Vector3(0, 0.6, 0), tr * 1.55, tr * 1.1, 10);
    const nPrim = d.crown === 'cone' ? 3 : 4 + (rng.next() * 2 | 0);
    const crownR = d.crown === 'cone' ? h * 0.22 : h * (sp === 'willow_oak' ? 0.42 : 0.33);
    for (let i = 0; i < nPrim; i++) {
      const a = (i / nPrim) * Math.PI * 2 + rng.next() * 0.6;
      const lean = d.crown === 'vase' ? 0.45 : 0.75;
      const e = new Vector3(Math.cos(a) * crownR * lean, fork + (h - fork) * (0.45 + rng.next() * 0.25), Math.sin(a) * crownR * lean);
      taperBar(wood, d.bark, new Vector3(0, fork - 0.2, 0), e, tr * 0.55, tr * 0.18, 7);
      // secondary limbs
      for (let k = 0; k < 3; k++) {
        const b = new Vector3(0, fork, 0).lerp(e, 0.45 + k * 0.2);
        const a2 = a + (rng.next() - 0.5) * 1.6;
        const e2 = b.clone().add(new Vector3(Math.cos(a2) * crownR * 0.45, (h - fork) * 0.25 * rng.next(), Math.sin(a2) * crownR * 0.45));
        taperBar(wood, d.bark, b, e2, tr * 0.16, 0.04, 5);
        tips.push({ p: e2, s: 1 });
      }
      tips.push({ p: e, s: 1.2 });
      if (d.crown === 'cone') {
        taperBar(wood, d.bark, new Vector3(0, fork, 0), new Vector3(0, h * 0.95, 0), tr * 0.7, 0.05, 7);
      }
    }
  }
  // foliage cards: crossed quads distributed over the crown shell + around branch tips
  const cardKey = `leafcard:${sp}`;
  for (let i = 0; i < d.cards; i++) {
    let c: Vector3;
    if (i < tips.length * 2) { const t = tips[i % tips.length]; c = t.p.clone().add(new Vector3((rng.next() - 0.5) * 2.5, (rng.next() - 0.3) * 2, (rng.next() - 0.5) * 2.5)); }
    else if (d.crown === 'pine') { const t = rng.pick(tips); c = t.p.clone().add(new Vector3((rng.next() - 0.5) * 2, rng.next() * 1.2, (rng.next() - 0.5) * 2)); }
    else {
      const crownR = d.crown === 'cone' ? h * 0.22 : h * (sp === 'willow_oak' ? 0.42 : 0.34);
      const yc = d.crown === 'cone' ? h * 0.55 : h * 0.68, ry = d.crown === 'cone' ? h * 0.42 : h * 0.3;
      const u = rng.next() * Math.PI * 2, v = Math.acos(2 * rng.next() - 1), r = 0.65 + 0.35 * rng.next();
      const shrink = d.crown === 'cone' ? 1 - (Math.cos(v) * 0.5 + 0.5) * 0.7 : 1;
      c = new Vector3(Math.cos(u) * Math.sin(v) * crownR * r * shrink, yc + Math.cos(v) * ry * r, Math.sin(u) * Math.sin(v) * crownR * r * shrink);
    }
    const s = d.card * (0.75 + rng.next() * 0.5);
    const rot = rng.next() * Math.PI;
    for (let k = 0; k < 2; k++) {
      const a = rot + (k * Math.PI) / 2, ca = Math.cos(a) * s / 2, sa = Math.sin(a) * s / 2;
      const tilt = (rng.next() - 0.5) * 0.6;
      leaves.quad(cardKey, [c.x - ca, c.y - s / 2 + tilt, c.z - sa], [c.x + ca, c.y - s / 2 - tilt, c.z + sa], [c.x + ca, c.y + s / 2 - tilt, c.z + sa], [c.x - ca, c.y + s / 2 + tilt, c.z - sa], [[0, 0], [1, 0], [1, 1], [0, 1]]);
    }
    // a horizontal card for top cover
    leaves.quad(cardKey, [c.x - s / 2, c.y, c.z - s / 2], [c.x - s / 2, c.y, c.z + s / 2], [c.x + s / 2, c.y, c.z + s / 2], [c.x + s / 2, c.y, c.z - s / 2], [[0, 0], [0, 1], [1, 1], [1, 0]]);
  }
  return { wood, leaves, h };
}

// ------------------------------------------------------------------------------------------ instancing
export interface TreeInst { sp: Species; x: number; y: number; z: number; rot: number; scale: number; }
const VARIANTS = 3;
const geoCache = new Map<string, ReturnType<typeof treeGeometry>>();

/** Group of InstancedMeshes (per species/variant/material) for a list of trees. */
export function treeGroup(list: TreeInst[]): Object3D {
  const root = new Object3D(); root.name = 'trees';
  const by = new Map<string, TreeInst[]>();
  for (const t of list) { const v = Math.floor(hash01(Math.round(t.x * 10), Math.round(t.z * 10), 3) * VARIANTS); const k = `${t.sp}:${v}`; let a = by.get(k); if (!a) by.set(k, (a = [])); a.push(t); }
  const m4 = new Matrix4(), q = new Quaternion(), s = new Vector3(), p = new Vector3(), up = new Vector3(0, 1, 0);
  for (const [k, arr] of by) {
    const [sp, v] = k.split(':');
    let geo = geoCache.get(k);
    if (!geo) { geo = treeGeometry(sp as Species, Number(v)); geoCache.set(k, geo); }
    for (const [b, isLeaf] of [[geo.wood, false], [geo.leaves, true]] as const) for (const key of b.buckets.keys()) {
      const g = b.geometryFor(key)!;
      const im = new InstancedMesh(g, isLeaf ? leafMaterial(sp as Species) : mat(key), arr.length);
      im.name = `${k}:${isLeaf ? 'leaves' : 'wood'}`; im.userData.matKey = isLeaf ? `leaf:${SPECIES[sp as Species].leaf}` : key;
      im.castShadow = true; im.receiveShadow = !isLeaf;
      arr.forEach((t, i) => { q.setFromAxisAngle(up, t.rot); s.setScalar(t.scale); p.set(t.x, t.y, t.z); m4.compose(p, q, s); im.setMatrixAt(i, m4); });
      im.computeBoundingSphere();
      root.add(im);
    }
  }
  return root;
}

/** Low-poly far tree: two crossed silhouettes colored by species (for impostor tiles). */
export function farTreeColor(sp: Species): Color { return pc(SPECIES[sp].leaf); }
