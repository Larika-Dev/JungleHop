// Ground decals with hard edges (leaves, needles, cracks, tar snakes, patches, gum): alpha-cut so
// they sit in the opaque pass and receive shadows. Instances carry (variant, seed) in custom data.
shader_type spatial;
render_mode diffuse_burley, cull_back;
#include "res://world/shaders/ground_decal.gdshaderinc"

uniform int kind = 0;
varying vec4 vcustom;

void vertex() {
	vcustom = INSTANCE_CUSTOM;
	// roads render 1.5 cm proud of their mesh: float above them, a little more with distance
	float d = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
	VERTEX.y += 0.02 + d * 0.0005;
}

void fragment() {
	vec3 wpos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 col; float a; float rough; float metal;
	decal_pattern(kind, UV, vcustom.y, int(vcustom.x + 0.5), wpos.xz, col, a, rough, metal);
	ALBEDO = col;
	ALPHA = a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = rough;
	METALLIC = metal;
	SPECULAR = 0.4;
}
