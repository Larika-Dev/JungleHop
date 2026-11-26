// Hair strand cards (NpcHair): UV.x across the card (+ a per-card random
// offset), UV.y root (0) to tip (1). Strands are cut with alpha scissor.
shader_type spatial;
render_mode cull_disabled;

uniform vec3 hair_color : source_color = vec3(0.1, 0.07, 0.05);

float hash(float x) { return fract(sin(x * 127.1) * 43758.5453); }

void fragment() {
	float across = fract(UV.x);
	float seed = floor(UV.x * 0.0) + UV.x - across;
	float lanes = 9.0;
	float lane = floor(across * lanes);
	float lx = fract(across * lanes);
	float r = hash(lane + UV.x * 13.0 - across * 13.0);
	float len_cut = 0.65 + 0.35 * r;               // strands end at different lengths
	float strand = smoothstep(0.5, 0.15, abs(lx - 0.5)) * step(UV.y, len_cut);
	float edge = smoothstep(0.0, 0.12, across) * smoothstep(1.0, 0.88, across);
	ALPHA = strand * edge;
	ALPHA_SCISSOR_THRESHOLD = 0.35;
	vec3 c = hair_color * (0.7 + 0.4 * r) * mix(0.75, 1.05, UV.y);
	// strand direction from the UV derivatives -> anisotropic highlight running across the
	// strands (the bright band on real hair), plus a dimmer secondary band via rim light
	vec3 dpdx = dFdx(VERTEX);
	vec3 dpdy = dFdy(VERTEX);
	float dudx = dFdx(UV.x);
	float dudy = dFdy(UV.x);
	vec3 strand_dir = dudy * dpdx - dudx * dpdy;
	if (dot(strand_dir, dFdx(UV.y) * dpdx + dFdy(UV.y) * dpdy) < 0.0) strand_dir = -strand_dir;
	if (length(strand_dir) > 1e-8) {
		vec3 tn = normalize(strand_dir - NORMAL * dot(NORMAL, strand_dir));
		TANGENT = tn;
		BINORMAL = cross(NORMAL, tn);
		ANISOTROPY = 0.85;
		ANISOTROPY_FLOW = vec2(1.0, 0.0);
	}
	// root-to-tip darkening and per-strand value noise
	c *= 0.85 + 0.3 * hash(lane * 7.3 + floor(UV.x * 31.0));
	ALBEDO = c;
	ROUGHNESS = 0.38;
	SPECULAR = 0.5;
	RIM = 0.25;
	RIM_TINT = 0.8;
	BACKLIGHT = c * 0.4;
}
