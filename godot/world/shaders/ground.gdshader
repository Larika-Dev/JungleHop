// City ground: terrain and road surfaces. Base colors are the map's palette vertex colors
// (linear); the shader recognises the surface type from the color and adds PBR detail:
// grass blades and dirt, asphalt aggregate, cracks and patches, concrete slab joints,
// brick paver bond. Terrain holes are cut where a streamed interior stands.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
#include "res://world/shaders/noise.gdshaderinc"

uniform vec4 bld_a[32];   // origin x, origin z, cos(rotY), sin(rotY)
uniform vec4 bld_b[32];   // footprint x, footprint z
uniform int bld_count = 0;


uniform float detail = 1.0;
uniform float lift = 0.0;   // roads sit on the terrain: lift them a little so they never z-fight
global uniform float cm_quality;

void vertex() {
	VERTEX += NORMAL * lift;
}

void fragment() {
	// world position / normal from view space (no extra varyings: keeps the depth prepass and
	// color pass vertex code identical, which avoids depth-equal mismatches on some drivers)
	vec3 wpos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 wnrm = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	for (int i = 0; i < bld_count; i++) {
		vec2 d = wpos.xz - bld_a[i].xy;
		float lx = bld_a[i].z * d.x - bld_a[i].w * d.y;
		float lz = bld_a[i].w * d.x + bld_a[i].z * d.y;
		if (lx > 0.1 && lz > 0.1 && lx < bld_b[i].x - 0.1 && lz < bld_b[i].y - 0.1) {
			discard;
		}
	}
	vec3 base = COLOR.rgb;
	vec2 p = wpos.xz;
	float dist = length(VERTEX);
	float near = 1.0 - smoothstep(25.0, 90.0, dist);      // fine detail fades out with distance
	float mid = 1.0 - smoothstep(120.0, 400.0, dist);
	float fw = max(length(fwidth(p)), 1e-5);              // pixel footprint in meters
	float mx = max(base.r, max(base.g, base.b));
	float mn = min(base.r, min(base.g, base.b));
	float sat = mx > 0.0001 ? (mx - mn) / mx : 0.0;
	bool grass = base.g > base.r * 1.15 && base.g > base.b * 1.6;
	bool marking = base.r > 0.35 && base.b < 0.1 && sat > 0.8;
	bool soil_red = lift <= 0.0 && !grass && !marking && base.r > base.g * 2.2 && mx > 0.08;   // RED_CLAY banks / PINE_STRAW beds on the terrain
	bool brick = !grass && !marking && !soil_red && base.r > base.g * 2.2 && mx > 0.08;
	bool forest = lift <= 0.0 && !grass && !marking && !soil_red && sat > 0.6 && mx < 0.25 && base.b < base.g * 0.45;   // forest floor
	bool asphalt = !grass && !marking && mx < 0.09 && sat < 0.5;
	vec3 col = base;
	float rough = 0.9;
	float h = 0.0;          // height field for the normal
	float spec = 0.4;
	float macro = cm_fbm(p * 0.03, 3);
	float meso = cm_fbm(p * 0.35, 3);
	if (forest || soil_red) {
		// forest floor / clay banks: leaf litter over dark soil, twigs, moss, exposed clay
		vec3 soil = soil_red ? base : vec3(0.1, 0.07, 0.035);
		vec3 leafa = vec3(0.258, 0.102, 0.027);   // FALLEN_LEAF_A, linear
		vec3 leafb = vec3(0.434, 0.254, 0.027);   // FALLEN_LEAF_B
		vec3 moss = vec3(0.075, 0.11, 0.025);     // MOSS
		float litter = smoothstep(0.35, 0.65, cm_fbm(p * 0.25 + 3.0, 3));
		vec2 lc = cm_voronoi(p * 9.0);
		float leaf = mix(0.5, step(0.08, lc.x), cm_aa(9.0, fw));   // leaf-sized cells, dark gaps
		vec3 lcol = mix(leafa, leafb, lc.y) * (0.7 + 0.5 * cm_hash(floor(p * 9.0)));
		col = mix(soil * (0.8 + 0.4 * meso), lcol * (0.6 + 0.4 * leaf), soil_red ? litter * 0.35 : 0.55 + 0.4 * litter);
		col = mix(col, moss, smoothstep(0.62, 0.8, cm_fbm(p * 0.7 + 11.0, 3)) * 0.5);
		float twig = 1.0 - smoothstep(0.0, 0.02 + fw, abs(cm_noise(p * vec2(1.3, 11.0)) - 0.5));
		col *= 1.0 - twig * 0.3 * cm_aa(11.0, fw) * near;
		rough = 0.95;
		h = leaf * 0.006 * cm_aa(9.0, fw) + meso * 0.02;
		spec = 0.3;
	} else if (grass) {
		// patchy lawns: lush/dry hue shifts, worn dirt, clover clumps, leaf litter under trees
		vec3 worn = vec3(0.21, 0.25, 0.075);     // GRASS_WORN, linear
		vec3 dirt = vec3(0.26, 0.2, 0.11);       // DIRT_PATH, linear
		vec3 leaf = vec3(0.26, 0.1, 0.027);      // FALLEN_LEAF_MIX, linear
		col = mix(base * 0.72, base * 1.0, smoothstep(0.3, 0.7, macro));
		col = mix(col, worn, smoothstep(0.55, 0.75, meso) * 0.55);
		col = mix(col, dirt, smoothstep(0.72, 0.82, cm_fbm(p * 0.12 + 4.0, 4)) * 0.6);
		col = mix(col, leaf, smoothstep(0.68, 0.8, cm_fbm(p * 0.6 + 9.0, 3)) * 0.35);
		float blades = mix(0.5, cm_noise(p * 38.0), cm_aa(38.0, fw)) * 0.6 + mix(0.5, cm_noise(p * 90.0), cm_aa(90.0, fw)) * 0.4;
		col *= 0.85 + 0.3 * blades;
		h = blades * 0.004 * cm_aa(38.0, fw) + meso * 0.01;
		rough = 0.95;
		spec = 0.3;
	} else if (asphalt) {
		// aggregate speckle, polish in wheel paths, crack network and sealed patches
		float agg = mix(0.5, cm_noise(p * 120.0), cm_aa(120.0, fw));
		float grit = mix(0.5, cm_noise(p * 300.0), cm_aa(300.0, fw));
		col = base * (0.85 + 0.25 * macro + 0.3 * (agg - 0.5) + 0.15 * (grit - 0.5));
		vec2 vc = cm_voronoi(p * 0.35);
		// hairline cracks, only in patches and broken along their length
		float crack = (1.0 - smoothstep(0.0, 0.012 + fw * 0.3, vc.x)) * smoothstep(0.62, 0.8, cm_fbm(p * 0.08, 3)) * step(0.4, cm_noise(p * 1.7)) * mid * cm_aa(8.0, fw);
		vec3 patch_col = vec3(0.039, 0.041, 0.044);   // ASPHALT_PATCH, linear
		float patchm = step(0.82, vc.y) * smoothstep(0.62, 0.66, cm_fbm(p * 0.2 + 2.0, 2));
		col = mix(col, patch_col, patchm * 0.8);
		col = mix(col, vec3(0.018), crack * 0.7);
		rough = 0.82 - 0.12 * smoothstep(0.4, 0.8, macro) + 0.1 * grit;
		h = (agg - 0.5) * 0.0008 * cm_aa(120.0, fw) + (grit - 0.5) * 0.0003 * cm_aa(300.0, fw) - crack * 0.004;
		spec = 0.45;
	} else if (brick) {
		// brick pavers 20 x 10 cm, running bond, sand joints, a few darker / lighter units
		vec2 b = cm_bricks(p, vec2(0.203, 0.103), 0.006);
		float ba = cm_aa(10.0, fw);
		vec3 sand = vec3(0.37, 0.33, 0.26);
		col = base * (0.85 + 0.3 * mix(0.5, b.y, cm_aa(5.0, fw))) * (0.92 + 0.16 * meso);
		col = mix(col, sand * 0.6, b.x * ba * 0.8);
		rough = mix(0.8 + 0.1 * b.y, 0.95, b.x * ba);
		h = (1.0 - b.x) * 0.003 * ba;
	} else if (marking) {
		col = base * (0.85 + 0.2 * mix(0.5, cm_noise(p * 40.0), cm_aa(40.0, fw)));   // worn paint
		col = mix(col, vec3(0.03), smoothstep(0.62, 0.8, cm_fbm(p * 3.0, 3)) * 0.6);
		rough = 0.6;
		h = 0.0;
	} else {
		// concrete: broom finish, slab joints every 1.5 m, stains
		vec2 g = fract(p / 1.524);
		vec2 e = min(g, 1.0 - g) * 1.524;
		float joint = (1.0 - smoothstep(0.004, 0.01 + fw, min(e.x, e.y))) * cm_aa(3.0, fw);
		float broom = mix(0.5, cm_noise(vec2(p.x * 2.0, p.y * 140.0)), cm_aa(140.0, fw));
		col = base * (0.88 + 0.2 * macro + 0.08 * (broom - 0.5));
		col = mix(col, base * 0.55, smoothstep(0.68, 0.85, cm_fbm(p * 0.5 + 5.0, 4)) * 0.5);   // stains
		col *= 1.0 - joint * 0.5;
		rough = 0.88 + 0.08 * broom;
		h = (broom - 0.5) * 0.0003 * cm_aa(140.0, fw) - joint * 0.003;
	}
	// bump from the height field (h in meters of relief)
	NORMAL = cm_bump(VERTEX, NORMAL, h * detail);
	ALBEDO = col;
	ROUGHNESS = clamp(rough, 0.05, 1.0);
	SPECULAR = spec;
}
