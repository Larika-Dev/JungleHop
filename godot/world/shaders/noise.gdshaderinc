// Shared procedural noise for Cathedral Mount surface shaders.
// Integer hashing on the float bits: stable at large world coordinates (sin-based hashes band
// into stripes once coordinates reach the thousands, especially on some drivers).
uint cm_pcg(uint v) {
	uint state = v * 747796405u + 2891336453u;
	uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
	return (word >> 22u) ^ word;
}
float cm_hash(vec2 p) {
	uvec2 u = floatBitsToUint(p + 0.0);
	return float(cm_pcg(u.x ^ cm_pcg(u.y))) * (1.0 / 4294967295.0);
}
vec2 cm_hash2(vec2 p) {
	uvec2 u = floatBitsToUint(p + 0.0);
	uint a = cm_pcg(u.x ^ cm_pcg(u.y));
	return vec2(float(a), float(cm_pcg(a))) * (1.0 / 4294967295.0);
}
float cm_noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(cm_hash(i), cm_hash(i + vec2(1, 0)), u.x), mix(cm_hash(i + vec2(0, 1)), cm_hash(i + vec2(1, 1)), u.x), u.y);
}
float cm_fbm(vec2 p, int oct) {
	float v = 0.0; float a = 0.5;
	for (int i = 0; i < 6; i++) {
		if (i >= oct) break;
		v += a * cm_noise(p); p = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * p * 2.02 + 7.3; a *= 0.5;
	}
	return v;
}
// distance to the nearest cell edge of a Voronoi pattern (cracks, stones)
vec2 cm_voronoi(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	float d1 = 8.0; float d2 = 8.0; float id = 0.0;
	for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++) {
		vec2 g = vec2(float(x), float(y));
		vec2 o = cm_hash2(i + g);
		float d = length(g + o - f);
		if (d < d1) { d2 = d1; d1 = d; id = cm_hash(i + g); } else if (d < d2) { d2 = d; }
	}
	return vec2(d2 - d1, id);
}
// Brick/paver bond: returns (mortar mask 0 brick .. 1 joint, brick id). size = brick + joint (m).
vec2 cm_bricks(vec2 p, vec2 size, float joint) {
	float row = floor(p.y / size.y);
	p.x += mod(row, 2.0) * size.x * 0.5;
	vec2 cell = floor(p / size);
	vec2 f = fract(p / size) * size;
	vec2 e = min(f, size - f);
	float m = 1.0 - smoothstep(joint * 0.35, joint * 0.6, min(e.x, e.y));
	return vec2(m, cm_hash(cell));
}
vec3 cm_luma_jitter(vec3 c, float v) { return c * (1.0 + v); }
// Derivative bump mapping (Mikkelsen 2010): perturbs view-space normal n by height h (meters).
vec3 cm_bump(vec3 vpos, vec3 n, float h) {
	vec3 dpdx = dFdx(vpos);
	vec3 dpdy = dFdy(vpos);
	vec3 r1 = cross(dpdy, n);
	vec3 r2 = cross(n, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (dFdx(h) * r1 + dFdy(h) * r2);
	vec3 r = abs(det) * n - grad;
	float l = length(r);
	return (l > 1e-12 && !isnan(l)) ? r / l : n;
}
// Detail fade for a pattern of frequency f (cycles per meter) given the pixel footprint fw (m):
// 1 while the pattern is resolved, 0 once it would alias.
float cm_aa(float f, float fw) { return 1.0 - smoothstep(0.12, 0.45, f * fw); }
