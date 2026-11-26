// Street props (PropBuilder "solid" layer, MultiMesh instanced). Per vertex: COLOR = sRGB palette
// color, UV = (roughness, metallic), UV2 = (tint mask, emission). Per instance (MultiMesh custom
// data): rgb = paint color for tinted parts (car paint, bins, bikes), a = random seed.
// Adds weathering: grime toward the ground, dust on top faces, subtle per-instance value jitter.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
#include "res://world/shaders/noise.gdshaderinc"

uniform bool instanced = true;
uniform float grime = 1.0;
global uniform float cm_night;
varying vec4 vcustom;

void vertex() {
	vcustom = instanced ? INSTANCE_CUSTOM : vec4(1.0, 1.0, 1.0, 0.5);
}

void fragment() {
	vec3 wpos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 wn = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 col = pow(COLOR.rgb, vec3(2.2));
	vec4 cd = vcustom;
	float seed = cd.a;
	if (UV2.x > 0.5) {
		col = pow(cd.rgb, vec3(2.2)) * col;   // tinted parts are built white (or grey for shading)
	}
	float rough = UV.x;
	float metal = UV.y;
	// weathering: noise mottling, grime near the ground, dusty up-facing surfaces
	float n1 = cm_fbm(wpos.xz * 3.1 + wpos.y * 2.3 + seed * 17.0, 3);
	float n2 = cm_noise(wpos.xz * 21.0 + wpos.yy * 13.0);
	float ground_y = MODEL_MATRIX[3].y;
	float low = 1.0 - smoothstep(0.0, 0.35, wpos.y - ground_y);
	col *= 0.9 + 0.2 * n1 + 0.06 * (seed - 0.5);
	col = mix(col, col * vec3(0.55, 0.5, 0.45), low * 0.5 * grime);
	// dust settles on rough up-facing surfaces (not on glossy car paint)
	col = mix(col, vec3(0.33, 0.31, 0.28), smoothstep(0.75, 1.0, wn.y) * smoothstep(0.55, 0.8, n1) * 0.2 * grime * smoothstep(0.4, 0.6, UV.x));
	rough = clamp(rough + (n2 - 0.5) * 0.12 + low * 0.15 * grime, 0.04, 1.0);
	ALBEDO = col;
	ROUGHNESS = rough;
	METALLIC = metal;
	SPECULAR = 0.5;
	if (UV2.y > 0.0) {
		EMISSION = col * UV2.y * 4.0 * cm_night;
	}
}
