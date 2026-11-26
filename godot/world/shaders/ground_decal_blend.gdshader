// Ground decals with soft edges (puddles, oil, grime, worn soil, mulch beds): alpha blended over
// the ground, no depth writes. Puddles are near-mirror smooth so they pick up sky reflections.
shader_type spatial;
render_mode diffuse_burley, cull_back, blend_mix, depth_draw_never, shadows_disabled;
#include "res://world/shaders/ground_decal.gdshaderinc"

uniform int kind = 6;
varying vec4 vcustom;

void vertex() {
	vcustom = INSTANCE_CUSTOM;
	float d = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
	VERTEX.y += 0.02 + d * 0.0005;
}

void fragment() {
	vec3 wpos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 col; float a; float rough; float metal;
	decal_pattern(kind, UV, vcustom.y, int(vcustom.x + 0.5), wpos.xz, col, a, rough, metal);
	ALBEDO = col;
	ALPHA = a;
	ROUGHNESS = rough;
	METALLIC = metal;
	SPECULAR = kind == 6 ? 0.7 : 0.4;
}
