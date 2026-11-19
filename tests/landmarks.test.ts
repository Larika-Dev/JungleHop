// CLAUDE.md §10/§19: every landmark has a valid hand-authored (or generated) plan with full interior rules.
import { describe, expect, it } from 'vitest';
import { landmarkSpecs } from '../src/buildings/landmarks/index';
import { planFor } from '../src/buildings/manager';
import { validatePlan } from '../src/interiors/validate';
import { allRoomMeta } from '../src/interiors/roomMeta';

describe('landmarks', () => {
  const specs = landmarkSpecs();
  it('covers all 15 §10 landmarks', () => {
    const ids = new Set(specs.map((s) => s.id.slice(0, 4)));
    for (let n = 1; n <= 15; n++) expect(ids.has(`LM${String(n).padStart(2, '0')}`), `LM${n}`).toBe(true);
  });
  for (const s of specs) it(`${s.id} plan is valid`, () => {
    const p = planFor(s);
    const v = validatePlan(p);
    expect(v.errors).toEqual([]);
    for (const m of allRoomMeta(p)) expect(m.itemSlots).toEqual([]);
  });
});
