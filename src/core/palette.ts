// MASTER COLOR PALETTE — the ONLY file in /src allowed to contain hex color literals (tests/palette.test.ts).
// Section numbers refer to CLAUDE.md §4. "EXT" keys are colors the spec names inline (business colors, furniture,
// grout, etc.) promoted to palette keys so no other file needs a literal.
import { Color } from 'three';

export const PALETTE = {
  // 4.1 Masonry
  BRICK_CAMPUS_A: '#8E3B2E',
  BRICK_CAMPUS_B: '#A04A35',
  BRICK_CAMPUS_C: '#7A3328',
  BRICK_HEADER_GLAZED: '#4A2620',
  BRICK_DOWNTOWN_A: '#9C5038',
  BRICK_DOWNTOWN_B: '#B0623F',
  BRICK_DOWNTOWN_C: '#6E3A2C',
  BRICK_PAINTED_WHITE: '#E9E4D8',
  BRICK_PAVER_A: '#9A4F3A',
  BRICK_PAVER_B: '#8C4433',
  MORTAR_HISTORIC: '#CFC6B4',
  MORTAR_MODERN: '#B9B5AC',
  EFFLORESCENCE: '#E8E4DA',
  // 4.2 Stone & Concrete
  FIELDSTONE_A: '#8A8478',
  FIELDSTONE_B: '#6F6A60',
  FIELDSTONE_C: '#A39C8E',
  FIELDSTONE_D: '#7B6E5C',
  CAPSTONE: '#9A958B',
  GRANITE_CURB: '#9E9E98',
  LIMESTONE_TRIM: '#D8D0BE',
  MARBLE_WHITE: '#ECE9E2',
  CONCRETE_NEW: '#BDB9B0',
  CONCRETE_AGED: '#A6A29A',
  CONCRETE_BOARDFORM: '#9C988F',
  MOSS: '#4E5E2C',
  LICHEN: '#A9AE8C',
  // 4.3 Wood, Paint, Trim
  TRIM_WHITE: '#F3F0E8',
  TRIM_WHITE_AGED: '#E6E0D2',
  COLUMN_WHITE: '#EFEBE1',
  SHUTTER_GREEN: '#2F3F33',
  SHUTTER_BLACK: '#1E1F1F',
  DOOR_RED: '#6B1F1A',
  DOOR_BLACK: '#18191A',
  DOOR_GREEN: '#23382C',
  DOOR_HEAVENBLUE: '#80B4D9',
  BRASS: '#B08D57',
  BRASS_WORN: '#C9A86B',
  OAK_FLOOR: '#A47A4F',
  HEART_PINE: '#B5793E',
  WALNUT_DARK: '#4F3524',
  // 4.4 Roofs & Metal
  SLATE_A: '#4B4F55',
  SLATE_B: '#5A5E63',
  COPPER_NEW: '#B87333',
  COPPER_PATINA: '#5E9C8C',
  STANDING_SEAM: '#6C7378',
  ASPHALT_SHINGLE: '#3F3E3C',
  TPO_ROOF: '#D9D9D4',
  IRON_GREEN: '#1F3A2E',
  IRON_BLACK: '#1A1A1A',
  GALV_STEEL: '#8E9396',
  ALUMINUM_STOREFRONT: '#3A3C3E',
  // 4.5 Ground, Roads, Markings
  ASPHALT_FRESH: '#2E2F31',
  ASPHALT_AGED: '#4A4B4D',
  ASPHALT_PATCH: '#3A3B3D',
  MARKING_WHITE: '#EDEDE6',
  MARKING_YELLOW: '#E8B923',
  BIKE_LANE_GREEN: '#4F9A5A',
  CURB_PAINT_RED: '#A8322A',
  RED_CLAY: '#9B4A2C',
  DIRT_PATH: '#8A7B5E',
  PINE_STRAW: '#8C5A2B',
  GRASS_OCT: '#5E7F3A',
  GRASS_WORN: '#7D8A4E',
  GRAVEL: '#A39E93',
  PUDDLE_TINT: '#2A2C2E',
  // 4.6 Vegetation
  WILLOW_OAK_LEAF: '#6B7A35',
  WILLOW_OAK_LEAF_TURN: '#B08A2E', // EXT: 30% blend target
  WHITE_OAK_LEAF: '#8A5A2E',
  RED_MAPLE_LEAF: '#B23A26',
  SUGAR_MAPLE_LEAF: '#D9822B',
  DOGWOOD_LEAF: '#8E2F2F',
  GINKGO_LEAF: '#E3C04D',
  MAGNOLIA_LEAF: '#2F4A2A',
  LOBLOLLY_NEEDLE: '#3E5A2F',
  HOLLY_LEAF: '#23402A',
  HOLLY_BERRY: '#B3201B', // EXT
  BOXWOOD: '#3F5B2E',
  IVY: '#31502A',
  OAK_BARK: '#5C5853',
  PINE_BARK: '#5B4636',
  FALLEN_LEAF_A: '#8A5A2E', // FALLEN_LEAF_MIX
  FALLEN_LEAF_B: '#B08A2E',
  FALLEN_LEAF_C: '#6B4A2A',
  AZALEA: '#4A6B3A', // EXT §12
  // 4.7 School Identity & Signage
  HEAVEN_BLUE: '#80B4D9',
  ONSU_NAVY: '#142B4E',
  ONSU_WHITE: '#FFFFFF',
  EARL_BLUE: '#0A2A8A',
  SIGN_STREET_GREEN: '#0B6B3A',
  SIGN_CAMPUS_NAVY: '#142B4E',
  NEON_PINK: '#FF4FA3',
  NEON_BLUE: '#4FC3FF',
  NEON_RED: '#FF3B2F',
  MARQUEE_BULB: '#FFD27A',
  // 4.8 Interior Finishes
  PLASTER_CAMPUS: '#EFE8D8',
  PLASTER_IVORY: '#F2EDE1',
  WAINSCOT_GREEN: '#3E4E40',
  PAINT_DORM_BLOCK: '#E9E6DD',
  PAINT_OFFICE: '#EDEDEA',
  PAINT_HOSPITAL: '#F4F5F2',
  PAINT_HOSPITAL_ACCENT: '#9CC7C2',
  PAINT_DINER: '#D9E8E3',
  PAINT_BAR_DARK: '#2B2422',
  PAINT_RETAIL: '#F1EFEA',
  CEILING_WHITE: '#F7F7F4',
  ACOUSTIC_TILE: '#E8E6E0',
  ACOUSTIC_GRID: '#DADAD6', // EXT
  VCT_A: '#D8D3C6',
  VCT_B: '#9E9A8F',
  TERRAZZO: '#CFC8BA',
  TERRAZZO_FLECK_A: '#8E8678', // EXT
  TERRAZZO_FLECK_B: '#F2EFE8',
  TERRAZZO_FLECK_C: '#6D6A63',
  CARPET_INN: '#5A2A2E',
  CARPET_OFFICE: '#5F646A',
  SEALED_CONCRETE: '#9D9A93',
  TILE_WHITE_SUBWAY: '#F4F2EC',
  SUBWAY_GROUT: '#C9C6BF', // EXT
  HEX_TILE_WHITE: '#F1F0EB',
  HEX_GROUT: '#BDBAB2', // EXT
  SPORTS_MAPLE: '#D8B07A',
  RUBBER_FLOOR: '#2F3133',
  SHEET_VINYL: '#DCDAD2', // EXT §7.5 hospital wards
  PORCELAIN_MODERN: '#CFCBC2', // EXT §7.5 modern restrooms
  BOH_PAINT: '#DCD9D2', // EXT §7.5 back-of-house painted walls
  // 4.9 Light Colors
  SUN_GOLDEN: '#FFC98A',
  SUN_NOON: '#FFF4E5',
  SKY_GOLDEN_ZENITH: '#7FA6CC',
  SKY_GOLDEN_HORIZON: '#F2C48D',
  SKY_NIGHT: '#0B1424',
  SKY_RAIN: '#8D949B',
  SKY_MIDDAY_ZENITH: '#8FB8DE', // EXT §15
  SKY_MIDDAY_HORIZON: '#D6E6F2', // EXT §15
  MOON: '#AFC4E8', // EXT §15
  LAMP_SODIUM: '#FFB765',
  LAMP_LED: '#EAF0FF',
  LAMP_CAMPUS: '#FFD9A8',
  INTERIOR_WARM: '#FFD9A0',
  INTERIOR_COOL: '#F2F6FF',

  // ---------- EXT: business / district colors (§9.9, §9.11, §11) ----------
  STOREFRONT_TERRACOTTA: '#C7522A',
  STOREFRONT_MUSTARD: '#E0B341',
  STOREFRONT_TEAL: '#4C7A8C',
  STOREFRONT_SAGE: '#7E9C5B',
  STOREFRONT_ROSE: '#B8577A',
  SIDING_CREAM: '#E9E4D8',
  SIDING_SAGE: '#9DB0A3',
  SIDING_WHEAT: '#D4C59A',
  SIDING_SLATE_BLUE: '#8A9BB0',
  AWNING_HARBOR_BLUE: '#1F4E79',
  AWNING_COFFEE: '#3E2A1E',
  AWNING_LINEN: '#B5A68A',
  CINEMA_MAROON: '#7A2E2E',
  SIGN_CREAM: '#E6D3A3',
  // ---------- EXT: landmarks & street furniture (§10, §13, §5) ----------
  FIELD_TURF: '#3D7A3A',
  MEMBRANE_WHITE: '#E4E6E6',
  TRUNCATED_DOME: '#B5873A',
  HYDRANT_RED: '#C9302C',
  HYDRANT_CAP: '#E6E3DA',
  SIGNAL_HEAD: '#2B2B2B',
  BENCH_SLAT: '#8A6A48',
  // ---------- EXT: rendering-only neutrals (added per §0 rule 2) ----------
  GLASS_TINT: '#B9C7CC', // window glass base tint
  GLASS_DARK: '#20262B', // unlit far-window interior fallback
  SHADOW_INK: '#000000', // pure black (UI shadows, masks)
  STUCCO: '#E2DACB', // stucco end walls (Elder East/West), Toadstool houses
  MULLION_WHITE: '#F3F0E8',
  STEEL_DOOR_GRAY: '#7D8286',
  RUBBER_TREAD: '#2F3133',
  UI_PANEL: '#101418',
} as const;

export type PaletteKey = keyof typeof PALETTE;

export const PALETTE_KEYS = Object.keys(PALETTE) as PaletteKey[];

const cache = new Map<string, Color>();
/** Linear-space THREE.Color for a palette key (cached; do not mutate). */
export function pc(key: PaletteKey): Color {
  let c = cache.get(key);
  if (!c) {
    c = new Color(PALETTE[key]);
    cache.set(key, c);
  }
  return c;
}

/** CSS hex string, for canvas/2D UI drawing. */
export function css(key: PaletteKey): string {
  return PALETTE[key];
}

/** CSS rgba() for a palette key with alpha. */
export function cssA(key: PaletteKey, a: number): string {
  const h = PALETTE[key];
  const n = parseInt(h.slice(1), 16);
  return `rgba(${(n >> 16) & 255},${(n >> 8) & 255},${n & 255},${a})`;
}

/**
 * Jittered color around a palette base: value ±valuePct, hue ±hueDeg (CLAUDE.md §4 jitter rule).
 * `r1`, `r2` are uniform randoms in [0,1).
 */
export function jitter(key: PaletteKey, r1: number, r2: number, valuePct = 0.06, hueDeg = 3, out = new Color()): Color {
  out.copy(pc(key));
  const hsl = { h: 0, s: 0, l: 0 };
  out.getHSL(hsl);
  hsl.h = (hsl.h + ((r1 * 2 - 1) * hueDeg) / 360 + 1) % 1;
  hsl.l = Math.min(1, Math.max(0, hsl.l * (1 + (r2 * 2 - 1) * valuePct)));
  out.setHSL(hsl.h, hsl.s, hsl.l);
  return out;
}

/** Linear blend of two palette colors. */
export function mixKeys(a: PaletteKey, b: PaletteKey, t: number, out = new Color()): Color {
  return out.copy(pc(a)).lerp(pc(b), t);
}

/** Expose the palette as CSS custom properties (--c-KEY) so stylesheets never carry hex literals. */
export function installCssPalette(root: HTMLElement = document.documentElement) {
  for (const k of PALETTE_KEYS) root.style.setProperty(`--c-${k}`, PALETTE[k]);
}
