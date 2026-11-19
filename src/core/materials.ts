// Material library. Every GeoBuilder material key resolves here; every color comes from palette.ts.
//
// Key grammar:
//   paint:KEY  matte (r .85)      satin:KEY (r .5)     gloss:KEY (r .3)     metal:KEY (metalness 1, r .35)
//   emit:KEY   emissive panel      neon:KEY  bright emissive tube          glow:KEY lamp globe
//   tex:<name>[:KEY]  procedural texture set (core/textures.ts), optional palette tint
//   brick:<bond>:<KEY>[:painted]  procedural brick bond
//   glass | glassShop | glassFar (interior mapping, interiors/interiorMapping.ts) | water | leaf:KEY
import { Color, DoubleSide, Material, MeshBasicMaterial, MeshPhysicalMaterial, MeshStandardMaterial, Vector2 } from 'three';
import { PALETTE, pc, type PaletteKey } from './palette';
import { getTexSet } from './textures';

export type MaterialFactory = (key: string) => Material | null;
const factories: MaterialFactory[] = [];
/** Register an extra material factory (e.g. interior-mapping shader). */
export function registerMaterialFactory(f: MaterialFactory) { factories.push(f); }

const cache = new Map<string, Material>();
const created: ((m: Material) => void)[] = [];
/** Hook called for every material created (CSM shadow setup, wetness...). Also replays existing ones. */
export function onMaterialCreated(f: (m: Material) => void) { created.push(f); for (const m of cache.values()) f(m); }
const ROUGH: Record<string, number> = {
  asphalt_aged: 0.92, asphalt_fresh: 0.88, asphalt_patch: 0.9, concrete_new: 0.85, concrete_aged: 0.9, granite: 0.7,
  marble: 0.25, terrazzo: 0.35, vct: 0.45, vct_plain: 0.45, subway: 0.2, hextile: 0.25, porcelain: 0.3, oak_floor: 0.45,
  heart_pine: 0.5, maple_court: 0.3, walnut: 0.45, slate: 0.75, shingle: 0.95, seam: 0.45, tpo: 0.8, patina: 0.6,
  grass: 1, grass_worn: 1, turf: 0.95, clay: 1, dirt: 1, gravel: 1, pinestraw: 1, leaflitter: 1, carpet_inn: 1, carpet_office: 1,
  tin: 0.4, cmu: 0.85, boardform: 0.9, limestone: 0.75, capstone: 0.85, stucco: 0.9, fieldstone: 0.9, rubber: 0.9,
  sealed_concrete: 0.55, sheet_vinyl: 0.4, pavers_herringbone: 0.85, pavers_running: 0.85, concrete_deck: 0.85, acoustic: 0.95,
};

export function isPaletteKey(k: string): k is PaletteKey { return k in PALETTE; }

/** Extract the palette key a material key is built from (debug "palette key under cursor"). */
export function paletteKeyOf(matKey: string): string {
  const parts = matKey.split(':');
  for (const p of parts) if (isPaletteKey(p)) return p;
  return parts.slice(1).join(':') || matKey;
}

function std(color: Color, roughness: number, extra: Partial<MeshStandardMaterial> = {}): MeshStandardMaterial {
  const m = new MeshStandardMaterial({ color, roughness, metalness: 0, vertexColors: true, ...extra });
  return m;
}

function texMat(name: string, tint?: PaletteKey): Material {
  const set = getTexSet(name);
  const rough = name.startsWith('brick:') ? 0.85 : ROUGH[name] ?? 0.85;
  if (!set) return std(tint ? pc(tint) : pc('CONCRETE_AGED'), rough);
  const mats = std(tint ? pc(tint) : new Color(1, 1, 1), rough, { map: set.map });
  const rep = new Vector2(1 / set.sizeM[0], 1 / set.sizeM[1]);
  for (const t of [set.map, set.normalMap, set.roughnessMap]) if (t) t.repeat.copy(rep);
  if (set.normalMap) { mats.normalMap = set.normalMap; mats.normalScale = new Vector2(1, 1); }
  if (set.roughnessMap) { mats.roughnessMap = set.roughnessMap; mats.roughness = 1; }
  return mats;
}

function build(key: string): Material {
  for (const f of factories) { const m = f(key); if (m) return m; }
  const [kind, a, b] = key.split(':');
  const col = (k: string | undefined) => (k && isPaletteKey(k) ? pc(k) : pc('TRIM_WHITE'));
  switch (kind) {
    case 'paint': return std(col(a), 0.85);
    case 'satin': return std(col(a), 0.5);
    case 'gloss': return std(col(a), 0.3);
    case 'leafy': return std(col(a), a === 'MAGNOLIA_LEAF' ? 0.3 : 0.8, { side: DoubleSide });
    case 'metal': return std(col(a), 0.35, { metalness: 1 });
    case 'rough': return std(col(a), 0.95);
    case 'emit': return std(col(a), 0.9, { emissive: col(a), emissiveIntensity: 1.2 });
    case 'neon': return new MeshBasicMaterial({ color: col(a).clone().multiplyScalar(3), toneMapped: false });
    case 'glow': return std(col(a), 0.4, { emissive: col(a), emissiveIntensity: 0.0 });
    case 'tex': return texMat(a, b && isPaletteKey(b) ? b : undefined);
    case 'brick': return texMat(key);
    case 'leaf': {
      const m = std(col(a), 0.8, { side: DoubleSide, alphaTest: 0.5 });
      return m;
    }
    case 'glass': case 'glassShop': {
      const m = new MeshPhysicalMaterial({
        color: pc('GLASS_TINT'), roughness: 0.05, metalness: 0, transmission: 0, transparent: true,
        opacity: kind === 'glassShop' ? 0.18 : 0.28, depthWrite: false, side: DoubleSide, envMapIntensity: 1.5,
      });
      return m;
    }
    case 'water': return new MeshPhysicalMaterial({ color: pc('PUDDLE_TINT'), roughness: 0.05, metalness: 0.1, transparent: true, opacity: 0.85 });
    case 'shadowink': return new MeshBasicMaterial({ color: pc('SHADOW_INK'), transparent: true, opacity: 0.35, depthWrite: false });
  }
  return std(isPaletteKey(kind) ? pc(kind) : pc('TRIM_WHITE'), 0.85);
}

/** Resolve a material key (cached). */
export function mat(key: string): Material {
  let m = cache.get(key);
  if (!m) {
    m = build(key);
    m.name = key;
    m.userData.matKey = key;
    if ((m as MeshStandardMaterial).roughness !== undefined) {
      m.userData.baseRoughness = (m as MeshStandardMaterial).roughness;
      m.userData.baseColor = (m as MeshStandardMaterial).color?.clone();
    }
    cache.set(key, m);
    for (const f of created) f(m);
  }
  return m;
}

export function allMaterials(): IterableIterator<[string, Material]> { return cache.entries(); }

/** Exterior-surface material? (used by the rain preset to apply wetness) */
export function isExteriorKey(key: string): boolean {
  return /^(brick|tex:(asphalt|concrete|pavers|granite|limestone|capstone|fieldstone|slate|shingle|seam|tpo|grass|clay|dirt|gravel|boardform|stucco|patina|leaflitter|pinestraw|turf)|paint:(TRIM|COLUMN|SHUTTER|DOOR|IRON|GALV|CAPSTONE))/.test(key);
}
