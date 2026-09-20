shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, shadows_disabled, fog_disabled;

#include "res://assets/shaders/water.gdshaderinc"

// Redirection preview overlay. Transparent. Never fade-to-black.
// `is_range`: half-fixed ring — "this is a range", not a precise fill.

group_uniforms Preview;
uniform int step : hint_enum("Flooded", "Falling", "Mud", "Dry") = 0;
uniform bool is_range = false;
uniform bool reduced_motion = false;
uniform float ghost_alpha : hint_range(0.05, 0.8, 0.01) = 0.38;

group_uniforms Albedo;
uniform sampler2D albedo_flooded : source_color, filter_linear, repeat_enable;
uniform sampler2D albedo_falling : source_color, filter_linear, repeat_enable;
uniform sampler2D albedo_mud : source_color, filter_linear, repeat_enable;
uniform sampler2D albedo_dry : source_color, filter_linear, repeat_enable;
uniform sampler2D hatch_tex : source_color, hint_default_white, filter_linear, repeat_enable;
uniform float uv_scale : hint_range(0.05, 2.0, 0.01) = 0.25;
uniform vec3 tint : source_color = vec3(0.78, 0.80, 0.82);

varying vec2 v_world_xz;

void vertex() {
	v_world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

vec3 polder_sample_step(int s, vec2 uv) {
	if (s <= WATER_FLOODED) {
		return texture(albedo_flooded, uv).rgb;
	}
	if (s == WATER_FALLING) {
		return texture(albedo_falling, uv).rgb;
	}
	if (s == WATER_MUD) {
		return texture(albedo_mud, uv).rgb;
	}
	return texture(albedo_dry, uv).rgb;
}

void fragment() {
	vec2 uv = v_world_xz * uv_scale;
	vec3 alb = polder_sample_step(step, uv);
	alb = mix(alb, tint, 0.35);

	float hatch = texture(hatch_tex, v_world_xz * 0.55).r;
	float pattern = mix(0.65, 1.0, hatch);

	float rings = polder_ring(length(v_world_xz), 0.28, 0.10);
	float dash = step(0.35, fract(atan(v_world_xz.y, v_world_xz.x) * 5.092958));
	if (reduced_motion) {
		dash = 1.0;
	}

	float a = ghost_alpha * pattern;
	if (is_range) {
		float range_mark = max(rings * dash, hatch * 0.25);
		a = ghost_alpha * (0.45 + 0.55 * range_mark);
		alb = mix(tint, alb, 0.4);
	} else {
		a *= mix(0.85, 1.0, rings * 0.5);
	}

	ALBEDO = alb;
	ALPHA = clamp(a, 0.0, 0.72);
}
