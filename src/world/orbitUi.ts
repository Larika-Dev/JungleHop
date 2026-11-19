// Model-viewer overlay for ?view=orbit: legend card, district & landmark labels projected over the
// city, lighting presets, fly-to. The city keeps streaming full-detail tiles (cm geometry, interiors)
// around the orbit target; impostors cover everything farther away. Colors are palette CSS vars only.
import { Vector3 } from 'three';
import type { App } from '../app';
import type { PresetName } from '../lighting/presets';
import { DISTRICTS, LANDMARKS } from './layout';
import { Terrain } from '../terrain/terrain';
import { cityPlan } from './cityPlan';
import { buildingMatrix } from '../buildings/exterior';

const STYLE = `
.ov-card { position: fixed; top: calc(14px + env(safe-area-inset-top, 0px)); left: max(14px, env(safe-area-inset-left, 0px)); width: min(340px, calc(100vw - 28px));
  background: color-mix(in srgb, var(--c-ONSU_NAVY) 88%, transparent); color: var(--c-MARKING_WHITE); border: 1px solid color-mix(in srgb, var(--c-HEAVEN_BLUE) 40%, transparent);
  border-radius: 6px; padding: 14px 16px 12px; display: grid; gap: 9px; font-family: 'Libre Baskerville', Georgia, serif; z-index: 20; backdrop-filter: blur(6px); }
.ov-card h1 { margin: 0; font: 600 26px/1 'Oswald', 'Arial Narrow', sans-serif; letter-spacing: .12em; }
.ov-card p { margin: 0; font-size: 11.5px; line-height: 1.5; color: color-mix(in srgb, var(--c-MARKING_WHITE) 72%, var(--c-HEAVEN_BLUE)); }
.ov-row { display: flex; flex-wrap: wrap; gap: 6px; }
.ov-card button { font: 500 11.5px 'Oswald', sans-serif; letter-spacing: .08em; text-transform: uppercase; color: var(--c-MARKING_WHITE); background: transparent;
  border: 1px solid color-mix(in srgb, var(--c-HEAVEN_BLUE) 55%, transparent); border-radius: 4px; padding: 5px 9px; cursor: pointer; }
.ov-card button[aria-pressed="true"] { background: var(--c-HEAVEN_BLUE); color: var(--c-ONSU_NAVY); border-color: var(--c-HEAVEN_BLUE); }
.ov-card button:hover { border-color: var(--c-SUN_GOLDEN); }
.ov-card button:focus-visible { outline: 2px solid var(--c-SUN_GOLDEN); outline-offset: 2px; }
.ov-stat { font: 500 11px 'Oswald', sans-serif; letter-spacing: .06em; color: var(--c-HEAVEN_BLUE); font-variant-numeric: tabular-nums; }
.ov-labels { position: fixed; inset: 0; pointer-events: none; overflow: hidden; z-index: 10; }
.ov-labels.off { display: none; }
.ov-lab { position: absolute; left: 0; top: 0; white-space: nowrap; will-change: transform; }
.ov-district { font: 600 15px 'Oswald', sans-serif; letter-spacing: .22em; text-transform: uppercase; color: var(--c-MARKING_WHITE);
  text-shadow: 0 1px 3px var(--c-SKY_NIGHT), 0 0 12px var(--c-SKY_NIGHT); }
.ov-landmark { pointer-events: auto; cursor: pointer; display: flex; align-items: center; gap: 6px; font: 12px 'Libre Baskerville', Georgia, serif; color: var(--c-MARKING_WHITE);
  background: color-mix(in srgb, var(--c-ONSU_NAVY) 88%, transparent); border: 1px solid color-mix(in srgb, var(--c-HEAVEN_BLUE) 45%, transparent); padding: 3px 8px 3px 4px; border-radius: 999px; }
.ov-landmark b { font: 500 11px 'Oswald', sans-serif; color: var(--c-ONSU_NAVY); background: var(--c-HEAVEN_BLUE); border-radius: 50%; width: 18px; height: 18px; display: grid; place-items: center; }
.ov-landmark:hover, .ov-landmark:focus-visible { border-color: var(--c-SUN_GOLDEN); outline: none; }
@media (max-width: 560px) { .ov-card p.hint { display: none; } .ov-landmark span { display: none; } .ov-district { font-size: 12px; } }
`;

export function installOrbitUi(app: App, opts: { tilesActive: () => number; buildings: number }) {
  const T = Terrain.get();
  const st = document.createElement('style'); st.textContent = STYLE; document.head.appendChild(st);
  const layer = document.createElement('div'); layer.className = 'ov-labels'; document.body.appendChild(layer);
  const card = document.createElement('section'); card.className = 'ov-card'; card.setAttribute('aria-label', 'Model viewer');
  card.innerHTML = `
    <h1>CATHEDRAL MOUNT</h1>
    <p>Old North State University, State of Pamlico. Generated live from seed 1795 at full centimeter detail: every brick, sash, dentil and curb near the view center.</p>
    <div class="ov-row" role="group" aria-label="Lighting">
      <button type="button" data-p="golden" aria-pressed="true">Golden hour</button><button type="button" data-p="midday" aria-pressed="false">Midday</button>
      <button type="button" data-p="night" aria-pressed="false">Night</button><button type="button" data-p="rain" aria-pressed="false">Rain</button>
    </div>
    <div class="ov-row">
      <button type="button" id="ov-labels" aria-pressed="true">Labels</button>
      <button type="button" id="ov-city">Whole city</button>
      <button type="button" id="ov-summit">The Summit</button>
      <button type="button" id="ov-close">Brick close-up</button>
    </div>
    <div class="ov-stat" id="ov-stat"></div>
    <p class="hint">Drag to orbit, right-drag to pan, scroll to zoom toward the cursor. Click a numbered landmark to fly there.</p>`;
  document.body.appendChild(card);

  const presetBtns = [...card.querySelectorAll<HTMLButtonElement>('button[data-p]')];
  for (const b of presetBtns) b.addEventListener('click', () => {
    app.lighting.apply(b.dataset.p as PresetName);
    for (const o of presetBtns) o.setAttribute('aria-pressed', String(o === b));
  });
  const lb = card.querySelector<HTMLButtonElement>('#ov-labels')!;
  lb.addEventListener('click', () => { const on = lb.getAttribute('aria-pressed') !== 'true'; lb.setAttribute('aria-pressed', String(on)); layer.classList.toggle('off', !on); });

  // ------------------------------------------------------------------ fly-to
  const c = app.orbit!;
  let fly: { t: number; fT: Vector3; fP: Vector3; tT: Vector3; tP: Vector3 } | null = null;
  const reduce = matchMedia('(prefers-reduced-motion: reduce)').matches;
  const flyTo = (target: Vector3, pos: Vector3) => { fly = { t: reduce ? 0.999 : 0, fT: c.target.clone(), fP: app.camera.position.clone(), tT: target, tP: pos }; };
  const around = (x: number, z: number, dist: number, elev = 0.55) => {
    const y = T.height(x, z), dir = app.camera.position.clone().sub(c.target).setY(0).normalize();
    if (!isFinite(dir.x)) dir.set(0.5, 0, 0.8).normalize();
    return [new Vector3(x, y, z), new Vector3(x, y, z).addScaledVector(dir, dist * Math.cos(elev)).setY(y + dist * Math.sin(elev))] as const;
  };
  card.querySelector('#ov-city')!.addEventListener('click', () => flyTo(new Vector3(-90, -12, 240), new Vector3(-860, 760, 1260)));
  card.querySelector('#ov-summit')!.addEventListener('click', () => { const [t, p] = around(0, 0, 160, 0.5); flyTo(t, p); });
  // a campus Flemish-bond wall at arm's length: Elder West's front face, between ground-floor windows
  card.querySelector('#ov-close')!.addEventListener('click', () => {
    const s = cityPlan().byId.get('LM06_ELDER_WEST')?.spec;
    if (!s) return;
    const M = buildingMatrix(s), W = s.w / 100;
    flyTo(new Vector3(W * 0.5 + 0.9, 2.2, 0).applyMatrix4(M), new Vector3(W * 0.5 + 0.35, 2.35, -0.75).applyMatrix4(M));
  });

  // ------------------------------------------------------------------ labels
  const labels: { el: HTMLElement; p: Vector3; kind: 'district' | 'landmark' }[] = [];
  for (const d of DISTRICTS) {
    if (d.id === 'summit') continue;
    const el = document.createElement('div'); el.className = 'ov-lab ov-district'; el.textContent = d.name; layer.appendChild(el);
    labels.push({ el, kind: 'district', p: new Vector3(d.label[0], T.height(d.label[0], d.label[1]) + 14, d.label[1]) });
  }
  for (const l of LANDMARKS) {
    const el = document.createElement('button'); el.type = 'button'; el.className = 'ov-lab ov-landmark';
    el.innerHTML = `<b>${l.n}</b><span></span>`; el.querySelector('span')!.textContent = l.name; el.setAttribute('aria-label', `Fly to ${l.name}`);
    el.addEventListener('click', () => { const [t, p] = around(l.x, l.z, 140); flyTo(t, p); });
    layer.appendChild(el);
    labels.push({ el, kind: 'landmark', p: new Vector3(l.x, T.height(l.x, l.z) + 32, l.z) });
  }
  const v = new Vector3();
  const stat = card.querySelector<HTMLElement>('#ov-stat')!;
  let statT = 0;
  const ease = (t: number) => (t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2);
  app.frameHooks.push((dt) => {
    if (fly) {
      fly.t = Math.min(1, fly.t + dt / 1.8);
      const k = ease(fly.t);
      c.target.lerpVectors(fly.fT, fly.tT, k); app.camera.position.lerpVectors(fly.fP, fly.tP, k);
      if (fly.t >= 1) fly = null;
    }
    const w = innerWidth, h = innerHeight, dist = app.camera.position.distanceTo(c.target);
    // declutter: nearest labels first; skip any whose box overlaps one already placed
    const cam = app.camera.position;
    const order = labels.map((l) => ({ l, d: l.p.distanceTo(cam) })).sort((a, b) => a.d - b.d);
    const placed: [number, number, number, number][] = [];
    for (const { l, d } of order) {
      v.copy(l.p).project(app.camera);
      const far = l.kind === 'district' ? dist > 300 : dist > 60;
      let vis = far && d < Math.max(1400, dist * 2.2) && v.z < 1 && Math.abs(v.x) < 1.05 && Math.abs(v.y) < 1.05;
      const x = (v.x * 0.5 + 0.5) * w, y = (-v.y * 0.5 + 0.5) * h;
      if (vis) {
        const bw = (l.el.offsetWidth || 120) / 2 + 4, bh = (l.el.offsetHeight || 22) / 2 + 3;
        const box: [number, number, number, number] = [x - bw, y - bh, x + bw, y + bh];
        if (placed.some((p) => box[0] < p[2] && box[2] > p[0] && box[1] < p[3] && box[3] > p[1])) vis = false;
        else placed.push(box);
      }
      l.el.style.display = vis ? '' : 'none';
      if (vis) l.el.style.transform = `translate(${x.toFixed(1)}px, ${y.toFixed(1)}px) translate(-50%, -50%)`;
    }
    if ((statT += dt) > 0.4) {
      statT = 0;
      const d = dist >= 1000 ? `${(dist / 1000).toFixed(2)} km` : dist >= 2 ? `${dist.toFixed(0)} m` : `${(dist * 100).toFixed(0)} cm`;
      stat.textContent = `VIEW DISTANCE ${d} · FULL-DETAIL TILES ${opts.tilesActive()} · ${opts.buildings} BUILDINGS`;
    }
  });
}
