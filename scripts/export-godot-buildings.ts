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


// Godot: building exteriors only, merged per 200 m tile (terrain/roads/trees come from city.glb).
// Usage: npx vite-node scripts/export-godot-buildings.ts [outDir] [tileFilter]
const outDir = process.argv[2] ?? 'godot/assets/buildings';
const filter = process.argv[3];
mkdirSync(outDir, { recursive: true });
let total = 0;
for (const t of allTiles()) {
  const name = tileName(t);
  if (!tileInCore(t) || (filter && name !== filter)) continue;
  const list = city.byTile.get(name) ?? [];
  if (!list.length) continue;
  const g = new GeoBuilder();
  let n = 0;
  for (const s of list) {
    try { g.merge(noFar(exterior(s).g), buildingMatrix(s.spec)); n++; } catch (e) { console.warn('skip', s.spec.id, (e as Error).message); }
  }
  const root = new Group();
  root.name = name;
  root.add(g.toGroup(mat, 'buildings'));
  const bytes = await writeGlb(`${outDir}/${name}.glb`, root);
  total += bytes;
  console.log(`${name}: ${n} buildings, ${(bytes / 1e6).toFixed(1)} MB`);
}
console.log(`total ${(total / 1e6).toFixed(0)} MB`);
