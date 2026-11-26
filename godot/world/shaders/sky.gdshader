// Cathedral Mount sky: palette gradient (CLAUDE.md §4.9) + analytic scattering around the sun,
// a sun disk, layered procedural clouds lit from the sun, a moon and stars at night.
shader_type sky;
render_mode use_half_res_pass;

uniform vec3 zenith_color : source_color = vec3(0.56, 0.72, 0.87);
uniform vec3 horizon_color : source_color = vec3(0.84, 0.9, 0.95);
uniform vec3 ground_color : source_color = vec3(0.25, 0.24, 0.22);
uniform vec3 sun_tint : source_color = vec3(1.0, 0.96, 0.9);
uniform float day = 1.0;            // 0 night .. 1 day
uniform float golden = 0.0;         // 0 midday .. 1 golden hour
uniform float cloud_cover : hint_range(0.0, 1.0) = 0.45;
uniform float cloud_time = 0.0;     // advanced by DayNight (game minutes) so radiance updates stay cheap
uniform float exposure = 1.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float hash3(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p, int oct) {
	float v = 0.0; float a = 0.5;
	mat2 r = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	for (int i = 0; i < 6; i++) {
		if (i >= oct) break;
		v += a * noise(p); p = r * p * 2.03 + 11.7; a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 d = normalize(EYEDIR);
	vec3 sd = LIGHT0_ENABLED ? normalize(LIGHT0_DIRECTION) : vec3(0.0, -1.0, 0.0);
	float up = d.y;
	// base gradient, a little horizon haze band
	float hz = pow(1.0 - clamp(up, 0.0, 1.0), 4.0);
	vec3 col = mix(zenith_color, horizon_color, hz);
	if (up < 0.0) col = mix(horizon_color, ground_color, smoothstep(0.0, -0.25, up));
	// scattering glow toward the sun (Mie-ish forward lobe + broad Rayleigh-ish brightening)
	float mu = dot(d, sd);
	float mie = pow(max(mu, 0.0), 12.0) * 0.55 + pow(max(mu, 0.0), 300.0) * 2.5;
	float sunlow = 1.0 - clamp(sd.y * 2.5, 0.0, 1.0);
	col += sun_tint * mie * day * (0.6 + 0.8 * sunlow);
	col += horizon_color * sun_tint * hz * max(mu, 0.0) * golden * 0.6 * day;
	// sun disk (only on the main pass; the radiance map gets the glow)
	if (!AT_CUBEMAP_PASS && LIGHT0_ENABLED) {
		float disk = smoothstep(0.99985, 0.99993, mu);
		col += LIGHT0_COLOR * LIGHT0_ENERGY * disk * 18.0;
	}
	// moon and stars
	float night = 1.0 - day;
	if (LIGHT1_ENABLED && night > 0.01) {
		vec3 md = normalize(LIGHT1_DIRECTION);
		float mm = dot(d, md);
		col += vec3(0.85, 0.9, 1.0) * smoothstep(0.99955, 0.9997, mm) * 2.5 * night;
		col += vec3(0.25, 0.32, 0.45) * pow(max(mm, 0.0), 40.0) * 0.4 * night;
	}
	if (night > 0.01 && up > 0.0) {
		vec3 cell = floor(d * 280.0);
		float s = hash3(cell);
		float star = step(0.9965, s) * smoothstep(0.0, 0.15, up);
		float tw = 0.6 + 0.4 * sin(cloud_time * 3.0 + s * 100.0);
		col += vec3(0.9, 0.93, 1.0) * star * tw * 1.4 * night;
		// faint milky band
		col += vec3(0.05, 0.06, 0.09) * night * smoothstep(0.5, 0.0, abs(dot(d, normalize(vec3(0.3, 0.6, -0.74))))) * fbm(d.xz * 9.0, 3);
	}
	// clouds on a curved layer
	if (up > 0.0) {
		vec2 uv = d.xz / (up + 0.12) * 1.6;
		vec2 wind = vec2(cloud_time * 0.004, cloud_time * 0.0017);
		int oct = AT_CUBEMAP_PASS ? 3 : 5;
		float n = fbm(uv + wind, oct);
		float n2 = fbm(uv * 2.4 - wind * 1.6 + 3.1, oct - 1);
		float cov = mix(0.72, 0.38, cloud_cover);
		float dens = smoothstep(cov, cov + 0.22, n * 0.75 + n2 * 0.35);
		// cheap self shadowing: sample toward the sun
		float ns = fbm(uv + wind + sd.xz * 0.12, 3) * 0.75 + n2 * 0.35;
		float shade = clamp(1.0 - smoothstep(cov, cov + 0.3, ns) * 0.65, 0.3, 1.0);
		vec3 lit = mix(vec3(0.55, 0.58, 0.64), vec3(1.0), shade) * mix(vec3(1.0), sun_tint * vec3(1.15, 0.95, 0.8), golden);
		lit = mix(vec3(0.03, 0.04, 0.07), lit, clamp(day * 1.3, 0.0, 1.0));
		// silver lining near the sun
		lit += sun_tint * pow(max(mu, 0.0), 8.0) * (1.0 - dens) * 1.2 * day;
		float fade = smoothstep(0.0, 0.18, up);
		col = mix(col, lit * mix(horizon_color, vec3(1.0), 0.6) * 1.1, dens * fade * 0.92);
	}
	COLOR = col * exposure;
}
