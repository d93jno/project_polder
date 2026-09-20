shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, unshaded, shadows_disabled, fog_disabled;

#include "res://assets/shaders/water.gdshaderinc"

// Known-quiet ageing. Unknown is "draw nothing" (engine). Live is staleness = 0.
// Dust, flatter colour, colder marks. No day-count digits.
// Reduced motion: grade holds; drift is extra, not the carrier.

group_uniforms Ageing;
uniform float staleness : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform bool reduced_motion = false;
uniform vec3 dust_tint : source_color = vec3(0.62, 0.60, 0.56);
uniform vec3 cold_tint : source_color = vec3(0.46, 0.52, 0.56);
uniform float veil : hint_range(0.0, 0.7, 0.01) = 0.34;
uniform float dust_scale : hint_range(1.0, 64.0, 0.5) = 18.0;

varying vec2 v_world_xz;

void vertex() {
	v_world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	if (staleness <= 0.001) {
		discard;
	}

	vec2 gp = v_world_xz * dust_scale;
	if (!reduced_motion) {
		gp += vec2(TIME * 0.03, TIME * -0.017);
	}
	float cell = polder_hash12(floor(gp));
	float fine = polder_hash12(gp * 3.1);
	float dust = smoothstep(0.62, 0.92, cell) * mix(0.4, 1.0, fine);

	vec3 grade = mix(dust_tint, cold_tint, staleness);
	ALBEDO = mix(grade, grade * 0.78, dust * 0.65);
	ALPHA = staleness * (veil + dust * 0.16);
}
