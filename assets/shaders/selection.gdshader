shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, shadows_disabled, fog_disabled;

#include "res://assets/shaders/water.gdshaderinc"

// Ground mark under a unit. Same for every body. Not a founder crown.
// Mesh: PlaneMesh on XZ, a few cm above the tile, ~1.2 m across.

group_uniforms Mark;
uniform vec3 tint : source_color = vec3(0.90, 0.88, 0.80);
uniform sampler2D ring_tex : source_color, hint_default_transparent, filter_linear, repeat_disable;
uniform bool use_ring_tex = true;
uniform float inner : hint_range(0.15, 0.7, 0.01) = 0.42;
uniform float outer : hint_range(0.4, 0.98, 0.01) = 0.86;
uniform float alpha : hint_range(0.1, 1.0, 0.01) = 0.85;
uniform bool reduced_motion = false;

varying vec2 v_uv;

void vertex() {
	v_uv = UV;
}

void fragment() {
	vec2 p = v_uv * 2.0 - 1.0;
	float r = length(p);

	float a = 0.0;
	if (use_ring_tex) {
		vec4 t = texture(ring_tex, v_uv);
		a = t.a * alpha;
		ALBEDO = mix(tint, t.rgb, 0.55);
	} else {
		float band_a = smoothstep(inner, inner + 0.05, r) * (1.0 - smoothstep(outer - 0.06, outer, r));
		float band_b = smoothstep(inner - 0.16, inner - 0.12, r) * (1.0 - smoothstep(inner - 0.04, inner, r));
		float rings = polder_ring(r, 9.0, 0.08);
		a = max(band_a, band_b * 0.7) * alpha;
		a *= mix(0.75, 1.0, rings);
		ALBEDO = tint;
	}

	if (r > 0.98) {
		discard;
	}

	ALPHA = clamp(a, 0.0, 1.0);
}
