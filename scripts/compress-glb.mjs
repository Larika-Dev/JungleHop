import { NodeIO } from '@gltf-transform/core';
import { ALL_EXTENSIONS } from '@gltf-transform/extensions';
import { dedup, weld, quantize, meshopt, prune, reorder } from '@gltf-transform/functions';
import { MeshoptEncoder, MeshoptDecoder } from 'meshoptimizer';
import fs from 'node:fs';
await MeshoptEncoder.ready; await MeshoptDecoder.ready;
const io = new NodeIO().registerExtensions(ALL_EXTENSIONS).registerDependencies({ 'meshopt.encoder': MeshoptEncoder, 'meshopt.decoder': MeshoptDecoder });
const [inp, out] = process.argv.slice(2);
const quiet = console.warn; console.warn = () => {};
const doc = await io.read(inp);
// colors are all-white per material in exterior geometry: drop them (materials carry the color)
let dropped = 0;
for (const m of doc.getRoot().listMeshes()) for (const p of m.listPrimitives()) {
  for (const sem of p.listSemantics()) if (sem.startsWith('_')) p.setAttribute(sem, null); // interior-mapping data (runtime only)
  const c = p.getAttribute('COLOR_0'); if (!c) continue;
  const a = c.getArray(); let white = true; for (let i = 0; i < a.length; i++) if (a[i] < 0.999) { white = false; break; }
  if (white && p.getMaterial()?.getName() !== 'terrain') { p.setAttribute('COLOR_0', null); dropped++; }
}
await doc.transform(dedup(), weld(), prune(), reorder({ encoder: MeshoptEncoder }), quantize({ quantizePosition: 16, quantizeNormal: 8, quantizeTexcoord: 14, quantizeColor: 8 }), meshopt({ encoder: MeshoptEncoder, level: 'high' }));
await io.write(out, doc);
console.log(`colors dropped on ${dropped} prims; ${(fs.statSync(inp).size / 1e6).toFixed(1)} MB -> ${(fs.statSync(out).size / 1e6).toFixed(2)} MB`);
