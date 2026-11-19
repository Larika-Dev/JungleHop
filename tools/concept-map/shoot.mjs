// Rasterizes docs/phase-1/concept-map.svg -> screenshots/phase-1/concept-map.png via the preinstalled Playwright.
import { createRequire } from 'node:module';
const { chromium } = createRequire(import.meta.url)('playwright');
import { readFileSync, mkdirSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const svg = readFileSync(resolve(root, 'docs/phase-1/concept-map.svg'), 'utf8');
const [, w, h] = svg.match(/width="(\d+)" height="(\d+)"/);
mkdirSync(resolve(root, 'screenshots/phase-1'), { recursive: true });
const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: +w, height: +h }, deviceScaleFactor: Number(process.argv[2] ?? 1) });
await page.setContent(`<html><body style="margin:0">${svg}</body></html>`);
await page.screenshot({ path: resolve(root, 'screenshots/phase-1/concept-map.png'), fullPage: true });
await browser.close();
console.log('wrote screenshots/phase-1/concept-map.png');
