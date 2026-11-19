// Tile streaming (CLAUDE.md §17): tiles load in a 3x3 ring around the player, the next ring is
// prefetched (built but hidden), tiles beyond the keep radius are disposed. Builds are time-sliced.
import { Object3D } from 'three';
import { ring, tileAt, tileName, type TileId } from './tiles';

export interface TileContent {
  object: Object3D;
  /** Called when the tile becomes active (visible + collidable). */
  activate?(): void;
  /** Called when the tile becomes inactive (prefetched only). */
  deactivate?(): void;
  dispose(): void;
}
export type TileLoader = (t: TileId) => Promise<TileContent>;

interface Entry { id: TileId; name: string; state: 'loading' | 'ready'; content?: TileContent; active: boolean; promise?: Promise<void>; }

export class TileStreamer {
  entries = new Map<string, Entry>();
  root = new Object3D();
  private queue: TileId[] = [];
  private busy = 0;
  onChange: (() => void)[] = [];
  constructor(private loader: TileLoader, public opts = { active: 1, prefetch: 2, keep: 3, concurrency: 1 }) { this.root.name = 'tiles'; }

  /** Recompute desired sets around plan position (x, z). */
  update(x: number, z: number) {
    const c = tileAt(x, z);
    const active = new Set(ring(c, this.opts.active).map(tileName));
    const want = ring(c, this.opts.prefetch).sort((a, b) => dist(a, c) - dist(b, c));
    const keep = new Set(ring(c, this.opts.keep).map(tileName));
    this.queue = want.filter((t) => !this.entries.has(tileName(t)));
    for (const [name, e] of this.entries) {
      if (!keep.has(name)) {
        if (e.state === 'ready') { e.content!.object.removeFromParent(); e.content!.dispose(); this.entries.delete(name); this.emit(); }
        continue;
      }
      const shouldBeActive = active.has(name);
      if (e.state === 'ready' && shouldBeActive !== e.active) this.setActive(e, shouldBeActive);
    }
    this.pump(active);
  }
  private setActive(e: Entry, on: boolean) {
    e.active = on;
    e.content!.object.visible = on;
    if (on) e.content!.activate?.(); else e.content!.deactivate?.();
    this.emit();
  }
  private pump(active: Set<string>) {
    while (this.busy < this.opts.concurrency && this.queue.length) {
      const t = this.queue.shift()!;
      const name = tileName(t);
      if (this.entries.has(name)) continue;
      const e: Entry = { id: t, name, state: 'loading', active: false };
      this.entries.set(name, e);
      this.busy++;
      e.promise = this.loader(t).then((content) => {
        this.busy--;
        if (!this.entries.has(name)) { content.dispose(); return; }
        e.content = content; e.state = 'ready';
        content.object.name = name;
        this.root.add(content.object);
        content.object.visible = false;
        if (this.lastActive.has(name)) this.setActive(e, true); else this.emit();
        this.pump(this.lastActive);
      }).catch((err) => { this.busy--; console.error('tile load failed', name, err); this.entries.delete(name); });
    }
    this.lastActive = active;
  }
  private lastActive = new Set<string>();
  private emit() { for (const f of this.onChange) f(); }

  /** Resolves when every tile in the active ring is ready. */
  async ready(x: number, z: number): Promise<void> {
    this.update(x, z);
    const names = ring(tileAt(x, z), this.opts.active).map(tileName);
    for (;;) {
      const pending = names.map((n) => this.entries.get(n)).filter((e) => !e || e.state !== 'ready');
      if (!pending.length) return;
      await Promise.all(pending.map((e) => e?.promise ?? new Promise((r) => setTimeout(r, 50))));
      this.update(x, z);
    }
  }
  isActive(name: string) { return this.entries.get(name)?.active ?? false; }
  activeNames(): string[] { return [...this.entries.values()].filter((e) => e.active).map((e) => e.name); }
}

const dist = (a: TileId, b: TileId) => Math.max(Math.abs(a.col - b.col), Math.abs(a.row - b.row)) * 10 + Math.abs(a.col - b.col) + Math.abs(a.row - b.row);

/** Yield to the browser so tile builds don't hitch the frame. */
export const yieldFrame = () => new Promise<void>((r) => (typeof requestAnimationFrame !== 'undefined' ? setTimeout(r, 0) : r()));
