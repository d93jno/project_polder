shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, diffuse_burley, specular_schlick_ggx;

#include "res://assets/shaders/water.gdshaderinc"

// One plane per bowl. Engine sets `step` and `water_height` from data.
// Draws before every other transparent thing (render_priority in water.tres) and writes no
// depth, so path tiles, fog veils and the selection ring that sit under the surface still show.
// Drop a PlaneMesh on a MeshInstance3D, assign water.tres, set node Y to water_height
// (leave displace_to_height off) OR enable displace_to_height and leave the node at y=0.

group_uniforms Step;
uniform int step : hint_enum("Flooded", "Falling", "Mud", "Dry") = 0;
uniform float water_height : hint_range(-2.0, 8.0, 0.01) = 2.0;
uniform bool reduced_motion = false;
uniform bool displace_to_height = false;

group_uniforms Albedo;
uniform sampler2D albedo_flooded : source_color, filter_linear, repeat_enable;
uniform sampler2D albedo_falling : source_color, filter_linear, repeat_enable;
uniform sampler2D albedo_mud : source_color, filter_linear, repeat_enable;
uniform sampler2D albedo_dry : source_color, filter_linear, repeat_enable;
uniform float uv_scale : hint_range(0.05, 2.0, 0.01) = 0.25;

// Can the bottom be seen? Deep water is close to opaque, so a swimmer's legs and the street are
// gone. Chest-deep water is murky but you can see the slabs through it. That "is the bottom
// there" read carries Flooded against Falling without colour or motion (UI 3, UI 14).
group_uniforms Opacity;
uniform float opacity_flooded : hint_range(0.0, 1.0, 0.01) = 0.94;
uniform float opacity_falling : hint_range(0.0, 1.0, 0.01) = 0.58;
uniform float opacity_mud : hint_range(0.0, 1.0, 0.01) = 1.0;

group_uniforms Motion;
uniform float flood_speed : hint_range(0.0, 4.0, 0.01) = 1.0;
uniform float falling_speed : hint_range(0.0, 4.0, 0.01) = 0.28;
uniform float flood_wave_cm : hint_range(0.0, 12.0, 0.1) = 4.0;

varying vec2 v_world_xz;

void vertex() {
	if (displace_to_height) {
		VERTEX.y = water_height;
	}
	if (!reduced_motion) {
		if (step == WATER_FLOODED) {
			float a = flood_wave_cm * 0.01;
			VERTEX.y += a * sin(VERTEX.x * 2.2 + TIME * 1.15) * cos(VERTEX.z * 1.6 + TIME * 0.82);
		} else if (step == WATER_FALLING) {
			float a = flood_wave_cm * 0.003;
			VERTEX.y += a * sin(VERTEX.x * 3.1 + TIME * 0.45);
		}
	}
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
	float speed = 0.0;
	if (step == WATER_FLOODED) {
		speed = flood_speed;
	} else if (step == WATER_FALLING) {
		speed = falling_speed;
	}

	vec2 uv = polder_water_uv(v_world_xz, uv_scale, TIME, speed, reduced_motion);
	vec3 alb = polder_sample_step(step, uv);

	if (step == WATER_FLOODED && !reduced_motion) {
		vec2 uv2 = polder_water_uv(v_world_xz, uv_scale * 0.73, TIME, speed * 0.55, false);
		alb = mix(alb, polder_sample_step(step, uv2), 0.28);
	}

	if (step == WATER_FALLING) {
		// Debris lives in the albedo. A second static sample keeps it when motion is off.
		vec2 uv_deb = v_world_xz * uv_scale + vec2(0.37, 0.19);
		vec3 deb = texture(albedo_falling, uv_deb).rgb;
		float d = smoothstep(0.10, 0.22, abs(polder_luma(deb) - polder_luma(alb)));
		alb = mix(alb, deb, d * 0.35);
	}

	ALBEDO = alb;

	if (step == WATER_FLOODED) {
		ROUGHNESS = 0.07;
		SPECULAR = 0.72;
		METALLIC = 0.0;
		RIM = 0.18;
		RIM_TINT = 0.4;
	} else if (step == WATER_FALLING) {
		ROUGHNESS = 0.22;
		SPECULAR = 0.42;
		METALLIC = 0.0;
		RIM = 0.08;
	} else if (step == WATER_MUD) {
		float wet = 1.0 - smoothstep(0.42, 0.70, polder_luma(alb));
		ROUGHNESS = mix(0.58, 0.22, wet);
		SPECULAR = mix(0.22, 0.48, wet);
		METALLIC = 0.0;
	} else {
		ROUGHNESS = 0.84;
		SPECULAR = 0.16;
		METALLIC = 0.0;
	}

	if (step == WATER_FLOODED) {
		ALPHA = opacity_flooded;
	} else if (step == WATER_FALLING) {
		ALPHA = opacity_falling;
	} else {
		ALPHA = opacity_mud;
	}
}
