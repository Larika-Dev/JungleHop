// NPC skin, hair, eyes and clothing on one shared body mesh.
// The mesh carries rest-pose coordinates: UV.x = body part (+0.5 on the right
// side), UV.y = height / standing height, UV2.x = angle around the part
// (0..1, 0.75 faces forward), UV2.y = position along the part.
shader_type spatial;
render_mode cull_back, depth_draw_opaque;

uniform vec3 skin_color : source_color = vec3(0.8, 0.6, 0.5);
uniform vec3 hair_color : source_color = vec3(0.1, 0.07, 0.05);
uniform vec3 eye_color : source_color = vec3(0.3, 0.2, 0.1);
uniform vec3 top_color : source_color = vec3(0.2, 0.3, 0.5);
uniform vec3 bottom_color : source_color = vec3(0.15, 0.15, 0.2);
uniform vec3 shoe_color : source_color = vec3(0.9);
uniform float bottom_cut = 0.055;   // hem height, fraction of standing height
uniform float sleeve_cut = 0.71;
uniform float hair_front = 0.968;   // hairline height at the forehead
uniform float hair_side = 0.948;
uniform float hair_back = 0.905;    // lowest hair at the back of the head
uniform float hair_amount = 1.0;    // 0 = bald, 0.5 = buzz cut
uniform float stubble = 0.0;       // 0 clean shaven .. 1 full beard (grooming)
uniform float detail = 1.0;         // 1 close up, 0 far: fades 1 mm pore/weave detail

varying vec3 rest_info;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

void fragment() {
	int part = int(floor(UV.x + 0.01));
	float yn = UV.y;
	float th = UV2.x * 360.0;
	float df = abs(th - 270.0);          // degrees away from facing forward
	vec3 col = skin_color;
	float rough = 0.55;
	float spec = 0.4;
	int mat = 0;                          // 0 skin, 1 top, 2 bottom, 3 shoe, 4 hair, 5 eye, 6 lip
	if (part == 0) {                      // torso
		mat = yn > 0.822 ? 0 : (yn > 0.565 ? 1 : 2);
	} else if (part == 1) {               // leg
		mat = yn > bottom_cut ? 2 : 0;
	} else if (part == 2) {               // arm
		mat = yn > sleeve_cut ? 1 : 0;
	} else if (part == 4) {               // foot
		mat = 3;
	} else if (part == 3) {               // head
		float line = df < 40.0 ? mix(hair_front, hair_side, smoothstep(20.0, 40.0, df))
			: (df < 110.0 ? mix(hair_side, hair_back, smoothstep(70.0, 110.0, df)) : hair_back);
		if (hair_amount > 0.01 && yn > line) mat = 4;
		for (int e = 0; e < 2; e++) {
			float ec = e == 0 ? 251.0 : 289.0;
			float ex = (th - ec) / 9.5;             // 1 = half the eye width (about 13 mm)
			float ey = (yn - 0.938) / 0.0028;       // 1 = half the eye height (about 5 mm)
			if (abs(ex) < 1.0 && abs(ey) < 1.0 - ex * ex) {
				mat = 5;
				float ir = length(vec2(ex / 0.45, ey / 1.2));
				col = ir < 1.0 ? (ir < 0.38 ? vec3(0.02) : eye_color * (0.8 + 0.4 * ir)) : vec3(0.93, 0.91, 0.88);
			}
		}
		if (stubble > 0.01 && mat == 0 && yn < 0.912 && df < 75.0 && !(df < 13.0 && abs(yn - 0.9015) < 0.005)) {
			float edge = smoothstep(0.912, 0.904, yn) * smoothstep(75.0, 60.0, df);
			float dots = step(1.0 - stubble * 0.9, vnoise(vec2(UV2.x * 2400.0, yn * 8000.0)));
			col = mix(col, hair_color * 0.8, edge * mix(dots * 0.6, 0.9, smoothstep(0.6, 1.0, stubble)));
		}
		float lip = (df / 11.0) * (df / 11.0) + pow((yn - 0.9015) / 0.0034, 2.0);
		if (lip < 1.0) mat = 6;
		if (df > 9.0 && df < 27.0 && abs(yn - 0.9485 - (df - 9.0) * 0.00005) < 0.0016) { mat = 4; }
	}
	vec2 fine = vec2(UV2.x * 520.0, yn * 1700.0);   // roughly 1 mm cells on a body
	float n1 = vnoise(fine) * 2.0 - 1.0;
	float n2 = vnoise(fine * 0.27) * 2.0 - 1.0;
	if (mat == 0) {
		col *= 1.0 + 0.035 * n2 * detail + 0.02 * n1 * detail;
		rough = 0.52 + 0.12 * n1 * detail;
		spec = 0.35;
	} else if (mat == 1 || mat == 2) {
		col = mat == 1 ? top_color : bottom_color;
		float weave = sin(fine.x * 3.1) * sin(fine.y * 2.3);
		col *= 1.0 + 0.05 * weave * detail + 0.03 * n2;
		rough = 0.85;
		spec = 0.2;
	} else if (mat == 3) {
		col = yn < 0.004 ? shoe_color * 0.35 : shoe_color;
		rough = 0.6;
	} else if (mat == 4) {
		float strands = vnoise(vec2(UV2.x * 900.0, yn * 160.0));
		col = hair_color * (0.75 + 0.5 * strands * detail);
		if (hair_amount < 0.75) col = mix(skin_color, col, hair_amount * 1.2);
		rough = 0.45;
		spec = 0.5;
	} else if (mat == 5) {
		rough = 0.08;
		spec = 0.6;
	} else if (mat == 6) {
		col = mix(skin_color, vec3(0.62, 0.32, 0.32), 0.35) * 0.92;
		rough = 0.35;
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = spec;
	if (mat == 0) {
		SSS_STRENGTH = 0.0;
	}
}
