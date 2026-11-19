// Seeded deterministic RNG (CLAUDE.md §3: seed = 1795). sfc32 seeded via cyrb128 string hash.
export const WORLD_SEED = 1795;

function cyrb128(str: string): [number, number, number, number] {
  let h1 = 1779033703, h2 = 3144134277, h3 = 1013904242, h4 = 2773480762;
  for (let i = 0, k; i < str.length; i++) {
    k = str.charCodeAt(i);
    h1 = h2 ^ Math.imul(h1 ^ k, 597399067);
    h2 = h3 ^ Math.imul(h2 ^ k, 2869860233);
    h3 = h4 ^ Math.imul(h3 ^ k, 951274213);
    h4 = h1 ^ Math.imul(h4 ^ k, 2716044179);
  }
  h1 = Math.imul(h3 ^ (h1 >>> 18), 597399067);
  h2 = Math.imul(h4 ^ (h2 >>> 22), 2869860233);
  h3 = Math.imul(h1 ^ (h3 >>> 17), 951274213);
  h4 = Math.imul(h2 ^ (h4 >>> 19), 2716044179);
  return [(h1 ^ h2 ^ h3 ^ h4) >>> 0, (h2 ^ h1) >>> 0, (h3 ^ h1) >>> 0, (h4 ^ h1) >>> 0];
}

export class Rng {
  private a: number; private b: number; private c: number; private d: number;
  readonly label: string;
  constructor(seed: string | number = WORLD_SEED) {
    this.label = String(seed);
    [this.a, this.b, this.c, this.d] = cyrb128(this.label);
    for (let i = 0; i < 12; i++) this.next();
  }
  /** Uniform float in [0,1). */
  next(): number {
    this.a >>>= 0; this.b >>>= 0; this.c >>>= 0; this.d >>>= 0;
    let t = (this.a + this.b) | 0;
    this.a = this.b ^ (this.b >>> 9);
    this.b = (this.c + (this.c << 3)) | 0;
    this.c = (this.c << 21) | (this.c >>> 11);
    this.d = (this.d + 1) | 0;
    t = (t + this.d) | 0;
    this.c = (this.c + t) | 0;
    return (t >>> 0) / 4294967296;
  }
  range(a: number, b: number): number { return a + (b - a) * this.next(); }
  /** Integer in [a, b] inclusive. */
  int(a: number, b: number): number { return a + Math.floor(this.next() * (b - a + 1)); }
  chance(p: number): boolean { return this.next() < p; }
  pick<T>(arr: readonly T[]): T { return arr[Math.floor(this.next() * arr.length)]; }
  /** Weighted pick: [[value, weight], ...] */
  weighted<T>(items: readonly (readonly [T, number])[]): T {
    const total = items.reduce((s, [, w]) => s + w, 0);
    let r = this.next() * total;
    for (const [v, w] of items) { if ((r -= w) < 0) return v; }
    return items[items.length - 1][0];
  }
  shuffle<T>(arr: T[]): T[] {
    for (let i = arr.length - 1; i > 0; i--) { const j = Math.floor(this.next() * (i + 1)); [arr[i], arr[j]] = [arr[j], arr[i]]; }
    return arr;
  }
  /** Approx. normal(0,1). */
  gauss(): number { return (this.next() + this.next() + this.next() + this.next() - 2) * 1.732; }
  /** Integer centimeters uniformly in [a,b] cm. */
  cm(a: number, b: number): number { return this.int(a, b); }
  /** Independent child stream; same label -> same stream regardless of call order elsewhere. */
  fork(label: string): Rng { return new Rng(`${this.label}/${label}`); }
}

/** Root stream for a named subsystem: rng('trees/T_9_7'). */
export const rng = (label: string) => new Rng(`${WORLD_SEED}:${label}`);

/** Stateless hash -> [0,1) for integer coordinates (stable per-instance jitter). */
export function hash01(x: number, y = 0, z = 0): number {
  let h = Math.imul(x | 0, 374761393) ^ Math.imul(y | 0, 668265263) ^ Math.imul(z | 0, 2147483647) ^ WORLD_SEED;
  h = Math.imul(h ^ (h >>> 13), 1274126177);
  h ^= h >>> 16;
  return (h >>> 0) / 4294967296;
}
