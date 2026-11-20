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
	// a soft sheen band along the strand, like light catching the hair
	float sheen = pow(clamp(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0), 3.0);
	c += hair_color * 0.25 * sheen;
	ALBEDO = c;
	ROUGHNESS = 0.55;
	SPECULAR = 0.45;
}
