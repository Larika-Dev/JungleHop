// CLAUDE.md §2 — 1 unit = 1 m. Author in integer centimeters, convert once.
export type Cm = number;

/** Integer centimeters -> meters (the single conversion point). */
export const cm = (n: Cm): number => n / 100;
/** Meters -> integer centimeters (snaps to the 1 cm grid). */
export const toCm = (m: number): Cm => Math.round(m * 100);
/** Snap a meter value to the 1 cm grid. */
export const snap = (m: number): number => Math.round(m * 100) / 100;
/** True if a meter value lies on the 1 cm grid (within float tolerance). */
export const onGrid = (m: number, tol = 1e-6): boolean => Math.abs(m * 100 - Math.round(m * 100)) < tol * 100;

export const DEG = Math.PI / 180;
export const clamp = (v: number, a: number, b: number) => (v < a ? a : v > b ? b : v);
export const lerp = (a: number, b: number, t: number) => a + (b - a) * t;
export const smoothstep = (a: number, b: number, t: number) => {
  const u = clamp((t - a) / (b - a), 0, 1);
  return u * u * (3 - 2 * u);
};
