// Writes /data/*.json from the deterministic generators (CLAUDE.md §20). Run: npm run data
import { writeFileSync, mkdirSync } from 'node:fs';
import { PALETTE } from '../src/core/palette';

mkdirSync('data', { recursive: true });
writeFileSync('data/palette.json', JSON.stringify(PALETTE, null, 2) + '\n');
console.log('wrote data/palette.json');
const extra = await import('./build-data-city');
if (extra) await extra.default();
