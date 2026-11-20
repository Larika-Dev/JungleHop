// Furniture pass for Cathedral Mount (CLAUDE.md §7.4 items pass).
// Reads data/rooms.json + data/buildings.json and the 100-model catalogue, lays out furniture in every
// room against its anchorWalls (or in rows for large rooms), and writes:
//   godot/furniture/data/furniture_catalog.json    per-model size, kind, actions, seat / bed points
//   godot/furniture/data/furniture_actions.json    every action id with label, minutes, need effects
//   godot/furniture/data/furniture_placements.json per building: transform + items (building-local)
//
// Every placed piece must be reachable by the player: a 10 cm occupancy grid per room (furniture
// inflated by the 30 cm player capsule radius) is flood-filled from the room's doors, and every piece
// needs at least one reachable approach cell in front of it (or around it for tables and islands).
// Pieces that would cut another piece off are not placed.
//
// Deterministic: seeded RNG (1795). Run: node scripts/furniture/build-furniture-data.mjs
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { ACTIONS, DEFS } from './furniture-defs.mjs';

const OUT = 'godot/furniture/data';
const catalog = JSON.parse(readFileSync('godot/furniture/source/catalog.json', 'utf8'));
const buildings = JSON.parse(readFileSync('data/buildings.json', 'utf8')).buildings;
const rooms = JSON.parse(readFileSync('data/rooms.json', 'utf8')).rooms;

const PLAYER_R = 0.3; // capsule radius
const APPROACH = 0.65; // depth of the approach zone in front of a piece
const r3 = (v) => Math.round(v * 1000) / 1000;

// ---------- seeded RNG
function mulberry32(a) {
  return () => {
    a |= 0; a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
let rand = mulberry32(1795);
const pick = (arr) => arr[Math.floor(rand() * arr.length)];
const chance = (p) => rand() < p;

// ---------- catalogue
const M = {};
for (const c of catalog) {
  const d = DEFS[c.id];
  if (!d) throw new Error(`no defs for model ${c.id}`);
  for (const a of d.actions) if (!ACTIONS[a]) throw new Error(`model ${c.id}: unknown action ${a}`);
  M[c.id] = { ...c, ...d, w: c.w_cm / 100, h: c.h_cm / 100, d: c.d_cm / 100 };
}

function seatPoints(m) {
  if (!m.seatH) return [];
  const n = m.seats;
  const usable = m.w * (n > 1 ? 0.8 : 0);
  const pts = [];
  for (let i = 0; i < n; i++) {
    const x = n > 1 ? -usable / 2 + (usable * (i + 0.5)) / n : 0;
    pts.push([r3(x), r3(m.seatH), r3(m.seatDz ?? 0.05)]);
  }
  return pts;
}
function bedPoints(m) {
  if (!m.bedH) return [];
  const hs = m.beds ?? [m.bedH];
  const n = m.w > 1.5 ? 2 : 1; // double beds sleep two side by side
  const pts = [];
  for (const h of hs) for (let i = 0; i < n; i++) pts.push([r3(n === 2 ? (i ? 0.38 : -0.38) : 0), r3(h), r3(-m.d / 2 + 0.3)]);
  return pts;
}

const catalogOut = catalog.map((c) => {
  const m = M[c.id];
  return {
    id: c.id, name: c.name, folder: c.folder, model: `res://furniture/models/${c.folder}.glb`,
    category: c.category, setting: c.setting, kind: m.kind, actions: m.actions,
    size_m: [r3(m.w), r3(m.h), r3(m.d)], mount_y: m.mountY ?? 0,
    seats: seatPoints(m), // local [x, seat height, z]; the sitter faces +Z
    beds: bedPoints(m), // local [x, mattress top, head z]; head toward -Z
    access: m.allSides ? 'all' : m.twoSided ? 'front_back' : 'front',
    light_y: m.light ?? null,
  };
});

// ---------- groups: a primary piece plus satellites in group-local metres (primary at origin, front +Z)
const P = (id, x = 0, z = 0, rot = 0, opt = {}) => ({ id, x, z, rot, ...opt });
const sz = (id, rot = 0) => { const m = M[id]; const q = Math.abs(Math.round(rot / (Math.PI / 2))) % 2; return q ? [m.d, m.w] : [m.w, m.d]; };

function group(id, sats = []) { return { items: [P(id), ...sats] }; }
function deskSet(desk, chair) {
  const D = M[desk], C = M[chair];
  return group(desk, [P(chair, 0, D.d / 2 + C.d / 2 - 0.2, Math.PI, { sat: 'chair' })]);
}
function tableSet(table, chair, perSide, ends = 0) {
  const T = M[table], C = M[chair];
  const sats = [];
  const span = T.w * 0.8;
  for (let i = 0; i < perSide; i++) {
    const x = perSide === 1 ? 0 : -span / 2 + (span * (i + 0.5)) / perSide;
    sats.push(P(chair, x, T.d / 2 + C.d / 2 - 0.18, Math.PI, { sat: 'chair' }));
    sats.push(P(chair, x, -(T.d / 2 + C.d / 2 - 0.18), 0, { sat: 'chair' }));
  }
  if (ends) {
    sats.push(P(chair, T.w / 2 + C.d / 2 - 0.15, 0, -Math.PI / 2, { sat: 'chair' }));
    sats.push(P(chair, -(T.w / 2 + C.d / 2 - 0.15), 0, Math.PI / 2, { sat: 'chair' }));
  }
  return group(table, sats);
}
function roundSet(table, chair, n) {
  const T = M[table], C = M[chair];
  const sats = [];
  const r = T.w / 2 + C.d / 2 - 0.15;
  for (let i = 0; i < n; i++) {
    const a = (i * 2 * Math.PI) / n; // chairs on the 4 axis points face the centre
    sats.push(P(chair, r3(Math.sin(a) * r), r3(Math.cos(a) * r), a + Math.PI, { sat: 'chair' }));
  }
  return group(table, sats);
}
function benchTable(table, benchId) {
  const T = M[table], B = M[benchId];
  return group(table, [P(benchId, 0, T.d / 2 + B.d / 2 - 0.05, Math.PI, { sat: 'chair' }), P(benchId, 0, -(T.d / 2 + B.d / 2 - 0.05), 0, { sat: 'chair' })]);
}
function bedSet(bedId, both) {
  const B = M[bedId], N = M[32];
  const z = -B.d / 2 + N.d / 2;
  const sats = [P(32, B.w / 2 + N.w / 2 + 0.03, z, 0, { optional: true })];
  if (both) sats.push(P(32, -(B.w / 2 + N.w / 2 + 0.03), z, 0, { optional: true }));
  return group(bedId, sats);
}
function kitchenRun() { return group(24, [P(25, 0, -M[24].d / 2 + M[25].d / 2, 0, { y: M[25].mountY, optional: true })]); }

// entry: { g: group | () => group, at: 'wall'|'center'|'grid', n, p, minArea, maxArea, opposite, front, max }
const W = (g, o = {}) => ({ g, at: 'wall', ...o });
const C = (g, o = {}) => ({ g, at: 'center', ...o });
const GR = (g, o = {}) => ({ g, at: 'grid', ...o });

function rulesFor(room, b) {
  const t = room.roomType, a = room.areaM2, typ = b.typology, biz = b.business?.type ?? null;
  const house = typ === 'house';
  switch (t) {
    case 'living': case 'apartment_living': return [
      W(group(a > 28 && chance(0.4) ? 13 : 1), { tag: 'sofa' }),
      W(group(6), { opposite: 'sofa' }),
      W(group(3), { p: 0.85 }), W(group(pick([10, 14])), { p: 0.5 }), W(group(7), { p: 0.8 }),
      W(group(8), { p: 0.8 }), W(group(12), { p: 0.6 }), W(group(5), { p: 0.4 }), W(group(9), { p: 0.3 }),
      W(group(15), { p: a > 40 ? 0.5 : 0.15 }), W(group(11), { p: 0.3 }),
      C(group(4)),
      ...(t === 'apartment_living' && a > 45 ? [C(tableSet(16, 17, 3)), W(group(21), { p: 0.6 })] : []),
    ];
    case 'bedroom': case 'apartment_bed': {
      const kid = house && chance(0.22), baby = house && !kid && chance(0.1);
      const bedId = kid ? pick([30, 31]) : a > 25 && chance(0.5) ? 29 : 28;
      return [
        W(bedSet(bedId, !kid), { front: 0.9, alt: [bedSet(28, false), bedSet(30, false), group(30)] }),
        ...(baby ? [W(group(37))] : []),
        W(group(chance(0.5) ? 35 : 34)), W(group(33), { p: 0.75 }), W(group(39), { p: 0.5 }),
        W(group(36), { p: kid ? 0 : 0.35 }), W(deskSet(45, 47), { p: kid ? 0.8 : 0.3 }),
        W(group(8), { p: 0.3 }), W(group(38), { p: 0.3 }), W(group(14), { p: 0.15 }),
      ];
    }
    case 'dorm_double': return [W(bedSet(30, false), { alt: [group(30)] }), W(bedSet(30, false), { alt: [group(30)] }), W(deskSet(45, 47)), W(deskSet(45, 47)), W(group(35)), W(group(35), { p: 0.7 }), W(group(50), { p: 0.4 })];
    case 'dorm_single': return [W(bedSet(30, false)), W(deskSet(45, 47)), W(group(35)), W(group(7), { p: 0.5 }), W(group(39), { p: 0.3 })];
    case 'guest_room': return [W(bedSet(a > 22 ? 29 : 28, true), { front: 0.9, alt: [bedSet(28, false), group(28), bedSet(30, false), group(30)] }), W(group(33)), W(group(3), { p: 0.6 }), W(group(8), { p: 0.5 }), W(group(40), { p: 0.5 }), W(deskSet(45, 17), { p: 0.4 })];
    case 'kitchen': case 'apartment_kitchen': {
      const commercial = !house && t === 'kitchen';
      return [
        ...Array.from({ length: commercial ? 8 : 4 }, () => W(kitchenRun(), { beside: true })),
        C(group(20), { minArea: commercial ? 0 : 14 }),
        ...(commercial ? [W(group(100)), W(group(100), { p: 0.5 })] : [W(group(26), { p: 0.4 })]),
        ...(!commercial ? [C(roundSet(27, 69, 2), { p: 0.6 })] : []),
        ...(house && chance(0.4) ? [W(group(19)), W(group(19))] : []),
      ];
    }
    case 'dining':
      if (house) return [C(tableSet(16, 17, 3)), W(group(21), { p: 0.7 }), W(group(23), { p: 0.5 })];
      return [W(group(67), { p: 0.6 }), W(group(70), { n: 6 }), GR(roundSet(27, 69, 2), { max: 40 })];
    case 'cafe': return [W(group(64)), W(group(61)), W(group(70), { n: 4 }), GR(roundSet(27, 69, 2), { max: 30 })];
    case 'bar': return [W(group(61)), W(group(70), { n: 6 }), W(group(19), { n: 4 }), GR(roundSet(27, 69, 2), { max: 30 })];
    case 'pool_room': return [W(group(70), { n: 2 }), W(group(19), { n: 4 }), C(roundSet(27, 69, 2))];
    case 'back_room': return [C(tableSet(16, 17, 3)), W(group(100))];
    case 'food_court': return [W(group(61), { n: 3 }), GR(roundSet(27, 69, 2), { max: 60 })];
    case 'study':
      if (typ === 'library') return [W(deskSet(74, 87), { n: 8, beside: true }), GR(tableSet(73, 87, 3), { max: 12 })];
      return [W(deskSet(chance(0.5) ? 46 : 45, 47)), W(group(7)), W(group(7), { p: 0.6 }), W(group(48), { p: 0.6 }), W(group(3), { p: 0.5 }), W(group(8), { p: 0.5 }), W(group(50), { p: 0.3 })];
    case 'office':
      if (a < 30) return [W(deskSet(pick([45, 46, 49]), 47)), W(group(98)), W(group(7), { p: 0.6 }), W(group(17), { p: 0.6 }), W(group(48), { p: 0.4 })];
      if (a < 80) return [W(deskSet(pick([46, 49]), 47), { n: 3 }), C(tableSet(96, 87, 4, 1), { p: 0.35 }), W(group(98), { n: 2 }), W(group(100)), W(group(99), { p: 0.4 })];
      return [W(group(97), { p: 0.5 }), W(group(98), { n: 3 }), W(group(100), { n: 2 }), GR(deskSet(pick([93, 49]), 47), { max: 40 })];
    case 'classroom':
      return [W(deskSet(78, 47), { tag: 'front', alt: [group(78)] }), W(group(91), { tag: 'front2', near: 'front' }), W(group(100), { p: 0.5 }),
        GR(chance(0.3) ? deskSet(86, 87) : group(77), { face: 'front', max: 40, aisle: 0.3, rowGap: 0.75 })];
    case 'lecture': return [W(group(76), { tag: 'front' }), W(group(91), { near: 'front' }), GR(group(75), { face: 'front', max: 80, aisle: 0.1, rowGap: 0.75 })];
    case 'retail_floor': return retailRules(biz, a);
    case 'stockroom': return [W(group(63), { n: 8, beside: true }), W(group(100), { n: 2 }), W(group(26)), W(group(80), { p: 0.3 })];
    case 'fitting_room': return [W(group(62), { n: 6, beside: true }), C(group(59)), W(group(39))];
    case 'restroom': return [W(group(41), { n: a > 15 ? 3 : 1, beside: true })];
    case 'bath': case 'apartment_bath': case 'guest_bath': return [W(group(41)), W(group(42), { p: 0.7 })];
    case 'hall':
      if (house) return [W(group(44), { p: 0.5 }), W(group(43), { p: 0.6 }), W(group(40), { p: 0.5 }), W(group(11), { p: 0.5 })];
      return [W(group(99), { p: a > 15 ? 0.6 : 0 }), W(group(60), { p: typ === 'library' ? 0.6 : 0.1 })];
    case 'lobby': return [W(group(97)), W(group(99), { n: 2 }), W(group(2), { p: 0.5 }), W(group(10), { p: 0.5 }), W(group(60), { p: 0.4 }), W(group(8), { p: 0.4 })];
    case 'elevator_lobby': return [W(group(99), { p: 0.4 })];
    case 'corridor': return [W(group(99), { p: 0.3 }), W(group(94), { p: typ === 'historic_academic' || typ === 'modern_academic' ? 0.6 : 0, n: 4, beside: true })];
    case 'ward': return [W(bedSet(30, false), { n: 4 }), W(group(87), { n: 2 }), W(group(100), { p: 0.6 })];
    case 'exam': return [W(bedSet(30, false)), W(deskSet(45, 47)), W(group(100)), W(group(41)), W(group(17))];
    case 'or': return [C(group(30)), W(group(88)), W(group(100), { n: 2 })];
    case 'operatory': return [C(group(30)), W(group(88)), W(group(41)), W(group(100))];
    case 'stacks': return [W(group(71), { n: 12, beside: true }), W(group(80), { n: 2 }), W(group(85)), W(group(84)), W(group(95), { p: 0.5 }), GR(group(72), { max: 40, aisle: 0.9 })];
    case 'reading_room': return [W(group(79)), W(group(81)), W(group(82), { n: 2 }), W(group(83)), W(group(71), { n: 6, beside: true }), GR(tableSet(73, 87, 3), { max: 16 })];
    case 'gallery': return typ === 'library'
      ? [W(group(15), { n: 3 }), W(group(82), { n: 2 }), W(group(99), { n: 2 }), C(group(66))]
      : [W(group(66), { n: 3 }), W(group(99)), C(group(66))];
    case 'storage': return [W(group(100), { n: 2 }), W(group(50)), W(group(7), { p: 0.5 }), W(group(38), { p: house ? 0.5 : 0 })];
    case 'attic': return [W(group(38), { p: 0.6 }), W(group(50), { p: 0.5 }), W(group(7), { p: 0.4 }), W(group(37), { p: 0.05 })];
    case 'cellar': return [W(group(100), { p: 0.7 }), W(group(50), { p: 0.6 }), W(group(63), { p: 0.4 })];
    case 'mechanical': return [W(group(100), { p: 0.5 })];
    case 'laundry': return [W(group(50)), W(group(42), { p: 0.5 }), W(group(24), { n: 2, beside: true })];
    case 'studio': return [W(group(91)), W(group(47), { p: 0.5 }), GR(deskSet(90, 89), { max: 12 })];
    case 'ballroom': return [GR(roundSet(18, 87, 4), { max: 30 })];
    case 'great_hall': return [GR(benchTable(16, 22), { max: 12 })];
    case 'suite': return [W(group(1), { n: 2 }), W(group(61)), C(group(4)), W(deskSet(93, 47))];
    case 'press_box': return [GR(deskSet(93, 47), { max: 24 }), W(group(61))];
    case 'concourse': return [W(group(99), { n: 6 })];
    case 'locker': return [W(group(94), { n: 12, beside: true }), GR(group(22), { max: 8 })];
    case 'vault': return [W(group(100), { n: 6, beside: true }), W(group(81), { n: 2 })];
    case 'banking_hall': return [W(group(97), { n: 2 }), W(group(99), { n: 2 }), C(group(67))];
    case 'reception': return [W(group(97)), W(group(99), { n: 2 }), W(group(60))];
    case 'listening_room': return [W(group(92)), W(group(1)), W(group(6)), W(group(7), { n: 2 })];
    case 'dressing': return [W(group(36)), W(group(39)), W(group(35))];
    case 'backstage': return [W(group(36)), W(group(39)), W(group(87), { n: 3 })];
    case 'projection': case 'brewhouse': return [W(group(100))];
    case 'deck': return [GR(roundSet(27, 69, 2), { max: 12 })];
    default: return []; // stair, parking, court, theater (raked), gym, bell rooms
  }
}

function retailRules(biz, a) {
  const counter = (id) => W(group(id), { tag: 'counter' });
  switch (biz) {
    case 'clothing': return [counter(64), W(group(62), { n: 2, beside: true }), W(group(39)), W(group(54), { n: 2 }), W(group(59), { p: 0.6 }), GR(group(55), { max: 10, aisle: 0.9 })];
    case 'bookstore': return [counter(64), W(group(63), { n: 10, beside: true }), W(group(60)), GR(group(56), { max: 6, aisle: 1 })];
    case 'records': return [counter(64), W(group(51), { n: 6, beside: true }), GR(group(68), { max: 8, aisle: 1 })];
    case 'florist': case 'bakery': return [counter(57), W(group(65), { n: 2 }), W(group(61)), GR(group(56), { max: 4, aisle: 1 })];
    case 'optics': return [counter(57), W(group(39), { n: 2 }), W(group(57)), W(group(99)), C(group(66))];
    case 'hardware': return [counter(53), W(group(58), { n: 8, beside: true }), GR(group(52), { max: 12, aisle: 1.1 })];
    case 'cafe': case 'takeout': case 'deli': case 'tacos': case 'pizza': case 'breakfast': case 'diner': case 'brewpub': case 'bar':
      return [counter(64), W(group(61), { n: 2 }), W(group(70), { n: 4 }), W(group(67), { p: 0.3 }), GR(roundSet(27, 69, 2), { max: 20 })];
    case 'dental': return [W(group(97)), W(group(99), { n: 2 }), W(group(60))];
    case 'tutoring': return [W(deskSet(78, 47)), W(group(91)), GR(tableSet(73, 87, 3), { max: 6 })];
    case 'bank': return [W(group(97), { n: 2 }), W(group(99), { n: 2 })];
    default: // general store / co-op market
      return [counter(53), W(group(53), { p: a > 200 ? 1 : 0 }), W(group(61), { n: 3, beside: true }), W(group(63), { n: 8, beside: true }), W(group(60), { p: 0.5 }), GR(group(52), { max: 30, aisle: 1.1 }), C(group(68), { p: 0.5 })];
  }
}

// ---------- geometry helpers (building-local, metres; rooms are axis-aligned)
const rotVec = (x, z, th) => [Math.cos(th) * x + Math.sin(th) * z, -Math.sin(th) * x + Math.cos(th) * z];
function itemBox(it, ox, oz, th) {
  const [x, z] = rotVec(it.x, it.z, th);
  const [w, d] = sz(it.id, th + it.rot);
  const cx = ox + x, cz = oz + z, m = M[it.id], y0 = it.y ?? m.mountY ?? 0;
  return { x0: cx - w / 2, x1: cx + w / 2, z0: cz - d / 2, z1: cz + d / 2, y0, y1: y0 + m.h, cx, cz, rot: th + it.rot, it };
}
const overlaps = (a, b, pad = 0) => a.x0 < b.x1 + pad && a.x1 > b.x0 - pad && a.z0 < b.z1 + pad && a.z1 > b.z0 - pad && a.y0 < b.y1 && a.y1 > b.y0;
function groupLocalFootprint(g) {
  let x0 = Infinity, x1 = -Infinity, z0 = Infinity, z1 = -Infinity;
  for (const it of g.items) { const b = itemBox(it, 0, 0, 0); x0 = Math.min(x0, b.x0); x1 = Math.max(x1, b.x1); z0 = Math.min(z0, b.z0); z1 = Math.max(z1, b.z1); }
  return { x0, x1, z0, z1 };
}
// Approach zones for one placed item (where a person stands to use it).
function accessZones(b) {
  const m = M[b.it.id];
  const zones = [];
  const dirs = b.it.sat === 'chair' ? [Math.PI, Math.PI / 2, -Math.PI / 2] // pulled-out chair: from behind or the side
    : m.allSides || m.kind === 'dining_table' || m.kind === 'table' || m.kind === 'conference_table' || (m.kind === 'counter' && b.it.id === 20) ? [0, Math.PI, Math.PI / 2, -Math.PI / 2]
    : m.twoSided ? [0, Math.PI] : m.kind === 'bed' || m.seatH ? [0, Math.PI / 2, -Math.PI / 2] : [0];
  for (const dth of dirs) {
    const th = b.rot + dth;
    const nx = Math.sin(th), nz = Math.cos(th);
    const hw = Math.abs(nx) > 0.5 ? (b.z1 - b.z0) / 2 : (b.x1 - b.x0) / 2;
    const hd = Math.abs(nx) > 0.5 ? (b.x1 - b.x0) / 2 : (b.z1 - b.z0) / 2;
    const cx = b.cx + nx * (hd + APPROACH / 2), cz = b.cz + nz * (hd + APPROACH / 2);
    const ex = Math.abs(nx) > 0.5 ? APPROACH / 2 : Math.max(hw, 0.3), ez = Math.abs(nx) > 0.5 ? Math.max(hw, 0.3) : APPROACH / 2;
    zones.push({ x0: cx - ex, x1: cx + ex, z0: cz - ez, z1: cz + ez });
  }
  return zones;
}

// ---------- reachability grid
class RoomGrid {
  constructor(room) {
    const [x0, z0, x1, z1] = room.rect;
    this.x0 = x0; this.z0 = z0;
    this.cell = room.areaM2 > 150 ? 0.2 : 0.1;
    this.nx = Math.max(1, Math.ceil((x1 - x0) / this.cell)); this.nz = Math.max(1, Math.ceil((z1 - z0) / this.cell));
    this.room = room;
    this.seeds = [];
    for (const o of room.openings) if (o.type === 'door') this.seeds.push([o.position[0], o.position[2]]);
  }
  idx(x, z) { const i = Math.floor((x - this.x0) / this.cell), k = Math.floor((z - this.z0) / this.cell); return i < 0 || k < 0 || i >= this.nx || k >= this.nz ? -1 : k * this.nx + i; }
  // returns reach mask (1 = a standing player can get here) given placed boxes
  flood(boxes) {
    const { nx, nz, cell } = this;
    const blocked = new Uint8Array(nx * nz);
    const wallPad = Math.ceil(PLAYER_R / cell) - 1; // standing cells keep the capsule off the walls
    for (let k = 0; k < nz; k++) for (let i = 0; i < nx; i++) if (i < wallPad || k < wallPad || i >= nx - wallPad || k >= nz - wallPad) blocked[k * nx + i] = 1;
    for (const b of boxes) {
      if (b.y0 > 1.6) continue; // wall-hung above head height
      const i0 = Math.max(0, Math.floor((b.x0 - PLAYER_R - this.x0) / cell)), i1 = Math.min(nx - 1, Math.floor((b.x1 + PLAYER_R - this.x0) / cell));
      const k0 = Math.max(0, Math.floor((b.z0 - PLAYER_R - this.z0) / cell)), k1 = Math.min(nz - 1, Math.floor((b.z1 + PLAYER_R - this.z0) / cell));
      for (let k = k0; k <= k1; k++) for (let i = i0; i <= i1; i++) blocked[k * nx + i] = 1;
    }
    const reach = new Uint8Array(nx * nz);
    const q = new Int32Array(nx * nz); let h = 0, t = 0;
    const push = (j) => { if (j >= 0 && !blocked[j] && !reach[j]) { reach[j] = 1; q[t++] = j; } };
    if (this.seeds.length) {
      for (const [sx, sz2] of this.seeds) {
        // the door sits on the room edge: seed every free cell within 0.7 m of it
        for (let dz = -0.7; dz <= 0.7; dz += cell) for (let dx = -0.7; dx <= 0.7; dx += cell) push(this.idx(sx + dx, sz2 + dz));
      }
    } else {
      // no door in metadata (attics, some suites reached by stairs): use the biggest open region
      let best = -1, bestN = 0; const seen = new Uint8Array(nx * nz);
      for (let j = 0; j < nx * nz; j++) {
        if (blocked[j] || seen[j]) continue;
        let n = 0; const st = [j]; seen[j] = 1;
        while (st.length) { const c = st.pop(); n++; const ci = c % nx; for (const nb of [c - 1, c + 1, c - nx, c + nx]) { if (nb < 0 || nb >= nx * nz || seen[nb] || blocked[nb]) continue; if ((nb === c - 1 && ci === 0) || (nb === c + 1 && ci === nx - 1)) continue; seen[nb] = 1; st.push(nb); } }
        if (n > bestN) { bestN = n; best = j; }
      }
      push(best);
    }
    while (h < t) {
      const c = q[h++], ci = c % nx;
      if (ci > 0) push(c - 1); if (ci < nx - 1) push(c + 1);
      push(c - nx); if (c + nx < nx * nz) push(c + nx);
    }
    return reach;
  }
  zoneReachable(reach, z) {
    for (let x = z.x0 + this.cell / 2; x < z.x1; x += this.cell) for (let zz = z.z0 + this.cell / 2; zz < z.z1; zz += this.cell) { const j = this.idx(x, zz); if (j >= 0 && reach[j]) return true; }
    return false;
  }
  // pieces nobody can walk up to; a table with chairs counts as reached when one of its chairs is
  unreachable(boxes) {
    const reach = this.flood(boxes);
    const ok = new Map(boxes.map((b) => [b, accessZones(b).some((z) => this.zoneReachable(reach, z))]));
    const chairOk = new Set(boxes.filter((b) => b.it.sat === 'chair' && ok.get(b)).map((b) => b.gid));
    return boxes.filter((b) => !ok.get(b) && !(b.primary && chairOk.has(b.gid)));
  }
  allReachable(boxes) { return this.unreachable(boxes).length === 0; }
}

// ---------- layout of one room
function layoutRoom(room, b) {
  const rules = rulesFor(room, b);
  if (!rules.length) return [];
  const [rx0, rz0, rx1, rz1] = room.rect;
  const inside = (bx) => bx.x0 >= rx0 + 0.02 && bx.x1 <= rx1 - 0.02 && bx.z0 >= rz0 + 0.02 && bx.z1 <= rz1 - 0.02;
  const ceiling = room.ceilingCm / 100;
  // keep each doorway and its swing clear: half-width + 15 cm along the wall, 95 cm into the room
  const doorZones = room.openings.filter((o) => o.type === 'door').map((o) => {
    const [px, , pz] = o.position, hw = o.widthCm / 200 + 0.15, depth = 0.95;
    const dx = Math.min(Math.abs(px - rx0), Math.abs(px - rx1)), dz = Math.min(Math.abs(pz - rz0), Math.abs(pz - rz1));
    const onX = dx < dz; // door sits on a west/east edge
    return onX ? { x0: px - depth, x1: px + depth, z0: pz - hw, z1: pz + hw, y0: -1, y1: 9 } : { x0: px - hw, x1: px + hw, z0: pz - depth, z1: pz + depth, y0: -1, y1: 9 };
  });
  const winZones = room.openings.filter((o) => o.type === 'window').map((o) => { const h = o.widthCm / 200; return { x0: o.position[0] - h, x1: o.position[0] + h, z0: o.position[2] - h, z1: o.position[2] + h, y0: 1.0, y1: 9 }; });
  const grid = new RoomGrid(room);
  const placed = []; // boxes
  const tags = {};

  const walls = room.anchorWalls.map((w) => {
    const ux = w.end[0] - w.start[0], uz = w.end[2] - w.start[2], L = Math.hypot(ux, uz);
    return { ...w, L, u: [ux / L, uz / L], th: Math.atan2(w.normal[0], w.normal[2]) };
  }).filter((w) => w.L >= 0.4);

  const fits = (boxes) => boxes.every((bx) => inside(bx) && bx.y1 <= ceiling - 0.05 && !placed.some((p) => overlaps(bx, p, 0.03)) && !doorZones.some((z) => overlaps(bx, z)) && (bx.y1 < 1.2 || !winZones.some((z) => overlaps(bx, z))));
  let gidSeq = 0;
  const boxesAt = (g, ox, oz, th) => { const gid = ++gidSeq; return g.items.map((it, i) => Object.assign(itemBox(it, ox, oz, th), { gid, primary: i === 0 })); };
  const tryCommit = (boxes) => {
    if (!fits(boxes)) return false;
    if (!grid.allReachable([...placed, ...boxes])) return false;
    placed.push(...boxes);
    return true;
  };
  const stripOptional = (g) => ({ items: g.items.filter((it) => !it.optional) });

  function placeWall(rule, g) {
    const fp = groupLocalFootprint(g);
    let order = walls.slice();
    for (let i = order.length - 1; i > 0; i--) { const j = Math.floor(rand() * (i + 1)); [order[i], order[j]] = [order[j], order[i]]; }
    if (rule.opposite && tags[rule.opposite]) { const n = tags[rule.opposite].n; order.sort((a, c) => (a.normal[0] * n[0] + a.normal[2] * n[2]) - (c.normal[0] * n[0] + c.normal[2] * n[2])); }
    if (rule.near && tags[rule.near]) { const n = tags[rule.near].n; order.sort((a, c) => -((a.normal[0] * n[0] + a.normal[2] * n[2]) - (c.normal[0] * n[0] + c.normal[2] * n[2]))); }
    if (rule.beside && placeWall.last) { const lw = placeWall.last; order.sort((a, c) => (c === lw) - (a === lw)); }
    const front = rule.front ?? 0;
    for (const w of order) {
      const th = w.th;
      const lx = [Math.cos(th), -Math.sin(th)]; // group-local +X in building-local
      const sgn = lx[0] * w.u[0] + lx[1] * w.u[1] > 0 ? 1 : -1;
      const a0 = sgn > 0 ? fp.x0 : -fp.x1, a1 = sgn > 0 ? fp.x1 : -fp.x0; // along-wall extent relative to origin
      const off = -fp.z0 + 0.02; // back of group against the wall
      const steps = [];
      for (let s = -a0; s + a1 <= w.L + 1e-6; s += 0.1) steps.push(s);
      if (rand() < 0.5) steps.reverse();
      let tries = 0;
      for (const s of steps) {
        const ox = w.start[0] + w.u[0] * s + w.normal[0] * off, oz = w.start[2] + w.u[1] * s + w.normal[2] * off;
        const boxes = boxesAt(g, ox, oz, th);
        if (front) { // keep a walkway in front (beds)
          const b0 = boxes[0], nx = w.normal[0], nz = w.normal[2];
          const fz = {
            x0: nx > 0 ? b0.x1 : nx < 0 ? b0.x0 - front : b0.x0, x1: nx > 0 ? b0.x1 + front : nx < 0 ? b0.x0 : b0.x1,
            z0: nz > 0 ? b0.z1 : nz < 0 ? b0.z0 - front : b0.z0, z1: nz > 0 ? b0.z1 + front : nz < 0 ? b0.z0 : b0.z1, y0: -1, y1: 9,
          };
          if (placed.some((p) => overlaps(fz, p))) continue;
        }
        if (!fits(boxes)) continue;
        if (++tries > 6) break;
        if (tryCommit(boxes)) { placeWall.last = w; if (rule.tag) tags[rule.tag] = { n: w.normal, th }; return boxes; }
      }
    }
    return null;
  }
  function placeCenter(rule, g) {
    const fp = groupLocalFootprint(g);
    const cx = (rx0 + rx1) / 2, cz = (rz0 + rz1) / 2;
    const long = rx1 - rx0 >= rz1 - rz0;
    const ths = long ? [0, Math.PI] : [Math.PI / 2, -Math.PI / 2];
    const cands = [];
    for (let dx = -2; dx <= 2; dx += 0.25) for (let dz = -2; dz <= 2; dz += 0.25) cands.push([dx, dz]);
    cands.sort((p, q) => Math.hypot(...p) - Math.hypot(...q));
    let tries = 0;
    for (const [dx, dz] of cands) for (const th of ths) {
      const ocx = (fp.x0 + fp.x1) / 2, ocz = (fp.z0 + fp.z1) / 2;
      const [rx, rz] = rotVec(ocx, ocz, th);
      const boxes = boxesAt(g, cx + dx - rx, cz + dz - rz, th);
      if (!fits(boxes)) continue;
      if (++tries > 8) return null;
      if (tryCommit(boxes)) return boxes;
    }
    return null;
  }
  function placeGrid(rule, g) {
    let th = 0;
    if (rule.face && tags[rule.face]) th = tags[rule.face].th + Math.PI; // rows look at the front wall
    else th = rx1 - rx0 >= rz1 - rz0 ? Math.PI / 2 : 0;
    const fp = groupLocalFootprint(g);
    // aisle: gap between pieces in a row (along the piece's local X); rowGap: between rows (local Z)
    const aisle = rule.aisle ?? 0.8, rowGap = rule.rowGap ?? Math.max(aisle, 0.8);
    const swap = Math.abs(Math.sin(th)) > 0.5;
    const [w, d] = swap ? [fp.z1 - fp.z0, fp.x1 - fp.x0] : [fp.x1 - fp.x0, fp.z1 - fp.z0];
    const gx = swap ? rowGap : aisle, gz = swap ? aisle : rowGap;
    const sx = w + gx, sz2 = d + gz;
    const m = 1.0; // keep the perimeter free as a walkway
    const ax0 = rx0 + m, ax1 = rx1 - m, az0 = rz0 + m, az1 = rz1 - m;
    const nxc = Math.floor((ax1 - ax0 + gx) / sx), nzc = Math.floor((az1 - az0 + gz) / sz2);
    if (nxc < 1 || nzc < 1) return null;
    const offx = ax0 + (ax1 - ax0 - (nxc * sx - gx)) / 2 + w / 2, offz = az0 + (az1 - az0 - (nzc * sz2 - gz)) / 2 + d / 2;
    const added = [];
    const ocx = (fp.x0 + fp.x1) / 2, ocz = (fp.z0 + fp.z1) / 2;
    const [rcx, rcz] = rotVec(ocx, ocz, th);
    for (let k = 0; k < nzc; k++) for (let i = 0; i < nxc; i++) {
      if (added.length >= (rule.max ?? 50) * g.items.length) break;
      const boxes = boxesAt(g, offx + i * sx - rcx, offz + k * sz2 - rcz, th);
      if (!fits(boxes)) continue;
      placed.push(...boxes); added.push(...boxes);
    }
    // prune anything the rows cut off (removing only ever frees space)
    for (let guard = 0; guard < 50 && added.length; guard++) {
      const bad = grid.unreachable(placed);
      if (!bad.length) break;
      // drop the whole row group owning an unreachable piece (grid pieces only; removing only frees space)
      const gids = new Set(bad.filter((x) => added.includes(x)).map((x) => x.gid));
      if (!gids.size) break;
      const drop = added.filter((x) => gids.has(x.gid));
      for (const x of drop) { placed.splice(placed.indexOf(x), 1); added.splice(added.indexOf(x), 1); }
    }
    return added;
  }

  for (const rule of rules) {
    if (rule.p !== undefined && !chance(rule.p)) continue;
    if (rule.minArea && room.areaM2 < rule.minArea) continue;
    const n = rule.n ?? 1;
    for (let k = 0; k < n; k++) {
      const g = typeof rule.g === 'function' ? rule.g() : rule.g;
      let res = null;
      if (rule.at === 'wall') res = placeWall(rule, g) ?? (g.items.some((i) => i.optional) ? placeWall(rule, stripOptional(g)) : null);
      else if (rule.at === 'center') res = placeCenter(rule, g) ?? (g.items.some((i) => i.optional) ? placeCenter(rule, stripOptional(g)) : null);
      else res = placeGrid(rule, g);
      for (const alt of res || rule.at === 'grid' ? [] : rule.alt ?? []) {
        res = rule.at === 'wall' ? placeWall(rule, alt) : placeCenter(rule, alt);
        if (res) break;
      }
      if (!res && rule.at !== 'grid') break;
    }
  }
  placeWall.last = null;
  return placed;
}

// ---------- run
const byBuilding = new Map(buildings.map((b) => [b.id, b]));
const out = {};
let total = 0, roomsFurnished = 0;
const perModel = new Map();
const perType = new Map();
for (const room of rooms) {
  const b = byBuilding.get(room.buildingId);
  rand = mulberry32(hash(room.roomId) ^ 1795);
  const boxes = layoutRoom(room, b);
  if (!boxes.length) continue;
  roomsFurnished++;
  let e = out[b.id];
  if (!e) { const t = b.transform; e = out[b.id] = { t: [t.x, t.y, t.z, t.rotY], rooms: [], items: [] }; }
  const ri = e.rooms.length;
  e.rooms.push(room.roomId);
  for (const bx of boxes) {
    let rot = Math.atan2(Math.sin(bx.rot), Math.cos(bx.rot));
    e.items.push([bx.it.id, r3(bx.cx), r3(room.y + bx.y0), r3(bx.cz), r3(rot), ri]);
    perModel.set(bx.it.id, (perModel.get(bx.it.id) ?? 0) + 1);
    total++;
  }
  perType.set(room.roomType, (perType.get(room.roomType) ?? 0) + boxes.length);
}
function hash(s) { let h = 2166136261; for (let i = 0; i < s.length; i++) { h ^= s.charCodeAt(i); h = Math.imul(h, 16777619); } return h >>> 0; }

mkdirSync(OUT, { recursive: true });
writeFileSync(`${OUT}/furniture_catalog.json`, JSON.stringify({ units: 'metres; model front +Z, origin at floor centre', models: catalogOut }, null, 1));
writeFileSync(`${OUT}/furniture_actions.json`, JSON.stringify({ note: 'needs: change per use, or per game hour when perHour', actions: ACTIONS }, null, 1));
writeFileSync(`${OUT}/furniture_placements.json`, JSON.stringify({
  seed: 1795, format: 'items: [modelId, x, y, z, rotY, roomIndex], building-local metres; world = R_y(t[3]) * local + t[0..2]',
  count: total, buildings: out,
}));
const unused = catalog.filter((c) => !perModel.has(c.id)).map((c) => c.id);
console.log(`placed ${total} pieces in ${roomsFurnished}/${rooms.length} rooms across ${Object.keys(out).length} buildings; models unused: ${unused.join(',') || 'none'}`);
console.log([...perType].sort((a, c) => c[1] - a[1]).slice(0, 25).map(([k, v]) => `${k}:${v}`).join(' '));
