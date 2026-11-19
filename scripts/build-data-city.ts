// City data export (CLAUDE.md §7.4/§14/§20): data/buildings.json, data/rooms.json, data/parody-names.json.
import { writeFileSync } from 'node:fs';
import { cityPlan } from '../src/world/cityPlan';
import { planFor } from '../src/buildings/manager';
import { allRoomMeta } from '../src/interiors/roomMeta';
import { validatePlan } from '../src/interiors/validate';
import { ROSTER } from '../src/districts/businesses';
import { LANDMARKS, ROADS } from '../src/world/layout';

export default async function () {
  const city = cityPlan();
  const buildings: unknown[] = [];
  const rooms: unknown[] = [];
  let invalid = 0;
  for (const s of city.buildings) {
    const sp = s.spec, plan = planFor(sp);
    const v = validatePlan(plan);
    if (!v.ok) invalid++;
    const metas = allRoomMeta(plan);
    buildings.push({
      id: sp.id, name: sp.name ?? null, district: sp.district, tile: s.tile, typology: sp.typology, plan: sp.custom ?? sp.plan,
      transform: { x: +sp.x.toFixed(3), y: sp.y, z: +sp.z.toFixed(3), rotY: +sp.rotY.toFixed(6), note: 'world = R_y(rotY) * local + (x, y, z); local meters, +x along frontage, +z into the building' },
      footprintCm: [sp.w, sp.d], floors: sp.floors, basement: sp.basement, attic: sp.attic, roofCm: plan.roofY,
      facade: { wall: sp.facade.wall, roof: sp.facade.roof, window: sp.facade.window, cornice: sp.facade.cornice },
      business: sp.business ? { name: sp.business.name, type: sp.business.type } : null,
      floorsList: plan.floors.map((f) => ({ floor: f.floor, yCm: f.y, ftfCm: f.ftf, ceilingCm: f.ceiling, rooms: f.rooms.length })),
      stairs: plan.stairs.length, elevators: plan.shafts.length, exteriorDoors: plan.extDoors.length, windows: plan.windows.length, rooms: metas.length, valid: v.ok,
    });
    for (const m of metas) rooms.push(m);
  }
  writeFileSync('data/buildings.json', JSON.stringify({ seed: 1795, count: buildings.length, buildings }, null, 1));
  writeFileSync('data/rooms.json', JSON.stringify({ seed: 1795, units: 'meters, building-local (see buildings.json transform)', count: rooms.length, rooms }));
  const parody: { real_inspiration: string; parody_name: string; type: string; district: string }[] = [
    { real_inspiration: 'Chapel Hill, NC', parody_name: 'Cathedral Mount', type: 'town', district: 'all' },
    { real_inspiration: 'North Carolina', parody_name: 'State of Pamlico', type: 'state', district: 'all' },
    { real_inspiration: 'University of North Carolina at Chapel Hill', parody_name: 'Old North State University (ONSU)', type: 'university', district: 'campus' },
    { real_inspiration: 'Tar Heels (team nickname)', parody_name: 'Pitch Soles', type: 'team nickname', district: 'campus' },
    { real_inspiration: 'Rameses (mascot)', parody_name: 'the Billram', type: 'mascot (original ram-goat design)', district: 'campus' },
    { real_inspiration: 'Duke University', parody_name: 'Earl University', type: 'rival university', district: 'outer_ring' },
    { real_inspiration: 'Durham, NC', parody_name: 'Steer City', type: 'rival city', district: 'outer_ring' },
    { real_inspiration: 'Carrboro, NC', parody_name: 'Carrburg', type: 'town', district: 'carrburg' },
    { real_inspiration: 'Gimghoul neighborhood', parody_name: 'Toadstool Hill', type: 'neighborhood', district: 'toadstool' },
    { real_inspiration: 'Battle Park', parody_name: 'Battle Ravine', type: 'park', district: 'battle_ravine' },
    { real_inspiration: 'The Pit', parody_name: 'The Quarry', type: 'plaza', district: 'quarry' },
    { real_inspiration: 'McCorkle Place', parody_name: 'ONSU North Quad', type: 'quad', district: 'north_quad' },
    { real_inspiration: 'Polk Place', parody_name: "Founders' Quad", type: 'quad', district: 'founders_quad' },
    { real_inspiration: 'Franklin St', parody_name: 'Hamilton St', type: 'street', district: 'hamilton_strip' },
    { real_inspiration: 'Merritt Mill Rd', parody_name: "Miller's Run Rd", type: 'street', district: 'carrburg' },
    { real_inspiration: 'Manning Dr', parody_name: 'Manor Dr', type: 'street', district: 'carillon_south' },
    { real_inspiration: 'Raleigh St / Raleigh Rd', parody_name: 'Raleigh Pike', type: 'street', district: 'campus' },
    { real_inspiration: 'Top of the Hill (intersection)', parody_name: 'The Summit', type: 'intersection', district: 'summit' },
    { real_inspiration: 'Old Well', parody_name: 'The Old Cistern', type: 'landmark', district: 'north_quad' },
    { real_inspiration: 'Morehead-Patterson Bell Tower', parody_name: 'The Carillon Spire', type: 'landmark', district: 'carillon_south' },
    { real_inspiration: 'Hill Hall / historic campus library', parody_name: 'Wilberforce Library', type: 'landmark', district: 'north_quad' },
    { real_inspiration: 'Davis Library', parody_name: 'Davies Stacks', type: 'landmark', district: 'quarry' },
    { real_inspiration: 'South Building', parody_name: "Founders' Hall", type: 'landmark', district: 'founders_quad' },
    { real_inspiration: 'Old East / Old West', parody_name: 'Elder East / Elder West', type: 'landmark', district: 'north_quad' },
    { real_inspiration: 'Morehead Planetarium', parody_name: 'Moorhouse Observatory', type: 'landmark', district: 'hamilton_strip' },
    { real_inspiration: 'Wilson Library', parody_name: 'Ashgrove Library', type: 'landmark', district: 'founders_quad' },
    { real_inspiration: 'Carolina Union / Lenoir Hall', parody_name: 'Student Union & Dining Hall', type: 'landmark', district: 'quarry' },
    { real_inspiration: 'Kenan Memorial Stadium', parody_name: 'Benefactor Memorial Stadium', type: 'landmark', district: 'carillon_south' },
    { real_inspiration: 'Dean E. Smith Center', parody_name: "The Coach's Dome", type: 'landmark', district: 'carillon_south' },
    { real_inspiration: 'The Carolina Inn', parody_name: 'Pamlico Inn', type: 'landmark', district: 'cameron_heights' },
    { real_inspiration: 'UNC Hospitals', parody_name: 'ONSU Medical Center', type: 'landmark', district: 'medical' },
    { real_inspiration: 'Gimghoul Castle', parody_name: 'Ghoulgrave Keep', type: 'landmark', district: 'toadstool' },
    { real_inspiration: 'Forest Theatre', parody_name: 'Grove Amphitheatre', type: 'landmark', district: 'battle_ravine' },
    { real_inspiration: 'Carr Mill', parody_name: 'Loomhouse Mill', type: 'landmark', district: 'carrburg' },
  ];
  for (const b of ROSTER) parody.push({ real_inspiration: b.real ?? 'invented', parody_name: b.name, type: b.type, district: 'hamilton_strip' });
  for (const s of city.buildings) if (s.spec.business && !ROSTER.some((r) => r.name === s.spec.business!.name)) parody.push({ real_inspiration: 'none (generated)', parody_name: s.spec.business.name, type: String(s.spec.business.type), district: s.spec.district });
  for (const r of ROADS) if (!parody.some((p) => p.parody_name === r.name)) parody.push({ real_inspiration: 'invented', parody_name: r.name, type: r.kind === 'alley' ? 'alley' : 'street', district: '' });
  writeFileSync('data/parody-names.json', JSON.stringify(parody, null, 1));
  console.log(`wrote buildings.json (${buildings.length}, invalid ${invalid}), rooms.json (${rooms.length} rooms), parody-names.json (${parody.length})`);
  void LANDMARKS;
}
