shader_type spatial;
// Map-detail building massing; hidden inside tiles whose detailed exteriors are loaded.
uniform vec4 tiles[9];   // x0, z0, x1, z1
uniform int tile_count = 0;
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	for (int i = 0; i < tile_count; i++) {
		if (wpos.x > tiles[i].x && wpos.z > tiles[i].y && wpos.x < tiles[i].z && wpos.z < tiles[i].w) { discard; }
	}
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.9;
}
