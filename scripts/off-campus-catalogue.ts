// Off Campus — business & place catalogue, generated from the Cathedral Mount map data.
// Reads data/buildings.json + data/rooms.json (the map is the source of truth for what exists and where)
// and joins each building to a gameplay profile (hours, jobs, wages, services, robbery risk).
// Outputs:
//   data/off-campus/businesses.json   every storefront business (241)
//   data/off-campus/places.json       campus, hospital, stadium, inn, decks, chapels, mill (non-retail)
//   data/off-campus/housing.json      rentable units: apartments above shops, houses, dorm rooms
//   docs/off-campus/BUSINESS-CATALOGUE.md  human-readable tables
// Rooms keep their roomId so the later furniture pass (existing furniture models) can fill itemSlots.
// Usage: npm run catalogue   (node --experimental-strip-types; no dependencies)
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';

type Room = { roomId: string; buildingId: string; floor: number; roomType: string; areaM2: number; itemSlots: unknown[] };
type Building = {
  id: string; name: string; district: string; tile: string; typology: string;
  transform: { x: number; y: number; z: number; rotY: number };
  floors: number; basement: boolean; business: { name: string; type: string } | null; rooms: number;
};

const buildings: Building[] = JSON.parse(readFileSync('data/buildings.json', 'utf8')).buildings;
const rooms: Room[] = JSON.parse(readFileSync('data/rooms.json', 'utf8')).rooms;
const roomsBy = new Map<string, Room[]>();
for (const r of rooms) (roomsBy.get(r.buildingId) ?? roomsBy.set(r.buildingId, []).get(r.buildingId)!).push(r);

// ---------------------------------------------------------------------------------------------
// Gameplay profiles. Hours are [open, close] in 24 h game time (close > 24 = past midnight).
// Wages are in-game dollars per hour. priceTier 1 = cheap … 3 = pricey. robbery: risk of being
// caught (police response, cameras, staff) and cash on hand — both 1 (low) … 3 (high).
// ---------------------------------------------------------------------------------------------
type Job = { role: string; wage: number; shift: 'day' | 'evening' | 'night' | 'any'; needs?: string };
type Profile = {
  category: 'food' | 'drink' | 'retail' | 'service' | 'entertainment' | 'finance' | 'health' | 'education';
  hours: [number, number]; priceTier: 1 | 2 | 3; services: string[]; jobs: Job[];
  robbery: { risk: 1 | 2 | 3; cash: 1 | 2 | 3 }; socialHub: boolean;
};

const P: Record<string, Profile> = {
  takeout:   { category: 'food', hours: [11, 27], priceTier: 1, services: ['buy meal', 'late-night food'], jobs: [{ role: 'line cook', wage: 13, shift: 'evening' }, { role: 'counter staff', wage: 12, shift: 'any' }, { role: 'delivery driver', wage: 11, shift: 'night', needs: 'bike or car' }], robbery: { risk: 1, cash: 1 }, socialHub: false },
  cafe:      { category: 'food', hours: [7, 20], priceTier: 2, services: ['buy coffee', 'study spot', 'meet up'], jobs: [{ role: 'barista', wage: 13, shift: 'day' }, { role: 'shift lead', wage: 16, shift: 'day', needs: '2 weeks as barista' }], robbery: { risk: 1, cash: 1 }, socialHub: true },
  clothing:  { category: 'retail', hours: [10, 20], priceTier: 2, services: ['buy clothes', 'change outfit'], jobs: [{ role: 'sales associate', wage: 13, shift: 'day' }, { role: 'stock clerk', wage: 12, shift: 'any' }], robbery: { risk: 2, cash: 1 }, socialHub: false },
  retail:    { category: 'retail', hours: [10, 20], priceTier: 2, services: ['buy goods', 'buy ONSU gear'], jobs: [{ role: 'sales associate', wage: 13, shift: 'day' }, { role: 'stock clerk', wage: 12, shift: 'any' }], robbery: { risk: 2, cash: 1 }, socialHub: false },
  bar:       { category: 'drink', hours: [16, 26], priceTier: 2, services: ['buy drinks', 'pool', 'meet people', 'game-day crowd'], jobs: [{ role: 'bartender', wage: 15, shift: 'night', needs: 'age 21+' }, { role: 'bouncer', wage: 16, shift: 'night' }, { role: 'barback', wage: 12, shift: 'night' }], robbery: { risk: 2, cash: 2 }, socialHub: true },
  brewpub:   { category: 'drink', hours: [11, 26], priceTier: 2, services: ['buy drinks', 'buy meal', 'rooftop deck', 'meet people'], jobs: [{ role: 'bartender', wage: 15, shift: 'evening', needs: 'age 21+' }, { role: 'server', wage: 12, shift: 'any' }, { role: 'brewer assistant', wage: 17, shift: 'day' }], robbery: { risk: 2, cash: 2 }, socialHub: true },
  tacos:     { category: 'food', hours: [11, 25], priceTier: 1, services: ['buy meal', 'patio'], jobs: [{ role: 'line cook', wage: 13, shift: 'any' }, { role: 'cashier', wage: 12, shift: 'any' }], robbery: { risk: 1, cash: 1 }, socialHub: false },
  gallery:   { category: 'retail', hours: [11, 18], priceTier: 3, services: ['view art', 'buy art', 'opening nights'], jobs: [{ role: 'gallery attendant', wage: 14, shift: 'day' }], robbery: { risk: 3, cash: 1 }, socialHub: false },
  salon:     { category: 'service', hours: [9, 19], priceTier: 2, services: ['haircut', 'change hairstyle'], jobs: [{ role: 'receptionist', wage: 12, shift: 'day' }, { role: 'stylist', wage: 18, shift: 'day', needs: 'cosmetology course' }], robbery: { risk: 1, cash: 1 }, socialHub: false },
  pizza:     { category: 'food', hours: [11, 26], priceTier: 1, services: ['buy meal', 'order delivery'], jobs: [{ role: 'pizza cook', wage: 13, shift: 'any' }, { role: 'delivery driver', wage: 11, shift: 'night', needs: 'bike or car' }], robbery: { risk: 1, cash: 1 }, socialHub: false },
  deli:      { category: 'food', hours: [8, 18], priceTier: 1, services: ['buy meal', 'buy groceries'], jobs: [{ role: 'deli clerk', wage: 12, shift: 'day' }], robbery: { risk: 1, cash: 1 }, socialHub: false },
  bakery:    { category: 'food', hours: [6, 16], priceTier: 1, services: ['buy food'], jobs: [{ role: 'baker', wage: 14, shift: 'night' }, { role: 'counter staff', wage: 12, shift: 'day' }], robbery: { risk: 1, cash: 1 }, socialHub: false },
  florist:   { category: 'retail', hours: [9, 18], priceTier: 2, services: ['buy flowers (relationship gift)'], jobs: [{ role: 'florist assistant', wage: 12, shift: 'day' }, { role: 'delivery driver', wage: 12, shift: 'day', needs: 'car' }], robbery: { risk: 1, cash: 1 }, socialHub: false },
  optics:    { category: 'health', hours: [9, 18], priceTier: 3, services: ['eye exam', 'buy glasses'], jobs: [{ role: 'optical assistant', wage: 15, shift: 'day' }], robbery: { risk: 2, cash: 1 }, socialHub: false },
  bookstore: { category: 'retail', hours: [9, 21], priceTier: 2, services: ['buy textbooks', 'buy books', 'study spot'], jobs: [{ role: 'bookseller', wage: 12, shift: 'any' }], robbery: { risk: 1, cash: 1 }, socialHub: true },
  bank:      { category: 'finance', hours: [9, 17], priceTier: 1, services: ['open account', 'deposit / withdraw', 'student loan', 'pay rent'], jobs: [{ role: 'teller', wage: 16, shift: 'day', needs: 'clean record' }, { role: 'security guard', wage: 17, shift: 'any', needs: 'clean record' }], robbery: { risk: 3, cash: 3 }, socialHub: false },
  diner:     { category: 'food', hours: [6, 22], priceTier: 1, services: ['buy meal', 'pharmacy'], jobs: [{ role: 'short-order cook', wage: 13, shift: 'any' }, { role: 'server', wage: 11, shift: 'any' }, { role: 'pharmacy tech', wage: 18, shift: 'day', needs: 'pharmacy course' }], robbery: { risk: 2, cash: 2 }, socialHub: true },
  cinema:    { category: 'entertainment', hours: [12, 25], priceTier: 2, services: ['watch movie (date activity)', 'concessions'], jobs: [{ role: 'usher', wage: 11, shift: 'evening' }, { role: 'projectionist', wage: 15, shift: 'evening' }], robbery: { risk: 2, cash: 2 }, socialHub: true },
  dental:    { category: 'health', hours: [8, 17], priceTier: 3, services: ['dental checkup'], jobs: [{ role: 'front desk', wage: 15, shift: 'day' }, { role: 'dental assistant', wage: 20, shift: 'day', needs: 'health science course' }], robbery: { risk: 2, cash: 1 }, socialHub: false },
  breakfast: { category: 'food', hours: [0, 24], priceTier: 1, services: ['buy meal', 'open 24 h'], jobs: [{ role: 'grill cook', wage: 13, shift: 'any' }, { role: 'server', wage: 11, shift: 'any' }], robbery: { risk: 1, cash: 2 }, socialHub: true },
  records:   { category: 'retail', hours: [11, 21], priceTier: 2, services: ['buy records', 'listening room'], jobs: [{ role: 'clerk', wage: 12, shift: 'any' }], robbery: { risk: 1, cash: 1 }, socialHub: true },
  hardware:  { category: 'retail', hours: [7, 19], priceTier: 2, services: ['buy tools', 'buy home supplies', 'copy keys'], jobs: [{ role: 'floor associate', wage: 13, shift: 'day' }], robbery: { risk: 2, cash: 1 }, socialHub: false },
  tutoring:  { category: 'education', hours: [14, 22], priceTier: 2, services: ['pay for tutoring (grade boost)'], jobs: [{ role: 'tutor', wage: 20, shift: 'evening', needs: 'B+ average in subject' }], robbery: { risk: 1, cash: 1 }, socialHub: false },
  tattoo:    { category: 'service', hours: [12, 23], priceTier: 3, services: ['get tattoo (appearance)'], jobs: [{ role: 'shop assistant', wage: 12, shift: 'any' }, { role: 'apprentice artist', wage: 15, shift: 'any', needs: 'art course' }], robbery: { risk: 1, cash: 2 }, socialHub: false },
};

// Non-retail places by typology (campus, hospital, etc.). Chapels are detected by id prefix.
type Place = { role: string; services: string[]; jobs: Job[]; hours: [number, number] };
const PLACE: Record<string, Place> = {
  historic_academic:  { role: 'school', services: ['attend class', 'office hours'], jobs: [{ role: 'research assistant', wage: 15, shift: 'day', needs: 'enrolled, B average' }, { role: 'custodian', wage: 14, shift: 'night' }], hours: [7, 22] },
  modern_academic:    { role: 'school', services: ['attend class', 'campus services'], jobs: [{ role: 'student worker', wage: 12, shift: 'any', needs: 'enrolled' }], hours: [7, 24] },
  office_lab:         { role: 'school', services: ['attend lab', 'research'], jobs: [{ role: 'lab assistant', wage: 16, shift: 'day', needs: 'enrolled in science' }], hours: [7, 22] },
  library:            { role: 'study', services: ['study (grade boost)', 'quiet meetups'], jobs: [{ role: 'library desk', wage: 12, shift: 'any', needs: 'enrolled' }], hours: [8, 26] },
  residence_historic: { role: 'housing', services: ['dorm room', 'RA'], jobs: [{ role: 'resident advisor', wage: 0, shift: 'any', needs: 'sophomore+; pays free room' }], hours: [0, 24] },
  residence_highrise: { role: 'housing', services: ['dorm room', 'RA'], jobs: [{ role: 'resident advisor', wage: 0, shift: 'any', needs: 'sophomore+; pays free room' }], hours: [0, 24] },
  hospital:           { role: 'health', services: ['treatment', 'respawn after knockout', 'medical bills'], jobs: [{ role: 'orderly', wage: 15, shift: 'any' }, { role: 'nurse', wage: 32, shift: 'any', needs: 'nursing degree' }, { role: 'doctor', wage: 70, shift: 'any', needs: 'medical degree' }], hours: [0, 24] },
  arena:              { role: 'events', services: ['game day', 'concerts', 'tailgates'], jobs: [{ role: 'concessions', wage: 12, shift: 'evening' }, { role: 'event security', wage: 15, shift: 'evening' }], hours: [10, 24] },
  parking:            { role: 'parking', services: ['park car', 'rent space'], jobs: [{ role: 'parking attendant', wage: 12, shift: 'any' }], hours: [0, 24] },
  inn:                { role: 'hotel', services: ['rent a night', 'restaurant', 'ballroom events'], jobs: [{ role: 'front desk', wage: 14, shift: 'any' }, { role: 'housekeeping', wage: 13, shift: 'day' }, { role: 'server', wage: 12, shift: 'evening' }], hours: [0, 24] },
  mill:               { role: 'market', services: ['buy groceries', 'farmers market'], jobs: [{ role: 'co-op clerk', wage: 13, shift: 'day' }], hours: [8, 21] },
  chapel:             { role: 'community', services: ['services', 'weddings', 'community events'], jobs: [], hours: [8, 20] },
};

// ---------------------------------------------------------------------------------------------
const pos = (b: Building) => ({ x: b.transform.x, y: b.transform.y, z: b.transform.z, rotY: b.transform.rotY });
const typeCounts = (rs: Room[]) => rs.reduce<Record<string, number>>((m, r) => ((m[r.roomType] = (m[r.roomType] ?? 0) + 1), m), {});
// One apartment = one apartment_living room (each unit has living + bed + kitchen + bath).
const apartmentsIn = (rs: Room[]) => rs.filter((r) => r.roomType === 'apartment_living').length;
// Rooms the player-facing business uses (ground floor + basement + any non-apartment upper rooms).
const APT = new Set(['apartment_living', 'apartment_bed', 'apartment_kitchen', 'apartment_bath', 'laundry']);

const businesses = buildings.filter((b) => b.business).map((b) => {
  const rs = roomsBy.get(b.id) ?? [];
  const prof = P[b.business!.type];
  if (!prof) throw new Error(`no gameplay profile for business type "${b.business!.type}" (${b.id})`);
  const bizRooms = rs.filter((r) => !APT.has(r.roomType));
  return {
    id: b.id, name: b.business!.name, type: b.business!.type, district: b.district, tile: b.tile,
    position: pos(b), floors: b.floors, basement: b.basement,
    ...prof,
    rooms: { total: rs.length, business: bizRooms.length, byType: typeCounts(bizRooms) },
    apartmentsAbove: apartmentsIn(rs),
    furnishRoomIds: bizRooms.filter((r) => !['stair', 'hall', 'elevator_lobby', 'mechanical'].includes(r.roomType)).map((r) => r.roomId),
  };
});

const places = buildings.filter((b) => !b.business && b.typology !== 'house').map((b) => {
  const key = b.id.startsWith('CHU_') ? 'chapel' : b.typology;
  const pl = PLACE[key];
  if (!pl) throw new Error(`no place profile for typology "${key}" (${b.id})`);
  const rs = roomsBy.get(b.id) ?? [];
  return {
    id: b.id, name: b.name, typology: b.typology, district: b.district, tile: b.tile, position: pos(b), floors: b.floors,
    ...pl, rooms: { total: rs.length, byType: typeCounts(rs) },
    classrooms: rs.filter((r) => ['classroom', 'lecture', 'auditorium'].includes(r.roomType)).length,
    dormRooms: rs.filter((r) => r.roomType.startsWith('dorm')).length,
  };
});

// Housing: apartments above shops (and the two residence towers on Hamilton), houses, dorms.
const RENT_BY_DISTRICT: Record<string, number> = { hamilton_strip: 1350, rosemary_row: 950, carrburg: 800, cameron_heights: 1500, residential_north: 1200, toadstool: 2600, battle_ravine: 1100 };
const housing = buildings.flatMap((b) => {
  const rs = roomsBy.get(b.id) ?? [];
  const base = RENT_BY_DISTRICT[b.district] ?? 1100;
  if (b.typology === 'house') {
    const beds = rs.filter((r) => /bed/.test(r.roomType)).length || 1;
    return [{ id: b.id, kind: 'house', building: b.name, district: b.district, position: pos(b), bedrooms: beds, rentPerMonth: Math.round((base + beds * 350) / 10) * 10, buyPrice: Math.round((base + beds * 350) * 180 / 1000) * 1000, rooms: rs.length }];
  }
  const apts = apartmentsIn(rs);
  if (apts > 0) return [{ id: b.id, kind: 'apartments', building: b.business?.name ?? b.name, district: b.district, position: pos(b), units: apts, rentPerMonth: base, buyPrice: null, rooms: rs.length }];
  const dorms = rs.filter((r) => r.roomType.startsWith('dorm')).length;
  if (dorms > 0) return [{ id: b.id, kind: 'dorm', building: b.name, district: b.district, position: pos(b), units: dorms, rentPerMonth: 0, buyPrice: null, rooms: rs.length, note: 'covered by housing fee when enrolled' }];
  return [];
});

mkdirSync('data/off-campus', { recursive: true });
mkdirSync('docs/off-campus', { recursive: true });
const meta = { generatedFrom: ['data/buildings.json', 'data/rooms.json'], seed: 1795 };
writeFileSync('data/off-campus/businesses.json', JSON.stringify({ ...meta, count: businesses.length, businesses }, null, 1));
writeFileSync('data/off-campus/places.json', JSON.stringify({ ...meta, count: places.length, places }, null, 1));
writeFileSync('data/off-campus/housing.json', JSON.stringify({ ...meta, count: housing.length, housing }, null, 1));

// ---------------------------------------------------------------------------------------------
// Markdown catalogue
// ---------------------------------------------------------------------------------------------
const DN: Record<string, string> = { hamilton_strip: 'Hamilton Strip', rosemary_row: 'Rosemary Row', carrburg: 'Carrburg', north_quad: 'North Quad', founders_quad: "Founders' Quad", quarry: 'The Quarry', carillon_south: 'Carillon Hill & South Campus', medical: 'Medical Center', cameron_heights: 'Cameron Heights', toadstool: 'Toadstool Hill', campus_generic: 'Campus (general)', residential_north: 'Residential North', battle_ravine: 'Battle Ravine' };
const hrs = ([o, c]: [number, number]) => (o === 0 && c === 24 ? '24 h' : `${o}:00–${c % 24}:00${c > 24 ? ' (+1)' : ''}`);
const ROSTER = new Set(['HAM_N_000', 'HAM_N_001', 'HAM_S_002', 'HAM_N_003', 'HAM_N_004', 'HAM_N_005', 'HAM_N_006', 'HAM_N_007', 'HAM_N_008', 'HAM_N_009', 'HAM_S_010', 'HAM_S_011', 'HAM_S_012', 'HAM_S_013', 'HAM_N_014', 'HAM_N_015', 'HAM_N_016', 'HAM_N_017']);
const L: string[] = [];
L.push('# Off Campus — Business & Place Catalogue', '');
L.push('_Generated by `scripts/off-campus-catalogue.ts` from the Cathedral Mount map (`data/buildings.json`, `data/rooms.json`). Do not edit by hand — edit the profiles in the script and re-run._', '');
const totalApts = housing.filter((h) => h.kind === 'apartments').reduce((s, h: any) => s + h.units, 0);
L.push('## Totals', '', '| What | Count |', '|---|---|');
L.push(`| Businesses | ${businesses.length} (${ROSTER.size} hand-authored roster + ${businesses.length - ROSTER.size} generated) |`);
L.push(`| Non-retail places (campus, hospital, venues, decks, chapels) | ${places.length} |`);
L.push(`| Houses | ${housing.filter((h) => h.kind === 'house').length} |`);
L.push(`| Apartments above shops | ${totalApts} units in ${housing.filter((h) => h.kind === 'apartments').length} buildings |`);
L.push(`| Dorm rooms | ${housing.filter((h) => h.kind === 'dorm').reduce((s, h: any) => s + h.units, 0)} |`);
L.push(`| Job positions (distinct role × location) | ${businesses.reduce((s, b) => s + b.jobs.length, 0) + places.reduce((s, p) => s + p.jobs.length, 0)} |`);
L.push(`| Business rooms waiting for furniture | ${businesses.reduce((s, b) => s + b.furnishRoomIds.length, 0)} |`, '');

L.push('## Business types', '', '| Type | Count | Hours | Price | Jobs (wage/h) | Robbery risk / cash | Social hub |', '|---|---|---|---|---|---|---|');
const byType = new Map<string, typeof businesses>();
for (const b of businesses) (byType.get(b.type) ?? byType.set(b.type, []).get(b.type)!).push(b);
for (const [t, bs] of [...byType].sort((a, b) => b[1].length - a[1].length)) {
  const p = P[t];
  L.push(`| ${t} | ${bs.length} | ${hrs(p.hours)} | ${'$'.repeat(p.priceTier)} | ${p.jobs.map((j) => `${j.role} $${j.wage}`).join(', ')} | ${p.robbery.risk} / ${p.robbery.cash} | ${p.socialHub ? 'yes' : ''} |`);
}
L.push('');

L.push('## Every business, by district', '');
L.push('★ = hand-authored roster business (CLAUDE.md §11). Position is the building origin in meters (x east, z south).', '');
for (const d of ['hamilton_strip', 'rosemary_row', 'carrburg']) {
  const bs = businesses.filter((b) => b.district === d).sort((a, b) => a.position.x - b.position.x);
  L.push(`### ${DN[d]} (${bs.length})`, '', '| ID | Name | Type | Floors | Apts above | Position (x, z) |', '|---|---|---|---|---|---|');
  for (const b of bs) L.push(`| ${b.id} | ${ROSTER.has(b.id) ? '★ ' : ''}${b.name} | ${b.type} | ${b.floors}${b.basement ? ' + B' : ''} | ${b.apartmentsAbove || ''} | ${b.position.x.toFixed(0)}, ${b.position.z.toFixed(0)} |`);
  L.push('');
}

L.push('## Places (non-retail)', '', '| ID | Name | District | Role | Floors | Classrooms | Dorm rooms | Jobs |', '|---|---|---|---|---|---|---|---|');
for (const p of [...places].sort((a, b) => a.role.localeCompare(b.role) || a.name.localeCompare(b.name)))
  L.push(`| ${p.id} | ${p.name} | ${DN[p.district] ?? p.district} | ${p.role} | ${p.floors} | ${p.classrooms || ''} | ${p.dormRooms || ''} | ${p.jobs.map((j) => j.role).join(', ')} |`);
L.push('');

L.push('## Housing by district', '', '| District | Houses | Apartment units | Base rent / month |', '|---|---|---|---|');
for (const d of Object.keys(DN)) {
  const hs = housing.filter((h) => h.district === d);
  if (!hs.length) continue;
  const houses = hs.filter((h) => h.kind === 'house').length;
  const apts = hs.filter((h) => h.kind === 'apartments').reduce((s, h: any) => s + h.units, 0);
  if (!houses && !apts) continue;
  L.push(`| ${DN[d]} | ${houses || ''} | ${apts || ''} | $${RENT_BY_DISTRICT[d] ?? 1100} |`);
}
L.push('');

// Data issues worth fixing in the map before the port.
const dupBiz = [...businesses.reduce((m, b) => m.set(b.name, (m.get(b.name) ?? 0) + 1), new Map<string, number>())].filter(([, n]) => n > 1);
const dupPlace = [...places.reduce((m, p) => m.set(p.name, (m.get(p.name) ?? 0) + 1), new Map<string, number>())].filter(([, n]) => n > 1);
L.push('## Map data issues found while cataloguing', '');
L.push(`- Duplicate business names: ${dupBiz.map(([n, c]) => `${n} ×${c}`).join(', ') || 'none'}.`);
L.push(`- Duplicate place names: ${dupPlace.map(([n, c]) => `${n} ×${c}`).join(', ') || 'none'}.`);
L.push('- Loomhouse Mill (Co-op Market) is a `place`, not a `business`, in buildings.json; it is catalogued as a market.');
L.push('');
writeFileSync('docs/off-campus/BUSINESS-CATALOGUE.md', L.join('\n'));

console.log(`businesses ${businesses.length}, places ${places.length}, housing entries ${housing.length} (${totalApts} apartment units)`);
