shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, unshaded, shadows_disabled, fog_disabled;

#include "res://assets/shaders/water.gdshaderinc"

// Watch volume. Same language for every faction; length is mesh scale, not colour.
// Mesh: ConeMesh, apex at +Y (Godot default). Origin at the watcher after you offset
// by -height/2 on Y and rotate +Y into the look direction.
// v_along 0 = apex, 1 = far. Spent is a tick on the unit — this shader no-ops.

group_uniforms Cone;
uniform int mode : hint_enum("FriendlyOutline", "EnemyLive", "UnresolvedApex", "Spent") = 1;
uniform bool reduced_motion = false;
uniform float cone_height : hint_range(0.2, 40.0, 0.1) = 8.0;
uniform float cone_radius : hint_range(0.1, 20.0, 0.1) = 3.0;
uniform float apex_fade : hint_range(0.05, 0.6, 0.01) = 0.22;
uniform vec3 tint : source_color = vec3(0.55, 0.56, 0.52);
uniform sampler2D hatch_tex : source_color, hint_default_white, filter_linear, repeat_enable;
uniform float hatch_scale : hint_range(0.1, 8.0, 0.05) = 1.1;
uniform float fill_alpha : hint_range(0.0, 0.5, 0.01) = 0.05;
uniform float outline_alpha : hint_range(0.0, 1.0, 0.01) = 0.55;
uniform float ring_count : hint_range(2.0, 16.0, 1.0) = 6.0;
uniform float near_fade_m : hint_range(2.0, 30.0, 0.5) = 10.0;

varying float v_along;
varying float v_radial;
varying vec3 v_world;
varying vec3 v_local;
varying float v_cam_dist;

void vertex() {
	float h = max(cone_height, 0.001);
	v_along = clamp((0.5 * h - VERTEX.y) / h, 0.0, 1.0);
	float slice_r = length(VERTEX.xz);
	float expected = mix(0.001, max(cone_radius, 0.001), max(v_along, 0.02));
	v_radial = clamp(slice_r / expected, 0.0, 1.5);
	v_local = VERTEX;
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_cam_dist = length((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
}

void fragment() {
	if (mode == 3) {
		discard;
	}
	// A long cone that clips the camera near plane becomes a cream wall. Fade it out.
	if (v_cam_dist < near_fade_m * 0.45) {
		discard;
	}

	vec3 n = normalize(NORMAL);
	vec3 v = normalize(VIEW);
	float fres = pow(1.0 - clamp(abs(dot(n, v)), 0.0, 1.0), 2.4);

	float rim = smoothstep(0.88, 0.98, v_radial);
	float rings = polder_ring(v_along, ring_count, 0.07);
	float ang = atan(v_local.z, v_local.x);
	float spokes = polder_ring(ang / TAU + 0.5, 8.0, 0.06);

	float hatch = texture(hatch_tex, v_world.xz * hatch_scale).r;
	if (!reduced_motion) {
		hatch = mix(hatch, texture(hatch_tex, v_world.xz * hatch_scale + vec2(TIME * 0.02, 0.0)).r, 0.25);
	}

	float outline = max(fres, max(rim, max(rings * 0.85, spokes * 0.4)));
	float fill = mix(fill_alpha * 0.55, fill_alpha, hatch);

	float a = 0.0;
	vec3 col = tint;
	if (mode == 0) {
		a = outline * outline_alpha;
	} else {
		a = max(outline * outline_alpha, fill);
		a += rings * 0.08;
	}

	if (mode == 2) {
		float nse = polder_hash12(floor(v_world.xz * 6.0));
		float cut = apex_fade + nse * 0.10;
		float keep = smoothstep(cut - 0.07, cut + 0.12, v_along);
		a *= keep;
		if (keep < 0.02) {
			discard;
		}
	}

	float near = smoothstep(near_fade_m * 0.45, near_fade_m, v_cam_dist);
	ALBEDO = col;
	ALPHA = clamp(a * near, 0.0, 0.45);
}
