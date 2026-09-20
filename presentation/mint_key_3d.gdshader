shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, blend_mix;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 key_color : source_color = vec3(0.0, 1.0, 0.667);
uniform float tolerance : hint_range(0.02, 0.4, 0.01) = 0.14;
uniform float alpha_mul : hint_range(0.0, 1.0, 0.01) = 1.0;

void fragment() {
	vec4 c = texture(albedo_tex, UV);
	float d = distance(c.rgb, key_color);
	float key_a = 1.0 - smoothstep(tolerance * 0.45, tolerance, d);
	ALBEDO = c.rgb;
	ALPHA = c.a * key_a * alpha_mul;
}
