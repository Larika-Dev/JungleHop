// Open-licensed fonts bundled in /public/fonts (CLAUDE.md §14), loaded via the FontFace API.
export const FONTS = {
  serif: 'Libre Baskerville', display: 'Playfair Display', condensed: 'Oswald', poster: 'Bebas Neue', script: 'Pacifico', slab: 'Roboto Slab',
} as const;
const FILES: [string, string, string][] = [
  ['Libre Baskerville', 'libre-baskerville-latin-700-normal.woff2', '700'], ['Playfair Display', 'playfair-display-latin-700-normal.woff2', '700'],
  ['Oswald', 'oswald-latin-600-normal.woff2', '600'], ['Bebas Neue', 'bebas-neue-latin-400-normal.woff2', '400'],
  ['Pacifico', 'pacifico-latin-400-normal.woff2', '400'], ['Roboto Slab', 'roboto-slab-latin-500-normal.woff2', '500'],
];
let loading: Promise<void> | null = null;
export function loadFonts(): Promise<void> {
  if (typeof document === 'undefined') return Promise.resolve();
  return (loading ??= Promise.all(FILES.map(async ([fam, file, weight]) => {
    try {
      const f = new FontFace(fam, `url(${import.meta.env.BASE_URL}fonts/${file})`, { weight });
      await f.load();
      (document.fonts as any).add(f);
    } catch (e) { console.warn('font failed', fam, e); }
  })).then(() => undefined));
}
export const font = (fam: keyof typeof FONTS, px: number, weight = '700') => `${weight} ${px}px "${FONTS[fam]}", Georgia, serif`;
