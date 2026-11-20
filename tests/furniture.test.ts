// Furniture items pass (godot/furniture): placements stay inside their rooms, keep doorways clear,
// and every model / action referenced exists.
import { describe, expect, it } from 'vitest';
import { readFileSync } from 'node:fs';

const rooms = JSON.parse(readFileSync('data/rooms.json', 'utf8')).rooms as any[];
const byId = new Map(rooms.map((r) => [r.roomId, r]));
const catalog = JSON.parse(readFileSync('godot/furniture/data/furniture_catalog.json', 'utf8')).models as any[];
const actions = JSON.parse(readFileSync('godot/furniture/data/furniture_actions.json', 'utf8')).actions;
const placements = JSON.parse(readFileSync('godot/furniture/data/furniture_placements.json', 'utf8'));
const models = new Map(catalog.map((m) => [m.id, m]));

describe('furniture catalogue', () => {
  it('has 100 models with known actions', () => {
    expect(catalog.length).toBe(100);
    const used = new Set<string>();
    for (const m of catalog) {
      expect(m.actions.length).toBeGreaterThan(0);
      for (const a of m.actions) { expect(actions[a], `${m.id} ${a}`).toBeTruthy(); used.add(a); }
    }
    expect(used.size).toBeGreaterThanOrEqual(100);
  });
  it('seating has seat points and beds have sleep points', () => {
    for (const m of catalog) {
      if (m.actions.includes('sit')) expect(m.seats.length, m.name).toBeGreaterThan(0);
      if (m.actions.includes('sleep')) expect(m.beds.length, m.name).toBeGreaterThan(0);
    }
  });
});

describe('furniture placements', () => {
  const all: { r: any; m: any; it: number[] }[] = [];
  for (const e of Object.values<any>(placements.buildings)) for (const it of e.items) all.push({ r: byId.get(e.rooms[it[5]]), m: models.get(it[0]), it });

  it('places tens of thousands of pieces using every model', () => {
    expect(all.length).toBe(placements.count);
    expect(all.length).toBeGreaterThan(50000);
    expect(new Set(all.map((p) => p.m.id)).size).toBe(100);
  });
  it('keeps every piece inside its room, on its floor, under its ceiling', () => {
    for (const { r, m, it } of all) {
      const [, x, y, z, rot] = it;
      const q = Math.abs(Math.round(rot / (Math.PI / 2))) % 2;
      const [w, d] = q ? [m.size_m[2], m.size_m[0]] : [m.size_m[0], m.size_m[2]];
      const [x0, z0, x1, z1] = r.rect;
      expect(x - w / 2 >= x0 - 0.01 && x + w / 2 <= x1 + 0.01 && z - d / 2 >= z0 - 0.01 && z + d / 2 <= z1 + 0.01, `${r.roomId} ${m.name}`).toBe(true);
      expect(Math.abs(y - (r.y + (m.mount_y || 0)))).toBeLessThan(0.002);
      expect(y - r.y + m.size_m[1]).toBeLessThanOrEqual(r.ceilingCm / 100);
    }
  });
  it('leaves doorways clear', () => {
    for (const { r, m, it } of all) {
      for (const o of r.openings) {
        if (o.type !== 'door') continue;
        const [, x, , z, rot] = it;
        const q = Math.abs(Math.round(rot / (Math.PI / 2))) % 2;
        const [w, d] = q ? [m.size_m[2], m.size_m[0]] : [m.size_m[0], m.size_m[2]];
        const dx = Math.max(0, Math.abs(o.position[0] - x) - w / 2), dz = Math.max(0, Math.abs(o.position[2] - z) - d / 2);
        expect(Math.hypot(dx, dz), `${r.roomId} ${m.name} blocks a door`).toBeGreaterThan(o.widthCm / 200);
      }
    }
  });
});
