// Grass blades (GrassField clumps). Instance color = the lawn's palette color (linear) and a
// random value in alpha. Blades bend with the wind, darken toward the root (self shadowing),
// glow when backlit, and shrink to nothing at the edge of the grass radius so there is no pop.
shader_type spatial;
render_mode cull_disabled, diffuse_burley;
#include "res://world/shaders/noise.gdshaderinc"

uniform float fade_end = 40.0;
global uniform vec4 cm_wind;
varying vec3 tint;
varying float rnd;
varying float vy;

void vertex() {
	tint = COLOR.rgb;
	rnd = COLOR.a;
	vy = UV.y;
	vec3 origin = MODEL_MATRIX[3].xyz;
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float d = distance(wp, (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz);
	float keep = 1.0 - smoothstep(fade_end * 0.7, fade_end, d);
	VERTEX.y *= keep;
	float t = cm_wind.w;
	vec2 dir = normalize(cm_wind.xy);
	// rolling gust waves across the lawn
	float wave = sin(dot(wp.xz, dir) * 0.35 - t * 2.2) * 0.5 + 0.5;
	float flick = sin(t * 6.0 + rnd * 40.0 + wp.x * 2.0) * 0.25;
	float bend = (wave * cm_wind.z + flick * 0.4) * UV.y * UV.y * 0.09;
	VERTEX.xz += (inverse(mat3(MODEL_MATRIX)) * vec3(dir.x, 0.0, dir.y)).xz * bend;
}

void fragment() {
	vec3 tip = mix(tint * 1.05, vec3(0.2, 0.17, 0.06), 0.4 * step(0.7, rnd));   // some dry tips
	vec3 col = mix(tint * 0.3, tip, smoothstep(0.0, 0.9, vy));
	col *= 0.8 + 0.25 * rnd;
	ALBEDO = col;
	ROUGHNESS = 0.7;
	SPECULAR = 0.3;
	BACKLIGHT = col * 0.5;
	AO = mix(0.4, 1.0, vy);
	AO_LIGHT_AFFECT = 0.5;
}
