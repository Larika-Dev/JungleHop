// Procedural ground decal patterns (GroundDecals). uv 0..1 over the decal quad, seed 0..1 per
// instance, variant 0..3. Colors are linear versions of the palette keys named beside them.
#include "res://world/shaders/noise.gdshaderinc"

// FALLEN_LEAF_A / B / C, RED_MAPLE_LEAF, SUGAR_MAPLE_LEAF, GINKGO_LEAF (linear)
const vec3 LEAF_COLS[6] = vec3[6](vec3(0.258, 0.102, 0.027), vec3(0.434, 0.254, 0.027), vec3(0.144, 0.068, 0.023),
	vec3(0.445, 0.042, 0.019), vec3(0.694, 0.223, 0.024), vec3(0.768, 0.527, 0.074));

float leaf_shape(vec2 f, float rot, float len) {
	vec2 r = mat2(vec2(cos(rot), sin(rot)), vec2(-sin(rot), cos(rot))) * f;
	r.y /= len;
	// pointed oval with a little lobing
	float w = 0.22 * (1.0 - r.y * r.y * 2.2) * (1.0 + 0.12 * sin(r.y * 22.0));
	return step(abs(r.x), max(w, 0.0)) * step(abs(r.y), 0.48);
}

void decal_pattern(int kind, vec2 uv, float seed, int variant, vec2 world, out vec3 col, out float a, out float rough, out float metal) {
	vec2 q = uv * 2.0 - 1.0;
	float r = length(q);
	float n = cm_fbm(uv * 3.0 + seed * 13.7, 3);
	col = vec3(0.1);
	a = 0.0;
	rough = 0.85;
	metal = 0.0;
	if (kind == 0) {
		// fallen leaves: three jittered layers of individual leaves, densest in the middle
		float dens = (1.0 - smoothstep(0.35, 1.0, r + (n - 0.5) * 0.6)) * (0.75 + 0.25 * float(variant) / 3.0);
		for (int l = 0; l < 3; l++) {
			float sc = 6.0 + float(l) * 3.0;
			vec2 g = uv * sc + vec2(seed * 31.0 + float(l) * 7.1);
			vec2 cell = floor(g);
			vec2 h = cm_hash2(cell);
			if (cm_hash(cell + 3.7) > dens) { continue; }
			vec2 f = fract(g) - 0.5 - (h - 0.5) * 0.4;
			float m = leaf_shape(f, h.x * 6.28, 0.8 + h.y * 0.5);
			if (m > 0.5) {
				int ci = int(floor(cm_hash(cell + 9.1) * 5.99));
				col = LEAF_COLS[ci] * (0.7 + 0.5 * cm_hash(cell + 1.3));
				col *= 0.85 + 0.3 * smoothstep(-0.3, 0.3, f.x + f.y);   // curl shading
				a = 1.0;
				rough = 0.72;
			}
		}
	} else if (kind == 1) {
		// pine needles: thin crossing strokes
		float dens = 1.0 - smoothstep(0.3, 1.0, r + (n - 0.5) * 0.5);
		for (int l = 0; l < 2; l++) {
			vec2 g = uv * (14.0 + float(l) * 6.0) + seed * 17.0 + float(l) * 3.3;
			vec2 cell = floor(g);
			if (cm_hash(cell) > dens) { continue; }
			float ang = cm_hash(cell + 2.0) * 3.14159;
			vec2 f = fract(g) - 0.5;
			vec2 d = vec2(cos(ang), sin(ang));
			float along = dot(f, d);
			float across = abs(dot(f, vec2(-d.y, d.x)));
			if (across < 0.035 && abs(along) < 0.48) {
				col = vec3(0.262, 0.102, 0.024) * (0.6 + 0.6 * cm_hash(cell + 5.0));   // PINE_STRAW
				a = 1.0;
				rough = 0.8;
			}
		}
	} else if (kind == 2) {
		// pavement cracks: a broken branching line, thin, fading in and out along its length
		vec2 vc = cm_voronoi(uv * 2.5 + seed * 9.0);
		float mask = (1.0 - smoothstep(0.3, 0.9, r + (n - 0.5) * 0.5)) * step(0.45, cm_noise(uv * 6.0 + seed * 3.0));
		float line = 1.0 - smoothstep(0.0, 0.018 + 0.012 * n, vc.x);
		if (line * mask > 0.5) { col = vec3(0.03, 0.03, 0.028); a = 1.0; rough = 0.95; }
	} else if (kind == 3) {
		// sealed crack ("tar snake"): a glossy wandering ribbon
		float x = q.x - 0.3 * sin(q.y * 3.0 + seed * 6.28) - 0.12 * sin(q.y * 9.0 + seed * 20.0);
		float w = 0.06 + 0.03 * cm_noise(uv * 8.0 + seed);
		if (abs(x) < w && abs(q.y) < 0.98) { col = vec3(0.006); a = 1.0; rough = 0.28; }
	} else if (kind == 4) {
		// patched asphalt: blotchy rectangle, fresher darker aggregate, a sealed seam around it
		float bx = max(abs(q.x), abs(q.y)) + (n - 0.5) * 0.12;
		if (bx < 0.92) {
			float agg = cm_noise(world * 90.0);
			col = vec3(0.028, 0.029, 0.031) * (0.8 + 0.4 * agg) * (float(variant) == 3.0 ? 0.8 : 1.0);   // ASPHALT_PATCH / FRESH
			a = 1.0;
			rough = 0.78;
			if (bx > 0.86) { col = vec3(0.008); rough = 0.4; }
		}
	} else if (kind == 5) {
		// flattened gum and spills on busy sidewalks
		vec2 g = uv * 9.0 + seed * 11.0;
		vec2 cell = floor(g);
		vec2 f = fract(g) - 0.5 - (cm_hash2(cell) - 0.5) * 0.5;
		if (cm_hash(cell + 4.0) < 0.3 * (1.0 - r * 0.7) && length(f) < 0.12 + 0.08 * cm_hash(cell + 1.0)) {
			col = vec3(0.05, 0.048, 0.045) * (0.6 + cm_hash(cell + 8.0));
			a = 1.0;
			rough = 0.5;
		}
	} else if (kind == 6) {
		// puddle: still water with a damp rim
		float s = r + (n - 0.5) * 0.55;
		float water = 1.0 - smoothstep(0.55, 0.7, s);
		float damp = 1.0 - smoothstep(0.65, 0.98, s);
		col = mix(vec3(0.025, 0.026, 0.028), vec3(0.012, 0.013, 0.015), water);   // PUDDLE_TINT
		a = max(water * 0.92, damp * 0.45);
		rough = mix(0.6, 0.03, water);
		metal = 0.0;
	} else if (kind == 7) {
		// oil drip: dark soft stain with a faint thin-film sheen
		float s = r + (n - 0.5) * 0.7;
		a = (1.0 - smoothstep(0.2, 0.9, s)) * 0.55;
		vec3 film = 0.5 + 0.5 * cos(6.28 * (vec3(0.0, 0.33, 0.67) + s * 2.0 + seed));
		col = vec3(0.01) + film * 0.012;
		rough = 0.35;
	} else if (kind == 8) {
		// generic grime blotch
		float s = r + (n - 0.5) * 0.8;
		a = (1.0 - smoothstep(0.1, 0.95, s)) * 0.35;
		col = vec3(0.03, 0.028, 0.024);
		rough = 0.9;
	} else if (kind == 9) {
		// bare worn soil in lawns
		float s = r + (n - 0.5) * 0.9;
		a = (1.0 - smoothstep(0.35, 0.95, s)) * 0.85;
		float g2 = cm_noise(world * 7.0);
		col = mix(vec3(0.254, 0.198, 0.111), vec3(0.33, 0.07, 0.025), 0.25 + 0.2 * g2) * (0.75 + 0.35 * cm_noise(world * 23.0));   // DIRT_PATH / RED_CLAY
		rough = 0.95;
	} else if (kind == 10) {
		// pine-straw mulch bed (variant 0 rectangle along a house front, 1 ring under a tree)
		float edge = variant == 1 ? r : max(abs(q.x) * 0.92, abs(q.y));
		float s = edge + (n - 0.5) * 0.25;
		a = 1.0 - smoothstep(0.82, 0.98, s);
		float fib = 0.0;
		for (int l = 0; l < 2; l++) {
			vec2 g = world * (10.0 + float(l) * 7.0);
			vec2 cell = floor(g);
			float ang = cm_hash(cell + float(l)) * 3.14159;
			vec2 f = fract(g) - 0.5;
			fib = max(fib, 1.0 - smoothstep(0.02, 0.05, abs(dot(f, vec2(-sin(ang), cos(ang))))));
		}
		col = vec3(0.262, 0.102, 0.024) * (0.45 + 0.55 * fib) * (0.8 + 0.4 * cm_noise(world * 3.0));   // PINE_STRAW
		if (variant == 1 && r < 0.18) { a = 0.0; }
		rough = 0.92;
	}
}
