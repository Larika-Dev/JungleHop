// CATHEDRAL MOUNT — Phase 1 concept layout (single source of truth for the concept map).
// Units: meters. Origin (0,0) = center of The Summit (Hamilton St x Columbia St), street-crown elevation 0.
// Plan coordinates are [x, z] with +x = east and +z = SOUTH (Three.js: -Z is north).
// These numbers are concept-level (10 m confidence). Phase 3 snaps roads to the 1 cm grid.

export const SEED = 1795;

/** Dense playable core and total map (core + 1 km outer ring). */
export const CORE = { x0: -900, x1: 700, z0: -450, z1: 950 }; // 1600 x 1400 m
export const TOTAL = { x0: -1900, x1: 1700, z0: -1450, z1: 1950 }; // 3600 x 3400 m
export const TILE = 200; // T_{col}_{row}, counted from the NW corner of TOTAL

export const tileOf = (x, z) => {
  const col = Math.floor((x - TOTAL.x0) / TILE);
  const row = Math.floor((z - TOTAL.z0) / TILE);
  return `T_${col}_${row}`;
};

const rect = (x0, z0, x1, z1) => [[x0, z0], [x1, z0], [x1, z1], [x0, z1]];

/** Districts. `order` = paint order (low first). `color` keys refer to CLAUDE.md palette names. */
export const districts = [
  { id: 'campus_generic', name: 'ONSU Campus (generic halls & labs)', order: 0, palette: 'GRASS_OCT',
    poly: [[20, 11], [420, 11], [420, 220], [480, 380], [480, 950], [-140, 950], [-140, 560], [-10, 420], [-10, 330], [20, 330]], label: [340, 520] },
  { id: 'residential_north', name: 'Residential North', order: 1, palette: 'BRICK_PAINTED_WHITE',
    poly: rect(-480, -450, 420, -160), label: [-30, -320], elev: '-4 to -8 m' },
  { id: 'rosemary_row', name: 'Rosemary Row', order: 2, palette: 'CONCRETE_AGED',
    poly: rect(-420, -160, 380, -55), label: [-300, -138], elev: '-1 to -2 m' },
  { id: 'hamilton_strip', name: 'Hamilton Strip', order: 3, palette: 'BRICK_DOWNTOWN_A',
    poly: [[-420, -55], [380, -55], [380, 55], [300, 55], [300, 11], [20, 11], [20, 55], [-420, 55]], label: [-250, -32], elev: '0 m (ridge)' },
  { id: 'cameron_heights', name: 'Cameron Heights (proposed)', order: 3, palette: 'BRICK_PAINTED_WHITE',
    poly: rect(-480, 55, -10, 430), label: [-330, 250], elev: '-2 to -7 m' },
  { id: 'north_quad', name: 'ONSU North Quad', order: 4, palette: 'GRASS_OCT',
    poly: rect(20, 11, 300, 325), label: [190, 80], elev: '-1 to -3 m' },
  { id: 'founders_quad', name: "Founders' Quad", order: 4, palette: 'GRASS_OCT',
    poly: rect(100, 325, 285, 632), label: [190, 470], elev: '-5 to -7 m' },
  { id: 'quarry', name: 'The Quarry', order: 5, palette: 'BRICK_PAVER_A',
    poly: rect(5, 395, 100, 580), label: [52, 590], elev: '-7.5 m grade, plaza -10 m' },
  { id: 'carillon_south', name: 'Carillon Hill & South Campus', order: 4, palette: 'LOBLOLLY_NEEDLE',
    poly: [[100, 632], [420, 632], [480, 700], [480, 950], [-130, 950], [-130, 770], [100, 760]], label: [40, 735], elev: '-10 to -28 m' },
  { id: 'medical', name: 'ONSU Medical Center', order: 4, palette: 'PAINT_HOSPITAL_ACCENT',
    poly: rect(-470, 560, -145, 910), label: [-310, 578], elev: '-8 to -12 m' },
  { id: 'carrburg', name: 'Carrburg', order: 4, palette: 'RED_CLAY',
    poly: rect(-900, -300, -480, 320), label: [-800, -250], elev: '-12 m' },
  { id: 'toadstool', name: 'Toadstool Hill', order: 4, palette: 'LOBLOLLY_NEEDLE',
    poly: [[490, -40], [700, -40], [700, 250], [600, 240], [540, 180], [490, 110]], label: [610, -15], elev: '+1 to +3 m' },
  { id: 'battle_ravine', name: 'Battle Ravine', order: 5, palette: 'WILLOW_OAK_LEAF',
    poly: [[520, 160], [640, 200], [660, 320], [610, 480], [560, 640], [520, 770], [470, 770], [450, 640], [470, 470], [480, 300]], label: [600, 560], elev: 'creek -18 m' },
];

/** Streets: centerline polylines, right-of-way width (m), class. */
export const streets = [
  { name: 'Hamilton St', cls: 'main', row: 22.5, pts: [[-900, 40], [-760, 26], [-620, 8], [-520, 0], [700, 0]] },
  { name: 'Columbia St', cls: 'main', row: 18, pts: [[0, -450], [0, 430], [-40, 505], [-110, 570], [-135, 640], [-140, 950]] },
  { name: 'Rosemary St', cls: 'secondary', row: 16, pts: [[-480, -108], [380, -108], [440, -70], [480, 0]] },
  { name: 'Cameron Ave', cls: 'secondary', row: 14, pts: [[-480, 325], [390, 325]] },
  { name: 'Raleigh Pike', cls: 'main', row: 18, pts: [[390, 0], [390, 325], [470, 370], [560, 410], [700, 450]] },
  { name: 'Founders Rd', cls: 'campus', row: 10, pts: [[-40, 505], [40, 600], [95, 640], [95, 785]] },
  { name: 'Manor Dr', cls: 'main', row: 20, pts: [[-480, 760], [-140, 775], [95, 785], [225, 795], [235, 935], [480, 940], [700, 900]] },
  { name: "Miller's Run Rd", cls: 'main', row: 18, pts: [[-480, -450], [-480, 950]] },
  { name: 'Chancel St (inv.)', cls: 'secondary', row: 14, pts: [[-300, -450], [-300, 325]] },
  { name: 'Henley St (inv.)', cls: 'secondary', row: 14, pts: [[300, -450], [300, 0]] },
  { name: 'Keep Lane (inv.)', cls: 'lane', row: 6, pts: [[480, 0], [530, 50], [590, 70], [640, 130], [640, 195]] },
  { name: 'Bobbin Rd (inv.)', cls: 'secondary', row: 14, pts: [[-640, -300], [-640, 320]] },
  // Invented alleys (3.5-6 m)
  { name: "Tanner's Alley", cls: 'alley', row: 5, pts: [[-230, 11], [-230, -100]] },
  { name: 'Inkwell Lane', cls: 'alley', row: 4.5, pts: [[-110, 11], [-110, -62], [60, -62], [60, -100]] },
  { name: 'Blue Lantern Way', cls: 'alley', row: 4, pts: [[160, -11], [160, -100]] },
  { name: 'Sutter\'s Court (inv.)', cls: 'alley', row: 3.5, pts: [[-160, 11], [-160, 52], [-90, 52]] },
];

export const rail = { name: 'Pamlico & Western RR (1.5 m embankment)', pts: [[-760, -450], [-722, 0], [-692, 500], [-680, 950]] };

/** Landmarks — numbers match CLAUDE.md §10. rect: [x0,z0,x1,z1]; circle: [cx,cz,r]. */
export const landmarks = [
  { n: 1, name: 'The Old Cistern', circle: [190, 300, 6] },
  { n: 2, name: 'The Carillon Spire (52 m)', rect: [265, 663, 275, 673] },
  { n: 3, name: 'Wilberforce Library', rect: [255, 120, 295, 175] },
  { n: 4, name: 'Davies Stacks', rect: [8, 445, 48, 530] },
  { n: 5, name: "Founders' Hall", rect: [165, 337, 215, 358] },
  { n: 6, name: 'Elder West', rect: [107, 240, 120, 300] },
  { n: 6, name: 'Elder East', rect: [260, 240, 273, 300] },
  { n: 7, name: 'Moorhouse Observatory', rect: [405, 28, 478, 105] },
  { n: 8, name: "Founders' Quad Library", rect: [160, 588, 220, 628] },
  { n: 9, name: 'Student Union', rect: [50, 525, 100, 575] },
  { n: 9, name: 'Dining Hall', rect: [50, 400, 100, 443] },
  { n: 10, name: 'Benefactor Memorial Stadium', rect: [250, 715, 470, 905] },
  { n: 11, name: "The Coach's Dome (120 m)", circle: [0, 870, 60] },
  { n: 12, name: 'Pamlico Inn', rect: [-95, 340, -15, 410] },
  { n: 13, name: 'Med. Center Tower A', rect: [-430, 600, -375, 655] },
  { n: 13, name: 'Med. Center Tower B', rect: [-345, 600, -290, 655] },
  { n: 13, name: 'Med. Center Tower C', rect: [-430, 690, -375, 745] },
  { n: 13, name: 'Med. Center Tower D (helipad)', rect: [-320, 685, -250, 750] },
  { n: 14, name: 'Ghoulgrave Keep', rect: [625, 185, 655, 215] },
  { n: 15, name: 'Grove Amphitheatre', circle: [478, 292, 22] },
];

/** Other major built elements (not §10 landmarks). */
export const features = [
  { name: 'Top of the Mount', rect: [5, -45, 40, -12], kind: 'hero_shop' },
  { name: 'Bluebird Savings Bank', rect: [-40, -45, -5, -12], kind: 'hero_shop' },
  { name: 'Rosemary Deck West (5 lv)', rect: [-205, -98, -135, -66], kind: 'deck' },
  { name: 'Rosemary Deck East (5 lv)', rect: [75, -98, 145, -70], kind: 'deck' },
  { name: 'Med. Deck 1', rect: [-440, 815, -360, 885], kind: 'deck' },
  { name: 'Med. Deck 2', rect: [-320, 815, -240, 885], kind: 'deck' },
  { name: 'ER bay + canopy', rect: [-225, 640, -170, 700], kind: 'hospital' },
  { name: 'South Campus Deck', rect: [62, 880, 104, 945], kind: 'deck' },
  { name: 'Recreation Center', rect: [-125, 830, -72, 905], kind: 'campus' },
  { name: 'Res Hall 1', rect: [112, 840, 130, 905], kind: 'dorm' },
  { name: 'Res Hall 2', rect: [138, 840, 156, 905], kind: 'dorm' },
  { name: 'Res Hall 3', rect: [164, 840, 182, 905], kind: 'dorm' },
  { name: 'Res Hall 4', rect: [190, 840, 208, 905], kind: 'dorm' },
  { name: 'Loomhouse Mill (co-op)', rect: [-705, -90, -665, 50], kind: 'mill' },
  { name: 'Town Commons', rect: [-640, 40, -578, 110], kind: 'lawn' },
  { name: 'North Quad Hall I', rect: [30, 55, 100, 105], kind: 'campus' },
  { name: 'North Quad Hall II', rect: [30, 150, 100, 205], kind: 'campus' },
  { name: 'North Quad Hall III', rect: [255, 40, 295, 95], kind: 'campus' },
  { name: "Founders' Halls W1-W3", rect: [100, 380, 132, 570], kind: 'campus' },
  { name: "Founders' Halls E1-E3", rect: [250, 380, 282, 570], kind: 'campus' },
  { name: 'Quarry plaza (-2.5 m)', rect: [52, 452, 100, 518], kind: 'plaza' },
  { name: 'Sundial garden', circle: [442, 128, 14], kind: 'lawn' },
  { name: 'Stone footbridge', rect: [528, 445, 572, 452], kind: 'bridge' },
  { name: 'Raleigh Pike viaduct', rect: [500, 382, 560, 420], kind: 'bridge' },
];

/** Fieldstone walls (polylines). */
export const walls = [
  { name: 'North Quad wall (Hamilton St)', pts: [[22, 13], [298, 13]] },
  { name: 'North Quad wall (Columbia St)', pts: [[22, 13], [22, 320]] },
  { name: 'Cameron Ave wall', pts: [[100, 327], [285, 327]] },
];

/** Spot elevations (m relative to The Summit). These drive the schematic heightfield. */
export const spots = [
  // Hamilton Ridge
  [-450, 0, 0], [-300, 0, 0], [-150, 0, 0], [0, 0, 0], [150, 0, 0], [300, 0, 0], [450, 0, 0], [600, 0, 0.5],
  // North slope
  [-450, -420, -8], [0, -420, -8], [380, -420, -8], [-250, -220, -4.5], [150, -220, -4.5], [0, -108, -1.5],
  // Campus south slope
  [190, 160, -2], [60, 120, -1.5], [190, 470, -6], [60, 480, -7.5], [300, 420, -6.5], [0, 300, -6],
  [270, 668, -10], [160, 610, -8], [120, 700, -11],
  // South campus & hospital
  [0, 870, -14], [160, 880, -15], [-300, 700, -9], [-300, 880, -12], [-100, 760, -11], [350, 940, -18],
  // Cameron Heights
  [-250, 200, -4], [-55, 375, -6.5], [-400, 400, -7],
  // Carrburg
  [-560, 0, -8], [-700, 0, -12], [-700, 250, -12], [-700, -250, -12], [-860, 0, -12.5], [-480, 300, -7], [-480, -300, -6],
  // Toadstool Hill
  [600, 100, 3], [650, -30, 1.5],
  // edges
  [700, 600, -10], [700, 900, -16], [-880, 900, -13], [-880, -440, -11], [690, -440, -6], [-600, 700, -11],
];

/** Battle Ravine creek line (bed at -18 m) and Benefactor bowl (floor -28 m). */
export const ravine = { creek: [[580, 160], [560, 300], [540, 450], [505, 600], [490, 770]], bed: -18, halfWidth: 75 };
export const bowl = { cx: 360, cz: 810, rx: 75, rz: 55, falloff: 95, floor: -28 };

const smooth = (a, b, t) => { const u = Math.min(1, Math.max(0, (t - a) / (b - a))); return u * u * (3 - 2 * u); };
const segDist = (px, pz, [ax, az], [bx, bz]) => {
  const dx = bx - ax, dz = bz - az; const t = Math.max(0, Math.min(1, ((px - ax) * dx + (pz - az) * dz) / (dx * dx + dz * dz)));
  return Math.hypot(px - (ax + t * dx), pz - (az + t * dz));
};

/** Schematic heightfield (Phase 3 replaces this with the authored 0.5 m field). */
export function elevation(x, z) {
  let num = 0, den = 0;
  for (const [sx, sz, e] of spots) {
    const d2 = (x - sx) ** 2 + (z - sz) ** 2;
    if (d2 < 1) return carve(x, z, e);
    const w = 1 / (d2 * d2 ** 0.25); // IDW power 2.5
    num += w * e; den += w;
  }
  return carve(x, z, num / den);
}
function carve(x, z, base) {
  let e = base;
  // ravine
  let d = Infinity;
  for (let i = 0; i < ravine.creek.length - 1; i++) d = Math.min(d, segDist(x, z, ravine.creek[i], ravine.creek[i + 1]));
  e = Math.min(e, ravine.bed + (base - ravine.bed) * smooth(4, ravine.halfWidth, d));
  // stadium bowl
  const q = Math.hypot((x - bowl.cx) / bowl.rx, (z - bowl.cz) / bowl.rz);
  const r = Math.max(0, q - 1) * Math.min(bowl.rx, bowl.rz);
  e = Math.min(e, bowl.floor + (e - bowl.floor) * smooth(0, bowl.falloff, r));
  return e;
}
