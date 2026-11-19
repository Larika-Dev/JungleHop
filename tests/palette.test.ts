// CLAUDE.md §4: no hex literal anywhere in /src except core/palette.ts.
import { readdirSync, readFileSync, statSync } from 'node:fs';
import { join, relative } from 'node:path';
import { describe, expect, it } from 'vitest';
import { PALETTE } from '../src/core/palette';

function walk(dir: string, out: string[] = []): string[] {
  for (const f of readdirSync(dir)) {
    const p = join(dir, f);
    if (statSync(p).isDirectory()) walk(p, out); else if (/\.(ts|js|css|glsl|html)$/.test(f)) out.push(p);
  }
  return out;
}

describe('palette', () => {
  it('has no hex literals outside palette.ts', () => {
    const offenders: string[] = [];
    for (const f of walk('src')) {
      if (f.endsWith(join('core', 'palette.ts'))) continue;
      const src = readFileSync(f, 'utf8');
      const re = /#[0-9a-fA-F]{6}\b|#[0-9a-fA-F]{3}\b(?![0-9a-zA-Z_])|0x[0-9a-fA-F]{6}\b/g;
      let m: RegExpExecArray | null;
      while ((m = re.exec(src))) {
        const line = src.slice(0, m.index).split('\n').length;
        offenders.push(`${relative('.', f)}:${line} ${m[0]}`);
      }
    }
    expect(offenders).toEqual([]);
  });
  it('all palette values are valid 6-digit hex', () => {
    for (const [k, v] of Object.entries(PALETTE)) expect(v, k).toMatch(/^#[0-9A-F]{6}$/i);
  });
  it('mirror data/palette.json matches palette.ts', async () => {
    const json = JSON.parse(readFileSync('data/palette.json', 'utf8'));
    expect(json).toEqual(PALETTE);
  });
  it('contains every spec base key', () => {
    for (const k of ['BRICK_CAMPUS_A', 'BRICK_HEADER_GLAZED', 'FIELDSTONE_D', 'COPPER_PATINA', 'ASPHALT_AGED', 'WILLOW_OAK_LEAF', 'HEAVEN_BLUE', 'EARL_BLUE', 'TERRAZZO', 'SPORTS_MAPLE', 'LAMP_SODIUM', 'INTERIOR_COOL'])
      expect(PALETTE).toHaveProperty(k);
  });
});
