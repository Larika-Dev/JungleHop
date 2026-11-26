// Interior finishes (InteriorStreamer). One palette color per material plus a surface pattern
// projected in world space: 0 paint, 1 wood planks, 2 tile grid, 3 carpet, 4 concrete,
// 5 terrazzo, 6 plaster, 7 brick.
shader_type spatial;
render_mode diffuse_burley;
#include "res://world/shaders/noise.gdshaderinc"

uniform vec3 albedo : source_color = vec3(0.9);
uniform int pattern = 0;
uniform float tile = 0.305;
uniform vec3 grout : source_color = vec3(0.79, 0.776, 0.749);
uniform float base_rough = 0.85;

void vertex() {
}

void fragment() {
	// world position / normal from view space (no extra varyings: keeps the depth prepass and
	// color pass vertex code identical, which avoids depth-equal mismatches on some drivers)
	vec3 wpos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 wnrm = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 n = abs(wnrm);
	vec2 p = n.y > 0.5 ? wpos.xz : (n.x > n.z ? wpos.zy : wpos.xy);
	vec3 col = albedo;
	float rough = base_rough;
	float h = 0.0;
	float spec = 0.45;
	if (pattern == 1) {
		// 9 cm boards, staggered ends, grain along the board
		vec2 b = cm_bricks(p.yx, vec2(1.22, 0.09), 0.003);
		float grain = cm_noise(vec2(p.x * 1.5, p.y * 70.0) + b.y * 10.0);
		col *= (0.82 + 0.3 * b.y) * (0.9 + 0.2 * grain);
		col = mix(col, col * 0.4, b.x);
		rough = 0.35 + 0.2 * grain;   // finished floors have a sheen
		h = 1.0 - b.x;
	} else if (pattern == 2) {
		vec2 g = fract(p / tile) * tile;
		vec2 e = min(g, tile - g);
		float j = 1.0 - smoothstep(0.0015, 0.003, min(e.x, e.y));
		float id = cm_hash(floor(p / tile));
		col *= 0.95 + 0.08 * id;
		col = mix(col, grout, j);
		rough = mix(0.2, 0.8, j);
		h = 1.0 - j;
		spec = 0.55;
	} else if (pattern == 3) {
		col *= 0.88 + 0.2 * cm_noise(p * 160.0) + 0.06 * cm_fbm(p * 2.0, 3);
		rough = 1.0;
		h = cm_noise(p * 160.0) * 0.5;
		spec = 0.2;
	} else if (pattern == 4) {
		col *= 0.85 + 0.2 * cm_fbm(p * 0.8, 4) + 0.05 * cm_noise(p * 60.0);
		rough = 0.55 + 0.3 * cm_fbm(p * 0.5, 3);
		h = cm_noise(p * 60.0) * 0.3;
	} else if (pattern == 5) {
		float fl = step(0.82, cm_noise(p * 140.0));
		float fd = step(0.86, cm_noise(p * 90.0 + 3.0));
		col = mix(col, vec3(0.27, 0.24, 0.2), fl * 0.8);
		col = mix(col, vec3(0.88, 0.86, 0.8), fd * 0.8);
		rough = 0.18;
		spec = 0.55;
	} else if (pattern == 6 || pattern == 0) {
		col *= 0.97 + 0.04 * cm_fbm(p * 4.0, 3) + 0.015 * cm_noise(p * 120.0);
		h = cm_noise(p * 120.0) * 0.25;
		rough = pattern == 0 ? 0.75 : 0.88;
	} else if (pattern == 7) {
		vec2 b = cm_bricks(p, vec2(0.204, 0.067), 0.01);
		col *= 0.85 + 0.3 * b.y;
		col = mix(col, grout * 0.7, b.x);
		h = 1.0 - b.x;
	}
	float fw = max(length(fwidth(p)), 1e-5);
	NORMAL = cm_bump(VERTEX, NORMAL, h * 0.0015 * cm_aa(40.0, fw));
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = spec;
}
