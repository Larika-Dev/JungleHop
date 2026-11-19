// Gradient sky dome + sun disc (colors from palette via uniforms; no literals in shader code).
import { BackSide, Color, Mesh, ShaderMaterial, SphereGeometry, Vector3 } from 'three';

export class Sky {
  mesh: Mesh;
  uniforms = {
    zenith: { value: new Color() },
    horizon: { value: new Color() },
    ground: { value: new Color() },
    sunDir: { value: new Vector3(0, 1, 0) },
    sunColor: { value: new Color() },
    sunSize: { value: 0.9995 },
    stars: { value: 0 },
    overcast: { value: 0 },
  };
  constructor(radius = 5000) {
    const mat = new ShaderMaterial({
      side: BackSide, depthWrite: false, fog: false, uniforms: this.uniforms,
      vertexShader: /* glsl */ `
        varying vec3 vDir;
        void main(){ vDir = normalize(position); vec4 p = projectionMatrix * modelViewMatrix * vec4(position,1.0); gl_Position = p.xyww; }`,
      fragmentShader: /* glsl */ `
        uniform vec3 zenith, horizon, ground, sunDir, sunColor; uniform float sunSize, stars, overcast;
        varying vec3 vDir;
        float hash(vec3 p){ p = fract(p*0.3183099+0.1); p*=17.0; return fract(p.x*p.y*p.z*(p.x+p.y+p.z)); }
        void main(){
          vec3 d = normalize(vDir);
          float h = d.y;
          vec3 col = h > 0.0 ? mix(horizon, zenith, pow(clamp(h,0.0,1.0), 0.55)) : mix(horizon, ground, clamp(-h*6.0,0.0,1.0));
          float sd = dot(d, normalize(sunDir));
          col += sunColor * (1.0-overcast) * (smoothstep(sunSize, 1.0, sd) * 4.0 + pow(max(sd,0.0), 64.0) * 0.35 + pow(max(sd,0.0),6.0)*0.12);
          if (stars > 0.0 && h > 0.0) { vec3 q = floor(d*420.0); float s = step(0.9975, hash(q)); col += vec3(s*stars*h); }
          gl_FragColor = vec4(col, 1.0);
          #include <tonemapping_fragment>
          #include <colorspace_fragment>
        }`,
    });
    this.mesh = new Mesh(new SphereGeometry(radius, 48, 24), mat);
    this.mesh.name = 'sky';
    this.mesh.frustumCulled = false;
    this.mesh.renderOrder = -1;
  }
}
