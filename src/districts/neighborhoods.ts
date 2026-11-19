// Remaining districts (CLAUDE.md §9.3–§9.11): Rosemary Row, Residential North, Cameron Heights, ONSU
// campus halls (North/Founders' quads, east campus, south campus), Carrburg, Toadstool Hill. Every
// building is enterable with a full generated interior.
import { defaultFacade } from '../buildings/facades';
import { DISTRICT_GENERATORS } from '../world/districtRegistry';
import type { CityPlanBuilder } from '../world/cityPlan';
import type { BuildingSpec, FacadeSpec, PlanKind, Typology } from '../interiors/types';
import type { DistrictId } from '../world/layout';
import { alongRoad, rngFor, type LotCtx } from './common';
import { bizSpec, generateBusiness, type Biz } from './businesses';
import { centered } from '../buildings/landmarks/common';

let uid = 0;
const id = (p: string) => `${p}_${String(uid++).padStart(4, '0')}`;
const spec = (lot: LotCtx | { x: number; z: number; rotY: number; w: number; d: number }, p: { pre: string; district: DistrictId; floors: number; typology: Typology; plan: PlanKind; facade: FacadeSpec; basement?: boolean; attic?: boolean; name?: string; tags?: string[]; pub?: boolean; party?: BuildingSpec['party']; upperUse?: BuildingSpec['upperUse'] }): BuildingSpec => ({
  id: id(p.pre), name: p.name, district: p.district, x: lot.x, z: lot.z, rotY: lot.rotY, y: 0, w: lot.w, d: lot.d,
  floors: p.floors, basement: p.basement ?? false, attic: p.attic ?? false, typology: p.typology, plan: p.plan, facade: p.facade,
  seed: `${p.pre}-${uid}`, public: p.pub, tags: p.tags, party: p.party, upperUse: p.upperUse,
});

const SIDING = ['paint:SIDING_CREAM', 'paint:SIDING_SAGE', 'paint:SIDING_WHEAT', 'paint:SIDING_SLATE_BLUE'];

function house(b: CityPlanBuilder, lot: LotCtx, district: DistrictId, rng: ReturnType<typeof rngFor>, style: 'bungalow' | 'ranch' | 'stone' | 'stucco'): BuildingSpec {
  const fac = style === 'ranch'
    ? defaultFacade('house', { wall: 'brick:running:BRICK_DOWNTOWN_B', roof: 'hip', pitch: 24, shutters: 'satin:SHUTTER_BLACK' })
    : style === 'stone' ? defaultFacade('house', { wall: 'tex:fieldstone', roof: 'gable', pitch: 45, roofKey: 'tex:slate', shutters: null, doorStyle: 'colonial:DOOR_GREEN' })
      : style === 'stucco' ? defaultFacade('house', { wall: 'tex:stucco', roof: 'gable', pitch: 42, roofKey: 'tex:slate', shutters: 'satin:SHUTTER_GREEN', doorStyle: 'colonial:DOOR_BLACK' })
        : defaultFacade('house', { wall: rng.pick(SIDING), roof: rng.chance(0.2) ? 'gambrel' : 'gable', pitch: rng.int(30, 42), doorStyle: `colonial:${rng.pick(['DOOR_RED', 'DOOR_BLACK', 'DOOR_GREEN'])}` });
  return spec(lot, { pre: district === 'toadstool' ? 'TDH' : district === 'cameron_heights' ? 'CAM' : 'RES', district, floors: style === 'ranch' ? 1 : rng.chance(0.7) ? 2 : 1, typology: 'house', plan: 'center_hall', facade: fac, basement: rng.chance(0.4), attic: style !== 'ranch' && rng.chance(0.5) });
}

// ------------------------------------------------------------------------------------------ Rosemary Row (§9.3)
DISTRICT_GENERATORS.push({
  name: 'rosemary', order: 20,
  run: (b) => {
    const rng = rngFor('rosemary');
    // two 5-level parking decks (CONCRETE_NEW, LAMP_LED)
    for (const [x0, name] of [[-205, 'Rosemary Deck West'], [75, 'Rosemary Deck East']] as const) {
      const s = spec({ x: x0 + 70, z: -66, rotY: Math.PI, w: 7000, d: 3200 }, { pre: 'RRD', district: 'rosemary_row', floors: 5, typology: 'parking', plan: 'parking', facade: defaultFacade('parking'), name, pub: true });
      b.add(s, { check: false });
    }
    const used = new Set<string>();
    // north side: 4–5 storey apartment blocks over shops
    alongRoad(b, 'rosemary', -1, 4, 860, 0.05, () => rng.int(12, 20) * 100, () => rng.int(20, 26) * 100, (lot) => {
      const biz = rng.chance(0.25) ? { ...generateBusiness(rng, used), type: 'takeout' as const } : generateBusiness(rng, used);
      return bizSpec(biz, { id: id('RRN'), district: 'rosemary_row', x: lot.x, z: lot.z, rotY: lot.rotY, y: 0, w: lot.w, d: lot.d, floors: rng.int(4, 5), basement: false, attic: false, seed: `rrn-${lot.i}`, party: { left: true, right: true }, public: false }, defaultFacade('downtown_commercial', { wall: rng.pick(['brick:running:BRICK_DOWNTOWN_C', 'brick:common:BRICK_DOWNTOWN_A', 'brick:running:BRICK_DOWNTOWN_B']), cornice: 'box' }));
    }, 0.02);
    // south side: back-entrance buildings and late-night food stalls (single-room kiosks)
    alongRoad(b, 'rosemary', 1, 4, 860, 0.05, () => (rng.chance(0.4) ? 400 : rng.int(9, 14) * 100), () => 1400, (lot) => {
      if (lot.w <= 400) {
        const biz: Biz = { ...generateBusiness(rng, used), type: rng.pick(['takeout', 'tacos', 'pizza'] as const) };
        return bizSpec(biz, { id: id('RRK'), district: 'rosemary_row', x: lot.x, z: lot.z, rotY: lot.rotY, y: 0, w: 400, d: 500, floors: 1, basement: false, attic: false, seed: `rrk-${lot.i}`, public: false }, defaultFacade('retail', { wall: 'paint:STOREFRONT_TERRACOTTA', window: 'none', cornice: 'box', storefront: { bays: 1, entry: 'center' } }));
      }
      return bizSpec(generateBusiness(rng, used), { id: id('RRS'), district: 'rosemary_row', x: lot.x, z: lot.z, rotY: lot.rotY, y: 0, w: lot.w, d: lot.d, floors: 2, basement: false, attic: false, seed: `rrs-${lot.i}`, public: false }, defaultFacade('downtown_commercial', { wall: 'brick:common:BRICK_DOWNTOWN_C', cornice: 'box' }));
    }, 1.5);
  },
});

// ------------------------------------------------------------------------------------------ Residential North (§9.11)
DISTRICT_GENERATORS.push({
  name: 'residential_north', order: 30,
  run: (b) => {
    const rng = rngFor('resnorth');
    const lot = (l: LotCtx) => house(b, l, 'residential_north', rng, rng.chance(0.25) ? 'ranch' : 'bungalow');
    for (const r of ['pell', 'harrow']) for (const side of [1, -1] as const) alongRoad(b, r, side, 10, 900, rng.int(5, 8), () => rng.int(11, 14) * 100, () => rng.int(9, 11) * 100, lot, rng.int(5, 8));
    for (const r of ['vance', 'audley', 'chancel', 'henley']) for (const side of [1, -1] as const) alongRoad(b, r, side, 10, 240, rng.int(5, 8), () => rng.int(11, 13) * 100, () => rng.int(9, 11) * 100, lot, rng.int(5, 8));
    for (const side of [1, -1] as const) alongRoad(b, 'columbia_n', side, 0, 235, 6, () => 1200, () => 1000, lot, 6);
    alongRoad(b, 'millers_run', 1, 0, 300, 6, () => 1200, () => 1000, lot, 6);
  },
});

// ------------------------------------------------------------------------------------------ Cameron Heights (proposed in Phase 1)
DISTRICT_GENERATORS.push({
  name: 'cameron_heights', order: 31,
  run: (b) => {
    const rng = rngFor('cameron');
    // two churches on Glebe St
    for (const [s, name] of [[120, 'First Pamlico Chapel'], [330, 'Glebe Street Meeting House']] as const) {
      alongRoad(b, 'glebe', -1, s, s + 40, 6, () => 1600, () => 3000, (l) => spec(l, { pre: 'CHU', district: 'cameron_heights', floors: 1, typology: 'historic_academic', plan: 'open_core', facade: defaultFacade('historic_academic', { wall: 'brick:flemish:BRICK_CAMPUS_C', roof: 'gable', pitch: 48, window: 'arched', winH: 300, bay: 400, shutters: null, cornice: 'box' }), name, pub: true, tags: ['cupola', 'church'] }), 0);
    }
    const lot = (l: LotCtx) => house(b, l, 'cameron_heights', rng, rng.chance(0.15) ? 'stucco' : 'bungalow');
    for (const side of [1, -1] as const) alongRoad(b, 'glebe', side, 10, 470, rng.int(5, 7), () => rng.int(12, 14) * 100, () => rng.int(9, 11) * 100, lot, rng.int(4, 7));
    alongRoad(b, 'cameron', -1, 10, 470, 6, () => rng.int(12, 14) * 100, () => rng.int(9, 11) * 100, lot, 5);
    for (const side of [1, -1] as const) alongRoad(b, 'chancel', side, 330, 650, 6, () => 1200, () => 1000, lot, 5);
  },
});

// ------------------------------------------------------------------------------------------ ONSU campus halls (§9.4–§9.7)
DISTRICT_GENERATORS.push({
  name: 'campus', order: 15,
  run: (b) => {
    const rng = rngFor('campus');
    const hist = (lot: { x: number; z: number; rotY: number; w: number; d: number }, name: string, floors = 3, extra: Partial<FacadeSpec> = {}) =>
      b.add(spec(lot, { pre: 'ONSU', district: 'north_quad', floors, typology: 'historic_academic', plan: 'double_loaded', facade: defaultFacade('historic_academic', extra), basement: true, attic: rng.chance(0.5), name, pub: true }));
    const C = (cx: number, cz: number, rot: number, w: number, d: number) => centered({ n: 0, id: '', name: '', x: cx, z: cz, rotY: rot }, w, d, { id: '', district: 'north_quad', floors: 1, basement: false, attic: false, typology: 'house', plan: 'custom', facade: defaultFacade('house'), seed: '' });
    // North Quad: 3 historic academic halls facing the lawn
    hist(C(65, 80, -Math.PI / 2, 5000, 1600), 'Pettigrew Hall');
    hist(C(65, 178, -Math.PI / 2, 5400, 1600), 'Caldwell Annex');
    hist(C(275, 67, Math.PI / 2, 5000, 1600), 'Hooper Hall');
    // Founders' Quad: six halls in Flemish bond, three per side facing the lawn
    const names = ['Mangum Hall', 'Battle-Vance Hall', 'Saunders Hall', 'Gerrard Hall', 'Murphey Annex', 'Bynum Hall'];
    for (let i = 0; i < 3; i++) {
      hist(C(116, 412 + i * 63, -Math.PI / 2, 5400, 1700), names[i], rng.int(3, 4), { cornice: 'dentil', quoins: i === 1 });
      hist(C(266, 412 + i * 63, Math.PI / 2, 5400, 1700), names[i + 3], rng.int(3, 4), { cornice: 'dentil' });
    }
    // east campus filler: modern labs + historic halls between the quads and the ravine
    let k = 0;
    for (let z = 150; z < 620; z += 70) for (const x of [330, 395]) {
      const modern = (k++ % 3) === 0;
      const lot = C(x, z, x < 360 ? -Math.PI / 2 : Math.PI / 2, modern ? 4200 : 4600, modern ? 2400 : 1600);
      const s = spec(lot, modern
        ? { pre: 'ONSU', district: 'campus_generic', floors: rng.int(3, 5), typology: 'office_lab', plan: 'open_core', facade: defaultFacade('office_lab'), name: `${['Chemistry', 'Physics', 'Data Science', 'Marine Lab', 'Biology'][k % 5]} Building`, pub: true }
        : { pre: 'ONSU', district: 'campus_generic', floors: 3, typology: 'historic_academic', plan: 'double_loaded', facade: defaultFacade('historic_academic'), basement: true, name: `${['Venable', 'Phillips', 'Peabody', 'Swain', 'Howell', 'Carroll'][k % 6]} Hall`, pub: true });
      b.add(s);
    }
    // south campus: 4 high-rise residence halls (9–11 floors), recreation center, parking deck
    for (let i = 0; i < 4; i++) b.add(spec(C(121 + i * 26, 872, Math.PI / 2, 6400, 1500), { pre: 'ONSU', district: 'carillon_south', floors: 9 + (i % 3), typology: 'residence_highrise', plan: 'double_loaded', facade: defaultFacade('residence_highrise'), name: ['Hinson Tower', 'Ehring Tower', 'Craigmoor Tower', 'Morrisey Tower'][i], pub: true }));
    b.add(spec(C(-98, 866, Math.PI / 2, 7000, 5000), { pre: 'ONSU', district: 'carillon_south', floors: 2, typology: 'modern_academic', plan: 'open_core', facade: defaultFacade('modern_academic', { winW: 300, bay: 360 }), name: 'Recreation Center', pub: true }));
    b.add(spec(C(83, 912, Math.PI / 2, 6200, 3200), { pre: 'ONSU', district: 'carillon_south', floors: 4, typology: 'parking', plan: 'parking', facade: defaultFacade('parking'), name: 'South Campus Deck', pub: true }));
  },
});

// ------------------------------------------------------------------------------------------ Carrburg (§9.9)
DISTRICT_GENERATORS.push({
  name: 'carrburg', order: 40,
  run: (b) => {
    const rng = rngFor('carrburg');
    // Loomhouse Mill: converted brick textile mill, 3 floors, 140 m long, sawtooth roof, co-op market
    b.add(spec({ x: -665, z: -90, rotY: -Math.PI / 2, w: 14000, d: 3800 }, { pre: 'CBG', district: 'carrburg', floors: 3, typology: 'mill', plan: 'open_core', facade: defaultFacade('mill', { roof: 'flat', parapetH: 60 }), name: 'Loomhouse Mill (Co-op Market)', pub: true, tags: ['sawtooth', 'mill'] }), { check: false });
    // colorful one-storey storefronts along Hamilton St west
    const colors = ['paint:STOREFRONT_TERRACOTTA', 'paint:STOREFRONT_MUSTARD', 'paint:STOREFRONT_TEAL', 'paint:STOREFRONT_SAGE', 'paint:STOREFRONT_ROSE'];
    const used = new Set<string>();
    for (const side of [1, -1] as const) alongRoad(b, 'hamilton_w', side, 50, 380, 0.05, () => rng.int(8, 12) * 100, () => rng.int(14, 18) * 100, (lot) =>
      bizSpec(generateBusiness(rng, used), { id: id('CBG'), district: 'carrburg', x: lot.x, z: lot.z, rotY: lot.rotY, y: 0, w: lot.w, d: lot.d, floors: 1, basement: false, attic: false, seed: `cbg-${lot.i}`, public: false },
        defaultFacade('retail', { wall: colors[lot.i % colors.length], cornice: 'box', parapetH: 120 })), 0.6);
    // houses on Bobbin Rd
    for (const side of [1, -1] as const) alongRoad(b, 'bobbin', side, 200, 600, 6, () => rng.int(11, 13) * 100, () => 1000, (l) => house(b, l, 'carrburg', rng, 'bungalow'), 6);
  },
});

// ------------------------------------------------------------------------------------------ Toadstool Hill (§9.10)
DISTRICT_GENERATORS.push({
  name: 'toadstool', order: 50,
  run: (b) => {
    const rng = rngFor('toadstool');
    for (const side of [1, -1] as const) alongRoad(b, 'keep_lane', side, 6, 200, rng.int(6, 10), () => rng.int(11, 14) * 100, () => rng.int(10, 12) * 100, (l) => house(b, l, 'toadstool', rng, rng.chance(0.5) ? 'stone' : 'stucco'), rng.int(8, 14));
  },
});
