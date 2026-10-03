shader_type particles;
render_mode disable_force, disable_velocity;

uniform vec3 source_position = vec3(0.0);
uniform vec3 target_position = vec3(-4.0, 0.0, 0.0);
uniform float radius = 0.35;
uniform int effect_kind = 0; // 0: suction, 1: flame, 2: spark, 3: smoke.
uniform bool enabled = false;

float random_value(float seed) {
	return fract(sin(seed * 12.9898 + 78.233) * 43758.5453);
}

void start() {
	float seed = float(NUMBER) + float(RANDOM_SEED % 65536u);
	CUSTOM = vec4(0.0, random_value(seed) * 6.2831853,
		random_value(seed + 2.3), mix(0.7, 1.0, random_value(seed + 7.1)));
	TRANSFORM = mat4(1.0);
}

void process() {
	CUSTOM.x += DELTA;
	float age = CUSTOM.x / max(LIFETIME * CUSTOM.w, 0.001);
	if (!enabled || age >= 1.0) {
		ACTIVE = false;
	} else {
		vec3 axis = normalize(target_position - source_position);
		vec3 reference = abs(axis.y) > 0.95 ? vec3(1.0, 0.0, 0.0) : vec3(0.0, 1.0, 0.0);
		vec3 side = normalize(cross(axis, reference));
		vec3 up = cross(side, axis);
		bool inward = effect_kind == 0;
		float progress = inward ? 1.0 - age : age;
		float spread = inward ? radius * progress : radius * mix(0.08, 1.0, progress);
		float angle = CUSTOM.y + age * (inward ? 3.0 : 0.8);
		vec3 offset = (side * cos(angle) + up * sin(angle)) * spread * sqrt(CUSTOM.z);
		vec3 position = mix(source_position, target_position, progress) + offset;
		if (effect_kind == 3) {
			position.y += age * age * 0.18;
		}
		float fade = smoothstep(0.0, 0.12, age) * (1.0 - smoothstep(0.65, 1.0, age));
		float stroke_scale = clamp(radius / 0.35, 0.6, 2.2);
		float width = inward ? 0.065 * stroke_scale : mix(0.18, 0.30, progress) * sqrt(stroke_scale);
		float height = inward ? 0.34 * sqrt(stroke_scale) : 0.48;
		if (effect_kind == 2) {
			width = 0.035;
			height = 0.10;
		} else if (effect_kind == 3) {
			width = mix(0.16, 0.38, age);
			height = width;
		}
		float size = mix(0.7, 1.2, CUSTOM.z);
		TRANSFORM = mat4(1.0);
		TRANSFORM[0].x = width * size;
		TRANSFORM[1].y = height * size;
		TRANSFORM[2].z = width * size;
		TRANSFORM[3].xyz = position;
		COLOR = vec4(1.0, 1.0, 1.0, fade);
	}
}
