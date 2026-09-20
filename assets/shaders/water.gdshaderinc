#ifndef POLDER_WATER_INC
#define POLDER_WATER_INC

const int WATER_FLOODED = 0;
const int WATER_FALLING = 1;
const int WATER_MUD = 2;
const int WATER_DRY = 3;

vec2 polder_water_uv(vec2 world_xz, float scale, float time, float speed, bool reduced_motion) {
	vec2 uv = world_xz * scale;
	if (!reduced_motion && speed > 0.0) {
		uv += vec2(time * speed * 0.031, time * speed * 0.017);
	}
	return uv;
}

float polder_hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float polder_hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float polder_luma(vec3 c) {
	return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

float polder_ring(float x, float count, float width) {
	float f = abs(fract(x * count) - 0.5);
	return 1.0 - smoothstep(0.0, width, f);
}

#endif
