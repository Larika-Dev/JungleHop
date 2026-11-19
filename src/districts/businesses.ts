// Hamilton Strip businesses (CLAUDE.md §11): the named roster with exact facade/awning/sign colors, a
// parody-name generator for every other storefront (palette-only colors, typed interiors), and the
// per-type interior built-ins (counters, oven alcove, teller line + vault, raked auditoriums...).
import { C, boxC } from '../kits/common';
import { customPlan, generatePlan } from '../interiors/floorplan';
import { finishFor } from '../interiors/finishes';
import { LANDMARK_HOOKS } from '../buildings/manager';
import { Rng } from '../core/rng';
import type { PaletteKey } from '../core/palette';
import type { BuildingSpec, FacadeSpec, Plan, RoomType, Typology } from '../interiors/types';

export type BizType = 'diner' | 'brewpub' | 'cinema' | 'cafe' | 'retail' | 'bookstore' | 'pizza' | 'bar' | 'breakfast' | 'takeout' | 'records' | 'bank' | 'dental' | 'hardware' | 'clothing' | 'tacos' | 'tutoring' | 'tattoo' | 'deli' | 'optics' | 'salon' | 'bakery' | 'florist' | 'gallery';
export interface Biz {
  name: string; type: BizType; real?: string;
  facade: string; // wall material key (brick:… or paint:…)
  awning?: PaletteKey | null; stripe?: PaletteKey; sign: PaletteKey; signBg: PaletteKey; door?: PaletteKey;
  floors?: number; width?: number; depth?: number; upstairs?: boolean; neon?: PaletteKey[];
}

// §11 roster — exact colors (palette keys). real = inspiration (parody-names.json only).
export const ROSTER: Biz[] = [
  { name: "Sutter's Pharmacy & Grill", type: 'diner', real: "Sutton's Drug Store", facade: 'brick:running:BRICK_DOWNTOWN_A', awning: 'AWNING_HARBOR_BLUE', sign: 'MARKING_WHITE', signBg: 'AWNING_HARBOR_BLUE' },
  { name: 'Top of the Mount', type: 'brewpub', real: 'Top of the Hill', facade: 'brick:running:BRICK_DOWNTOWN_C', awning: null, sign: 'BRASS_WORN', signBg: 'DOOR_BLACK', floors: 2, width: 1700 },
  { name: 'Junior Varsity Cinema', type: 'cinema', real: 'Varsity Theatre', facade: 'paint:CINEMA_MAROON', awning: null, sign: 'MARQUEE_BULB', signBg: 'DOOR_BLACK', floors: 2, width: 1800, depth: 3200 },
  { name: 'Pamlico Coffee House', type: 'cafe', real: 'Carolina Coffee Shop', facade: 'brick:running:BRICK_DOWNTOWN_B', awning: 'AWNING_COFFEE', sign: 'SIGN_CREAM', signBg: 'AWNING_COFFEE' },
  { name: 'Old North Outfitters', type: 'retail', real: 'campus spirit shops', facade: 'paint:HEAVEN_BLUE', awning: 'ONSU_NAVY', sign: 'ONSU_NAVY', signBg: 'ONSU_WHITE' },
  { name: 'Tarry Page Books', type: 'bookstore', real: 'Bull’s Head Bookshop', facade: 'paint:SHUTTER_GREEN', awning: null, sign: 'SIGN_CREAM', signBg: 'SHUTTER_GREEN' },
  { name: 'Mount Pizza Co.', type: 'pizza', real: 'downtown slice shops', facade: 'brick:running:BRICK_DOWNTOWN_A:painted', awning: 'CURB_PAINT_RED', sign: 'MARKING_WHITE', signBg: 'CURB_PAINT_RED' },
  { name: 'The Grinding Stone', type: 'bar', real: "He's Not Here", facade: 'brick:running:BRICK_DOWNTOWN_C', awning: null, sign: 'NEON_PINK', signBg: 'PAINT_BAR_DARK', neon: ['NEON_PINK', 'NEON_BLUE'] },
  { name: 'Ye Olde Waffle Hutch', type: 'breakfast', real: 'Ye Olde Waffle Shoppe', facade: 'paint:STOREFRONT_MUSTARD', awning: 'CINEMA_MAROON', sign: 'CINEMA_MAROON', signBg: 'STOREFRONT_MUSTARD' },
  { name: 'Late Night Lo Mein', type: 'takeout', real: 'late-night noodle counters', facade: 'paint:CURB_PAINT_RED', awning: null, sign: 'MARKING_YELLOW', signBg: 'CURB_PAINT_RED' },
  { name: 'Hamilton Records', type: 'records', real: 'Schoolkids Records', facade: 'paint:PAINT_BAR_DARK', awning: null, sign: 'NEON_PINK', signBg: 'PAINT_BAR_DARK' },
  { name: 'Bluebird Savings Bank', type: 'bank', real: 'corner banks of Franklin St', facade: 'tex:limestone', awning: null, sign: 'ONSU_NAVY', signBg: 'LIMESTONE_TRIM', floors: 3, width: 1800 },
  { name: 'Jolly Molar Dental', type: 'dental', real: 'upstairs dental offices', facade: 'brick:running:BRICK_DOWNTOWN_B', awning: null, sign: 'DOOR_RED', signBg: 'TRIM_WHITE', door: 'DOOR_RED', upstairs: true },
  { name: 'Hilltop Hardware', type: 'hardware', real: 'Chapel Hill hardware stores', facade: 'brick:running:BRICK_DOWNTOWN_A', awning: 'SHUTTER_GREEN', sign: 'MARKING_WHITE', signBg: 'SHUTTER_GREEN', depth: 2800 },
  { name: 'Linen & Lamb', type: 'clothing', real: 'Franklin St boutiques', facade: 'brick:running:BRICK_DOWNTOWN_A:painted', awning: 'AWNING_LINEN', sign: 'WALNUT_DARK', signBg: 'AWNING_LINEN' },
  { name: 'Cosmic Carnitas', type: 'tacos', real: 'Cosmic Cantina', facade: 'paint:STOREFRONT_TEAL', awning: null, sign: 'MARKING_YELLOW', signBg: 'STOREFRONT_TEAL' },
  { name: 'Cram Fortress Tutoring', type: 'tutoring', real: 'upstairs test-prep offices', facade: 'brick:running:BRICK_DOWNTOWN_C', awning: null, sign: 'ONSU_NAVY', signBg: 'TRIM_WHITE', door: 'ONSU_NAVY', upstairs: true },
  { name: 'Pitch Soles Tattoo', type: 'tattoo', real: 'downtown tattoo parlors', facade: 'paint:IRON_BLACK', awning: null, sign: 'NEON_RED', signBg: 'IRON_BLACK', neon: ['NEON_RED'] },
];

// ------------------------------------------------------------------------------------------ name generator
const ADJ = ['Gilded', 'Copper', 'Tin Roof', 'Ridgeline', 'Bluebell', 'Old Cistern', 'Oak Leaf', 'Brickyard', 'Lantern', 'Wandering', 'Hilltop', 'Pine Cone', 'Red Clay', 'Summit', 'Quarry', 'Cardinal', 'Goatfoot', 'Billram', 'Night Owl', 'Corner', 'Sweet Gum', 'Dogwood', 'Twin Pines', 'Crooked', 'Silver Spoon'];
const NOUN = ['Acorn', 'Kettle', 'Lamp', 'Spoke', 'Ledger', 'Thimble', 'Anvil', 'Compass', 'Sparrow', 'Fiddle', 'Hearth', 'Satchel', 'Saddle', 'Teacup', 'Ladder', 'Pennant', 'Lantern', 'Quill', 'Biscuit', 'Barrel'];
const KIND: Record<BizType, string[]> = {
  diner: ['Diner', 'Luncheonette', 'Grill'], brewpub: ['Taproom', 'Brewing Co.'], cinema: ['Picture House'], cafe: ['Café', 'Coffee Bar', 'Roasters'],
  retail: ['Mercantile', 'Supply', 'Goods'], bookstore: ['Books', 'Book Nook'], pizza: ['Pizza', 'Slice Shop'], bar: ['Tavern', 'Lounge', 'Saloon'],
  breakfast: ['Biscuit House', 'Pancake Parlor'], takeout: ['Noodle Bar', 'Wok Shop'], records: ['Records', 'Vinyl'], bank: ['Savings & Loan'],
  dental: ['Dental'], hardware: ['Hardware'], clothing: ['Outfitters', 'Haberdashery', 'Threads'], tacos: ['Taquería', 'Taco Counter'], tutoring: ['Tutoring'],
  tattoo: ['Tattoo', 'Ink Studio'], deli: ['Deli', 'Sandwich Co.'], optics: ['Optics'], salon: ['Salon', 'Barber Shop'], bakery: ['Bakery', 'Bake Shop'], florist: ['Florist'], gallery: ['Gallery', 'Print Shop'],
};
const GEN_TYPES: [BizType, number][] = [['cafe', 3], ['retail', 4], ['bar', 3], ['deli', 2], ['clothing', 3], ['optics', 1], ['salon', 2], ['bakery', 2], ['florist', 1], ['gallery', 2], ['bookstore', 1], ['pizza', 1], ['tacos', 1], ['takeout', 1]];
const FACADES: string[] = ['brick:running:BRICK_DOWNTOWN_A', 'brick:running:BRICK_DOWNTOWN_B', 'brick:running:BRICK_DOWNTOWN_C', 'brick:running:BRICK_DOWNTOWN_A:painted', 'paint:STOREFRONT_TERRACOTTA', 'paint:STOREFRONT_SAGE', 'paint:SIDING_SLATE_BLUE'];
const AWNINGS: PaletteKey[] = ['AWNING_HARBOR_BLUE', 'AWNING_COFFEE', 'AWNING_LINEN', 'SHUTTER_GREEN', 'CINEMA_MAROON', 'ONSU_NAVY', 'CURB_PAINT_RED'];
const SIGNS: [PaletteKey, PaletteKey][] = [['SIGN_CREAM', 'DOOR_BLACK'], ['MARKING_WHITE', 'SHUTTER_GREEN'], ['BRASS_WORN', 'WALNUT_DARK'], ['ONSU_WHITE', 'ONSU_NAVY'], ['MARKING_YELLOW', 'IRON_BLACK']];

export function generateBusiness(rng: Rng, used: Set<string>): Biz {
  for (let i = 0; i < 50; i++) {
    const type = rng.weighted(GEN_TYPES);
    const adj = rng.pick(ADJ), noun = rng.pick(NOUN.filter((x) => !adj.includes(x)));
    const name = `${rng.chance(0.5) ? adj : `The ${adj}`} ${rng.chance(0.6) ? noun + ' ' : ''}${rng.pick(KIND[type])}`;
    if (used.has(name)) continue;
    used.add(name);
    const [sign, signBg] = rng.pick(SIGNS);
    return { name, type, facade: rng.pick(FACADES), awning: rng.chance(0.6) ? rng.pick(AWNINGS) : null, stripe: rng.chance(0.3) ? 'MARKING_WHITE' : undefined, sign, signBg };
  }
  return { name: `Storefront ${used.size}`, type: 'retail', facade: FACADES[0], sign: 'MARKING_WHITE', signBg: 'DOOR_BLACK' };
}

// ------------------------------------------------------------------------------------------ spec + interiors
const TYPOLOGY: Partial<Record<BizType, Typology>> = { diner: 'diner', breakfast: 'diner', bar: 'bar', brewpub: 'bar' };
const MAIN_ROOM: Partial<Record<BizType, RoomType>> = {
  diner: 'dining', breakfast: 'dining', brewpub: 'bar', bar: 'bar', cafe: 'cafe', pizza: 'dining', takeout: 'retail_floor', tacos: 'dining', bank: 'banking_hall',
  records: 'retail_floor', bookstore: 'retail_floor', cinema: 'lobby', tattoo: 'studio', deli: 'dining', bakery: 'retail_floor', salon: 'studio', gallery: 'gallery',
};
const BACK_ROOM: Partial<Record<BizType, RoomType>> = {
  diner: 'kitchen', breakfast: 'kitchen', pizza: 'kitchen', takeout: 'kitchen', tacos: 'kitchen', cafe: 'kitchen', deli: 'kitchen', bakery: 'kitchen', brewpub: 'brewhouse',
  bar: 'back_room', bank: 'vault', records: 'listening_room', clothing: 'fitting_room', tattoo: 'studio', hardware: 'stockroom', bookstore: 'stockroom',
};

export function bizFacade(b: Biz, base: FacadeSpec): FacadeSpec {
  const awn = b.awning ? { kind: (b.type === 'cinema' ? 'canopy' : b.type === 'tacos' ? 'dome' : 'shed') as 'shed' | 'dome' | 'canopy', color: `paint:${b.awning}`, stripe: b.stripe ? `paint:${b.stripe}` : undefined } : b.type === 'cinema' ? { kind: 'canopy' as const, color: 'paint:DOOR_BLACK' } : null;
  return {
    ...base, wall: b.facade, backWall: 'brick:common:BRICK_DOWNTOWN_C',
    storefront: { bays: b.type === 'bank' ? 3 : 2, entry: b.type === 'bank' ? 'center' : 'center', awning: awn, signBand: `paint:${b.signBg}` },
    doorStyle: `colonial:${b.door ?? 'DOOR_BLACK'}`,
  };
}

export function bizSpec(b: Biz, base: Omit<BuildingSpec, 'typology' | 'plan' | 'facade' | 'business' | 'custom'>, facade: FacadeSpec): BuildingSpec {
  return {
    ...base, typology: TYPOLOGY[b.type] ?? 'downtown_commercial', plan: 'shotgun', custom: b.type === 'cinema' ? 'cinema' : 'business', facade: bizFacade(b, facade),
    business: { name: b.name, type: b.type, sign: b.sign, signBg: b.signBg, facade: b.facade, awning: b.awning ?? undefined, real: b.real },
    upperUse: b.type === 'dental' || b.type === 'tutoring' || b.type === 'bank' ? 'offices' : 'apartments',
  };
}

function retypeBusiness(p: Plan): Plan {
  const b = p.spec.business!;
  const type = b.type as BizType;
  const t = p.spec.typology;
  const set = (fl: number, i: number, ty: RoomType, label?: string) => { const r = p.floors.find((f) => f.floor === fl)?.rooms[i]; if (r) { r.type = ty; r.finish = finishFor(t, ty); if (label) r.label = label; } };
  const f0 = p.floors.find((f) => f.floor === 0)!;
  f0.rooms.forEach((r, i) => {
    if (r.type === 'retail_floor' || r.type === 'dining' || r.type === 'bar' || r.type === 'cafe' || r.type === 'banking_hall' || r.type === 'lobby') set(0, i, MAIN_ROOM[type] ?? 'retail_floor', b.name);
    else if (r.type === 'stockroom' || r.type === 'kitchen' || r.type === 'vault') set(0, i, BACK_ROOM[type] ?? 'stockroom');
  });
  if (p.spec.tags?.includes('roofdeck')) for (const fp of p.floors) if (fp.floor >= p.spec.floors) fp.rooms.forEach((r, i) => { if (r.type === 'attic') set(fp.floor, i, 'deck', i === 0 ? 'Rooftop deck' : undefined); });
  for (const fp of p.floors) if (fp.floor > 0 && fp.floor < p.spec.floors) fp.rooms.forEach((r, i) => {
    if (type === 'dental' && fp.floor === 1 && (r.type === 'office' || r.type === 'restroom')) set(1, i, i === 2 ? 'reception' : 'operatory', i === 2 ? 'Jolly Molar reception' : undefined);
    if (type === 'tutoring' && fp.floor === 1 && r.type === 'office') set(1, i, 'classroom');
    if (type === 'bar' && fp.floor === 1 && (r.type === 'apartment_living' || r.type === 'apartment_bed')) set(1, i, 'pool_room', 'Upstairs pool room');
    if (type === 'brewpub' && fp.floor === 1 && (r.type === 'apartment_living' || r.type === 'apartment_bed')) set(1, i, 'bar', 'Upstairs bar');
  });
  return p;
}

LANDMARK_HOOKS.set('business', {
  plan: (spec) => spec.w <= 600
    ? customPlan(spec, (pb, _fl, W, D, t) => {
      // late-night food stall: one serving room behind a counter window
      pb.room(0, { x0: t, z0: t, x1: W - t, z1: D - t }, 'kitchen', spec.business?.name);
      pb.extDoors.push({ floor: 0, side: 'back', at: Math.round(W / 2) - 45, w: 91, h: 213, style: 'steel', y: 0 });
    })
    : retypeBusiness(generatePlan({ ...spec, custom: undefined })),
  interior: (spec, plan, g) => {
    const type = spec.business!.type as BizType;
    const f0 = plan.floors.find((f) => f.floor === 0)!;
    const main = f0.rooms.find((r) => r.label === spec.business!.name) ?? f0.rooms[2];
    if (!main) return;
    const R = main.rect, w = R.x1 - R.x0, d = R.z1 - R.z0;
    const counter = (x0: number, z0: number, x1: number, z1: number, key = 'tex:walnut', top = 'tex:marble', h = 107) => { boxC(g, key, x0, 0, z0, x1, h - 5, z1); boxC(g, top, x0 - 4, h - 5, z0 - 4, x1 + 4, h, z1 + 4); };
    switch (type) {
      case 'diner': case 'breakfast': // long built-in lunch counter down one side
        counter(R.x0 + w * 0.45, R.z0 + 200, R.x0 + w * 0.45 + 70, R.z1 - 120, 'satin:TRIM_WHITE', 'tex:terrazzo'); break;
      case 'bar': case 'brewpub':
        counter(R.x1 - 90, R.z0 + 250, R.x1 - 20, R.z1 - 100, 'tex:walnut', 'tex:walnut', 112);
        boxC(g, 'tex:walnut', R.x1 - 15, 0, R.z0 + 250, R.x1, 230, R.z1 - 100); // back bar
        break;
      case 'cafe': case 'deli': case 'bakery': case 'takeout': case 'tacos':
        counter(R.x0 + 60, R.z1 - 180, R.x1 - 60, R.z1 - 110, 'satin:TRIM_WHITE_AGED', 'tex:walnut'); break;
      case 'pizza':
        counter(R.x0 + 60, R.z1 - 200, R.x1 - 60, R.z1 - 130);
        boxC(g, 'brick:running:BRICK_DOWNTOWN_A', R.x0 + w / 2 - 120, 0, R.z1 - 100, R.x0 + w / 2 + 120, 190, R.z1); // oven alcove mass
        boxC(g, 'paint:SHADOW_INK', R.x0 + w / 2 - 45, 95, R.z1 - 101, R.x0 + w / 2 + 45, 140, R.z1 - 100);
        break;
      case 'bank':
        counter(R.x0 + 80, R.z0 + d * 0.62, R.x1 - 80, R.z0 + d * 0.62 + 70, 'tex:walnut', 'tex:marble', 115); // teller line
        boxC(g, 'glass', R.x0 + 80, 115, R.z0 + d * 0.62 + 30, R.x1 - 80, 230, R.z0 + d * 0.62 + 31);
        break;
      case 'records': boxC(g, 'tex:walnut', R.x0 + 40, 0, R.z0 + 200, R.x0 + 120, 100, R.z1 - 150); break; // bins plinth
      case 'clothing': for (let i = 0; i < 2; i++) boxC(g, 'satin:TRIM_WHITE', R.x1 - 140, 0, R.z1 - 140 - i * 130, R.x1 - 130, 220, R.z1 - 20 - i * 130); break; // fitting-room partitions
      case 'tattoo': case 'salon': boxC(g, 'satin:TRIM_WHITE', R.x0 + w / 2 - 5, 0, R.z0 + d * 0.5, R.x0 + w / 2 + 5, 200, R.z1 - 60); break;
      case 'hardware': case 'retail': case 'bookstore': case 'gallery': case 'optics': case 'florist':
        counter(R.x0 + 60, R.z0 + 180, R.x0 + 260, R.z0 + 250); break;
      case 'cinema': break;
    }
    void C;
  },
});
