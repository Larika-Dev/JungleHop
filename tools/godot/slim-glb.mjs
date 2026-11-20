// Slim a building GLB for Godot: drop runtime-only attributes (_IM*), all-white vertex colors and UVs
// on untextured materials, weld, simplify (small error), prune. No meshopt/quantize (Godot can't read them).
// Usage: node tools/godot/slim-glb.mjs in.glb out.glb [error]
import { NodeIO } from '@gltf-transform/core';
import { dedup, weld, prune, simplify, flatten, join } from '@gltf-transform/functions';
import { MeshoptSimplifier } from 'meshoptimizer';
import fs from 'node:fs';
await MeshoptSimplifier.ready;
const [inp, out, err] = process.argv.slice(2);
const io = new NodeIO();
const doc = await io.read(inp);
for (const m of doc.getRoot().listMeshes()) for (const p of m.listPrimitives()) {
  for (const sem of p.listSemantics()) if (sem.startsWith('_')) p.setAttribute(sem, null);
  const c = p.getAttribute('COLOR_0');
  if (c) { const a = c.getArray(); let white = true; for (let i = 0; i < a.length; i++) if (a[i] < 0.999) { white = false; break; } if (white) p.setAttribute('COLOR_0', null); }
  const name = p.getMaterial()?.getName() ?? '';
  if (!name.startsWith('tex:') && !name.startsWith('brick:')) p.setAttribute('TEXCOORD_0', null);
}
await doc.transform(dedup(), flatten(), join(), weld(), simplify({ simplifier: MeshoptSimplifier, ratio: 0.0, error: Number(err ?? 0.0015), lockBorder: false }), prune());
await io.write(out, doc);
console.log(`${inp}: ${(fs.statSync(inp).size / 1e6).toFixed(1)} -> ${(fs.statSync(out).size / 1e6).toFixed(1)} MB`);
