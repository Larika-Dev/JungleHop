// Modeled window panes (world/buildings/building_detail.gd). Reflective glass with a parallax
// "interior mapping" room behind it: floor, ceiling, side walls, back wall, furniture shapes,
// blinds / curtains, a ceiling light pool at night. Storefront panes (COLOR.g = 1) show a deep,
// brightly lit shop with shelving and are lit every evening.
//   UV   = position in the pane (m, from its bottom-left), UV2 = pane size (m)
//   COLOR = (seed, shop flag, sill height / 4, ceiling height / 6)
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
#include "res://world/shaders/noise.gdshaderinc"

uniform float lit_fraction = 0.62;
uniform vec3 warm : source_color = vec3(1.0, 0.851, 0.627);      // INTERIOR_WARM
uniform vec3 cool : source_color = vec3(0.949, 0.965, 1.0);      // INTERIOR_COOL
global uniform float cm_night;

vec3 wall_tone(float id) {
	// PAINT_OFFICE, PLASTER_CAMPUS, PAINT_DORM_BLOCK, PAINT_RETAIL, PLASTER_IVORY, PAINT_BAR_DARK, sage (linear)
	if (id < 0.18) return vec3(0.84, 0.84, 0.82);
	if (id < 0.36) return vec3(0.86, 0.81, 0.69);
	if (id < 0.52) return vec3(0.82, 0.79, 0.72);
	if (id < 0.68) return vec3(0.88, 0.86, 0.82);
	if (id < 0.84) return vec3(0.89, 0.85, 0.75);
	if (id < 0.92) return vec3(0.025, 0.018, 0.016);
	return vec3(0.45, 0.55, 0.47);
}

void fragment() {
	float seed = COLOR.r;
	bool shop = COLOR.g > 0.5;
	float sill = COLOR.b * 4.0;
	float ceil_h = max(COLOR.a * 6.0, 2.3);
	vec2 lp = UV;
	vec2 wsz = max(UV2, vec2(0.1));
	vec3 n = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 t = normalize(vec3(-n.z, 0.0, n.x) + vec3(1e-5, 0.0, 0.0));
	vec3 vw = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);   // fragment -> camera
	vec3 rd = -vw;
	vec3 lr = vec3(dot(rd, t), rd.y, dot(rd, -n));
	// room box in pane space: wider than the pane, floor below the sill, ceiling above
	float depth = shop ? 6.5 : mix(3.2, 5.0, cm_hash(vec2(seed, 2.1)));
	float side = shop ? 0.2 : 1.1;
	vec3 lo = vec3(-side, -sill, 0.0);
	vec3 hi = vec3(wsz.x + side, ceil_h - sill, depth);
	vec3 ro = vec3(lp, 0.0);
	vec3 tt = vec3(
		lr.x > 0.0 ? (hi.x - ro.x) / lr.x : (lo.x - ro.x) / min(lr.x, -1e-4),
		lr.y > 0.0 ? (hi.y - ro.y) / lr.y : (lo.y - ro.y) / min(lr.y, -1e-4),
		(hi.z - ro.z) / max(lr.z, 1e-4));
	float tm = min(tt.x, min(tt.y, tt.z));
	vec3 hp = ro + lr * tm;
	float rid = cm_hash(vec2(seed, 1.91));
	vec3 wallc = shop ? vec3(0.88, 0.86, 0.82) : wall_tone(rid);
	vec3 ic;
	if (tm == tt.y) {
		if (lr.y > 0.0) {
			ic = vec3(0.9);
			// light panel / fixture on the ceiling
			vec2 lc = hp.xz - vec2(wsz.x * 0.5, depth * 0.5);
			if (abs(lc.x) < 0.6 && abs(lc.y) < 0.3) ic = vec3(2.2);
		} else {
			float wood = step(0.45, rid);
			ic = mix(vec3(0.16, 0.16, 0.17), vec3(0.34, 0.19, 0.09), wood);
			ic *= 0.85 + 0.15 * cm_noise(hp.xz * vec2(6.0, 1.2));
			if (shop) ic = mix(vec3(0.5, 0.48, 0.45), vec3(0.3, 0.17, 0.08), step(0.5, rid));
		}
	} else if (tm == tt.z) {
		ic = wallc;
		if (shop) {
			// shelving with goods along the back wall
			float shelf = step(0.85, fract(hp.y / 0.45));
			float goods = cm_hash(floor(vec2(hp.x / 0.18, hp.y / 0.45)) + seed * 13.0);
			vec3 gc = vec3(0.3 + 0.6 * goods, 0.25 + 0.5 * fract(goods * 7.3), 0.2 + 0.6 * fract(goods * 3.1));
			ic = hp.y + sill < 2.2 ? mix(gc, vec3(0.3, 0.2, 0.12), shelf) : wallc;
		} else {
			// a picture frame and a dark furniture silhouette
			float fx = cm_hash(vec2(seed, 3.3)) * (wsz.x + 2.0 * side - 1.4) - side;
			if (hp.x > fx && hp.x < fx + 1.4 && hp.y + sill < 0.8 + 0.9 * step(0.5, rid)) ic *= 0.3;
			vec2 pc = vec2(fx + 0.7, 1.6 - sill);
			if (abs(hp.x - pc.x) < 0.35 && abs(hp.y - pc.y) < 0.25 && rid > 0.3) ic = vec3(0.2, 0.25, 0.3) * (0.6 + rid);
		}
	} else {
		ic = wallc * 0.8;
		if (shop && hp.y + sill < 1.9) {
			// side racks / display tables
			float rack = step(0.5, fract(hp.z / 1.3));
			ic = mix(ic, vec3(0.35, 0.3, 0.28), rack * 0.7);
		}
	}
	// a person-height counter / table in the middle of shops
	if (shop) {
		float tc = (0.95 - sill - ro.y) / min(lr.y, -1e-4);
		if (lr.y < 0.0 && tc > 0.0 && tc < tm) {
			vec3 cp = ro + lr * tc;
			if (cp.z > 2.0 && cp.z < 3.0 && cp.x > 0.3 && cp.x < wsz.x - 0.3) { ic = vec3(0.32, 0.2, 0.1); hp = cp; }
		}
	}
	float dz = clamp(hp.z / depth, 0.0, 1.0);
	ic *= mix(1.0, 0.5, dz);
	bool lit = shop || cm_hash(vec2(seed, 7.7)) < lit_fraction;
	vec3 lamp = shop ? warm : mix(warm, cool, step(0.6, cm_hash(vec2(seed, 5.1))));
	float pool = 1.0 - smoothstep(0.0, 2.4, length(hp.xz - vec2(wsz.x * 0.5, depth * 0.45)));
	vec3 night_c = ic * lamp * (lit ? (shop ? 0.8 + 0.5 * pool : 0.3 + 0.4 * pool) : 0.008);
	vec3 day_c = ic * (shop ? 0.32 : 0.2);
	vec3 inside = mix(day_c, night_c, cm_night);
	// blinds / curtains (not in shops)
	if (!shop) {
		float bl = cm_hash(vec2(seed, 9.2));
		float yv = lp.y / wsz.y;
		if (bl > 0.5 && yv > 1.0 - (bl - 0.5) * 1.7) {
			float slat = step(0.45, fract(lp.y * 30.0));
			inside = vec3(0.78, 0.76, 0.7) * mix(0.3, lit ? 0.45 : 0.015, cm_night) * (0.82 + 0.18 * slat);
		} else if (bl < 0.22) {
			float cw = 0.25 + bl;
			float cx = min(lp.x, wsz.x - lp.x);
			if (cx < cw) {
				vec3 cc = mix(vec3(0.55, 0.15, 0.12), vec3(0.75, 0.7, 0.6), step(0.1, bl));
				inside = cc * (0.85 + 0.15 * sin(lp.x * 40.0)) * mix(0.3, lit ? 0.5 : 0.02, cm_night);
			}
		}
	}
	float fres = pow(1.0 - clamp(dot(vw, n), 0.0, 1.0), 5.0);
	// grime toward the pane edges
	vec2 e = min(lp, wsz - lp);
	float edge = 1.0 - smoothstep(0.0, 0.08, min(e.x, e.y));
	float grime = cm_fbm(lp * 7.0 + seed * 31.0, 3);
	ALBEDO = mix(vec3(0.01, 0.012, 0.014), vec3(0.08, 0.075, 0.065), edge * 0.6 + grime * 0.15);
	ROUGHNESS = 0.04 + 0.25 * edge + 0.12 * grime;
	METALLIC = 0.0;
	SPECULAR = 0.7;
	EMISSION = inside * (1.0 - fres * 0.9) * (1.0 - edge * 0.5);
}
