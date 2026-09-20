shader_type canvas_item;

// Icon contract: filled painterly on mint #00FFAA. Discard the key so HUD can sit on the 9-slice.
uniform vec3 key_color : source_color = vec3(0.0, 1.0, 0.667);
uniform float tolerance : hint_range(0.02, 0.4, 0.01) = 0.14;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float d = distance(c.rgb, key_color);
	c.a *= 1.0 - smoothstep(tolerance * 0.45, tolerance, d);
	COLOR = c;
}
