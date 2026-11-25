// Builds godot/npc/data/npc_buildings.json from data/buildings.json.
// Only what the NPC system needs: where each building's front door is,
// what it is used for, and how many people live or work there.
// Run from the repo root: node godot/npc/tools/extract-buildings.mjs
import { readFileSync, writeFileSync } from 'node:fs';

const src = JSON.parse(readFileSync('data/buildings.json', 'utf8'));

// People who live in one building of this typology (before scaling to 4,000).
const HOMES = {
  house: 3, residence_highrise: 220, residence_historic: 140, downtown_commercial: 2,
  inn: 6,
};
// Jobs per building of this typology.
const JOBS = {
  downtown_commercial: 6, bar: 9, diner: 12, office_lab: 55, hospital: 220,
  historic_academic: 30, modern_academic: 45, library: 18, arena: 25, inn: 14,
  mill: 30, parking: 1, residence_highrise: 4, residence_historic: 3,
};
const r2 = (v) => Math.round(v * 100) / 100;

const out = src.buildings.filter((b) => b.valid !== false).map((b) => {
  const t = b.transform;
  const [w, d] = b.footprintCm.map((c) => c / 100);
  const c = Math.cos(t.rotY), s = Math.sin(t.rotY);
  // world = R_y(rotY) * local + pos. Door: middle of frontage, 1.2 m outside.
  const rot = (lx, lz) => [c * lx + s * lz, -s * lx + c * lz];
  const [dx, dz] = rot(w / 2, -1.2);
  const [cx, cz] = rot(w / 2, d / 2);
  return {
    id: b.id,
    name: b.name,
    district: b.district,
    typology: b.typology,
    business: b.business ? b.business.type : null,
    business_name: b.business ? b.business.name : null,
    origin: [r2(t.x), r2(t.y), r2(t.z)],
    door: [r2(t.x + dx), r2(t.y), r2(t.z + dz)],
    center: [r2(t.x + cx), r2(t.y), r2(t.z + cz)],
    rot_y: t.rotY,
    size: [w, d],
    floors: b.floors,
    homes: HOMES[b.typology] ?? 0,
    jobs: JOBS[b.typology] ?? 0,
  };
});

writeFileSync('godot/npc/data/npc_buildings.json', JSON.stringify({ seed: src.seed, buildings: out }));
console.log(`wrote ${out.length} buildings, ${out.reduce((a, b) => a + b.homes, 0)} homes, ${out.reduce((a, b) => a + b.jobs, 0)} jobs`);
