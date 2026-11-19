// Interior-mapping window shader (CLAUDE.md §7.6): far windows show fake rooms with correct floor heights,
// wall/floor colors from the building's finish rules and lit/unlit states, so the city never looks
// hollow. When a building's real interior is streamed in, its far glass is discarded (uLoaded[]).
import { Color, ShaderMaterial, UniformsLib, UniformsUtils, Vector3 } from 'three';
import { registerMaterialFactory } from '../core/materials';
import { pc } from '../core/palette';

export const MAX_LOADED = 24;
export const imUniforms = {
  uLit: { value: 0.15 },
  uNight: { value: 0 },
  uSky: { value: new Color() },
  uWarm: { value: new Color() },
  uCool: { value: new Color() },
  uCeil: { value: new Color() },
  uSun: { value: new Vector3(0, 1, 0) },
  uLoaded: { value: new Float32Array(MAX_LOADED).fill(-1) },
};

/** Per-window vertex attributes (constant over each window). */
export interface IMAttrs { imO: [number, number, number]; imT: [number, number]; imF: [number, number, number, number]; imR: [number, number, number, number]; imC: [number, number, number]; imD: [number, number, number]; }
export function imAttrs(a: IMAttrs): Record<string, number[]> { return { imO: a.imO, imT: a.imT, imF: a.imF, imR: a.imR, imC: a.imC, imD: a.imD }; }

let material: ShaderMaterial | null = null;
export function interiorMappingMaterial(): ShaderMaterial {
  if (material) return material;
  imUniforms.uWarm.value.copy(pc('INTERIOR_WARM'));
  imUniforms.uCool.value.copy(pc('INTERIOR_COOL'));
  imUniforms.uCeil.value.copy(pc('CEILING_WHITE'));
  material = new ShaderMaterial({
    name: 'glassFar',
    fog: true,
    uniforms: UniformsUtils.merge([UniformsLib.fog, {}]),
    vertexShader: /* glsl */ `
      attribute vec3 imO; attribute vec2 imT; attribute vec4 imF; attribute vec4 imR; attribute vec3 imC; attribute vec3 imD;
      varying vec3 vW; varying vec3 vN; varying vec3 vO; varying vec2 vT; varying vec4 vF; varying vec4 vR; varying vec3 vC; varying vec3 vD;
      #include <fog_pars_vertex>
      void main() {
        vec4 wp = modelMatrix * vec4(position, 1.0);
        vW = wp.xyz; vN = normalize(mat3(modelMatrix) * normal);
        vO = imO; vT = imT; vF = imF; vR = imR; vC = imC; vD = imD;
        vec4 mvPosition = viewMatrix * wp;
        gl_Position = projectionMatrix * mvPosition;
        #include <fog_vertex>
      }`,
    fragmentShader: /* glsl */ `
      uniform float uLit, uNight; uniform vec3 uSky, uWarm, uCool, uCeil, uSun; uniform float uLoaded[${MAX_LOADED}];
      varying vec3 vW; varying vec3 vN; varying vec3 vO; varying vec2 vT; varying vec4 vF; varying vec4 vR; varying vec3 vC; varying vec3 vD;
      #include <fog_pars_fragment>
      float h1(vec3 p) { p = fract(p * vec3(0.1031, 0.1030, 0.0973)); p += dot(p, p.yxz + 33.33); return fract((p.x + p.y) * p.z); }
      void main() {
        for (int i = 0; i < ${MAX_LOADED}; i++) if (abs(uLoaded[i] - vR.w) < 0.5) discard;
        vec3 V = normalize(vW - cameraPosition);
        vec3 T = normalize(vec3(vT.x, 0.0, vT.y));
        vec3 N = normalize(vN);
        float cw = max(vR.x, 0.5);
        float u = dot(vW - vO, T) - vR.y;
        float cell = floor(u / cw);
        float cu = u - cell * cw;
        float v = vW.y - vO.y - vF.x;
        vec3 d = vec3(dot(V, T), V.y, dot(V, -N));
        d.z = max(d.z, 1e-3);
        float ceilH = vF.z, depth = vF.w;
        float tb = depth / d.z;
        float tx = d.x > 0.0 ? (cw - cu) / max(d.x, 1e-4) : cu / max(-d.x, 1e-4);
        float ty = d.y > 0.0 ? (ceilH - v) / max(d.y, 1e-4) : v / max(-d.y, 1e-4);
        float t = min(tb, min(tx, ty));
        vec3 hp = vec3(cu, v, 0.0) + d * t;
        vec3 col;
        if (t == ty) col = d.y > 0.0 ? uCeil * 0.9 : vD * 0.8;
        else if (t == tx) col = vC * 0.82;
        else col = vC;
        float depthShade = mix(1.0, 0.55, clamp(hp.z / depth, 0.0, 1.0));
        float seed = vR.z + vF.x * 3.17;
        float rnd = h1(vec3(cell, seed, vO.x * 0.01 + vO.z * 0.013));
        float lit = step(rnd, uLit);
        float blind = step(0.72, h1(vec3(cell + 7.0, seed, 3.0)));
        float dayDim = (0.28 + 0.12 * clamp(uSun.y, 0.0, 1.0)) * mix(1.0, 0.07, uNight);
        vec3 lamp = rnd > 0.5 ? uWarm : uCool;
        vec3 interior = col * depthShade * mix(dayDim, 1.35, lit * mix(0.35, 1.0, uNight)) * mix(vec3(1.0), lamp, lit);
        // blinds lowered to a random height
        float bl = mix(ceilH * 0.35, ceilH, h1(vec3(cell, seed, 11.0)));
        if (blind > 0.5 && v > bl) interior = vC * 0.7 * mix(dayDim * 1.4, 1.2, lit);
        if (v > ceilH) interior = vec3(0.05);
        float fres = 0.08 + 0.6 * pow(1.0 - clamp(dot(-V, N), 0.0, 1.0), 4.0);
        vec3 c = mix(interior, uSky, fres * mix(1.0, 0.35, uNight));
        gl_FragColor = vec4(c, 1.0);
        #include <tonemapping_fragment>
        #include <colorspace_fragment>
        #include <fog_fragment>
      }`,
  });
  Object.assign(material.uniforms, imUniforms);
  material.userData.matKey = 'glassFar';
  return material;
}

registerMaterialFactory((key) => (key === 'glassFar' ? interiorMappingMaterial() : null));

/** Mark a building index as loaded (its far glass is hidden) or unloaded. */
export function setInteriorLoaded(index: number, loaded: boolean) {
  const a = imUniforms.uLoaded.value;
  if (loaded) { if (a.includes(index)) return; const i = a.indexOf(-1); if (i >= 0) a[i] = index; }
  else { const i = a.indexOf(index); if (i >= 0) a[i] = -1; }
}
