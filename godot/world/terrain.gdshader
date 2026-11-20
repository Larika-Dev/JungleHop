shader_type spatial;
// City terrain with palette vertex colors. Holes are cut where a streamed building interior stands,
// so the ground never shows through interior floors.
uniform vec4 bld_a[32];   // origin x, origin z, cos(rotY), sin(rotY)
uniform vec4 bld_b[32];   // footprint x, footprint z
uniform int bld_count = 0;
varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	for (int i = 0; i < bld_count; i++) {
		vec2 d = wpos.xz - bld_a[i].xy;
		float lx = bld_a[i].z * d.x - bld_a[i].w * d.y;
		float lz = bld_a[i].w * d.x + bld_a[i].z * d.y;
		if (lx > 0.1 && lz > 0.1 && lx < bld_b[i].x - 0.1 && lz < bld_b[i].y - 0.1) {
			discard;
		}
	}
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.92;
}
