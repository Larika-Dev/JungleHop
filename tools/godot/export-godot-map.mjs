// Converts export/cathedral-mount-map.glb into Godot-ready assets (Godot cannot read EXT_mesh_gpu_instancing):
//   godot/assets/map/city.glb    terrain, roads, building massing, landmark exteriors (no instancing)
//   godot/assets/map/trees.glb   one prototype mesh per tree species (node per species, identity transform)
//   godot/data/trees.json        { species: [[x,y,z,rotY,scaleXZ,scaleY], ...] } for MultiMeshInstance3D
// Usage: node tools/godot/export-godot-map.mjs   (run `npm run export` first if the map changed)
import { NodeIO } from '@gltf-transform/core';
import { ALL_EXTENSIONS } from '@gltf-transform/extensions';
import { prune } from '@gltf-transform/functions';
import fs from 'node:fs';

const SRC = 'export/cathedral-mount-map.glb';
const io = new NodeIO().registerExtensions(ALL_EXTENSIONS);

function quatYaw([x, y, z, w]) { return Math.atan2(2 * (w * y + x * z), 1 - 2 * (y * y + z * z)); }
const r3 = (v) => Math.round(v * 1000) / 1000;

// ---- city.glb: everything except instanced trees
const city = await io.read(SRC);
const trees = {};
for (const n of city.getRoot().listNodes()) {
  const inst = n.getExtension('EXT_mesh_gpu_instancing');
  if (!inst) continue;
  const T = inst.getAttribute('TRANSLATION'), R = inst.getAttribute('ROTATION'), S = inst.getAttribute('SCALE');
  const species = n.getName().replace(/^trees_/, '');
  const list = [];
  const t = [0, 0, 0], r = [0, 0, 0, 1], s = [1, 1, 1];
  for (let i = 0; i < T.getCount(); i++) {
    T.getElement(i, t); if (R) R.getElement(i, r); if (S) S.getElement(i, s);
    list.push([r3(t[0]), r3(t[1]), r3(t[2]), r3(quatYaw(r)), r3(s[0]), r3(s[1])]);
  }
  trees[species] = list;
  n.dispose();
}
for (const e of city.getRoot().listExtensionsUsed()) if (e.extensionName === 'EXT_mesh_gpu_instancing') e.dispose();
await city.transform(prune());
fs.mkdirSync('godot/assets/map', { recursive: true });
await io.write('godot/assets/map/city.glb', city);
fs.writeFileSync('godot/data/trees.json', JSON.stringify(trees));

// ---- trees.glb: prototypes only
const proto = await io.read(SRC);
const scene = proto.getRoot().getDefaultScene() ?? proto.getRoot().listScenes()[0];
for (const n of proto.getRoot().listNodes()) {
  if (n.getExtension('EXT_mesh_gpu_instancing')) { n.setExtension('EXT_mesh_gpu_instancing', null); n.setTranslation([0, 0, 0]); n.setRotation([0, 0, 0, 1]); n.setScale([1, 1, 1]); }
  else if (n.getMesh()) n.dispose();
}
for (const e of proto.getRoot().listExtensionsUsed()) if (e.extensionName === 'EXT_mesh_gpu_instancing') e.dispose();
await proto.transform(prune({ keepLeaves: true }));
await io.write('godot/assets/map/trees.glb', proto);

const total = Object.values(trees).reduce((a, l) => a + l.length, 0);
console.log(`city.glb ${(fs.statSync('godot/assets/map/city.glb').size / 1e6).toFixed(1)} MB, trees.glb ${(fs.statSync('godot/assets/map/trees.glb').size / 1e3).toFixed(0)} kB, ${total} trees in ${Object.keys(trees).length} species`);
