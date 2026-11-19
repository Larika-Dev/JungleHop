// Cathedral Mount master layout (Phase 1 concept, refined). Plan coords [x, z]: +x east, +z south.
// World (Three.js) position = (x, y, z) with the same x/z, so -Z is north. Units: meters.
import type { PaletteKey } from '../core/palette';

export type P2 = [number, number];
export const rect = (x0: number, z0: number, x1: number, z1: number): P2[] => [[x0, z0], [x1, z0], [x1, z1], [x0, z1]];

export type DistrictId =
  | 'hamilton_strip' | 'summit' | 'rosemary_row' | 'residential_north' | 'north_quad' | 'founders_quad' | 'quarry'
  | 'carillon_south' | 'medical' | 'carrburg' | 'toadstool' | 'battle_ravine' | 'cameron_heights' | 'campus_generic' | 'outer_ring';

export interface District { id: DistrictId; name: string; poly: P2[]; order: number; mapColor: PaletteKey; label: P2; }

export const DISTRICTS: District[] = [
  { id: 'campus_generic', name: 'ONSU Campus', order: 0, mapColor: 'GRASS_OCT', label: [340, 520],
    poly: [[20, 11], [420, 11], [420, 220], [480, 380], [480, 950], [-140, 950], [-140, 560], [-10, 420], [-10, 330], [20, 330]] },
  { id: 'residential_north', name: 'Residential North', order: 1, mapColor: 'SIDING_CREAM', label: [-30, -320], poly: rect(-480, -450, 420, -160) },
  { id: 'rosemary_row', name: 'Rosemary Row', order: 2, mapColor: 'CONCRETE_AGED', label: [-300, -138], poly: rect(-420, -160, 380, -55) },
  { id: 'hamilton_strip', name: 'Hamilton Strip', order: 3, mapColor: 'BRICK_DOWNTOWN_A', label: [-250, -32],
    poly: [[-420, -55], [380, -55], [380, 55], [300, 55], [300, 11], [20, 11], [20, 55], [-420, 55]] },
  { id: 'cameron_heights', name: 'Cameron Heights', order: 3, mapColor: 'SIDING_WHEAT', label: [-330, 250], poly: rect(-480, 55, -10, 430) },
  { id: 'north_quad', name: 'ONSU North Quad', order: 4, mapColor: 'GRASS_OCT', label: [190, 80], poly: rect(20, 11, 300, 325) },
  { id: 'founders_quad', name: "Founders' Quad", order: 4, mapColor: 'GRASS_OCT', label: [190, 470], poly: rect(100, 325, 285, 632) },
  { id: 'quarry', name: 'The Quarry', order: 5, mapColor: 'BRICK_PAVER_A', label: [52, 590], poly: rect(5, 395, 100, 580) },
  { id: 'carillon_south', name: 'Carillon Hill', order: 4, mapColor: 'LOBLOLLY_NEEDLE', label: [40, 735],
    poly: [[100, 632], [420, 632], [480, 700], [480, 950], [-130, 950], [-130, 770], [100, 760]] },
  { id: 'medical', name: 'ONSU Medical Center', order: 4, mapColor: 'PAINT_HOSPITAL_ACCENT', label: [-310, 578], poly: rect(-470, 560, -145, 910) },
  { id: 'carrburg', name: 'Carrburg', order: 4, mapColor: 'RED_CLAY', label: [-800, -250], poly: rect(-900, -300, -480, 320) },
  { id: 'toadstool', name: 'Toadstool Hill', order: 4, mapColor: 'LOBLOLLY_NEEDLE', label: [610, -15],
    poly: [[490, -40], [700, -40], [700, 250], [600, 240], [540, 180], [490, 110]] },
  { id: 'battle_ravine', name: 'Battle Ravine', order: 5, mapColor: 'WILLOW_OAK_LEAF', label: [600, 560],
    poly: [[520, 160], [640, 200], [660, 320], [610, 480], [560, 640], [520, 770], [470, 770], [450, 640], [470, 470], [480, 300]] },
  { id: 'summit', name: 'The Summit', order: 6, mapColor: 'MARKING_YELLOW', label: [0, 0], poly: rect(-30, -30, 30, 30) },
];

// ------------------------------------------------------------------------------------------ ROADS
/** Cross-section kinds (all widths in cm; CLAUDE.md §9.1 for Hamilton). */
export type RoadKind = 'hamilton' | 'main' | 'secondary' | 'campus' | 'lane' | 'alley' | 'highway' | 'rail';
export interface RoadSection {
  laneCm: number; lanes: number; parkingCm: number; bikeCm: number; sidewalkCm: number; curb: boolean;
  surface: 'asphalt_aged' | 'asphalt_fresh' | 'concrete_new'; walk: 'pavers_running' | 'pavers_herringbone' | 'concrete_aged' | 'concrete_new' | 'none';
  curbKey: PaletteKey; centerline: 'double_yellow' | 'dashed_yellow' | 'none'; light: 'LAMP_LED' | 'LAMP_SODIUM' | 'LAMP_CAMPUS' | 'none';
}
export const SECTIONS: Record<RoadKind, RoadSection> = {
  hamilton: { laneCm: 330, lanes: 2, parkingCm: 244, bikeCm: 0, sidewalkCm: 525, curb: true, surface: 'asphalt_aged', walk: 'pavers_running', curbKey: 'CONCRETE_AGED', centerline: 'double_yellow', light: 'LAMP_LED' },
  main: { laneCm: 330, lanes: 2, parkingCm: 0, bikeCm: 150, sidewalkCm: 300, curb: true, surface: 'asphalt_aged', walk: 'concrete_aged', curbKey: 'CONCRETE_AGED', centerline: 'double_yellow', light: 'LAMP_LED' },
  secondary: { laneCm: 320, lanes: 2, parkingCm: 0, bikeCm: 0, sidewalkCm: 240, curb: true, surface: 'asphalt_aged', walk: 'concrete_aged', curbKey: 'CONCRETE_AGED', centerline: 'dashed_yellow', light: 'LAMP_SODIUM' },
  campus: { laneCm: 300, lanes: 2, parkingCm: 0, bikeCm: 0, sidewalkCm: 240, curb: true, surface: 'asphalt_aged', walk: 'pavers_herringbone', curbKey: 'GRANITE_CURB', centerline: 'dashed_yellow', light: 'LAMP_CAMPUS' },
  lane: { laneCm: 460, lanes: 1, parkingCm: 0, bikeCm: 0, sidewalkCm: 0, curb: false, surface: 'asphalt_aged', walk: 'none', curbKey: 'GRANITE_CURB', centerline: 'none', light: 'LAMP_CAMPUS' },
  alley: { laneCm: 450, lanes: 1, parkingCm: 0, bikeCm: 0, sidewalkCm: 0, curb: false, surface: 'asphalt_aged', walk: 'none', curbKey: 'CONCRETE_AGED', centerline: 'none', light: 'LAMP_SODIUM' },
  highway: { laneCm: 365, lanes: 4, parkingCm: 0, bikeCm: 0, sidewalkCm: 0, curb: false, surface: 'asphalt_fresh', walk: 'none', curbKey: 'CONCRETE_NEW', centerline: 'double_yellow', light: 'none' },
  rail: { laneCm: 300, lanes: 1, parkingCm: 0, bikeCm: 0, sidewalkCm: 0, curb: false, surface: 'asphalt_aged', walk: 'none', curbKey: 'CONCRETE_AGED', centerline: 'none', light: 'none' },
};
/** Half-width of paved roadway (curb face to centerline), meters. */
export const roadHalf = (k: RoadKind) => { const s = SECTIONS[k]; return (s.laneCm * s.lanes + 2 * s.parkingCm + 2 * s.bikeCm) / 200; };
/** Half-width of full right-of-way (back of sidewalk), meters. */
export const rowHalf = (k: RoadKind) => roadHalf(k) + SECTIONS[k].sidewalkCm / 100 + (SECTIONS[k].curb ? 0.15 : 0);

export interface RoadDef { id: string; name: string; kind: RoadKind; pts: P2[]; alleyWidthCm?: number; }

export const ROADS: RoadDef[] = [
  { id: 'hamilton', name: 'Hamilton St', kind: 'hamilton', pts: [[-480, 0], [700, 0]] },
  { id: 'hamilton_w', name: 'Hamilton St', kind: 'main', pts: [[-900, 40], [-760, 26], [-620, 8], [-520, 0], [-480, 0]] },
  { id: 'columbia_n', name: 'Columbia St', kind: 'main', pts: [[0, -450], [0, 0]] },
  { id: 'columbia_s', name: 'Columbia St', kind: 'main', pts: [[0, 0], [0, 430], [-40, 505], [-110, 570], [-135, 640], [-140, 950]] },
  { id: 'rosemary', name: 'Rosemary St', kind: 'secondary', pts: [[-480, -108], [380, -108], [425, -92], [452, -55], [460, 0]] },
  { id: 'cameron', name: 'Cameron Ave', kind: 'campus', pts: [[-480, 325], [390, 325]] },
  { id: 'raleigh', name: 'Raleigh Pike', kind: 'main', pts: [[390, 0], [390, 325], [470, 370], [560, 410], [700, 450]] },
  { id: 'founders', name: 'Founders Rd', kind: 'campus', pts: [[-40, 505], [40, 600], [95, 640], [95, 785]] },
  { id: 'manor', name: 'Manor Dr', kind: 'main', pts: [[-480, 760], [-140, 775], [95, 785], [212, 795], [218, 935], [480, 940], [700, 900]] },
  { id: 'millers_run', name: "Miller's Run Rd", kind: 'main', pts: [[-480, -450], [-480, 950]] },
  { id: 'chancel', name: 'Chancel St', kind: 'secondary', pts: [[-300, -450], [-300, 325]] },
  { id: 'henley', name: 'Henley St', kind: 'secondary', pts: [[300, -450], [300, 0]] },
  { id: 'keep_lane', name: 'Keep Lane', kind: 'lane', pts: [[530, 0], [545, 45], [590, 70], [640, 130], [640, 185]] },
  { id: 'bobbin', name: 'Bobbin Rd', kind: 'secondary', pts: [[-640, -300], [-640, 320]] },
  // Residential North grid (invented local streets)
  { id: 'pell', name: 'Pell St', kind: 'secondary', pts: [[-480, -230], [420, -230]] },
  { id: 'harrow', name: 'Harrow St', kind: 'secondary', pts: [[-480, -330], [420, -330]] },
  { id: 'vance', name: 'Vance Ln', kind: 'secondary', pts: [[-150, -450], [-150, -108]] },
  { id: 'audley', name: 'Audley St', kind: 'secondary', pts: [[150, -450], [150, -108]] },
  // Cameron Heights local street
  { id: 'glebe', name: 'Glebe St', kind: 'secondary', pts: [[-480, 175], [0, 175]] },
  // Invented alleys (CLAUDE.md §9.1, 3.5-6 m)
  { id: 'tanners', name: "Tanner's Alley", kind: 'alley', pts: [[-230, -11], [-230, -100]], alleyWidthCm: 500 },
  { id: 'inkwell', name: 'Inkwell Lane', kind: 'alley', pts: [[-110, -11], [-110, -62], [60, -62], [60, -100]], alleyWidthCm: 450 },
  { id: 'bluelantern', name: 'Blue Lantern Way', kind: 'alley', pts: [[160, -11], [160, -100]], alleyWidthCm: 400 },
  { id: 'sutters', name: "Sutter's Court", kind: 'alley', pts: [[-160, 11], [-160, 52], [-90, 52]], alleyWidthCm: 350 },
];

/** Outer-ring bypass (4-lane), plan coords. */
export const BYPASS: P2[] = [[-1500, -1050], [1300, -1050], [1400, -300], [1350, 1550], [-1500, 1550], [-1550, 300], [-1500, -1050]];

export const RAIL: P2[] = [[-760, -1450], [-760, -450], [-722, 0], [-692, 500], [-680, 950], [-660, 1950]];

// ------------------------------------------------------------------------------------------ TERRAIN CONTROL
/** Spot elevations [x, z, y] (meters relative to The Summit street crown). */
export const SPOTS: [number, number, number][] = [
  [-450, 0, 0], [-300, 0, 0], [-150, 0, 0], [0, 0, 0], [150, 0, 0], [300, 0, 0], [450, 0, 0], [600, 0, 0.5],
  [-450, -420, -8], [0, -420, -8], [380, -420, -8], [-250, -220, -4.5], [150, -220, -4.5], [0, -108, -1.5],
  [190, 160, -2], [60, 120, -1.5], [190, 470, -6], [60, 480, -7.5], [300, 420, -6.5], [0, 300, -6],
  [270, 668, -10], [160, 610, -8], [120, 700, -11],
  [0, 870, -14], [160, 880, -15], [-300, 700, -9], [-300, 880, -12], [-100, 760, -11], [350, 940, -18],
  [-250, 200, -4], [-55, 375, -6.5], [-400, 400, -7],
  [-560, 0, -8], [-700, 0, -12], [-700, 250, -12], [-700, -250, -12], [-860, 0, -12.5], [-480, 300, -7], [-480, -300, -6],
  [600, 100, 3], [650, -30, 1.5],
  [700, 600, -10], [700, 900, -16], [-880, 900, -13], [-880, -440, -11], [690, -440, -6], [-600, 700, -11],
  // outer ring (gentle rolling piedmont)
  [-1800, -1300, -14], [0, -1350, -12], [1600, -1300, -8], [1600, 300, -4], [1600, 1800, -22], [0, 1850, -30], [-1800, 1800, -20], [-1800, 300, -15],
  [-1200, -800, -10], [1000, -800, -7], [1100, 1200, -20], [-1100, 1200, -16],
];
export const RAVINE = { creek: [[580, 120], [560, 300], [540, 450], [505, 600], [490, 770], [470, 900]] as P2[], bed: -18, halfWidth: 75 };
export const BOWL = { cx: 360, cz: 810, rx: 70, rz: 48, falloff: 62, floor: -28 };
/** Benefactor stadium seating bowl: rounded-rect inner edge (field + apron), tier slope, rim offset (m). */
export const STADIUM = { cx: 360, cz: 810, hx: 65, hz: 35, r: 16, slope: 0.445, rim: 28.4, floor: -28 };
export const QUARRY_PLAZA = { x0: 52, z0: 452, x1: 100, z1: 518, depth: 2.5 };

// ------------------------------------------------------------------------------------------ LANDMARKS (CLAUDE.md §10)
export interface LandmarkSite { n: number; id: string; name: string; x: number; z: number; rotY: number; }
/** Center positions & facing (rotY: radians; 0 = front faces -Z/north, PI = faces south). */
export const LANDMARKS: LandmarkSite[] = [
  { n: 1, id: 'old_cistern', name: 'The Old Cistern', x: 190, z: 300, rotY: 0 },
  { n: 2, id: 'carillon_spire', name: 'The Carillon Spire', x: 270, z: 668, rotY: 0 },
  { n: 3, id: 'wilberforce_library', name: 'Wilberforce Library', x: 275, z: 147, rotY: Math.PI / 2 },
  { n: 4, id: 'davies_stacks', name: 'Davies Stacks', x: 28, z: 487, rotY: -Math.PI / 2 },
  { n: 5, id: 'founders_hall', name: "Founders' Hall", x: 190, z: 348, rotY: Math.PI },
  { n: 6, id: 'elder_west', name: 'Elder West', x: 113, z: 270, rotY: -Math.PI / 2 },
  { n: 6, id: 'elder_east', name: 'Elder East', x: 267, z: 270, rotY: Math.PI / 2 },
  { n: 7, id: 'moorhouse', name: 'Moorhouse Observatory', x: 441, z: 66, rotY: 0 },
  { n: 8, id: 'ashgrove_library', name: 'Ashgrove Library', x: 190, z: 608, rotY: 0 },
  { n: 9, id: 'student_union', name: 'Student Union', x: 75, z: 550, rotY: 0 },
  { n: 9, id: 'dining_hall', name: 'Dining Hall', x: 75, z: 421, rotY: Math.PI },
  { n: 10, id: 'benefactor_stadium', name: 'Benefactor Memorial Stadium', x: 360, z: 810, rotY: 0 },
  { n: 11, id: 'coachs_dome', name: "The Coach's Dome", x: 0, z: 870, rotY: 0 },
  { n: 12, id: 'pamlico_inn', name: 'Pamlico Inn', x: -55, z: 375, rotY: Math.PI / 2 },
  { n: 13, id: 'medical_center', name: 'ONSU Medical Center', x: -330, z: 680, rotY: 0 },
  { n: 14, id: 'ghoulgrave_keep', name: 'Ghoulgrave Keep', x: 640, z: 200, rotY: 0 },
  { n: 15, id: 'grove_amphitheatre', name: 'Grove Amphitheatre', x: 478, z: 292, rotY: Math.PI / 2 },
];

/** Desire paths worn across the quads (GRASS_WORN shortcut lines, CLAUDE.md §8/§9.5). w = width (m). */
export const WORN_PATHS: { w: number; pts: P2[] }[] = [
  { w: 1.6, pts: [[132, 30], [246, 288]] }, { w: 1.4, pts: [[248, 52], [150, 284]] }, { w: 1.1, pts: [[190, 20], [176, 160], [190, 292]] },
  { w: 1.8, pts: [[118, 368], [262, 598]] }, { w: 1.8, pts: [[262, 368], [118, 598]] }, { w: 1.2, pts: [[190, 362], [146, 470], [190, 584]] },
  { w: 1.0, pts: [[100, 520], [62, 562]] }, { w: 1.3, pts: [[230, 640], [265, 690], [330, 712]] }, { w: 1.0, pts: [[-20, 330], [40, 395]] },
  { w: 1.2, pts: [[300, 120], [380, 210]] }, { w: 0.9, pts: [[455, 150], [470, 260]] },
];

/** Fieldstone walls (plan polylines). */
export const STONE_WALLS: { name: string; pts: P2[] }[] = [
  { name: 'North Quad wall (Hamilton St)', pts: [[22, 11.5], [298, 11.5]] },
  { name: 'North Quad wall (Columbia St)', pts: [[9.5, 15], [9.5, 316]] },
  { name: 'Cameron Ave wall', pts: [[100, 333], [160, 333]] },
  { name: 'Cameron Ave wall E', pts: [[220, 333], [285, 333]] },
];

export function pointInPoly(x: number, z: number, poly: P2[]): boolean {
  let inside = false;
  for (let i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    const [xi, zi] = poly[i], [xj, zj] = poly[j];
    if ((zi > z) !== (zj > z) && x < ((xj - xi) * (z - zi)) / (zj - zi) + xi) inside = !inside;
  }
  return inside;
}
/** District at a point (highest order wins). */
export function districtAt(x: number, z: number): District | null {
  let best: District | null = null;
  for (const d of DISTRICTS) if (pointInPoly(x, z, d.poly) && (!best || d.order >= best.order)) best = d;
  return best;
}
