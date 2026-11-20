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

void fragment() {
	float yn = UV.y;
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
	ALBEDO = c;
	ROUGHNESS = rough;
	SPECULAR = spec;
}
