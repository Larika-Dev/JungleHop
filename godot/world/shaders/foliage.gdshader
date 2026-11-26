// Trees (TreeKit, MultiMesh instanced, unit height). Vertex colors carry bark / leaf palette
// colors. Wind sways crowns (more toward the top, per-tree phase) and flutters leaf cards;
// leaves are translucent against the sun. cards = true draws alpha-cut leaf (or needle) clusters.
shader_type spatial;
render_mode diffuse_burley, cull_disabled;
#include "res://world/shaders/noise.gdshaderinc"

uniform bool cards = false;
uniform bool needles = false;
global uniform vec4 cm_wind;     // xy direction, z gust strength, w time
global uniform float cm_quality;
varying float vh;
varying float vseed;

void vertex() {
	vh = VERTEX.y;
	vec3 origin = MODEL_MATRIX[3].xyz;
	vseed = cm_hash(origin.xz * 0.37);
	float t = cm_wind.w;
	float g = cm_wind.z;
	vec2 dir = normalize(cm_wind.xy);
	// trunk / crown sway: bend grows with height squared
	float bend = vh * vh;
	float sway = (sin(t * 1.1 + vseed * 6.28) * 0.6 + sin(t * 2.3 + vseed * 17.0) * 0.25 + 0.35) * g;
	vec3 off = vec3(dir.x, 0.0, dir.y) * sway * bend * 0.018;
	if (cards) {
		// leaf flutter, per-vertex
		float ph = dot(VERTEX, vec3(37.0, 23.0, 51.0));
		off += NORMAL * sin(t * 7.0 + ph) * 0.004 * g + vec3(0.0, sin(t * 5.3 + ph * 1.7) * 0.003 * g, 0.0);
	}
	// MODEL_MATRIX scales the unit tree; offsets are in unit-tree space.
	VERTEX += off;
}

void fragment() {
	vec3 col = pow(COLOR.rgb, vec3(2.2));   // TreeKit colors are sRGB palette values
	float rough = 0.9;
	if (cards) {
		vec2 uv = UV;
		float a;
		if (needles) {
			// fascicles of long needles fanning from the card's base
			vec2 q = uv - vec2(0.5, 0.0);
			float ang = atan(q.x, q.y);
			float rr = length(q);
			float lanes = abs(fract(ang * 9.0 + cm_hash(floor(vec2(ang * 9.0, 1.0))) * 0.3) - 0.5);
			a = step(lanes, 0.18) * step(rr, 0.95 - 0.25 * cm_hash(vec2(floor(ang * 9.0), 3.0))) * step(0.05, rr);
			col *= 0.75 + 0.45 * rr;
		} else {
			// four leaves per card, each an ellipse with a midrib and serrated-ish edge
			vec2 cell = floor(uv * 3.0);
			vec2 f = fract(uv * 3.0) - 0.5;
			float rot = cm_hash(cell + vseed) * 6.28;
			vec2 r = mat2(vec2(cos(rot), sin(rot)), vec2(-sin(rot), cos(rot))) * f;
			float e = (r.x * r.x) / 0.06 + (r.y * r.y) / 0.22;
			float edge = 1.0 + 0.08 * sin(atan(r.y, r.x) * 14.0);
			a = step(e, edge);
			float rib = 1.0 - smoothstep(0.0, 0.02, abs(r.x));
			float shade = cm_hash(cell + vseed * 3.0);
			col *= (0.8 + 0.35 * shade) * (1.0 - rib * 0.25) * (0.9 + 0.2 * (0.5 - r.y));
		}
		ALPHA = a;
		ALPHA_SCISSOR_THRESHOLD = 0.5;
		rough = 0.55;
		SPECULAR = 0.35;
		BACKLIGHT = col * 0.6;
	} else if (UV.x > 0.5) {
		// the inner crown volume: dark and mottled so cards read in front of it
		col *= 0.55 + 0.35 * cm_fbm(vec2(vh * 18.0 + NORMAL.x * 3.0, vseed * 40.0 + NORMAL.z * 3.0), 3);
		BACKLIGHT = col * 0.3;
	} else {
		// bark: vertical ridges
		float ridge = cm_noise(vec2(atan(NORMAL.x, NORMAL.z) * 9.0, vh * 60.0));
		col *= 0.75 + 0.45 * ridge;
		rough = 0.95;
	}
	// per-tree hue / value variation
	col *= 0.9 + 0.2 * vseed;
	ALBEDO = col;
	ROUGHNESS = rough;
}
