// Boot: renderer, loop, world (CLAUDE.md §3).
import './style.css';
import { App } from './app';
import { installCssPalette } from './core/palette';
import { createWorld } from './world/world';

installCssPalette();
const loading = document.createElement('div');
loading.className = 'loading';
loading.innerHTML = '<h1>CATHEDRAL MOUNT</h1><div id="loadmsg">generating city (seed 1795)…</div>';
document.body.appendChild(loading);

const app = new App(document.getElementById('app')!);
const api = app.api();
(window as any).__cm = api;
app.start();
createWorld(app).then(async (world) => {
  app.setWorld(world);
  await world.ready();
  loading.remove();
  (window as any).__cmReady = true;
}).catch((e) => {
  console.error(e);
  (document.getElementById('loadmsg') as HTMLElement).textContent = 'Error: ' + e.message;
});
