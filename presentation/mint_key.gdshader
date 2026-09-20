shader_type canvas_item;

// Drop the mint key (#00FFAA and painterly cousins). Green-dominance, not an
// exact hex — Godot 2D vs 3D disagree on whether source_color is linear.
uniform float chroma_min : hint_range(0.02, 0.4, 0.01) = 0.10;
uniform float chroma_max : hint_range(0.1, 0.8, 0.01) = 0.22;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float chroma = c.g - max(c.r, c.b);
	float keyed = smoothstep(chroma_min, chroma_max, chroma);
	// COLOR already carries texture x the node's modulate (the HUD dims spent pips with it).
	// Only knock the key out of its alpha; assigning COLOR = c would drop the modulate.
	COLOR.a *= 1.0 - keyed;
}
