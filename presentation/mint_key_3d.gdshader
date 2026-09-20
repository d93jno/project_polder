shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, blend_mix;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float chroma_min : hint_range(0.02, 0.4, 0.01) = 0.10;
uniform float chroma_max : hint_range(0.1, 0.8, 0.01) = 0.22;
uniform float alpha_mul : hint_range(0.0, 1.0, 0.01) = 1.0;

void fragment() {
	vec4 c = texture(albedo_tex, UV);
	float chroma = c.g - max(c.r, c.b);
	float keyed = smoothstep(chroma_min, chroma_max, chroma);
	ALBEDO = c.rgb;
	ALPHA = c.a * (1.0 - keyed) * alpha_mul;
}
