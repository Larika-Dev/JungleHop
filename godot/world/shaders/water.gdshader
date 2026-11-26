// Creek water (Battle Ravine): flowing ripples along UV.y, refraction of the bed, depth tint,
// Fresnel sky reflection (plus SSR when enabled) and foam at the banks.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled, depth_draw_always;
#include "res://world/shaders/noise.gdshaderinc"

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D depth_tex : hint_depth_texture;
uniform vec3 shallow : source_color = vec3(0.32, 0.36, 0.28);
uniform vec3 deep : source_color = vec3(0.05, 0.08, 0.07);
uniform float flow_speed = 0.35;
global uniform vec4 cm_wind;
varying vec3 wpos;

float ripple(vec2 p) {
	return cm_noise(p) * 0.6 + cm_noise(p * 2.3 + 4.0) * 0.3 + cm_noise(p * 5.1 + 9.0) * 0.1;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float t = cm_wind.w;
	vec2 p = vec2(UV.x * 4.0, UV.y - t * flow_speed);
	vec2 q = wpos.xz * 1.4;
	float h = ripple(p * vec2(3.0, 1.2)) + 0.5 * ripple(q + vec2(t * 0.2, 0.0));
	float e = 0.05;
	float hx = ripple((p + vec2(e, 0.0)) * vec2(3.0, 1.2)) + 0.5 * ripple(q + vec2(e, 0.0) + vec2(t * 0.2, 0.0));
	float hy = ripple((p + vec2(0.0, e)) * vec2(3.0, 1.2)) + 0.5 * ripple(q + vec2(0.0, e) + vec2(t * 0.2, 0.0));
	NORMAL_MAP = normalize(vec3((h - hx) * 2.0, (h - hy) * 2.0, 1.0)) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 0.6;
	// water depth from the depth buffer
	float zb = texture(depth_tex, SCREEN_UV).r;
	vec4 vb = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, zb, 1.0);
	vb.xyz /= vb.w;
	float depth = clamp(VERTEX.z - vb.z, 0.0, 5.0);
	vec2 refr = SCREEN_UV + (vec2(h - hx, h - hy)) * 0.03 * clamp(depth, 0.0, 1.0);
	vec3 bed = textureLod(screen_tex, refr, 0.0).rgb;
	float absorb = 1.0 - exp(-depth * 1.4);
	vec3 col = mix(bed * shallow * 2.2, deep, absorb);
	float foam = (1.0 - smoothstep(0.0, 0.12, depth)) * step(0.55, cm_noise(p * vec2(10.0, 4.0)));
	foam += (1.0 - smoothstep(0.0, 0.08, min(UV.x, 1.0 - UV.x))) * 0.5;
	ALBEDO = mix(vec3(0.0), vec3(0.85), clamp(foam, 0.0, 1.0));
	EMISSION = col * (1.0 - clamp(foam, 0.0, 1.0)) * 0.6;
	ROUGHNESS = mix(0.04, 0.5, clamp(foam, 0.0, 1.0));
	METALLIC = 0.0;
	SPECULAR = 0.6;
	ALPHA = clamp(0.35 + absorb * 0.65 + foam, 0.0, 1.0) * smoothstep(0.0, 0.05, depth + foam);
}
