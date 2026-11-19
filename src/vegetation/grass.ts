// Instanced grass tufts within 25 m of the camera (CLAUDE.md §8): GRASS_OCT base, GRASS_WORN on desire
// paths; skips pavement, buildings and steep clay banks.
import { BufferGeometry, Color, DoubleSide, Float32BufferAttribute, InstancedMesh, Matrix4, MeshStandardMaterial, Quaternion, Vector3 } from 'three';
import { jitter } from '../core/palette';
import { hash01 } from '../core/rng';
import { Terrain } from '../terrain/terrain';
import { splatAt } from '../terrain/terrainMesh';
import { canPlant } from './placement';

const R = 25, STEP = 0.32;
function tuftGeometry(): BufferGeometry {
  const pos: number[] = [], nor: number[] = [];
  for (let k = 0; k < 3; k++) {
    const a = (k / 3) * Math.PI, ca = Math.cos(a) * 0.09, sa = Math.sin(a) * 0.09;
    const lean = 0.04 * (k - 1);
    pos.push(-ca, 0, -sa, ca, 0, sa, lean, 0.16 + k * 0.03, 0);
    for (let i = 0; i < 3; i++) nor.push(0, 1, 0);
  }
  const g = new BufferGeometry();
  g.setAttribute('position', new Float32BufferAttribute(pos, 3));
  g.setAttribute('normal', new Float32BufferAttribute(nor, 3));
  return g;
}

export class GrassField {
  mesh: InstancedMesh;
  private last = new Vector3(1e9, 0, 1e9);
  private memo = new Map<number, number>(); // cell -> packed (y, worn)
  constructor(cap = 26000) {
    const m = new MeshStandardMaterial({ side: DoubleSide, roughness: 1 });
    m.userData.matKey = 'leafy:GRASS_OCT';
    this.mesh = new InstancedMesh(tuftGeometry(), m, cap);
    this.mesh.name = 'grass-near'; this.mesh.count = 0; this.mesh.frustumCulled = false; this.mesh.receiveShadow = true;
  }
  update(cam: Vector3) {
    if (cam.distanceToSquared(this.last) < 4) return;
    this.last.copy(cam);
    const T = Terrain.get();
    const m = new Matrix4(), q = new Quaternion(), s = new Vector3(), p = new Vector3(), c = new Color(), up = new Vector3(0, 1, 0);
    let n = 0;
    const cap = this.mesh.instanceMatrix.count;
    const ix0 = Math.floor((cam.x - R) / STEP), ix1 = Math.floor((cam.x + R) / STEP), iz0 = Math.floor((cam.z - R) / STEP), iz1 = Math.floor((cam.z + R) / STEP);
    for (let i = ix0; i <= ix1 && n < cap; i++) for (let j = iz0; j <= iz1 && n < cap; j++) {
      const hx = hash01(i, j, 5), hz = hash01(j, i, 9);
      const x = (i + hx) * STEP, z = (j + hz) * STEP;
      const d2 = (x - cam.x) ** 2 + (z - cam.z) ** 2;
      if (d2 > R * R) continue;
      if (d2 > (R * 0.6) ** 2 && hash01(i, j, 1) < (Math.sqrt(d2) - R * 0.6) / (R * 0.4)) continue; // thin out with distance
      const key = i * 73856093 ^ j * 19349663;
      let info = this.memo.get(key);
      if (info === undefined) {
        const cx = Math.floor(x / 2) * 2, cz = Math.floor(z / 2) * 2;
        const ck = (cx * 7919) ^ (cz * 104729);
        let cellInfo = this.memo.get(ck + 0.5);
        if (cellInfo === undefined) {
          const sp = splatAt(cx + 1, cz + 1, T);
          cellInfo = canPlant(cx + 1, cz + 1, 0.3) && sp[0] > 0.45 ? (sp[1] > 0.25 ? 2 : 1) : 0;
          this.memo.set(ck + 0.5, cellInfo);
        }
        info = cellInfo;
        this.memo.set(key, info);
        if (this.memo.size > 600000) this.memo.clear();
      }
      if (!info) continue;
      p.set(x, T.height(x, z) - 0.01, z);
      if (Math.abs(p.y - cam.y) > 30) continue;
      q.setFromAxisAngle(up, hash01(i, j, 3) * 6.28);
      const sc = 0.7 + hash01(i, j, 4) * 0.8;
      s.set(sc, sc * (info === 2 ? 0.55 : 1), sc);
      m.compose(p, q, s);
      this.mesh.setMatrixAt(n, m);
      jitter(info === 2 ? 'GRASS_WORN' : 'GRASS_OCT', hash01(i, j, 6), hash01(i, j, 7), 0.12, 6, c);
      this.mesh.setColorAt(n, c);
      n++;
    }
    this.mesh.count = n;
    this.mesh.instanceMatrix.needsUpdate = true;
    if (this.mesh.instanceColor) this.mesh.instanceColor.needsUpdate = true;
  }
}
