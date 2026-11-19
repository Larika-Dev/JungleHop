// glTF export (CLAUDE.md §18 phase 12): one GLB per landmark (full exterior + full hollow interior with
// room metadata as node extras) and one GLB per core tile (terrain, roads, sidewalks, markings and every
// building exterior at full detail). Materials are flat palette colors. Exterior door leaves and
// near-detail bricks/pavers are runtime instancing and are not part of these files.
// Usage: npx vite-node scripts/export-gltf.ts [landmarks|tiles|all] [tileFilter]
import { mkdirSync, writeFileSync } from 'node:fs';
import { BufferAttribute, BufferGeometry, Color, Group, Matrix4, Mesh, MeshStandardMaterial, Object3D, Scene } from 'three';
import { GLTFExporter } from 'three/examples/jsm/exporters/GLTFExporter.js';
import { pc, type PaletteKey } from '../src/core/palette';
import { isPaletteKey, mat, paletteKeyOf, prependMaterialFactory } from '../src/core/materials';
import { GeoBuilder } from '../src/core/geo';
import { allTiles, tileBounds, tileInCore, tileName } from '../src/core/tiles';
import { Terrain } from '../src/terrain/terrain';
import { buildMidblockForTile, buildRoadsForTile } from '../src/roads/build';
import { cityPlan } from '../src/world/cityPlan';
import { planFor, LANDMARK_HOOKS } from '../src/buildings/manager';
import { buildExterior, buildingMatrix, type ExteriorOut } from '../src/buildings/exterior';
import { buildInterior } from '../src/interiors/build';
import { splatAt } from '../src/terrain/terrainMesh';
import { treesForTile } from '../src/vegetation/placement';
import { SPECIES, treeGeometry, type TreeInst } from '../src/vegetation/trees';
import { litterForTrees, shrubsForBuilding } from '../src/vegetation/shrubs';
import { ivyForBuilding } from '../src/vegetation/ivy';
import { furnitureByTile, furnitureGroup } from '../src/street/furniture';
import { buildTrailsForTile } from '../src/vegetation/parkPlugin';
import { Rng, hash01 } from '../src/core/rng';
import { InstancedMesh, Quaternion, Vector3 } from 'three';

(globalThis as any).FileReader ??= class {
  result: ArrayBuffer | string | null = null; onloadend: (() => void) | null = null; onload: (() => void) | null = null;
  readAsArrayBuffer(b: Blob) { b.arrayBuffer().then((a) => { this.result = a; this.onload?.(); this.onloadend?.(); }); }
  readAsDataURL(b: Blob) { b.arrayBuffer().then((a) => { this.result = `data:${b.type};base64,` + Buffer.from(a).toString('base64'); this.onload?.(); this.onloadend?.(); }); }
};

// ------------------------------------------------------------------------------------------ plain materials
const KEYWORDS: [RegExp, PaletteKey][] = [
  [/boardform/, 'CONCRETE_BOARDFORM'], [/concrete_new|deck/, 'CONCRETE_NEW'], [/concrete/, 'CONCRETE_AGED'], [/fieldstone|rubble/, 'FIELDSTONE_A'],
  [/slate/, 'SLATE_A'], [/marble/, 'MARBLE_WHITE'], [/granite/, 'GRANITE_CURB'], [/turf/, 'FIELD_TURF'], [/asphalt_fresh/, 'ASPHALT_FRESH'],
  [/asphalt/, 'ASPHALT_AGED'], [/patina|copper/, 'COPPER_PATINA'], [/limestone/, 'LIMESTONE_TRIM'], [/capstone/, 'CAPSTONE'],
  [/pavers/, 'BRICK_PAVER_A'], [/shingle/, 'ASPHALT_SHINGLE'], [/seam/, 'STANDING_SEAM'], [/tpo/, 'TPO_ROOF'], [/stucco/, 'STUCCO'],
  [/terrazzo/, 'TERRAZZO'], [/vct/, 'VCT_A'], [/subway/, 'TILE_WHITE_SUBWAY'], [/hextile/, 'HEX_TILE_WHITE'], [/porcelain/, 'PORCELAIN_MODERN'],
  [/oak_floor/, 'OAK_FLOOR'], [/heart_pine/, 'HEART_PINE'], [/carpet_inn/, 'CARPET_INN'], [/carpet/, 'CARPET_OFFICE'], [/acoustic/, 'ACOUSTIC_TILE'],
  [/maple/, 'SPORTS_MAPLE'], [/rubber/, 'RUBBER_FLOOR'], [/sealed/, 'SEALED_CONCRETE'], [/vinyl/, 'SHEET_VINYL'], [/tin/, 'CEILING_WHITE'],
  [/grass/, 'GRASS_OCT'], [/clay/, 'RED_CLAY'], [/dirt/, 'DIRT_PATH'], [/gravel/, 'GRAVEL'], [/pinestraw/, 'PINE_STRAW'], [/bark/, 'OAK_BARK'],
  [/cmu|block/, 'PAINT_DORM_BLOCK'], [/plaster/, 'PLASTER_CAMPUS'], [/walnut/, 'WALNUT_DARK'],
];
export function keyColor(key: string): Color {
  if (key.startsWith('glass')) return pc('GLASS_TINT');
  if (key === 'water' || key === 'puddle') return pc('PUDDLE_TINT');
  const k = paletteKeyOf(key);
  if (isPaletteKey(k)) return pc(k as PaletteKey);
  for (const [re, p] of KEYWORDS) if (re.test(key)) return pc(p);
  return pc('TRIM_WHITE');
}
prependMaterialFactory((key) => {
  const glass = key.startsWith('glass');
  const m = new MeshStandardMaterial({
    name: key, color: keyColor(key), roughness: glass ? 0.05 : key.startsWith('gloss') ? 0.3 : key.startsWith('satin') ? 0.5 : 0.85,
    metalness: key.startsWith('metal:') ? 1 : 0, transparent: glass, opacity: glass ? 0.35 : 1,
  });
  if (/^(emit|neon|glow):/.test(key)) { m.emissive.copy(m.color); m.emissiveIntensity = 1; }
  return m;
});

async function writeGlb(file: string, root: Object3D) {
  const scene = new Scene();
  scene.add(root);
  const glb = await new GLTFExporter().parseAsync(scene, { binary: true }) as ArrayBuffer;
  writeFileSync(file, Buffer.from(glb));
  return glb.byteLength;
}
const city = cityPlan();
const isLandmark = (s: (typeof city.buildings)[number]) => s.spec.id.startsWith('LM');
function exterior(s: (typeof city.buildings)[number]): ExteriorOut {
  const spec = s.spec, plan = planFor(spec);
  const hooks = spec.custom ? LANDMARK_HOOKS.get(spec.custom) : undefined;
  const ext: ExteriorOut = hooks?.customShell ? { g: new GeoBuilder(), doors: [], walls: [], floors: [], glass: [] } : buildExterior(spec, plan, { frontGrade: s.grades.front, lowGrade: s.grades.low, bIndex: 0 });
  hooks?.exterior?.(spec, plan, ext);
  return ext;
}
const noFar = (g: GeoBuilder) => { for (const k of [...g.buckets.keys()]) if (k.startsWith('glassFar')) g.buckets.delete(k); return g; };

const mode = process.argv[2] ?? 'all';
const filter = process.argv[3];

// ------------------------------------------------------------------------------------------ landmarks
if (mode === 'all' || mode === 'landmarks') {
  mkdirSync('export/landmarks', { recursive: true });
  for (const s of city.buildings.filter(isLandmark)) {
    if (filter && !s.spec.id.includes(filter)) continue;
    const spec = s.spec, plan = planFor(spec);
    const ext = exterior(s);
    const root = new Group();
    root.name = spec.id;
    root.userData = { buildingId: spec.id, name: spec.name ?? spec.custom, world: { x: spec.x, y: spec.y, z: spec.z, rotY: spec.rotY }, note: 'building-local meters; world = R_y(rotY) * local + (x, y, z)' };
    const ex = noFar(ext.g).toGroup(mat, 'exterior');
    const hooks = LANDMARK_HOOKS.get(spec.custom!);
    const int = buildInterior(plan, ext, !!hooks?.customShell);
    int.group.name = 'interior';
    root.add(ex, int.group);
    const bytes = await writeGlb(`export/landmarks/${spec.id}.glb`, root);
    console.log(`landmark ${spec.id}: ${(bytes / 1e6).toFixed(1)} MB, ${int.rooms.length} rooms`);
  }
}

// ------------------------------------------------------------------------------------------ tiles
if (mode === 'all' || mode === 'tiles') {
  mkdirSync('export/tiles', { recursive: true });
  const T = Terrain.get();
  for (const t of allTiles()) {
    const name = tileName(t);
    if (!tileInCore(t) || (filter && name !== filter)) continue;
    const g = new GeoBuilder();
    buildRoadsForTile(name, g);
    buildMidblockForTile(name, g);
    let n = 0;
    for (const s of city.byTile.get(name) ?? []) {
      try { g.merge(noFar(exterior(s).g), buildingMatrix(s.spec)); n++; } catch (e) { console.warn('skip', s.spec.id, (e as Error).message); }
    }
    // vegetation built exactly like the game's tile plug-in (same RNG stream): leaf litter, shrubs, ivy
    const trees = treesForTile(t);
    const vrng = new Rng(`veg:${name}`);
    const gFlat = new GeoBuilder();
    litterForTrees(gFlat, trees.filter((x) => x.sp !== 'loblolly'), vrng);
    buildTrailsForTile(t, gFlat); // forest-park trails (gravel with timber edging, dirt)
    for (const s of city.byTile.get(name) ?? []) { shrubsForBuilding(g, s, vrng); ivyForBuilding(g, s); }
    // terrain at 1 m with the game's ground splat blended into vertex colors
    const b = tileBounds(t), step = 1, nx = (b.x1 - b.x0) / step;
    const pos: number[] = [], col: number[] = [], idx: number[] = [];
    const GC = [pc('GRASS_OCT'), pc('GRASS_WORN'), pc('RED_CLAY'), pc('PINE_STRAW')];
    for (let j = 0; j <= nx; j++) for (let i = 0; i <= nx; i++) {
      const x = b.x0 + i * step, z = b.z0 + j * step;
      const w = splatAt(x, z, T);
      pos.push(x, T.height(x, z), z);
      col.push(GC.reduce((a, c, k) => a + c.r * w[k], 0), GC.reduce((a, c, k) => a + c.g * w[k], 0), GC.reduce((a, c, k) => a + c.b * w[k], 0));
    }
    for (let j = 0; j < nx; j++) for (let i = 0; i < nx; i++) { const a = j * (nx + 1) + i, c = a + nx + 1; idx.push(a, c, a + 1, a + 1, c, c + 1); }
    const tg = new BufferGeometry();
    tg.setAttribute('position', new BufferAttribute(new Float32Array(pos), 3));
    tg.setAttribute('color', new BufferAttribute(new Float32Array(col), 3));
    tg.setIndex(idx); tg.computeVertexNormals();
    const root = new Group();
    root.name = name;
    root.userData = { tile: name, bounds: b, buildings: n, note: 'world meters; +X east, -Z north, origin = The Summit' };
    root.add(new Mesh(tg, new MeshStandardMaterial({ name: 'terrain', vertexColors: true, roughness: 0.95 })));
    root.add(g.toGroup(mat, 'built'));
    root.add(gFlat.toGroup(mat, 'ground-detail'));
    // trees: real trunks/limbs + leaf cards, instanced per species/variant (same variant hash as the game)
    const by = new Map<string, TreeInst[]>();
    for (const tr of trees) { const v = Math.floor(hash01(Math.round(tr.x * 10), Math.round(tr.z * 10), 3) * 3); const k = `${tr.sp}:${v}`; if (!by.has(k)) by.set(k, []); by.get(k)!.push(tr); }
    const m4 = new Matrix4(), q = new Quaternion(), sc = new Vector3(), p = new Vector3(), up = new Vector3(0, 1, 0);
    const tg2 = new Group(); tg2.name = 'trees';
    for (const [k, arr] of by) {
      const [sp, v] = k.split(':');
      const geo = treeGeometry(sp as keyof typeof SPECIES, Number(v));
      for (const bld of [geo.wood, geo.leaves]) for (const key of bld.buckets.keys()) {
        const im = new InstancedMesh(bld.geometryFor(key)!, mat(key), arr.length);
        im.name = `${k}:${key}`;
        arr.forEach((tr, i) => { q.setFromAxisAngle(up, tr.rot); sc.setScalar(tr.scale); p.set(tr.x, tr.y, tr.z); m4.compose(p, q, sc); im.setMatrixAt(i, m4); });
        tg2.add(im);
      }
    }
    root.add(tg2);
    // street furniture (lamps, signals, benches, hydrants, meters, shelters, manholes, blades), instanced
    const fl = furnitureByTile().get(name) ?? [];
    if (fl.length) root.add(furnitureGroup(fl));
    const bytes = await writeGlb(`export/tiles/${name}.glb`, root);
    console.log(`tile ${name}: ${n} buildings, ${(bytes / 1e6).toFixed(1)} MB`);
  }
}
