// Building exteriors. Base colors are the map's palette vertex colors (linear). The shader adds:
// - brick bond with recessed lime mortar on brick-colored walls, stucco / stone grain elsewhere
// - roofs: slate courses, standing seams or membrane depending on color
// - weathering: rain streaks, grime, sun-faded patches
// - (windows = true) a grid of windows with frames, sills, blinds and parallax interiors
//   (fake rooms behind the glass with floors, ceilings and walls) that light up at night.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
#include "res://world/shaders/noise.gdshaderinc"

uniform bool windows = false;
uniform float floor_h = 3.4;
uniform float bay_w = 3.0;
uniform float win_w = 1.25;
uniform float win_h = 1.85;
uniform float sill = 0.9;
uniform float room_depth = 4.2;
uniform float lit_fraction = 0.6;
uniform vec3 mortar : source_color = vec3(0.81, 0.776, 0.706);   // MORTAR_HISTORIC
uniform vec3 trim : source_color = vec3(0.953, 0.941, 0.91);     // TRIM_WHITE
uniform vec3 warm : source_color = vec3(1.0, 0.851, 0.627);      // INTERIOR_WARM
uniform vec3 cool : source_color = vec3(0.949, 0.965, 1.0);      // INTERIOR_COOL
global uniform float cm_night;
global uniform float cm_quality;


void vertex() {
}

vec3 room_wall_color(float id) {
	// PAINT_OFFICE, PLASTER_CAMPUS, PAINT_DORM_BLOCK, PAINT_RETAIL, PLASTER_IVORY (linear)
	if (id < 0.2) return vec3(0.84, 0.84, 0.82);
	if (id < 0.4) return vec3(0.86, 0.81, 0.69);
	if (id < 0.6) return vec3(0.82, 0.79, 0.72);
	if (id < 0.8) return vec3(0.88, 0.86, 0.82);
	return vec3(0.89, 0.85, 0.75);
}

void fragment() {
	// world position / normal from view space (no extra varyings: keeps the depth prepass and
	// color pass vertex code identical, which avoids depth-equal mismatches on some drivers)
	vec3 wpos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 wnrm = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 base = COLOR.rgb;
	vec3 n = normalize(wnrm);
	float dist = length(VERTEX);
	float near = 1.0 - smoothstep(30.0, 110.0, dist);
	float fw = max(length(fwidth(wpos)), 1e-5);
	float mx = max(base.r, max(base.g, base.b));
	float mn = min(base.r, min(base.g, base.b));
	float sat = mx > 0.0001 ? (mx - mn) / mx : 0.0;
	vec3 col = base;
	float rough = 0.85;
	float metal = 0.0;
	float spec = 0.45;
	float h = 0.0;
	vec3 emis = vec3(0.0);
	// explicit surface kind from the modeled buildings (Mesher.KIND_*), 20 = classify by color
	int kind = int(round(COLOR.a * 20.0));
	bool modeled = kind < 20;
	float hb = UV2.x;      // height above the ground floor (modeled only)
	float dirt = UV2.y;    // per-building dirt amount (modeled only)
	bool roof = modeled ? (kind >= 12 && kind <= 16) : n.y > 0.55;
	if (roof) {
		vec2 p = wpos.xz;
		if (modeled && n.y < 0.97) {
			// slope-aligned coordinates: along the eave, up the slope
			vec3 te = normalize(cross(vec3(0.0, 1.0, 0.0), n) + vec3(1e-5, 0.0, 0.0));
			vec3 up_s = normalize(cross(n, te));
			p = vec2(dot(wpos, te), dot(wpos, up_s));
		}
		if (modeled && kind == 13) {
			// slate: staggered courses with chipped edges and color variation
			vec2 b = cm_bricks(p, vec2(0.3, 0.16), 0.01);
			col = base * (0.75 + 0.5 * b.y) * (0.9 + 0.2 * cm_fbm(p * 0.3, 3));
			h = (1.0 - b.x) * cm_aa(6.0, fw) + fract(p.y / 0.16) * 0.6 * cm_aa(6.0, fw);
			rough = 0.55 + 0.25 * b.y;
			spec = 0.55;
		} else if (modeled && kind == 12) {
			// asphalt shingles: tabs, granule noise, algae streaks
			vec2 b = cm_bricks(p, vec2(0.333, 0.142), 0.008);
			float gran = cm_noise(p * 120.0) * cm_aa(120.0, fw);
			col = base * (0.85 + 0.3 * b.y) * (0.92 + 0.16 * gran);
			float algae = smoothstep(0.55, 0.8, cm_noise(vec2(p.x * 2.0, p.y * 0.3))) * (0.3 + dirt * 0.5);
			col = mix(col, col * vec3(0.55, 0.6, 0.55), algae * 0.5);
			h = (1.0 - fract(p.y / 0.142)) * cm_aa(7.0, fw) + b.x * cm_aa(4.0, fw);
			rough = 0.92;
		} else if (modeled && kind == 16) {
			float rib = smoothstep(0.46, 0.5, abs(fract(p.x / 0.45) - 0.5));
			col = base * (0.85 + 0.2 * cm_fbm(p * 0.5, 3));
			h = rib * cm_aa(4.0, fw) * 2.0;
			metal = 0.6;
			rough = 0.4;
		} else if (!modeled && mx < 0.06) {
			// slate / shingle courses
			vec2 b = cm_bricks(p, vec2(0.36, 0.2), 0.012);
			col = base * (0.8 + 0.4 * b.y) * (0.9 + 0.2 * cm_fbm(p * 0.2, 3));
			h = (1.0 - b.x) * cm_aa(5.0, fw);
			rough = 0.7 + 0.2 * b.y;
		} else if ((modeled && kind == 14) || (sat < 0.12 && mx > 0.45)) {
			// membrane roof with seams, ponding stains and HVAC grime
			col = base * (0.9 + 0.12 * cm_fbm(p * 0.4, 3));
			col = mix(col, base * 0.6, smoothstep(0.6, 0.85, cm_fbm(p * 0.15, 4)) * 0.5);
			h = (1.0 - smoothstep(0.0, 0.02, abs(fract(p.x / 1.8) - 0.5) - 0.48)) * cm_aa(2.0, fw);
			rough = 0.75;
		} else {
			// standing seam / copper: ribs every 45 cm
			float rib = smoothstep(0.46, 0.5, abs(fract(p.x / 0.45) - 0.5));
			col = base * (0.85 + 0.2 * cm_fbm(p * 0.5, 3));
			h = rib * cm_aa(4.0, fw) * 2.0;
			metal = sat < 0.3 ? 0.6 : 0.2;
			rough = 0.45;
		}
	} else {
		// wall coordinates: u along the wall, v up
		vec3 t = normalize(vec3(-n.z, 0.0, n.x) + vec3(1e-4, 0.0, 0.0));
		float u = dot(wpos, t);
		float v = wpos.y;
		vec2 wp = vec2(u, v);
		bool brick = modeled ? kind == 2 : (base.r > base.g * 1.7 && base.r > base.b * 1.7 && mx > 0.05);
		bool stucco = modeled ? (kind == 6 || kind == 10 || kind == 18) : (sat < 0.25 && mx > 0.3);
		bool stone = modeled ? (kind == 8 || kind == 5) : sat < 0.3;
		if (modeled && kind == 3) {
			// fieldstone: irregular stones, deep mortar, moss in the joints
			vec2 vo = cm_voronoi(wp * vec2(3.2, 4.2));
			float jm = 1.0 - smoothstep(0.03, 0.09, vo.x);
			col = base * (0.75 + 0.5 * vo.y) * (0.9 + 0.2 * cm_fbm(wp * 3.0, 3));
			col = mix(col, mortar * 0.5, jm * 0.8);
			h = (1.0 - jm) * 3.0 * cm_aa(4.0, fw) + cm_fbm(wp * 9.0, 3) * cm_aa(18.0, fw);
			rough = 0.9;
		} else if (modeled && kind == 4) {
			// painted lap siding: 15 cm boards with a shadow line, brush grain, paint fade
			float lap = fract(v / 0.152);
			col = base * (0.9 + 0.1 * lap) * (0.95 + 0.06 * cm_noise(vec2(u * 0.7, v * 30.0)) * cm_aa(30.0, fw));
			col *= 1.0 - (1.0 - smoothstep(0.0, 0.08, lap)) * 0.35 * cm_aa(7.0, fw);
			h = lap * cm_aa(7.0, fw) * 2.0 + (cm_noise(vec2(u * 40.0, v * 3.0)) - 0.5) * 0.2 * cm_aa(40.0, fw);
			rough = 0.55;
		} else if (modeled && kind == 11) {
			// painted wood: vertical grain
			col = base * (0.92 + 0.08 * cm_noise(vec2(u * 3.0, v * 40.0)) * cm_aa(40.0, fw));
			h = cm_noise(vec2(u * 2.0, v * 60.0)) * 0.3 * cm_aa(60.0, fw);
			rough = 0.6;
		} else if (modeled && kind == 18) {
			// awning canvas: weave + sun fade on top
			float weave = (cm_noise(wp * 220.0) - 0.5) * cm_aa(220.0, fw);
			col = base * (0.95 + 0.08 * weave) * (1.0 + max(n.y, 0.0) * 0.12);
			h = weave * 0.3;
			rough = 0.95;
			spec = 0.2;
		} else if (modeled && kind == 10) {
			// smooth paint / trim / metalwork: faint orange peel + chipping
			col = base * (0.97 + 0.05 * cm_fbm(wp * 6.0, 3));
			float chip = smoothstep(0.78, 0.84, cm_fbm(wp * 9.0 + 3.1, 4)) * dirt;
			col = mix(col, col * 0.6, chip);
			h = cm_noise(wp * 90.0) * 0.08 * cm_aa(90.0, fw) - chip * 0.6;
			rough = 0.5;
		} else if (brick) {
			// modular brick 19.4 x 5.7 cm + 1 cm joints (CLAUDE.md §5), jitter value ±6%
			vec2 b = cm_bricks(wp, vec2(0.204, 0.067), 0.01);
			float ba = cm_aa(15.0, fw);
			float j = ((b.y - 0.5) * 0.12 + (cm_noise(wp * 30.0) - 0.5) * 0.06) * ba;
			col = base * (1.0 + j);
			col = mix(col, mix(base, mortar * 0.55, 0.18), 1.0 - ba);   // unresolved bond: mortar tint averaged in
			col = mix(col, mortar * 0.55, b.x * ba);
			rough = mix(0.78 + 0.14 * b.y, 0.95, b.x);
			h = (1.0 - b.x) * ba + (cm_noise(wp * 60.0) - 0.5) * 0.15 * cm_aa(60.0, fw);
		} else if (stucco) {
			// stucco, painted trim, limestone: fine grain + soft mottling
			col = base * (0.94 + 0.08 * cm_fbm(wp * 3.0, 4) + 0.04 * (cm_noise(wp * 50.0) - 0.5) * cm_aa(50.0, fw));
			h = cm_fbm(wp * 12.0, 3) * cm_aa(30.0, fw) * 0.5;
			rough = 0.8;
		} else if (stone) {
			// stone / concrete: coursed blocks with chiselled faces
			vec2 b = cm_bricks(wp, vec2(0.61, 0.305), 0.012);
			col = base * (0.88 + 0.22 * b.y) * (0.92 + 0.16 * cm_fbm(wp * 2.0, 4));
			h = (1.0 - b.x) * cm_aa(4.0, fw) + cm_fbm(wp * 8.0, 3) * cm_aa(20.0, fw) * 0.5;
			rough = 0.85;
		} else {
			// painted siding / colored storefront walls: lap boards every 15 cm
			float lap = fract(v / 0.152);
			col = base * (0.92 + 0.08 * lap) * (0.95 + 0.08 * cm_fbm(wp * 2.0, 3));
			h = lap * cm_aa(7.0, fw) * 1.5;
			rough = 0.6;
		}
		// weathering: rain streaks below sills, grime at the base, faded patches
		float streak = cm_noise(vec2(u * 6.0, v * 0.25)) * cm_noise(vec2(u * 1.3, v * 0.6));
		col *= 1.0 - smoothstep(0.35, 0.7, streak) * 0.18;
		col *= 0.9 + 0.12 * cm_fbm(wp * 0.15, 3);
		if (modeled && kind != 18) {
			// splash-zone grime at the base, dark drip trails, moss on north faces
			float splash = 1.0 - smoothstep(0.0, 0.9 + 0.4 * cm_noise(vec2(u * 2.0, 0.0)), hb);
			col *= 1.0 - splash * (0.18 + 0.25 * dirt);
			float drip = smoothstep(0.62, 0.9, cm_noise(vec2(u * 9.0, v * 0.35 + cm_hash(vec2(floor(u * 9.0), 1.0)) * 7.0)));
			col *= 1.0 - drip * 0.22 * dirt;
			if (kind == 2 || kind == 3 || kind == 8) {
				float north = clamp(-n.z, 0.0, 1.0);
				float moss = splash * north * smoothstep(0.45, 0.75, cm_fbm(wp * 2.5, 3));
				col = mix(col, vec3(0.08, 0.1, 0.035), moss * 0.6);
				// efflorescence blooms on masonry
				col = mix(col, vec3(0.8, 0.78, 0.72), smoothstep(0.7, 0.9, cm_fbm(wp * 1.7 + 9.0, 4)) * 0.12 * dirt);
			}
		}
		if (windows) {
			// window grid
			float cu = floor(u / bay_w);
			float cv = floor(v / floor_h);
			vec2 cid = vec2(cu, cv);
			float r = cm_hash(cid + 0.37);
			float lu = u - cu * bay_w;          // 0..bay_w
			float lv = v - cv * floor_h;        // 0..floor_h
			float x0 = (bay_w - win_w) * 0.5;
			float fr = 0.07;                    // frame width
			bool inwin = lu > x0 && lu < x0 + win_w && lv > sill && lv < sill + win_h;
			bool inframe = lu > x0 - fr && lu < x0 + win_w + fr && lv > sill - fr && lv < sill + win_h + fr;
			bool insill = lu > x0 - fr - 0.05 && lu < x0 + win_w + fr + 0.05 && lv > sill - fr - 0.06 && lv < sill - fr;
			if (insill) { col = trim * 0.8; h = 1.5 * cm_aa(3.0, fw); rough = 0.7; }
			if (inframe && !inwin) { col = trim * 0.85; h = 2.0 * cm_aa(3.0, fw); rough = 0.55; }
			if (inwin) {
				// muntins (6-over-6 look on brick, plain glass otherwise)
				float wx = (lu - x0) / win_w;
				float wy = (lv - sill) / win_h;
				float mun = 0.0;
				if (brick) {
					float gx = abs(fract(wx * 3.0) - 0.5);
					float gy = abs(fract(wy * 4.0) - 0.5);
					mun = max(step(0.475, gx), step(0.47, gy));
				}
				mun = max(mun, step(0.485, abs(wy - 0.5)) );
				// parallax interior
				vec3 vw = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);   // fragment -> camera, world
				vec3 rd = -vw;
				vec3 lr = vec3(dot(rd, t), rd.y, dot(rd, -n));                    // room-local ray
				vec3 ro = vec3(lu, lv, 0.0);
				vec3 lo = vec3(0.0, 0.0, 0.0);
				vec3 hi = vec3(bay_w, floor_h - 0.35, room_depth);
				vec3 tt = vec3(
					lr.x > 0.0 ? (hi.x - ro.x) / lr.x : (lo.x - ro.x) / min(lr.x, -1e-4),
					lr.y > 0.0 ? (hi.y - ro.y) / lr.y : (lo.y - ro.y) / min(lr.y, -1e-4),
					(hi.z - ro.z) / max(lr.z, 1e-4));
				float tm = min(tt.x, min(tt.y, tt.z));
				vec3 hp = ro + lr * tm;
				float rid = cm_hash(cid + 1.91);
				vec3 wallc = room_wall_color(rid);
				vec3 ic;
				if (tm == tt.y) {
					ic = lr.y > 0.0 ? vec3(0.92, 0.92, 0.9) : (rid > 0.5 ? vec3(0.38, 0.2, 0.09) : vec3(0.12, 0.13, 0.14));
					if (lr.y < 0.0) ic *= 0.85 + 0.15 * cm_noise(hp.xz * 6.0);
				} else if (tm == tt.z) {
					ic = wallc;
					// a dark furniture silhouette against the back wall
					float fx = cm_hash(cid + 3.3) * (bay_w - 1.2);
					if (hp.x > fx && hp.x < fx + 1.2 && hp.y < 0.85 + 0.9 * step(0.5, rid)) ic *= 0.35;
				} else {
					ic = wallc * 0.82;
				}
				// depth darkening
				ic *= mix(1.0, 0.55, clamp(hp.z / room_depth, 0.0, 1.0));
				bool lit = cm_hash(cid + 7.7) < lit_fraction;
				vec3 lamp = mix(warm, cool, step(0.6, cm_hash(cid + 5.1)));
				// ceiling light pool
				float pool = 1.0 - smoothstep(0.0, 2.2, length(hp.xz - vec2(bay_w * 0.5, room_depth * 0.5)));
				vec3 night_c = ic * lamp * (lit ? 0.3 + 0.35 * pool : 0.01);
				vec3 day_c = ic * 0.22;
				vec3 inside = mix(day_c, night_c, cm_night);
				// blinds: some windows half drawn
				float blind = cm_hash(cid + 9.2);
				if (blind > 0.55 && wy > 1.0 - (blind - 0.55) * 1.8) {
					float slat = step(0.5, fract(lv * 28.0));
					inside = vec3(0.75, 0.73, 0.68) * mix(0.25, lit ? 0.4 : 0.02, cm_night) * (0.85 + 0.15 * slat);
				}
				float fres = pow(1.0 - clamp(dot(vw, n), 0.0, 1.0), 4.0);
				col = mun > 0.5 ? trim * 0.85 : vec3(0.015, 0.018, 0.02);
				emis = mun > 0.5 ? vec3(0.0) : inside * (1.0 - fres * 0.85);
				rough = mun > 0.5 ? 0.55 : 0.03;
				spec = mun > 0.5 ? 0.4 : 0.6;
				h = (mun > 0.5 ? 2.0 : -2.0) * cm_aa(3.0, fw);
			}
		}
	}
	float k = 0.004 * clamp(cm_quality, 0.5, 3.0) / 2.0;
	NORMAL = cm_bump(VERTEX, NORMAL, h * k);
	ALBEDO = col;
	ROUGHNESS = rough;
	METALLIC = metal;
	SPECULAR = spec;
	EMISSION = emis;
}
