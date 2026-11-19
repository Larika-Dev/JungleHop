// CLAUDE.md §19: no real trademark / business name appears in any generated text.
import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
import { cityPlan } from '../src/world/cityPlan';
import { allParodyStrings, poster } from '../src/signage/parody';
import { Rng } from '../src/core/rng';
import { ROADS, LANDMARKS, DISTRICTS } from '../src/world/layout';

const banned = readFileSync('tests/data/trademarks.txt', 'utf8').split('\n').map((l) => l.trim()).filter((l) => l && !l.startsWith('#'));

function generatedText(): string[] {
  const out: string[] = [...allParodyStrings()];
  for (const s of cityPlan().buildings) { if (s.spec.name) out.push(s.spec.name); if (s.spec.business) out.push(s.spec.business.name); }
  const rng = new Rng('parody-test');
  for (let i = 0; i < 400; i++) { const p = poster(rng); out.push(p.title, ...p.lines); }
  for (const r of ROADS) out.push(r.name);
  for (const l of LANDMARKS) out.push(l.name);
  for (const d of DISTRICTS) out.push(d.name);
  out.push('Old North State University', 'ONSU', 'Pitch Soles', 'Billram', 'Earl University', 'Steer City', 'Cathedral Mount', 'State of Pamlico', 'CITY OF CATHEDRAL MOUNT — 1819');
  return out;
}

describe('parody text', () => {
  const texts = generatedText();
  it(`checks ${texts.length} strings against ${banned.length} banned names`, () => {
    const hits: string[] = [];
    for (const t of texts) for (const b of banned) {
      const re = new RegExp(`(^|[^A-Za-z])${b.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}([^A-Za-z]|$)`, 'i');
      if (re.test(t)) hits.push(`"${t}" ~ ${b}`);
    }
    expect(hits).toEqual([]);
  });
});
