// Clothes and shoes (NpcWardrobe). UV.y = height / standing height,
// UV2.x = angle around the body (0.75 = front).
shader_type spatial;
render_mode cull_disabled;

uniform vec3 color : source_color = vec3(0.5);
uniform vec3 color2 : source_color = vec3(0.3);
uniform int pattern = 0;     // 0 solid, 1 stripes, 2 plaid, 3 denim, 4 knit, 5 leather
uniform float is_shoe = 0.0;
uniform float detail = 1.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

float folds(float yn, float ang, int part) {
	// soft horizontal folds that gather at elbows, knees, the waist and hems,
	// plus long vertical drape folds on skirts
	float h = 0.0;
	float n = vnoise(vec2(ang * 40.0, yn * 30.0));
	float joint = 0.25;
	if (part == 2) joint += 1.2 * exp(-pow((yn - 0.63) / 0.03, 2.0));
	if (part == 1) joint += 1.0 * exp(-pow((yn - 0.285) / 0.03, 2.0)) + 1.2 * smoothstep(0.12, 0.05, yn);
	if (part == 0) joint += 0.8 * exp(-pow((yn - 0.585) / 0.025, 2.0));
	h += sin(yn * 380.0 + n * 9.0 + sin(ang * 25.0) * 3.0) * joint * (0.4 + 0.6 * vnoise(vec2(ang * 18.0, yn * 60.0)));
	if (part == 12) h = sin(ang * 70.0 + n * 3.0) * (0.4 + 0.6 * smoothstep(0.55, 0.3, yn)) + 0.3 * sin(yn * 300.0 + n * 5.0);
	return h * 0.5;
}

void fragment() {
	float yn = UV.y;
	if (UV2.y < 0.0) discard;   // outside the hem / neckline / cuff
	int part = int(floor(UV.x + 0.01));
	float e = 0.0015;
	float f0 = folds(yn, UV2.x, part);
	float fy = folds(yn + e, UV2.x, part);
	float fx = folds(yn, UV2.x + e, part);
	NORMAL_MAP = normalize(vec3((f0 - fx) * 0.35 * detail, (f0 - fy) * 0.35 * detail, 1.0)) * 0.5 + 0.5;
	vec2 q = vec2(UV2.x * 520.0, yn * 1700.0);   // about 1 mm cells
	vec3 c = color;
	float rough = 0.85;
	float spec = 0.25;
	if (pattern == 1) {
		c = mix(color, color2, step(0.5, fract(yn * 70.0)));
	} else if (pattern == 2) {
		float a = step(0.62, fract(yn * 45.0));
		float b = step(0.62, fract(UV2.x * 36.0));
		c = mix(color, color2, max(a, b) * 0.75);
		c = mix(c, color2 * 0.7, a * b);
	} else if (pattern == 3) {
		float twill = fract((q.x + q.y) * 0.9);
		c *= 0.85 + 0.25 * step(0.5, twill) * detail + 0.12 * vnoise(q * vec2(0.05, 0.6));
	} else if (pattern == 4) {
		c *= 0.9 + 0.12 * abs(sin(q.x * 2.2)) * detail * (0.7 + 0.3 * sin(q.y * 1.6));
		rough = 0.95;
	} else if (pattern == 5) {
		rough = 0.45;
		spec = 0.45;
	}
	c *= 0.97 + 0.06 * vnoise(q * 0.35) * detail;
	if (is_shoe > 0.5 && yn < 0.012) { c = color2; rough = 0.7; }   // sole
	c *= 0.93 + 0.07 * f0;   // shading in the fold valleys
	// seams: a stitched line down the sides and around the hems
	float seam_d = min(abs(fract(UV2.x + 0.25) - 0.5), abs(fract(UV2.x) - 0.5));
	float seam = 1.0 - smoothstep(0.002, 0.004, seam_d);
	float stitch = step(0.5, fract(yn * 900.0)) * (1.0 - smoothstep(0.004, 0.006, abs(seam_d - 0.006)));
	c *= 1.0 - seam * 0.15 * detail;
	c = mix(c, color2 * 1.2, stitch * 0.5 * detail * float(pattern == 3));
	ALBEDO = c;
	ROUGHNESS = rough;
	SPECULAR = spec;
	if (pattern == 5) {
		CLEARCOAT = 0.4;            // leather / shoe finish
		CLEARCOAT_ROUGHNESS = 0.35;
	} else {
		RIM = pattern == 4 ? 0.5 : 0.3;   // fabric sheen at grazing angles (fuzz on knits)
		RIM_TINT = 0.75;
	}
}
